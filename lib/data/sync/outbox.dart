/// Local write queue for offline field work.
///
/// Server RPCs already accept client UUIDs for idempotent retries. This layer
/// holds the RPC name + params on the phone until connectivity returns, then
/// flushes in order. Prefer a JSON list in SharedPreferences over Drift so
/// the outbox ships without codegen.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/errors.dart';
import '../remote/backend.dart';

/// Known outbox kinds. Values are the RPC names (or close aliases).
abstract final class OutboxKind {
  static const completeVisit = 'complete_visit';
  static const createOrUpdateExpense = 'create_or_update_expense';
  static const submitExpense = 'submit_expense';
  static const submitDayPlan = 'submit_day_plan';
}

class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.label,
    this.refusedReason,
  });

  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Short title for Sync Centre (e.g. "Visit — Dr. Sharma").
  final String? label;

  /// What the server said when it refused this, if it did.
  ///
  /// A refusal is not a retry: the server understood the call and said no, and
  /// it will say no again tomorrow. Set aside so the rest of the queue can
  /// drain past it, and shown to the rep — work that will never arrive has to
  /// say so, because the alternative is a day that quietly never syncs.
  final String? refusedReason;

  bool get isRefused => refusedReason != null;

  OutboxItem refusedWith(String reason) => OutboxItem(
        id: id,
        kind: kind,
        payload: payload,
        createdAt: createdAt,
        label: label,
        refusedReason: reason,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        if (label != null) 'label': label,
        if (refusedReason != null) 'refusedReason': refusedReason,
      };

  factory OutboxItem.fromJson(Map<String, dynamic> j) => OutboxItem(
        id: j['id'] as String,
        kind: j['kind'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        label: j['label'] as String?,
        refusedReason: j['refusedReason'] as String?,
      );

  String get displayTitle {
    if (label != null && label!.isNotEmpty) return label!;
    switch (kind) {
      case OutboxKind.completeVisit:
        return 'Visit completion';
      case OutboxKind.createOrUpdateExpense:
        return 'Expense draft';
      case OutboxKind.submitExpense:
        return 'Expense submit';
      case OutboxKind.submitDayPlan:
        return 'Day plan';
      default:
        return kind;
    }
  }
}

/// Persistent FIFO of pending RPC calls.
class OutboxStore {
  OutboxStore();

  static const _prefsKey = 'mrsales_outbox_v1';
  final _uuid = const Uuid();
  final _revision = ValueNotifier<int>(0);

  ValueListenable<int> get revision => _revision;

  List<OutboxItem> _items = const [];
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _items = const [];
    } else {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _items = [
          for (final e in list)
            OutboxItem.fromJson(Map<String, dynamic>.from(e as Map)),
        ];
      } catch (_) {
        _items = const [];
      }
    }
    _loaded = true;
  }

  Future<List<OutboxItem>> list() async {
    await ensureLoaded();
    return List.unmodifiable(_items);
  }

  /// Pending only — a refused item is not waiting for anything.
  Future<int> count() async {
    await ensureLoaded();
    return _items.where((i) => !i.isRefused).length;
  }

  Future<OutboxItem> enqueue({
    required String kind,
    required Map<String, dynamic> payload,
    String? id,
    String? label,
  }) async {
    await ensureLoaded();
    final item = OutboxItem(
      id: id ?? _uuid.v4(),
      kind: kind,
      payload: payload,
      createdAt: DateTime.now(),
      label: label,
    );
    _items = [..._items, item];
    await _persist();
    return item;
  }

  /// Everything still expected to reach the server.
  Future<List<OutboxItem>> pending() async {
    await ensureLoaded();
    return [for (final i in _items) if (!i.isRefused) i];
  }

  /// Everything the server has refused. These need a person, not a retry.
  Future<List<OutboxItem>> refused() async {
    await ensureLoaded();
    return [for (final i in _items) if (i.isRefused) i];
  }

  Future<void> markRefused(String id, String reason) async {
    await ensureLoaded();
    _items = [
      for (final i in _items) if (i.id == id) i.refusedWith(reason) else i,
    ];
    await _persist();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _items = [for (final i in _items) if (i.id != id) i];
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([for (final i in _items) i.toJson()]),
    );
    _revision.value++;
  }
}

/// What one pass of the outbox achieved.
class FlushResult {
  const FlushResult({this.sent = 0, this.refused = 0, this.stalled = false});

  /// Reached the server and was accepted.
  final int sent;

  /// Reached the server and was turned down. These will not retry.
  final int refused;

  /// Stopped early because the server could not be reached. The rest of the
  /// queue is untouched and in order.
  final bool stalled;

  int get handled => sent + refused;
}

/// Flushes the outbox against Supabase RPCs when online and live.
class OutboxFlusher {
  OutboxFlusher(this.store, {this.send, this.enabled});

  final OutboxStore store;

  /// How an item reaches the server. Injectable so the retry/refuse decision —
  /// the part with the teeth — can be tested without a network.
  final Future<void> Function(OutboxItem)? send;

  /// Overrides the `isLive` check, for the same reason.
  final bool? enabled;

  bool get _on => enabled ?? isLive;

  bool _flushing = false;

  /// Sends what is waiting, and says what happened.
  ///
  /// The two kinds of failure are not the same thing, and treating them the
  /// same is how a queue dies:
  ///
  ///   * **Could not reach the server** — a flat network, a timeout, a 5xx.
  ///     Stop, keep the order, try again later. This is the normal case in the
  ///     field and it resolves itself.
  ///   * **The server refused** — it understood the call and said no. Retrying
  ///     it tonight, tomorrow and next week produces the same no. Set it aside
  ///     and carry on with the rest.
  ///
  /// Stopping on *both* was the bug: one permanently refused visit sat at the
  /// head of the queue and every day of work behind it stayed on the phone,
  /// while Sync Centre said "Connected" and "Try again shortly".
  Future<FlushResult> flush() async {
    if (!_on || _flushing) return const FlushResult();
    _flushing = true;
    var sent = 0;
    var refused = 0;
    try {
      for (final item in await store.pending()) {
        try {
          await _dispatch(item);
          await store.remove(item.id);
          sent++;
        } on PostgrestException catch (e) {
          if (_isRefusal(e)) {
            await store.markRefused(
              item.id,
              readablePostgrestError(e, fallback: 'The server refused this.'),
            );
            refused++;
            continue;
          }
          debugPrint('Outbox: could not reach the server for ${item.kind}: $e');
          return FlushResult(sent: sent, refused: refused, stalled: true);
        } catch (e, st) {
          // Anything else is "could not get there" until proven otherwise.
          // Guessing that an unrecognised error is permanent would throw work
          // away, and work is the one thing here that cannot be recreated.
          debugPrint('Outbox: ${item.kind} did not go through: $e\n$st');
          return FlushResult(sent: sent, refused: refused, stalled: true);
        }
      }
    } finally {
      _flushing = false;
    }
    return FlushResult(sent: sent, refused: refused);
  }

  /// Did the server understand and say no?
  ///
  /// PostgREST answers 4xx when it did — a failed check, a raised exception in
  /// an RPC, a row that RLS will not let through. 5xx and 408 are the server
  /// having a bad time, which is a retry. A `PostgrestException` with no code
  /// at all is usually a transport problem wearing the wrong coat, so it is
  /// treated as a retry too.
  static bool _isRefusal(PostgrestException e) {
    final status = e.code == null ? null : int.tryParse(e.code!);
    if (status == null) return false;
    if (status == 408 || status == 429) return false;
    return status >= 400 && status < 500;
  }

  Future<void> _dispatch(OutboxItem item) async {
    final injected = send;
    if (injected != null) return injected(item);
    final SupabaseClient client = db;
    switch (item.kind) {
      case OutboxKind.completeVisit:
        await client.rpc('complete_visit', params: item.payload);
      case OutboxKind.createOrUpdateExpense:
        await client.rpc('create_or_update_expense', params: item.payload);
      case OutboxKind.submitExpense:
        await client.rpc('submit_expense', params: item.payload);
      case OutboxKind.submitDayPlan:
        await client.rpc('submit_day_plan', params: item.payload);
      default:
        throw StateError('Unknown outbox kind: ${item.kind}');
    }
  }
}

/// What the outbox does when the server says no.
///
/// The queue is the only copy of a day's field work, so the two failure modes
/// have to stay apart. "Could not reach the server" is a retry and must keep
/// its order. "The server refused" is not a retry at all, and treating it as
/// one parks every later item behind it forever — the rep keeps working, the
/// queue keeps growing, Sync Centre keeps saying "Connected", and nothing ever
/// arrives.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pharmaconnect/data/sync/outbox.dart';

/// A refusal: PostgREST understood and answered 4xx.
PostgrestException _refusal(String message) =>
    PostgrestException(message: message, code: '400');

/// Not a refusal: the server is having a bad time, or was never reached.
PostgrestException _serverTrouble() =>
    PostgrestException(message: 'upstream connect error', code: '503');

Future<OutboxStore> _storeWith(List<String> kinds) async {
  SharedPreferences.setMockInitialValues({});
  final store = OutboxStore();
  for (final k in kinds) {
    await store.enqueue(kind: k, payload: {'p': k}, label: k);
  }
  return store;
}

void main() {
  test('a refused item does not park the work behind it', () async {
    final store = await _storeWith(['first', 'second', 'third']);

    final attempted = <String>[];
    final flusher = OutboxFlusher(
      store,
      enabled: true,
      send: (item) async {
        attempted.add(item.kind);
        if (item.kind == 'first') throw _refusal('a reason is required');
      },
    );

    final r = await flusher.flush();

    // This is the whole point: the two behind it were tried and went through.
    expect(attempted, ['first', 'second', 'third']);
    expect(r.sent, 2);
    expect(r.refused, 1);
    expect(r.stalled, isFalse);

    expect((await store.pending()).map((i) => i.kind), isEmpty);
    final refused = await store.refused();
    expect(refused.map((i) => i.kind), ['first']);
    expect(refused.single.refusedReason, contains('a reason is required'));
  });

  test('but an unreachable server stops, and keeps the order', () async {
    final store = await _storeWith(['first', 'second', 'third']);

    final attempted = <String>[];
    final flusher = OutboxFlusher(
      store,
      enabled: true,
      send: (item) async {
        attempted.add(item.kind);
        if (item.kind == 'second') throw _serverTrouble();
      },
    );

    final r = await flusher.flush();

    expect(attempted, ['first', 'second'], reason: 'it should not run ahead');
    expect(r.sent, 1);
    expect(r.refused, 0);
    expect(r.stalled, isTrue);

    // Still queued, still in order, nothing thrown away.
    expect((await store.pending()).map((i) => i.kind), ['second', 'third']);
    expect(await store.refused(), isEmpty);
  });

  test('an unrecognised error is treated as a retry, never as a refusal',
      () async {
    // Guessing "permanent" on an error we do not understand throws away work
    // that cannot be recreated. The safe guess is the recoverable one.
    final store = await _storeWith(['first', 'second']);
    final flusher = OutboxFlusher(
      store,
      enabled: true,
      send: (item) async {
        if (item.kind == 'first') throw StateError('something unforeseen');
      },
    );

    final r = await flusher.flush();
    expect(r.stalled, isTrue);
    expect(r.refused, 0);
    expect((await store.pending()).map((i) => i.kind), ['first', 'second']);
  });

  test('a timeout or a rate limit is a retry, not a refusal', () async {
    for (final code in ['408', '429']) {
      final store = await _storeWith(['only']);
      final flusher = OutboxFlusher(
        store,
        enabled: true,
        send: (_) async =>
            throw PostgrestException(message: 'slow down', code: code),
      );
      final r = await flusher.flush();
      expect(r.refused, 0, reason: '$code should not be final');
      expect(r.stalled, isTrue, reason: '$code should be retried');
      expect((await store.pending()).length, 1);
    }
  });

  test('a refused item stops being counted as waiting', () async {
    // Sync Centre's badge reads this. An item that will never arrive is not
    // "waiting to sync", and counting it as such is how the number stopped
    // meaning anything.
    final store = await _storeWith(['first', 'second']);
    await OutboxFlusher(
      store,
      enabled: true,
      send: (item) async {
        if (item.kind == 'first') throw _refusal('no');
      },
    ).flush();

    expect(await store.count(), 0);
    expect((await store.list()).length, 1, reason: 'but it is still on file');
  });

  test('a refusal survives a restart, with its reason', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OutboxStore();
    await store.enqueue(kind: 'visit', payload: {'a': 1}, label: 'Dr. Sharma');
    await OutboxFlusher(store, enabled: true,
            send: (_) async => throw _refusal('client no longer exists'))
        .flush();

    // A second store over the same storage is what the next launch sees.
    final reopened = OutboxStore();
    final refused = await reopened.refused();
    expect(refused.single.label, 'Dr. Sharma');
    expect(refused.single.refusedReason, contains('client no longer exists'));
    expect(await reopened.count(), 0);
  });

  test('nothing is sent when the backend is not live', () async {
    final store = await _storeWith(['first']);
    var tried = false;
    final r = await OutboxFlusher(store,
        enabled: false, send: (_) async => tried = true).flush();
    expect(tried, isFalse);
    expect(r.handled, 0);
    expect((await store.pending()).length, 1);
  });
}

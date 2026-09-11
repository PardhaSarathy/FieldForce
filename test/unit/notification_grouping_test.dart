/// Notifications are a list of things needing attention, not a second copy of
/// the chat log.
///
/// All three of these came from the same screenshot: five rows, four of them
/// chat, three of those from one conversation — and a bell reading four while
/// the chat badge read something else entirely.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/engagement.dart';

AppNotification _chat(String id, String thread, {bool read = false, int count = 1}) =>
    AppNotification(
      id: id,
      kind: NotificationKind.message,
      title: 'Ravi Teja Varma',
      body: 'hi',
      createdAt: DateTime(2026, 9, 10, 11, 32),
      isRead: read,
      relatedId: thread,
      groupCount: count,
    );

AppNotification _task(String id, {bool read = false}) => AppNotification(
      id: id,
      kind: NotificationKind.taskAssigned,
      title: 'New task assigned',
      body: 'Had to visit Apollo',
      createdAt: DateTime(2026, 9, 11, 7, 20),
      isRead: read,
    );

void main() {
  final store = MockStore.instance;

  setUp(() {
    store.notifications
      ..clear()
      ..addAll([_task('t1'), _chat('c1', 'th-1'), _chat('c2', 'th-2')]);
  });

  test('the bell counts work, not chat', () async {
    // Chat is already counted by the chat badge. Counting it here as well
    // made one unread message show up as two separate numbers.
    expect(await MockNotificationRepository().unreadCount(), 1,
        reason: 'one unread task; the two chat rows belong to the chat badge');
  });

  test('reading a conversation clears its notification', () async {
    final chat = MockChatRepository();
    await chat.markRead('th-1');

    final rows = await MockNotificationRepository().list();
    final forThread = rows.firstWhere((n) => n.relatedId == 'th-1');
    expect(forThread.isRead, isTrue,
        reason: 'the row for a conversation you are looking at is not unread');

    // And the other conversation is untouched.
    expect(rows.firstWhere((n) => n.relatedId == 'th-2').isRead, isFalse);
  });

  test('a grouped row says how many it stands for', () {
    final one = _chat('c1', 'th-1');
    final many = _chat('c1', 'th-1', count: 3);
    expect(one.isGrouped, isFalse);
    expect(many.isGrouped, isTrue);
    expect(many.groupCount, 3);
    // The count survives being marked read, so the row can still describe
    // itself in the All tab.
    expect(many.copyWith(isRead: true).groupCount, 3);
  });

  test('work notifications still count, read or unread', () async {
    store.notifications
      ..clear()
      ..addAll([_task('t1'), _task('t2'), _task('t3', read: true)]);
    expect(await MockNotificationRepository().unreadCount(), 2);
  });
}

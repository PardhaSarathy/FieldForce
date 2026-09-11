import '../enums/app_enums.dart';
import 'activity.dart';

/// A manager-assigned task (§50).
class FieldTask {
  const FieldTask({
    required this.id,
    required this.title,
    required this.assignedToId,
    required this.assignedToName,
    required this.assignedById,
    required this.assignedByName,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.instructions,
    this.locationName,
    this.clientId,
    this.clientName,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String assignedToId;
  final String assignedToName;
  final String assignedById;
  final String assignedByName;
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final String? instructions;
  final String? locationName;
  final String? clientId;
  final String? clientName;
  final DateTime? createdAt;
  final DateTime? completedAt;

  /// Overdue is derived, not stored, so it is never stale.
  bool isOverdue({DateTime? now}) {
    if (status == TaskStatus.completed) return false;
    return dueDate.isBefore(now ?? DateTime.now());
  }

  TaskStatus effectiveStatus({DateTime? now}) =>
      isOverdue(now: now) ? TaskStatus.overdue : status;

  FieldTask copyWith({TaskStatus? status, DateTime? completedAt}) {
    return FieldTask(
      id: id,
      title: title,
      assignedToId: assignedToId,
      assignedToName: assignedToName,
      assignedById: assignedById,
      assignedByName: assignedByName,
      dueDate: dueDate,
      priority: priority,
      status: status ?? this.status,
      instructions: instructions,
      locationName: locationName,
      clientId: clientId,
      clientName: clientName,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.deepLink,
    this.relatedId,
    this.groupCount = 1,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Route to open when tapped, so notifications connect to real records
  /// rather than dead-ending in a list (§1).
  final String? deepLink;

  final String? relatedId;

  /// How many events this one row stands for.
  ///
  /// A conversation produces one notification, not one per message — so this
  /// says how many messages have arrived since it was last read. Anything
  /// that is genuinely a single event leaves it at one.
  final int groupCount;

  /// More than one message waiting behind this row.
  bool get isGrouped => groupCount > 1;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    deepLink: deepLink,
    relatedId: relatedId,
    groupCount: groupCount,
  );
}

enum ChatThreadKind { direct, group, community, announcement }

enum ChatMessageKind { text, image, location, liveLocation, system }

enum ChatDeliveryStatus { sending, sent, delivered, read, failed }

class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.storagePath,
    this.mimeType = 'image/jpeg',
    this.byteSize,
    this.width,
    this.height,
    this.signedUrl,
  });

  final String id;
  final String storagePath;
  final String mimeType;
  final int? byteSize;
  final int? width;
  final int? height;
  final String? signedUrl;

  ChatAttachment copyWith({String? signedUrl}) => ChatAttachment(
        id: id,
        storagePath: storagePath,
        mimeType: mimeType,
        byteSize: byteSize,
        width: width,
        height: height,
        signedUrl: signedUrl ?? this.signedUrl,
      );
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.lastMessageAt,
    this.isGroup = false,
    this.isPinned = false,
    this.unreadCount = 0,
    this.participantIds = const [],
    this.subtitle,
    this.isOnline = false,
    this.kind = ChatThreadKind.direct,
    this.peerId,
    this.isMuted = false,
    this.lastMessageKind = ChatMessageKind.text,
  });

  final String id;
  final String title;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool isGroup;
  final bool isPinned;
  final int unreadCount;
  final List<String> participantIds;
  final String? subtitle;
  final bool isOnline;
  final ChatThreadKind kind;
  final String? peerId;
  final bool isMuted;
  final ChatMessageKind lastMessageKind;

  ChatThread copyWith({
    String? title,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isPinned,
    ChatMessageKind? lastMessageKind,
  }) =>
      ChatThread(
        id: id,
        title: title ?? this.title,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        isGroup: isGroup,
        isPinned: isPinned ?? this.isPinned,
        unreadCount: unreadCount ?? this.unreadCount,
        participantIds: participantIds,
        subtitle: subtitle,
        isOnline: isOnline,
        kind: kind,
        peerId: peerId,
        isMuted: isMuted,
        lastMessageKind: lastMessageKind ?? this.lastMessageKind,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.isMine = false,
    this.attachmentPath,
    this.kind = ChatMessageKind.text,
    this.status = ChatDeliveryStatus.sent,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.liveLocationId,
    this.liveExpiresAt,
    this.liveIsActive = false,
    this.attachments = const [],
  });

  final String id;
  final String threadId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final bool isMine;
  final String? attachmentPath;
  final ChatMessageKind kind;
  final ChatDeliveryStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? liveLocationId;
  final DateTime? liveExpiresAt;
  final bool liveIsActive;
  final List<ChatAttachment> attachments;

  ChatMessage copyWith({
    ChatDeliveryStatus? status,
    bool? liveIsActive,
    List<ChatAttachment>? attachments,
    double? latitude,
    double? longitude,
  }) =>
      ChatMessage(
        id: id,
        threadId: threadId,
        senderId: senderId,
        senderName: senderName,
        text: text,
        sentAt: sentAt,
        isMine: isMine,
        attachmentPath: attachmentPath,
        kind: kind,
        status: status ?? this.status,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        accuracyMeters: accuracyMeters,
        liveLocationId: liveLocationId,
        liveExpiresAt: liveExpiresAt,
        liveIsActive: liveIsActive ?? this.liveIsActive,
        attachments: attachments ?? this.attachments,
      );
}

class SurveyResponse {
  const SurveyResponse({
    required this.id,
    required this.employeeId,
    required this.clientId,
    required this.clientName,
    required this.clientType,
    required this.submittedAt,
    required this.feedback,
    this.remarks,
    this.locationName,
    this.rating,
  });

  final String id;
  final String employeeId;
  final String clientId;
  final String clientName;
  final ClientType clientType;
  final DateTime submittedAt;
  final String feedback;
  final String? remarks;
  final String? locationName;
  final int? rating;
}

class Complaint {
  const Complaint({
    required this.id,
    required this.reference,
    required this.clientId,
    required this.clientName,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    this.productId,
    this.productName,
    this.mobile,
    this.email,
    this.attachmentPaths = const [],
    this.resolution,
    this.history = const [],
  });

  final String id;
  final String reference;
  final String clientId;
  final String clientName;
  final String subject;
  final String description;
  final ComplaintStatus status;
  final DateTime createdAt;
  final String? productId;
  final String? productName;
  final String? mobile;
  final String? email;
  final List<String> attachmentPaths;
  final String? resolution;
  final List<ApprovalEvent> history;
}

/// A pending decision surfaced in the approval center (§43).
///
/// This is a projection over the underlying records — leave, expense, tour plan
/// and order all normalise into this shape so the manager works one queue
/// instead of five.
class ApprovalItem {
  const ApprovalItem({
    required this.id,
    required this.kind,
    required this.recordId,
    required this.employeeId,
    required this.employeeName,
    required this.title,
    required this.submittedAt,
    required this.status,
    this.subtitle,
    this.amount,
    this.date,
    this.employeeRole,
  });

  final String id;
  final ApprovalKind kind;
  final String recordId;
  final String employeeId;
  final String employeeName;
  final String title;
  final DateTime submittedAt;
  final ApprovalStatus status;
  final String? subtitle;
  final double? amount;
  final DateTime? date;
  final String? employeeRole;
}

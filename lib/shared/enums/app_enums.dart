import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Organizational hierarchy (§3).
///
/// [level] drives data visibility: a user may only see records belonging to
/// themselves or to employees beneath them in the reporting tree. See
/// [DataScope] for how that is resolved.
enum UserRole {
  mr('Medical Representative', 'MR', 1),
  asm('Area Sales Manager', 'ASM', 2),
  rsm('Regional Sales Manager', 'RSM', 3),
  zsm('Zonal Sales Manager', 'ZSM', 4),
  nsm('National Sales Manager', 'NSM', 5),
  admin('System Administrator', 'Admin', 6);

  const UserRole(this.label, this.shortLabel, this.level);

  final String label;
  final String shortLabel;
  final int level;

  /// True for any role that manages a team (§40–§51).
  bool get isManager => level >= UserRole.asm.level && this != UserRole.admin;

  bool get isFieldUser => this == UserRole.mr;
  bool get isAdmin => this == UserRole.admin;

  /// A manager may act on records belonging to strictly lower levels.
  bool canManage(UserRole other) => level > other.level;
}

/// How much of the organization a signed-in user can see.
///
/// Resolved once at login from role + reporting relationships, then applied
/// uniformly at the repository layer rather than re-derived per screen. This is
/// the single client-side enforcement point for §66.1; the server must mirror
/// it (§70) because UI restrictions alone are not authorization.
enum DataScope {
  /// Own records only — field users.
  self,

  /// Own records plus every employee in the reporting subtree.
  subtree,

  /// Everything. Admin and national roles.
  global;

  static DataScope forRole(UserRole role) => switch (role) {
    UserRole.mr => DataScope.self,
    UserRole.asm || UserRole.rsm || UserRole.zsm => DataScope.subtree,
    UserRole.nsm || UserRole.admin => DataScope.global,
  };
}

/// Lifecycle shared by every approval-backed record (§62).
///
/// Kept as one enum rather than per-module duplicates so that the approval
/// center, badges and filters all speak the same language.
enum ApprovalStatus {
  draft('Draft'),
  submitted('Submitted'),
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const ApprovalStatus(this.label);
  final String label;

  bool get isDecided => this == approved || this == rejected;
  bool get isEditable => this == draft || this == rejected;
  bool get awaitsDecision => this == submitted || this == pending;

  StatusTone get tone => switch (this) {
    draft => StatusTone.neutral,
    submitted || pending => StatusTone.warning,
    approved => StatusTone.success,
    rejected => StatusTone.error,
  };
}

/// Lifecycle of a planned or executed field activity (§16, §17).
enum ActivityStatus {
  planned('Planned'),
  upcoming('Upcoming'),
  inProgress('In Progress'),
  completed('Completed'),
  missed('Missed'),
  rescheduled('Rescheduled');

  const ActivityStatus(this.label);
  final String label;

  bool get isOpen => this == planned || this == upcoming || this == inProgress;

  StatusTone get tone => switch (this) {
    planned => StatusTone.neutral,
    // Brand, not info. An upcoming visit is the app's own subject — the
    // thing it exists to get you to — rather than a piece of information
    // about it, and a blue chip on a teal card reads as a stray.
    upcoming => StatusTone.brand,
    inProgress => StatusTone.brand,
    completed => StatusTone.success,
    missed => StatusTone.error,
    rescheduled => StatusTone.warning,
  };
}

/// Offline synchronization state (§8, §61).
///
/// Every locally-mutable record carries one of these so the UI can always tell
/// a field user whether their work is safe.
enum SyncStatus {
  /// Persisted on device, not yet queued.
  savedLocally('Saved locally'),

  /// In the outbox, waiting for connectivity.
  pending('Waiting to sync'),

  syncing('Syncing'),
  synced('Synced'),
  failed('Sync failed');

  const SyncStatus(this.label);
  final String label;

  bool get needsAttention => this == failed;
  bool get isSettled => this == synced;

  StatusTone get tone => switch (this) {
    savedLocally || pending => StatusTone.neutral,
    syncing => StatusTone.info,
    synced => StatusTone.success,
    failed => StatusTone.error,
  };
}

/// Result of comparing captured GPS against a client's registered location
/// (§9). The distance itself is carried alongside on the record — this enum
/// only classifies the outcome.
enum GeoVerification {
  /// Inside the configured geo-fence radius.
  verified('Verified'),

  /// Outside the radius. Per our business rule the visit is still allowed but
  /// is permanently flagged and requires a reason.
  outOfRange('Not verified'),

  /// Location could not be determined — permission denied, GPS off, timeout.
  unavailable('Location unavailable'),

  /// Device reported a mock/spoofed provider.
  suspect('Location suspect');

  const GeoVerification(this.label);
  final String label;

  bool get isTrusted => this == verified;

  StatusTone get tone => switch (this) {
    verified => StatusTone.success,
    outOfRange => StatusTone.warning,
    unavailable => StatusTone.neutral,
    suspect => StatusTone.error,
  };
}

/// How strictly the geo-fence is enforced. Admin-configurable (§130).
///
/// Default is [warn]: hard-blocking an out-of-range visit means a rep who did
/// real work cannot record it, which pushes the problem into worse workarounds.
/// We record the truth instead and let managers see it.
enum GeoFencePolicy {
  /// Out-of-range visits are rejected outright.
  strict,

  /// Out-of-range visits are allowed but require a reason and are flagged.
  warn,

  /// Distance is recorded, no gating.
  off,
}

enum ClientType {
  doctor('Doctor'),
  hospital('Hospital'),
  chemist('Chemist'),
  stockist('Stockist'),
  other('Other');

  const ClientType(this.label);
  final String label;
}

/// Whether a client sits on the company's approved list.
///
/// A listed doctor is one head office already recognises; an unlisted one has
/// been met in the field but not yet added centrally. The distinction drives
/// coverage reporting, so it is recorded at registration rather than inferred.
enum ClientListing {
  listed('Listed'),
  unlisted('Unlisted');

  const ClientListing(this.label);
  final String label;

  StatusTone get tone => switch (this) {
    listed => StatusTone.success,
    unlisted => StatusTone.warning,
  };
}

/// Commercial importance of a client, used for planning priority.
enum ClientCategory {
  coreTarget('Core Target'),
  regular('Regular'),
  potential('Potential'),
  inactive('Inactive');

  const ClientCategory(this.label);
  final String label;

  StatusTone get tone => switch (this) {
    coreTarget => StatusTone.brand,
    regular => StatusTone.neutral,
    potential => StatusTone.sand,
    inactive => StatusTone.neutral,
  };
}

enum WorkType {
  fieldWork('Field Work'),
  officeWork('Office Work'),
  meeting('Meeting'),
  training('Training'),
  leave('Leave'),
  holiday('Holiday');

  const WorkType(this.label);
  final String label;
}

enum VisitPurpose {
  productDetailing('Product Detailing'),
  followUp('Follow-up'),
  sampleDrop('Sample Drop'),
  orderCollection('Order Collection'),
  paymentCollection('Payment Collection'),
  relationshipBuilding('Relationship Building'),
  complaintResolution('Complaint Resolution');

  const VisitPurpose(this.label);
  final String label;
}

enum ExpenseCategory {
  /// The flat daily allowance — what a worked day is worth before anything is
  /// spent above it. First in the list because it is the default and by far
  /// the commonest: most days are exactly this and nothing else.
  dailyAllowance('Daily Allowance'),

  travel('Travel'),
  food('Food'),
  lodging('Lodging'),
  fuel('Fuel'),
  other('Other');

  const ExpenseCategory(this.label);
  final String label;

  /// The categories a rep can put against an *excess*. The allowance is not
  /// one of them — it is what the excess is measured against.
  static List<ExpenseCategory> get spendable =>
      values.where((c) => c != dailyAllowance).toList();

  IconData get icon => switch (this) {
    dailyAllowance => Icons.payments_outlined,
    travel => Icons.directions_bus_outlined,
    food => Icons.restaurant_outlined,
    lodging => Icons.hotel_outlined,
    fuel => Icons.local_gas_station_outlined,
    other => Icons.receipt_long_outlined,
  };
}

/// Where a day's work happened, relative to the rep's own headquarters.
///
/// It does **not** change what the day pays. The allowance is flat, and this
/// exists to explain why a day went above it — travelling out is the usual
/// reason, and a manager reviewing an excess needs the destination named.
/// An earlier draft gave out-of-territory its own higher rate; that is not the
/// rule and re-introducing it would quietly pay two reps differently for the
/// same day.
enum ClaimScope {
  local('Local'),
  outOfTerritory('Out of territory');

  const ClaimScope(this.label);
  final String label;
}

enum TravelMode {
  bike('Bike'),
  car('Car'),
  bus('Bus'),
  train('Train'),
  flight('Flight'),
  auto('Auto'),
  taxi('Taxi');

  const TravelMode(this.label);
  final String label;
}

enum TourType {
  local('Local'),
  outstation('Outstation'),
  exStation('Ex-Station');

  const TourType(this.label);
  final String label;
}

enum LeaveType {
  casual('Casual Leave'),
  sick('Sick Leave'),
  earned('Earned Leave'),
  unpaid('Unpaid Leave'),
  compensatory('Compensatory Off');

  const LeaveType(this.label);
  final String label;
}

enum AttendanceStatus {
  present('Present'),
  leave('Leave'),
  holiday('Holiday'),
  absent('Absent'),
  weekOff('Week Off');

  const AttendanceStatus(this.label);
  final String label;

  /// Drawn from the calendar's four colours, so a green dot means the same
  /// thing on attendance as it does on the tour plan and the expense claim.
  /// A holiday is a day the company planned, which is what blue means here;
  /// a week off is the ordinary blank the other four are read against.
  Color get color => switch (this) {
    present => AppColors.calendarDone,
    leave => AppColors.calendarOff,
    holiday => AppColors.calendarPlanned,
    absent => AppColors.calendarProblem,
    weekOff => AppColors.grey500,
  };
}

enum TaskPriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  urgent('Urgent');

  const TaskPriority(this.label);
  final String label;

  StatusTone get tone => switch (this) {
    low => StatusTone.neutral,
    medium => StatusTone.info,
    high => StatusTone.warning,
    urgent => StatusTone.error,
  };
}

enum TaskStatus {
  assigned('Assigned'),
  inProgress('In Progress'),
  completed('Completed'),
  overdue('Overdue');

  const TaskStatus(this.label);
  final String label;

  StatusTone get tone => switch (this) {
    assigned => StatusTone.neutral,
    inProgress => StatusTone.brand,
    completed => StatusTone.success,
    overdue => StatusTone.error,
  };
}

enum ComplaintStatus {
  open('Open'),
  inReview('In Review'),
  resolved('Resolved'),
  closed('Closed');

  const ComplaintStatus(this.label);
  final String label;

  StatusTone get tone => switch (this) {
    open => StatusTone.warning,
    inReview => StatusTone.info,
    resolved => StatusTone.success,
    closed => StatusTone.neutral,
  };
}

/// The kind of record flowing through the approval center (§43).
enum ApprovalKind {
  leave('Leave', Icons.event_busy_outlined),
  expense('Expense', Icons.receipt_long_outlined),
  tourPlan('Tour Plan', Icons.map_outlined),
  order('Order', Icons.shopping_bag_outlined),
  other('Other', Icons.assignment_outlined);

  const ApprovalKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum NotificationKind {
  approvalRequested('Approval required', Icons.pending_actions_outlined),
  approvalCompleted('Approval completed', Icons.task_alt_outlined),
  taskAssigned('New task', Icons.assignment_outlined),
  visitReminder('Visit reminder', Icons.schedule_outlined),
  message('New message', Icons.chat_bubble_outline),
  targetUpdate('Target update', Icons.flag_outlined);

  const NotificationKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// What a client's special date actually is.
///
/// The date alone was useless: a rep cannot wish someone without knowing
/// whether it is a birthday or an anniversary, and "Happy anniversary" on
/// someone's birthday is worse than saying nothing.
enum SpecialOccasion {
  birthday('Birthday'),
  anniversary('Anniversary'),

  /// Anything else — a clinic's founding day, a festival they keep. Carries a
  /// typed note, because the whole point of "other" is that we cannot list it.
  other('Other');

  const SpecialOccasion(this.label);
  final String label;
}

/// Visual weight for status treatment. Maps a semantic state to palette tokens
/// so that badges, banners and dots stay consistent across modules — and so a
/// status is never communicated by color alone (§73).
enum StatusTone {
  neutral(AppColors.textSecondary, AppColors.surfaceSecondary),
  brand(AppColors.brandDark, AppColors.brandSoft),
  sand(AppColors.textPrimary, AppColors.sandSoft),
  success(AppColors.success, AppColors.successSoft),
  warning(AppColors.warning, AppColors.warningSoft),
  error(AppColors.error, AppColors.errorSoft),
  info(AppColors.info, AppColors.infoSoft);

  const StatusTone(this.foreground, this.background);

  final Color foreground;
  final Color background;
}

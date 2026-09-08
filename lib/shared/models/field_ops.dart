import '../enums/app_enums.dart';
import 'activity.dart';

/// A planned day of travel awaiting manager approval (§21).
class TravelPlan {
  const TravelPlan({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.workType,
    required this.status,
    this.areaId,
    this.areaName,
    this.territoryName,
    this.tourType = TourType.local,
    this.travelMode = TravelMode.bike,
    this.destination,
    this.purpose,
    this.plannedVisits = 0,
    this.estimatedKm,
    this.clientNames = const [],
    this.remarks,
    this.approvalHistory = const [],
    this.syncStatus = SyncStatus.synced,
    this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final WorkType workType;
  final ApprovalStatus status;
  final String? areaId;
  final String? areaName;
  final String? territoryName;
  final TourType tourType;
  final TravelMode travelMode;
  final String? destination;
  final String? purpose;
  final int plannedVisits;
  final double? estimatedKm;

  /// The clients the rep intends to call on. Names rather than ids so a plan
  /// stays readable if a client is later renamed or deactivated — the plan is
  /// a record of intent at a moment, not a live query.
  final List<String> clientNames;

  final String? remarks;
  final List<ApprovalEvent> approvalHistory;
  final SyncStatus syncStatus;
  final DateTime? createdAt;

  TravelPlan copyWith({
    ApprovalStatus? status,
    List<ApprovalEvent>? approvalHistory,
    SyncStatus? syncStatus,
  }) {
    return TravelPlan(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      workType: workType,
      status: status ?? this.status,
      areaId: areaId,
      areaName: areaName,
      territoryName: territoryName,
      tourType: tourType,
      travelMode: travelMode,
      destination: destination,
      purpose: purpose,
      plannedVisits: plannedVisits,
      clientNames: clientNames,
      remarks: remarks,
      estimatedKm: estimatedKm,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
    );
  }
}

/// A reimbursement claim (§22).
class Expense {
  const Expense({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.amount,
    this.categories = const [ExpenseCategory.dailyAllowance],
    required this.status,
    this.description,
    this.remarks,
    this.receiptPaths = const [],
    this.approvalHistory = const [],
    this.syncStatus = SyncStatus.synced,
    this.travelMode,
    this.fromLocation,
    this.toLocation,
    this.distanceKm,
    this.createdAt,
    this.dayPlanId,
    this.allowance = 0,
    this.scope = ClaimScope.local,
    this.place,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;

  /// What the claim covers. A list, because a day out of territory is often a
  /// fare *and* a meal *and* a bed, and asking the rep to file three separate
  /// lines for one day's excess is asking them to do the accounting.
  ///
  /// Never empty — a claim with no category is a claim nobody can code.
  final List<ExpenseCategory> categories;

  /// The one the row, the icon and the report group by.
  ///
  /// A getter, not a second field: two fields would be two places to say the
  /// same thing, and they would part company the first time either was set
  /// without the other.
  ExpenseCategory get category =>
      categories.isEmpty ? ExpenseCategory.other : categories.first;

  final double amount;
  final ApprovalStatus status;
  final String? description;
  final String? remarks;
  final List<String> receiptPaths;
  final List<ApprovalEvent> approvalHistory;
  final SyncStatus syncStatus;

  // Travel-specific detail, populated only for the travel category.
  final TravelMode? travelMode;
  final String? fromLocation;
  final String? toLocation;
  final double? distanceKm;

  final DateTime? createdAt;

  /// The day's intimation this claim hangs off (§16).
  ///
  /// A rep can only claim for a day he declared and worked. Enforced at the
  /// repository rather than in a screen, so there is one answer to "can this
  /// be claimed" no matter which screen asks.
  final String? dayPlanId;

  /// What the day was worth when the claim was made.
  ///
  /// Stored on the record, not looked up. The rate is company reference data
  /// and will change; a claim settled at ₹250 must still read ₹250 next year,
  /// and a report that recomputes history against today's figure is a report
  /// that disagrees with what was actually paid.
  final double allowance;

  /// Where the day happened. Context for the excess, never a rate.
  final ClaimScope scope;

  /// The place travelled to, when [scope] is out of territory.
  final String? place;

  bool get hasReceipt => receiptPaths.isNotEmpty;

  /// Spent above the day's allowance. This is the part that needs a bill.
  double get excess {
    final over = amount - allowance;
    return over > 0 ? over : 0;
  }

  /// A claim for exactly the allowance — the one-tap case, which needs no
  /// bill and no explanation.
  bool get isStandard => excess == 0;

  Expense copyWith({
    List<ExpenseCategory>? categories,
    ApprovalStatus? status,
    List<ApprovalEvent>? approvalHistory,
    SyncStatus? syncStatus,
    double? amount,
    String? description,
    String? remarks,
    List<String>? receiptPaths,
  }) {
    return Expense(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      categories: categories ?? this.categories,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      description: description ?? this.description,
      remarks: remarks ?? this.remarks,
      receiptPaths: receiptPaths ?? this.receiptPaths,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      syncStatus: syncStatus ?? this.syncStatus,
      travelMode: travelMode,
      fromLocation: fromLocation,
      toLocation: toLocation,
      distanceKm: distanceKm,
      createdAt: createdAt,
      dayPlanId: dayPlanId,
      allowance: allowance,
      scope: scope,
      place: place,
    );
  }
}

/// A month of tour plan — one entry per calendar day, planned or not.
///
/// **Derived, never stored.** The month is the unit a rep submits, but the
/// records underneath are still one [TravelPlan] per date; building a stored
/// month object would give the app two places to disagree about what is
/// planned.
/// The rule a tour month was judged under, kept from the moment it went in.
///
/// The *rule* rather than the figures it produced. Freezing `workingDays`
/// alone was tried first and was not enough: `plannedDays` went on counting
/// against the live week-off day, so a month with a frozen denominator and a
/// moving numerator reported five missing days out of nowhere. One frozen
/// rule keeps every figure derived from it consistent; three frozen numbers
/// is a promise to remember all three every time one is added.
class TourRule {
  const TourRule({required this.weekOff, required this.holidayDays});

  final int weekOff;
  final Set<int> holidayDays;
}

class TourMonth {
  const TourMonth({
    required this.month,
    required this.plans,
    this.holidays = const {},
    this.weekOff = DateTime.sunday,
    this.judgedUnder,
  });

  final DateTime month;

  /// Keyed by day of the month.
  final Map<int, TravelPlan> plans;

  /// Company holidays falling in this month, keyed by day.
  ///
  /// The company's own calendar, not the rep's — it comes from HR and is the
  /// same list the holiday screen shows. Named, because "Independence Day" on
  /// the 15th is the answer to why nothing is planned there.
  final Map<int, String> holidays;

  int get totalDays => DateTime(month.year, month.month + 1, 0).day;

  /// Which weekday nobody is expected to plan or claim for.
  ///
  /// Sunday everywhere in this app, and a **setting** rather than a fact —
  /// some field forces run Tuesday-off. It was `DateTime.sunday` written into
  /// this method and three other places, all of which had to agree.
  final int weekOff;

  /// The rule in force when the month was sent. Null while it is a draft.
  final TourRule? judgedUnder;

  /// A day nobody is expected to plan: the week off, or a company holiday.
  ///
  /// **Sunday is the week off by default, everywhere in this app.** It was
  /// not, and the tour plan asked a rep to open four or five Sundays a month
  /// and tell it what it already knew. A day that has one possible answer is
  /// not a question. A rep who *does* work one — a camp, a conference — can
  /// still tap it and say so; the default is what changed, not the freedom.
  ///
  /// Once the month has gone in this answers from [judgedUnder] instead, so
  /// every figure below it — working days, planned days, what is missing and
  /// whether it was complete — is measured against the rule an approver
  /// actually signed against rather than the one in force today.
  bool isOff(int day) {
    final rule = judgedUnder;
    if (rule != null) {
      return rule.holidayDays.contains(day) ||
          DateTime(month.year, month.month, day).weekday == rule.weekOff;
    }
    return holidays.containsKey(day) ||
        DateTime(month.year, month.month, day).weekday == weekOff;
  }

  String? holidayName(int day) => holidays[day];

  /// The days that actually need an answer.
  ///
  /// **Frozen once the month has been sent.** This was computed every time it
  /// was read, from the week-off rule and holiday list *in force right now* —
  /// so the day a company moved its week off from Sunday to Tuesday, or HR
  /// added a holiday to a past date, every month already approved silently
  /// restated itself. September 2026 was 26 days and complete; under a
  /// Tuesday week off the same record reads 25, and the Sundays the rep did
  /// plan start counting while the Tuesdays they planned stop.
  ///
  /// Nobody edited anything. The question changed underneath the answer, and
  /// an approver asked to explain a decision would be looking at figures they
  /// never saw. The fence radius is kept on each visit and the allowance on
  /// each claim for exactly this reason; this is the same rule, on the
  /// denominator a whole month was judged against.
  ///
  /// The freezing happens in [isOff], not here, so [plannedDays] and
  /// [missingDays] cannot drift away from this figure.
  int get workingDays {
    var n = 0;
    for (var d = 1; d <= totalDays; d++) {
      if (!isOff(d)) n++;
    }
    return n;
  }

  /// Working days with a plan on them. A Sunday the rep chose to work counts
  /// as planned — it is a plan — but was never counted as missing.
  int get plannedDays {
    var n = 0;
    for (final day in plans.keys) {
      if (!isOff(day)) n++;
    }
    return n;
  }

  int get missingDays => workingDays - plannedDays;

  /// The whole month has to be planned before any of it can be sent.
  ///
  /// A tour plan submitted with gaps in it is a plan the manager cannot
  /// approve — the days nobody declared are exactly the days they would ask
  /// about. Leave counts: saying "I am not working that Tuesday" is a plan.
  /// Sundays and company holidays do not, because nobody was asking.
  bool get isComplete => missingDays == 0;

  bool get isSubmitted =>
      plans.isNotEmpty &&
      plans.values.every((p) => p.status != ApprovalStatus.draft);

  /// Only a draft month can be edited. Once it is with an approver, changing
  /// it underneath them is how an approval comes to mean nothing.
  bool get isEditable => !isSubmitted;

  TravelPlan? planFor(int day) => plans[day];
}

/// Whether a work type needs anything beyond itself on a tour plan.
///
/// Leave and holidays do not: there is no territory to name, no area to work
/// and nobody to call on. Asking for them anyway is asking a rep to describe
/// the geography of a day they are not working.
bool tourDayNeedsDetail(WorkType type) =>
    type != WorkType.leave && type != WorkType.holiday;

/// A day the rep declared, and what has been claimed against it.
///
/// **Derived, never stored.** It is a day plan joined to whatever expenses
/// were filed for that date, exactly as a report is derived from the records
/// beneath it — storing it would give the app two places to disagree about
/// whether a day is claimed.
/// What kind of day this was, resolved from everything that knows.
///
/// A month of expenses used to be a list of the days a rep filed a day plan
/// for, and nothing else — so a Sunday, a company holiday, a week of approved
/// leave and a day he simply forgot to intimate were all the same thing: not
/// on the screen. The rep could not tell an unclaimable day from a missing
/// one, which is the difference between "nothing owed" and "money lost".
enum DayKind {
  /// A day plan was filed and the work type earns the allowance.
  worked('Worked'),

  /// A company holiday, from HR's calendar. [ClaimDay.note] names it.
  holiday('Holiday'),

  /// Sunday — the week off, everywhere in this app.
  weekOff('Week off'),

  /// Approved leave, or a day declared as leave on the plan.
  leave('Leave'),

  /// An ordinary working day with no day plan against it. Nothing can be
  /// claimed for it and nothing ever will be — which is exactly why it has to
  /// be on the screen.
  notDeclared('No day plan');

  const DayKind(this.label);
  final String label;

  /// Only a worked day earns anything.
  bool get earnsAllowance => this == DayKind.worked;
}

class ClaimDay {
  const ClaimDay({
    required this.date,
    required this.dayPlanId,
    required this.workType,
    required this.place,
    required this.allowance,
    // Required, with no default. [kind] and [workType] can otherwise be
    // constructed disagreeing — a day carrying `WorkType.leave` that still
    // says it was worked — and the one that decides whether money is owed
    // would have been the one nobody passed.
    required this.kind,
    this.note,
    this.expenses = const [],
    this.calls = 0,
  });

  final DateTime date;

  /// The intimation this day's claims hang off — null when there is none, and
  /// then nothing can be filed against the day.
  final String? dayPlanId;

  final WorkType workType;

  /// Where the day came from, and why it can or cannot be claimed.
  final DayKind kind;

  /// The company holiday's name, or the reason on the leave request. The row
  /// says it out loud rather than leaving the rep to work it out.
  final String? note;

  /// Where the day was worked — the day plan's area, or its cluster.
  final String place;

  /// What this day is worth, before anything is spent above it.
  final double allowance;

  final List<Expense> expenses;

  /// Visits completed that day. Context on the row, and the thing that makes
  /// an unclaimed day obviously a real working day rather than a blank.
  final int calls;

  /// Leave and holidays are not worked, so nothing can be claimed against
  /// them.
  ///
  /// Every other declared type is claimable. Whether a Meeting or Training
  /// day should earn the full allowance is a company policy question still
  /// with the client — when they answer, this getter is the only edit.
  static bool isClaimable(WorkType type) =>
      type != WorkType.leave && type != WorkType.holiday;

  /// A day earns the allowance only if it was worked *and* declared. The kind
  /// carries both halves — there is no claimable day without a day plan, so
  /// asking one question answers the other.
  bool get claimable => kind.earnsAllowance && dayPlanId != null;

  double get claimed => expenses.fold(0, (sum, e) => sum + e.amount);

  bool get hasClaim => expenses.isNotEmpty;

  /// Claimed above the allowance — the part carrying bills.
  bool get isExcess => claimed > allowance;

  /// What is left of the day's allowance.
  ///
  /// The form measures a new line against **this**, not against the full
  /// allowance. Measured against the full figure, a rep could file ₹250 twice
  /// on one day — each line at the allowance, each needing no bill — and walk
  /// away with ₹500 against a ₹250 day. The rule is per day, so the check has
  /// to be per day.
  double get remainingAllowance {
    final left = allowance - claimed;
    return left > 0 ? left : 0;
  }

  /// The state to show for the day, when several claims sit on it.
  ///
  /// The worst news wins: a rejected line is the one the rep has to act on,
  /// and a day that is half approved and half rejected is not "approved".
  ApprovalStatus? get status {
    if (expenses.isEmpty) return null;
    for (final s in [
      ApprovalStatus.rejected,
      ApprovalStatus.draft,
      ApprovalStatus.submitted,
      ApprovalStatus.pending,
    ]) {
      if (expenses.any((e) => e.status == s)) return s;
    }
    return ApprovalStatus.approved;
  }

  int get receiptCount =>
      expenses.fold(0, (sum, e) => sum + e.receiptPaths.length);

  /// A worked day with nothing filed against it yet. The figure that drives
  /// the whole screen.
  bool get isOpen => claimable && !hasClaim;
}

/// Why a month's claim cannot be sent yet — or that it can.
///
/// The claim goes the way the tour plan goes: **in one piece, once**. A rep
/// used to be able to send three days on the 8th and four more on the 19th,
/// which gives an approver the same month arriving in instalments and no
/// moment where the figure they are looking at is the month's figure.
enum ClaimGate {
  /// Nothing is waiting to go. The bar hides rather than showing a control
  /// with nothing behind it.
  nothingToSend,

  /// The month has not finished. Days keep arriving until it does, so a claim
  /// sent on the 20th could never be the month's claim.
  monthRunning,

  /// The month is over but days in it are still unanswered. Confirming them
  /// is one tap; losing them because the claim went without them is not
  /// recoverable in the same way.
  daysOpen,

  /// It can go.
  ready,
}

/// Reads [days] as a month and answers whether its claim can be submitted.
///
/// Pure, and takes [now] rather than reading the clock, so the gate can be
/// tested on a month that has ended without waiting for one to.
ClaimGate claimGate({
  required List<ClaimDay> days,
  required DateTime month,
  required DateTime now,
}) {
  final drafts = days
      .expand((d) => d.expenses)
      .where((e) => e.status == ApprovalStatus.draft)
      .length;
  if (drafts == 0) return ClaimGate.nothingToSend;

  // A month is over when the calendar has moved past it — not when the last
  // declared day has been confirmed. On the 20th every day so far can be
  // answered and the month still has ten days left in it.
  if (!month.isBefore(DateTime(now.year, now.month))) {
    return ClaimGate.monthRunning;
  }

  if (days.any((d) => d.isOpen)) return ClaimGate.daysOpen;
  return ClaimGate.ready;
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.workType,
    this.note,
  });

  final DateTime date;
  final AttendanceStatus status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final WorkType? workType;
  final String? note;
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.fromDate,
    required this.toDate,
    required this.type,
    required this.reason,
    required this.status,
    this.approvalHistory = const [],
    this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime fromDate;
  final DateTime toDate;
  final LeaveType type;
  final String reason;
  final ApprovalStatus status;
  final List<ApprovalEvent> approvalHistory;
  final DateTime? createdAt;

  /// Inclusive day count.
  int get days => toDate.difference(fromDate).inDays + 1;

  LeaveRequest copyWith({
    ApprovalStatus? status,
    List<ApprovalEvent>? approvalHistory,
  }) {
    return LeaveRequest(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      fromDate: fromDate,
      toDate: toDate,
      type: type,
      reason: reason,
      status: status ?? this.status,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      createdAt: createdAt,
    );
  }
}

class Holiday {
  const Holiday({
    required this.id,
    required this.name,
    required this.date,
    this.isOptional = false,
  });

  final String id;
  final String name;
  final DateTime date;
  final bool isOptional;
}

class Payslip {
  const Payslip({
    required this.id,
    required this.employeeId,
    required this.month,
    required this.grossPay,
    required this.deductions,
    this.earnings = const {},
    this.deductionBreakup = const {},
  });

  final String id;

  /// Whose pay this is.
  ///
  /// Required, and it was missing. The record carried a month and a set of
  /// figures and nothing saying whose they were, which works only while the
  /// list is fetched for whoever happens to be signed in — and the repository
  /// took an `employeeId` and threw it away, so every employee was served the
  /// same twelve payslips at the same salary. One API serving many people
  /// cannot answer "whose", and a figure this sensitive must never be a
  /// question the caller answers on the record's behalf.
  final String employeeId;

  final DateTime month;
  final double grossPay;
  final double deductions;
  final Map<String, double> earnings;
  final Map<String, double> deductionBreakup;

  double get netPay => grossPay - deductions;
}

class AppDocument {
  const AppDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.uploadedAt,
    this.sizeLabel,
    this.category = 'General',
    this.url,
  });

  final String id;
  final String name;
  final String type;
  final DateTime uploadedAt;
  final String? sizeLabel;
  final String category;
  final String? url;
}

/// Marketing and training material available to the field (§26).
class Resource {
  const Resource({
    required this.id,
    required this.title,
    required this.category,
    required this.updatedAt,
    this.description,
    this.fileType = 'PDF',
    this.sizeLabel,
    this.productId,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String category;
  final DateTime updatedAt;
  final String? description;
  final String fileType;
  final String? sizeLabel;
  final String? productId;
  final String? thumbnailUrl;
}

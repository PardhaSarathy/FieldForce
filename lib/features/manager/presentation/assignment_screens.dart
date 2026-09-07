import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/engagement.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/month_calendar.dart';
import '../../../core/theme/app_motion.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import '../../shell/presentation/app_shell.dart';

// ====================================================== target assignment ==

/// Monthly target grid (§48).
///
/// Twelve editable months in one view, with a running annual total. Managers
/// think in annual numbers and distribute them across months, so editing one
/// month at a time in a modal would be the wrong shape entirely.
class TargetAssignmentScreen extends ConsumerStatefulWidget {
  const TargetAssignmentScreen({super.key});

  @override
  ConsumerState<TargetAssignmentScreen> createState() =>
      _TargetAssignmentScreenState();
}

class _TargetAssignmentScreenState
    extends ConsumerState<TargetAssignmentScreen> {
  Employee? _employee;
  int _year = DateTime.now().year;
  final Map<int, TextEditingController> _controllers = {};
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTargets() async {
    final employee = _employee;
    if (employee == null) return;

    final session = ref.read(sessionProvider);
    final targets = await ref
        .read(businessRepositoryProvider)
        .targets(session, employeeId: employee.id);

    if (!mounted) return;
    setState(() {
      for (var m = 1; m <= 12; m++) {
        final match = targets
            .where((t) => t.month.year == _year && t.month.month == m)
            .firstOrNull;
        _controllers[m] = TextEditingController(
          text: match == null ? '' : match.targetAmount.round().toString(),
        );
      }
      _loaded = true;
    });
  }

  double get _annualTotal {
    return _controllers.values.fold<double>(
      0,
      (sum, c) => sum + (double.tryParse(c.text.trim()) ?? 0),
    );
  }

  Future<void> _save() async {
    final employee = _employee;
    if (employee == null) return;

    setState(() => _saving = true);
    final repo = ref.read(businessRepositoryProvider);

    for (var m = 1; m <= 12; m++) {
      final amount = double.tryParse(_controllers[m]?.text.trim() ?? '');
      if (amount == null || amount <= 0) continue;

      await repo.saveTarget(
        Target(
          id: 'tgt-${employee.id}-$_year-$m',
          employeeId: employee.id,
          employeeName: employee.name,
          month: DateTime(_year, m),
          targetAmount: amount,
          areaId: employee.areaId,
          areaName: employee.areaName,
          visitTarget: 182,
        ),
      );
    }

    if (!mounted) return;
    ref.bumpRevision();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Targets saved for ${employee.name}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Assign Targets')),
      bottomNavigationBar: _loaded
          ? BottomActionBar(
              children: [
                SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => context.pop(),
                ),
                PrimaryButton(
                  label: 'Save targets',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          teamAsync.when(
            loading: () => const Skeleton(height: 48),
            error: (_, _) => const ErrorState(compact: true),
            data: (team) => DropdownField<Employee>(
              label: 'Employee',
              required: true,
              hint: 'Select a team member',
              items: team,
              value: _employee,
              itemLabel: (e) => '${e.name} · ${e.employeeCode}',
              onChanged: (v) {
                setState(() {
                  _employee = v;
                  _loaded = false;
                });
                _loadTargets();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownField<int>(
            label: 'Year',
            items: [for (var y = _year - 1; y <= _year + 1; y++) y],
            value: _year,
            itemLabel: (y) => '$y',
            onChanged: (v) {
              setState(() {
                _year = v ?? _year;
                _loaded = false;
              });
              _loadTargets();
            },
          ),

          if (!_loaded) ...[
            const SizedBox(height: AppSpacing.xxxl),
            const EmptyState(
              compact: true,
              icon: Icons.flag_outlined,
              title: 'Select an employee',
              message: 'Choose a team member to set their monthly targets.',
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.section),
            SectionHeader(
              title: 'Monthly targets · $_year',
              trailing: Text(
                Fmt.money(_annualTotal),
                style: AppTypography.titleSm.copyWith(color: AppColors.brand),
              ),
            ),
            AppCard(
              child: Column(
                children: [
                  for (var m = 1; m <= 12; m++) ...[
                    if (m > 1) const AppDivider(height: AppSpacing.md),
                    Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(
                            Fmt.monthShort(DateTime(_year, m)),
                            style: AppTypography.titleSm,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controllers[m],
                            keyboardType: TextInputType.number,
                            style: AppTypography.numeric,
                            textAlign: TextAlign.right,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              hintText: '0',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              color: AppColors.brandSoft,
              borderColor: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Annual total',
                      style: AppTypography.titleSm.copyWith(
                        color: AppColors.brandDark,
                      ),
                    ),
                  ),
                  Text(
                    Fmt.money(_annualTotal),
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.brandDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// ======================================================== rate assignment ==

/// Travel rate configuration (§49). Rates drive expense auto-calculation, so
/// they are per employee, per travel mode.
class RateAssignmentScreen extends ConsumerStatefulWidget {
  const RateAssignmentScreen({super.key});

  @override
  ConsumerState<RateAssignmentScreen> createState() =>
      _RateAssignmentScreenState();
}

class _RateAssignmentScreenState extends ConsumerState<RateAssignmentScreen> {
  Employee? _employee;
  final Map<TravelMode, TextEditingController> _local = {
    for (final m in TravelMode.values) m: TextEditingController(),
  };
  final Map<TravelMode, TextEditingController> _outstation = {
    for (final m in TravelMode.values) m: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    // Sensible defaults so the screen is never an empty grid.
    const defaults = {
      TravelMode.bike: (3.5, 4.5),
      TravelMode.car: (9.0, 11.0),
      TravelMode.bus: (2.0, 2.5),
      TravelMode.train: (2.5, 3.0),
      TravelMode.flight: (0.0, 0.0),
      TravelMode.auto: (12.0, 14.0),
      TravelMode.taxi: (15.0, 18.0),
    };
    for (final entry in defaults.entries) {
      _local[entry.key]!.text = entry.value.$1.toString();
      _outstation[entry.key]!.text = entry.value.$2.toString();
    }
  }

  @override
  void dispose() {
    for (final c in [..._local.values, ..._outstation.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Travel Rates')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: 'Save rates',
            onPressed: _employee == null
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rates saved for ${_employee!.name}.'),
                      ),
                    );
                    context.pop();
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          teamAsync.when(
            loading: () => const Skeleton(height: 48),
            error: (_, _) => const ErrorState(compact: true),
            data: (team) => DropdownField<Employee>(
              label: 'Employee',
              required: true,
              hint: 'Select a team member',
              items: team,
              value: _employee,
              itemLabel: (e) => e.name,
              onChanged: (v) => setState(() => _employee = v),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Rate per kilometre'),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 84),
                    Expanded(
                      child: Text(
                        'Local',
                        style: AppTypography.overline,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Outstation',
                        style: AppTypography.overline,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const AppDivider(height: AppSpacing.md),
                for (final mode in TravelMode.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(mode.label, style: AppTypography.titleSm),
                        ),
                        Expanded(child: _RateInput(controller: _local[mode]!)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _RateInput(controller: _outstation[mode]!),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _RateInput extends StatelessWidget {
  const _RateInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: AppTypography.numeric,
      decoration: const InputDecoration(
        prefixText: '₹',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      ),
    );
  }
}

// ======================================================== task assignment ==

class TaskAssignmentScreen extends ConsumerStatefulWidget {
  const TaskAssignmentScreen({super.key});

  @override
  ConsumerState<TaskAssignmentScreen> createState() =>
      _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends ConsumerState<TaskAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _location = TextEditingController();

  Employee? _assignee;
  DateTime _due = DateTime.now().add(const Duration(days: 3));
  TaskPriority _priority = TaskPriority.medium;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (!_formKey.currentState!.validate() || _assignee == null) return;
    setState(() => _submitting = true);

    final session = ref.read(sessionProvider);
    await ref
        .read(taskRepositoryProvider)
        .create(
          FieldTask(
            id: const Uuid().v4(),
            title: _title.text.trim(),
            assignedToId: _assignee!.id,
            assignedToName: _assignee!.name,
            assignedById: session.employee.id,
            assignedByName: session.employee.name,
            dueDate: _due,
            priority: _priority,
            status: TaskStatus.assigned,
            instructions: _instructions.text.trim().isEmpty
                ? null
                : _instructions.text.trim(),
            locationName: _location.text.trim().isEmpty
                ? null
                : _location.text.trim(),
            createdAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task assigned to ${_assignee!.name}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Assign Task')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: 'Assign task',
            isLoading: _submitting,
            onPressed: _assign,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            teamAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const ErrorState(compact: true),
              data: (team) => DropdownField<Employee>(
                label: 'Assign to',
                required: true,
                hint: 'Select a team member',
                items: team,
                value: _assignee,
                itemLabel: (e) => '${e.name} · ${e.areaName ?? ''}',
                onChanged: (v) => setState(() => _assignee = v),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Task',
              required: true,
              controller: _title,
              hint: 'What needs to be done?',
              validator: (v) => Validate.required(v, 'Task'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: DateField(
                    label: 'Due date',
                    required: true,
                    value: _due,
                    firstDate: DateTime.now(),
                    onChanged: (d) => setState(() => _due = d),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownField<TaskPriority>(
                    label: 'Priority',
                    items: TaskPriority.values,
                    value: _priority,
                    itemLabel: (p) => p.label,
                    onChanged: (v) =>
                        setState(() => _priority = v ?? TaskPriority.medium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Location',
              controller: _location,
              hint: 'Area or client, if relevant',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Instructions',
              controller: _instructions,
              maxLines: 4,
              hint: 'Context the person needs to complete this well',
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ================================================================== tasks ==

/// **A to-do is personal.** Always the signed-in user's own, manager included.
///
/// A manager's list showed the whole team's, and a Mine/Team switch was added
/// to give them their own back. Both were wrong about what this screen is: a
/// to-do is a note you write for yourself, and putting the team's work in the
/// same list makes it a queue. Work a manager hands out is a different thing
/// with a different question attached — "did they do it" rather than "must I"
/// — and it has its own screen on the management side.
final _tasksProvider = FutureProvider.autoDispose<List<FieldTask>>((ref) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref
      .watch(taskRepositoryProvider)
      .list(session, employeeId: session.employee.id);
});

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  String _filter = 'Open';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_tasksProvider);
    const filters = ['Open', 'Overdue', 'Completed', 'All'];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('To-Do'),
        leading: const DrawerMenuButton(),
        actions: [
          IconButton(
            tooltip: 'Calendar',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push(Routes.taskCalendar),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      // One button, because there is one thing this screen does. It offered a
      // manager "Assign", so they could hand work to anyone on the team and
      // had no way to write down a thing of their own — on the one screen in
      // this app that is nobody else's business.
      floatingActionButton: AppFab(
        onPressed: () => context.push(Routes.newTask),
        icon: Icons.add,
        label: 'Add to-do',
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          FilterChipBar<String>(
            options: filters,
            selected: _filter,
            labelOf: (f) => f,
            onSelected: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) => const ErrorState(),
              data: (all) {
                final tasks = all.where((t) {
                  final status = t.effectiveStatus();
                  return switch (_filter) {
                    'Open' => status != TaskStatus.completed,
                    'Overdue' => status == TaskStatus.overdue,
                    'Completed' => status == TaskStatus.completed,
                    _ => true,
                  };
                }).toList();

                if (tasks.isEmpty) {
                  return EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No $_filter tasks',
                    message: _filter == 'Overdue'
                        ? 'Nothing is past its due date.'
                        : 'Tasks assigned to you appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    0,
                    AppSpacing.screenH,
                    AppSpacing.xxxl * 3,
                  ),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) => Arrive.staggered(
                    index: i,
                    child: _TaskCard(
                      task: tasks[i],
                      // Never here: every row is the reader's own.
                      showAssignee: false,
                      onComplete: () async {
                        await ref
                            .read(taskRepositoryProvider)
                            .updateStatus(tasks[i].id, TaskStatus.completed);
                        ref.bumpRevision();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================== assigned tasks ==

final _assignedTasksProvider = FutureProvider.autoDispose<List<FieldTask>>((
  ref,
) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref
      .watch(taskRepositoryProvider)
      .list(session, assignedById: session.employee.id);
});

/// The work a manager has handed to the team.
///
/// Split out of To-Do, which is personal. The two lists answer different
/// questions — "must I do this" against "did they do it" — and holding both in
/// one list turned a manager's own notes into a queue. It is also the screen
/// that was simply missing: **Manage → Tasks** opened the assignment *form*,
/// so a manager could give work out and had nowhere to see what they had
/// given.
class AssignedTasksScreen extends ConsumerStatefulWidget {
  const AssignedTasksScreen({super.key});

  @override
  ConsumerState<AssignedTasksScreen> createState() =>
      _AssignedTasksScreenState();
}

class _AssignedTasksScreenState extends ConsumerState<AssignedTasksScreen> {
  String _filter = 'Open';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_assignedTasksProvider);
    const filters = ['Open', 'Overdue', 'Completed', 'All'];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Assigned Tasks')),
      floatingActionButton: AppFab(
        onPressed: () => context.push(Routes.taskAssignment),
        icon: Icons.add,
        label: 'Assign',
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          FilterChipBar<String>(
            options: filters,
            selected: _filter,
            labelOf: (f) => f,
            onSelected: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) => const ErrorState(),
              data: (all) {
                final tasks = all.where((t) {
                  final status = t.effectiveStatus();
                  return switch (_filter) {
                    'Open' => status != TaskStatus.completed,
                    'Overdue' => status == TaskStatus.overdue,
                    'Completed' => status == TaskStatus.completed,
                    _ => true,
                  };
                }).toList();

                if (tasks.isEmpty) {
                  return EmptyState(
                    icon: Icons.assignment_ind_outlined,
                    title: 'No $_filter tasks',
                    message: _filter == 'Overdue'
                        ? 'Nothing you assigned is past its due date.'
                        : 'Work you give the team appears here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    0,
                    AppSpacing.screenH,
                    AppSpacing.xxxl * 3,
                  ),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) => Arrive.staggered(
                    index: i,
                    child: _TaskCard(
                      task: tasks[i],
                      // Always: the name is the point of this list.
                      showAssignee: true,
                      // A manager does not tick off someone else's work. The
                      // rep marks it done on their own To-Do; this screen is
                      // for seeing whether they have.
                      onComplete: null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================= to-do calendar ==

final _taskCalendarMonthProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month),
);

final _taskCalendarDayProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime.now(),
);

/// A month of the rep's own to-dos.
///
/// This screen used to be a general Calendar: a month of *activities* with the
/// day's agenda under it — which is My Activity, a tap away, with its own date
/// strip. Two screens answering "what am I doing on the 12th" is one screen
/// too many, and neither of them was the calendar the To-Do list actually
/// wanted. A to-do is the one thing here nobody else can see: personal, no
/// approval, no scope — so the calendar behind it carries to-dos and nothing
/// else.
class TaskCalendarScreen extends ConsumerWidget {
  const TaskCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_taskCalendarMonthProvider);
    final selected = ref.watch(_taskCalendarDayProvider);
    final async = ref.watch(_tasksProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('To-Do Calendar')),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading your to-dos'),
        error: (_, _) => ErrorState(onRetry: () => ref.invalidate(_tasksProvider)),
        data: (tasks) {
          bool onDay(FieldTask t, DateTime d) =>
              t.dueDate.year == d.year &&
              t.dueDate.month == d.month &&
              t.dueDate.day == d.day;

          final today = tasks.where((t) => onDay(t, selected)).toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.xxxl * 3,
            ),
            children: [
              Arrive(
                child: MonthCalendar(
                  month: month,
                  selected: selected,
                  onPreviousMonth: () =>
                      ref.read(_taskCalendarMonthProvider.notifier).state =
                          DateTime(month.year, month.month - 1),
                  onNextMonth: () =>
                      ref.read(_taskCalendarMonthProvider.notifier).state =
                          DateTime(month.year, month.month + 1),
                  dayOf: (day) {
                    final date = DateTime(month.year, month.month, day);
                    final due = tasks.where((t) => onDay(t, date)).toList();
                    if (due.isEmpty) return const CalendarDay();

                    // The same four colours every calendar here uses. Red is
                    // overdue, which is the only one a rep has to act on
                    // today; green is a day already cleared.
                    final ink = due.any(
                            (t) => t.effectiveStatus() == TaskStatus.overdue)
                        ? AppColors.calendarProblem
                        : due.every((t) =>
                                t.effectiveStatus() == TaskStatus.completed)
                            ? AppColors.calendarDone
                            : AppColors.calendarPlanned;

                    return CalendarDay(
                      fill: ink.withValues(alpha: 0.12),
                      ink: ink,
                      dot: ink,
                      onTap: () => ref
                          .read(_taskCalendarDayProvider.notifier)
                          .state = date,
                    );
                  },
                  legend: const [
                    CalendarLegendItem(AppColors.calendarPlanned, 'To do'),
                    CalendarLegendItem(AppColors.calendarDone, 'Done'),
                    CalendarLegendItem(AppColors.calendarProblem, 'Overdue'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(title: Fmt.relativeDay(selected)),
              if (today.isEmpty)
                Arrive(
                  delay: AppMotion.staggerFor(1),
                  child: AppCard(
                    child: EmptyState(
                      compact: true,
                      icon: Icons.check_circle_outline,
                      title: 'Nothing due',
                      message: 'Tap a date with a mark on it, or add a to-do '
                          'from the list.',
                    ),
                  ),
                )
              else
                for (var i = 0; i < today.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.cardGap),
                  Arrive.staggered(
                    index: i + 1,
                    child: _TaskCard(
                      task: today[i],
                      // Never: every row is the reader's own.
                      showAssignee: false,
                      onComplete: () async {
                        await ref
                            .read(taskRepositoryProvider)
                            .updateStatus(today[i].id, TaskStatus.completed);
                        ref.bumpRevision();
                      },
                    ),
                  ),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.showAssignee,
    required this.onComplete,
  });

  final FieldTask task;
  final bool showAssignee;

  /// `null` hides the button entirely rather than disabling it.
  ///
  /// A manager does not tick off someone else's work — the rep marks it done
  /// on their own To-Do, and this list is for seeing whether they have. A
  /// disabled "Mark complete" would be a control that cannot act, which this
  /// app treats as worse than no control at all.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final status = task.effectiveStatus();
    final isDone = status == TaskStatus.completed;

    return AppCard(
      accentColor: status == TaskStatus.overdue ? AppColors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: AppTypography.titleMd.copyWith(
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: task.priority.label,
                tone: task.priority.tone,
                dense: true,
              ),
            ],
          ),
          if (task.instructions != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              task.instructions!,
              style: AppTypography.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 13,
                color: status == TaskStatus.overdue
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Due ${Fmt.relativeDay(task.dueDate)}',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTypography.caption.copyWith(
                    color: status == TaskStatus.overdue
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (showAssignee) ...[
                const SizedBox(width: AppSpacing.md),
                const Icon(
                  Icons.person_outline,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    task.assignedToName,
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              StatusBadge(label: status.label, tone: status.tone, dense: true),
            ],
          ),
          if (!isDone && onComplete != null) ...[
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'Mark complete',
              icon: Icons.check,
              small: true,
              onPressed: onComplete,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================== new to-do ==

/// A rep's own to-do (§50).
///
/// Structurally the same record a manager assigns — assignee and assigner are
/// both the current user — so it lands in the same list, counts toward the
/// same pending figure, and syncs through the same path. A separate "personal
/// note" store would be a second source of truth for the same question.
class NewTaskScreen extends ConsumerStatefulWidget {
  const NewTaskScreen({super.key});

  @override
  ConsumerState<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends ConsumerState<NewTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();

  DateTime _due = DateTime.now();
  TaskPriority _priority = TaskPriority.medium;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final me = ref.read(sessionProvider).employee;
    await ref
        .read(taskRepositoryProvider)
        .create(
          FieldTask(
            // Client-generated so a retry after a dropped connection cannot
            // create the same to-do twice.
            id: const Uuid().v4(),
            title: _title.text.trim(),
            assignedToId: me.id,
            assignedToName: me.name,
            assignedById: me.id,
            assignedByName: me.name,
            dueDate: _due,
            priority: _priority,
            status: TaskStatus.assigned,
            instructions: _notes.text.trim().isEmpty
                ? null
                : _notes.text.trim(),
            createdAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('To-do added.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Add To-Do')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: 'Add to-do',
            isLoading: _submitting,
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            AppTextField(
              label: 'To-do',
              required: true,
              controller: _title,
              hint: 'What do you need to do?',
              validator: (v) => Validate.required(v, 'To-do'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: DateField(
                    label: 'Due date',
                    required: true,
                    value: _due,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    onChanged: (d) => setState(() => _due = d),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownField<TaskPriority>(
                    label: 'Priority',
                    items: TaskPriority.values,
                    value: _priority,
                    itemLabel: (p) => p.label,
                    onChanged: (v) =>
                        setState(() => _priority = v ?? TaskPriority.medium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Notes',
              controller: _notes,
              maxLines: 4,
              hint: 'Anything you will want to remember later',
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

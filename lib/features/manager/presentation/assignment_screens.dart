import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/engagement.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

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
          visitTarget: 132,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Assign Targets')),
      bottomNavigationBar: _loaded
          ? BottomActionBar(
              children: [
                SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
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
                    child: Text('Annual total',
                        style: AppTypography.titleSm
                            .copyWith(color: AppColors.brandDark)),
                  ),
                  Text(Fmt.money(_annualTotal),
                      style: AppTypography.titleMd
                          .copyWith(color: AppColors.brandDark)),
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
      backgroundColor: AppColors.background,
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
                        content:
                            Text('Rates saved for ${_employee!.name}.'),
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
                        child: Text('Local',
                            style: AppTypography.overline,
                            textAlign: TextAlign.center)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: Text('Outstation',
                            style: AppTypography.overline,
                            textAlign: TextAlign.center)),
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
                          child:
                              Text(mode.label, style: AppTypography.titleSm),
                        ),
                        Expanded(child: _RateInput(controller: _local[mode]!)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child: _RateInput(controller: _outstation[mode]!)),
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
    await ref.read(taskRepositoryProvider).create(
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
            locationName:
                _location.text.trim().isEmpty ? null : _location.text.trim(),
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
      backgroundColor: AppColors.background,
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

final _tasksProvider = FutureProvider.autoDispose<List<FieldTask>>((ref) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(taskRepositoryProvider).list(
        session,
        employeeId: session.isManager ? null : session.employee.id,
      );
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
    final session = ref.watch(sessionProvider);
    const filters = ['Open', 'Overdue', 'Completed', 'All'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: session.isManager
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/manage/tasks'),
              icon: const Icon(Icons.add),
              label: const Text('Assign'),
            )
          : null,
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
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xxxl * 3,
                  ),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) => _TaskCard(
                    task: tasks[i],
                    showAssignee: session.isManager,
                    onComplete: () async {
                      await ref
                          .read(taskRepositoryProvider)
                          .updateStatus(tasks[i].id, TaskStatus.completed);
                      ref.bumpRevision();
                    },
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.showAssignee,
    required this.onComplete,
  });

  final FieldTask task;
  final bool showAssignee;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final status = task.effectiveStatus();
    final isDone = status == TaskStatus.completed;

    return AppCard(
      accentColor:
          status == TaskStatus.overdue ? AppColors.error : null,
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
            Text(task.instructions!,
                style: AppTypography.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
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
                const Icon(Icons.person_outline,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(task.assignedToName,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
              const Spacer(),
              StatusBadge(label: status.label, tone: status.tone, dense: true),
            ],
          ),
          if (!isDone) ...[
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

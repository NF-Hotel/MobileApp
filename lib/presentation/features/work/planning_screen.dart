import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/presentation/features/work/my_work_view_model.dart';
import 'package:mobil_application/presentation/features/work/planning_view_model.dart';
import 'package:mobil_application/presentation/shared/app_theme.dart';
import 'package:mobil_application/presentation/shared/form_page.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The planning of a Manager (MIL-060): the shifts of a week, the rooms of the
/// housekeepers, and the trades that wait for approval.
class PlanningScreen extends StatefulWidget {
  /// Creates the screen over its [viewModel].
  const PlanningScreen({required this.viewModel, super.key});

  /// What the screen shows and does.
  final PlanningViewModel viewModel;

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(Strings.planning),
          actions: [
            IconButton(
              key: const ValueKey('refreshPlanning'),
              tooltip: Strings.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => unawaited(viewModel.load()),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: Strings.shiftsTab),
              const Tab(text: Strings.roomsTab),
              ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) => Tab(
                  key: const ValueKey('approvalsTab'),
                  text: viewModel.approvalCount == 0
                      ? Strings.approvalsTab
                      : '${Strings.approvalsTab} (${viewModel.approvalCount})',
                ),
              ),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final error = viewModel.errorMessage;
            return Column(
              children: [
                if (viewModel.isBusy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: FormError(error),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ShiftsTab(viewModel: viewModel),
                      _RoomsTab(viewModel: viewModel),
                      _ApprovalsTab(viewModel: viewModel),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _show(ScaffoldMessengerState messenger, WorkOutcome outcome) {
  if (outcome.message.isEmpty) {
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(outcome.message),
      backgroundColor: outcome.saved ? null : AppColors.error,
    ),
  );
}

Future<void> _run(
  BuildContext context,
  Future<WorkOutcome> Function() change,
) async {
  final messenger = ScaffoldMessenger.of(context);
  _show(messenger, await change());
}

class _ShiftsTab extends StatelessWidget {
  const _ShiftsTab({required this.viewModel});

  final PlanningViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = viewModel.days;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('previousWeek'),
              tooltip: Strings.previousWeek,
              icon: const Icon(Icons.chevron_left),
              onPressed: viewModel.isBusy
                  ? null
                  : () => unawaited(viewModel.previousWeek()),
            ),
            Expanded(
              child: Text(
                '${Strings.day(days.first)} – ${Strings.day(days.last)}',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('nextWeek'),
              tooltip: Strings.nextWeek,
              icon: const Icon(Icons.chevron_right),
              onPressed: viewModel.isBusy
                  ? null
                  : () => unawaited(viewModel.nextWeek()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final day in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(Strings.day(day), style: textTheme.titleMedium),
                    trailing: TextButton.icon(
                      key: ValueKey('addShift-${day.day}'),
                      onPressed: viewModel.isBusy
                          ? null
                          : () => unawaited(_edit(context, day, null)),
                      icon: const Icon(Icons.add),
                      label: const Text(Strings.addShift),
                    ),
                  ),
                  for (final shift in viewModel.shiftsOn(day)) ...[
                    const Divider(height: 1),
                    ListTile(
                      key: ValueKey('plannedShift-${shift.id}'),
                      title: Text(
                        '${Strings.times(shift.startsAt, shift.endsAt)} · '
                        '${Strings.role(shift.role)}',
                      ),
                      subtitle: Text(shift.assigneeName ?? Strings.nobodyYet),
                      trailing: PopupMenuButton<String>(
                        key: ValueKey('plannedShiftMenu-${shift.id}'),
                        tooltip: Strings.actions,
                        enabled: !viewModel.isBusy,
                        onSelected: (choice) => unawaited(
                          choice == 'edit'
                              ? _edit(context, day, shift)
                              : _run(
                                  context,
                                  () => viewModel.deleteShift(shift),
                                ),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            key: ValueKey('editShift-${shift.id}'),
                            value: 'edit',
                            child: const Text(Strings.editShift),
                          ),
                          PopupMenuItem(
                            key: ValueKey('deleteShift-${shift.id}'),
                            value: 'delete',
                            child: const Text(
                              Strings.deleteShift,
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, DateTime day, Shift? shift) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<WorkOutcome>(
      context: context,
      builder: (_) =>
          _ShiftDialog(viewModel: viewModel, day: day, existing: shift),
    );
    if (saved != null) {
      _show(messenger, saved);
    }
  }
}

class _ShiftDialog extends StatefulWidget {
  const _ShiftDialog({
    required this.viewModel,
    required this.day,
    required this.existing,
  });

  final PlanningViewModel viewModel;
  final DateTime day;
  final Shift? existing;

  @override
  State<_ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<_ShiftDialog> {
  late DateTime _day = widget.existing?.startsAt ?? widget.day;
  late TimeOfDay _start = widget.existing == null
      ? const TimeOfDay(hour: 7, minute: 0)
      : TimeOfDay.fromDateTime(widget.existing!.startsAt);
  late TimeOfDay _end = widget.existing == null
      ? const TimeOfDay(hour: 15, minute: 0)
      : TimeOfDay.fromDateTime(widget.existing!.endsAt);
  late StaffRole _role = widget.existing?.role ?? StaffRole.housekeeping;
  late int? _assigneeId = widget.existing?.assigneeId;
  bool _saving = false;

  String _clock(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(_day.year - 1),
      lastDate: DateTime(_day.year + 2),
    );
    if (picked != null) {
      setState(() => _day = picked);
    }
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked != null) {
      setState(() => start ? _start = picked : _end = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final outcome = await widget.viewModel.saveShift(
      day: _day,
      start: _start,
      end: _end,
      role: _role,
      assigneeId: _assigneeId,
      existing: widget.existing,
    );
    if (!mounted) {
      return;
    }
    if (outcome.saved) {
      Navigator.of(context).pop(outcome);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(outcome.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = widget.viewModel.staffFor(_role);
    final bodyLarge = Theme.of(context).textTheme.bodyLarge;
    return AlertDialog(
      title: Text(
        widget.existing == null ? Strings.addShift : Strings.editShift,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              key: const ValueKey('shiftDay'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text(Strings.date),
              subtitle: Text(Strings.day(_day)),
              onTap: _pickDay,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    key: const ValueKey('shiftStart'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(Strings.start),
                    subtitle: Text(_clock(_start)),
                    onTap: () => _pickTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    key: const ValueKey('shiftEnd'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(Strings.end),
                    subtitle: Text(_clock(_end)),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<StaffRole>(
              key: const ValueKey('shiftRole'),
              initialValue: _role,
              style: bodyLarge,
              decoration: const InputDecoration(labelText: Strings.roleLabel),
              items: [
                for (final role in StaffRole.values)
                  DropdownMenuItem(
                    value: role,
                    child: Text(Strings.role(role)),
                  ),
              ],
              onChanged: (role) => setState(() {
                _role = role ?? _role;
                _assigneeId = null;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              key: ValueKey('shiftWho-${_role.name}'),
              initialValue: people.any((account) => account.id == _assigneeId)
                  ? _assigneeId
                  : null,
              style: bodyLarge,
              decoration: const InputDecoration(labelText: Strings.who),
              items: [
                const DropdownMenuItem<int?>(child: Text(Strings.nobodyYet)),
                for (final account in people)
                  DropdownMenuItem<int?>(
                    value: account.id,
                    child: Text(account.displayName),
                  ),
              ],
              onChanged: (id) => setState(() => _assigneeId = id),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        TextButton(
          key: const ValueKey('saveShift'),
          onPressed: _saving ? null : _save,
          child: const Text(Strings.saveButton),
        ),
      ],
    );
  }
}

class _RoomsTab extends StatelessWidget {
  const _RoomsTab({required this.viewModel});

  final PlanningViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rooms = viewModel.rooms;
    if (rooms == null) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${Strings.housekeepers} (at least ${rooms.minimumRooms} rooms each)',
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final keeper in rooms.housekeepers)
                ListTile(
                  key: ValueKey('keeper-${keeper.id}'),
                  title: Text(keeper.name),
                  trailing: Text(
                    viewModel.isBelowMinimum(keeper)
                        ? '${keeper.roomCount} · ${Strings.belowMinimum}'
                        : '${keeper.roomCount}',
                    style: viewModel.isBelowMinimum(keeper)
                        ? textTheme.titleSmall?.copyWith(color: AppColors.error)
                        : textTheme.titleSmall,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(Strings.roomsTab, style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final (index, room) in rooms.rooms.indexed) ...[
                if (index > 0) const Divider(height: 1),
                ListTile(
                  title: Text('${Strings.roomTitle} ${room.roomNumber}'),
                  trailing: DropdownButton<int?>(
                    key: ValueKey('assign-${room.roomId}'),
                    value:
                        rooms.housekeepers.any(
                          (keeper) => keeper.id == room.staffId,
                        )
                        ? room.staffId
                        : null,
                    style: textTheme.bodyLarge,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<int?>(child: Text(Strings.nobody)),
                      for (final keeper in rooms.housekeepers)
                        DropdownMenuItem<int?>(
                          value: keeper.id,
                          child: Text(keeper.name),
                        ),
                    ],
                    onChanged: viewModel.isBusy
                        ? null
                        : (id) => unawaited(
                            _run(context, () => viewModel.assignRoom(room, id)),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab({required this.viewModel});

  final PlanningViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final shifts = viewModel.shiftApprovals;
    final rooms = viewModel.roomApprovals;
    if (shifts.isEmpty && rooms.isEmpty) {
      return const Center(child: Text(Strings.nothingToApprove));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final trade in shifts)
          _Approval(
            keyName: 'shiftApproval-${trade.id}',
            title: trade.isSwap
                ? '${Strings.swap}: ${trade.offeredByName} ↔ '
                      '${trade.takenByName ?? ''}'
                : '${Strings.giveAway}: ${trade.offeredByName} → '
                      '${trade.takenByName ?? ''}',
            detail: trade.isSwap
                ? '${Strings.shiftWhen(trade.shift.startsAt, trade.shift.endsAt)}\n'
                      '${Strings.shiftWhen(trade.swapShift!.startsAt, trade.swapShift!.endsAt)}'
                : Strings.shiftWhen(trade.shift.startsAt, trade.shift.endsAt),
            busy: viewModel.isBusy,
            onDecide: (step) =>
                _run(context, () => viewModel.decideShift(trade, step)),
          ),
        for (final trade in rooms)
          _Approval(
            keyName: 'roomApproval-${trade.id}',
            title: '${trade.fromName} → ${trade.toName}',
            detail:
                'Rooms ${Strings.roomNumbers(trade.give)}'
                '${trade.take.isEmpty ? '' : ' for ${Strings.roomNumbers(trade.take)}'}'
                '\n${Strings.leavesTooFew}',
            busy: viewModel.isBusy,
            onDecide: (step) =>
                _run(context, () => viewModel.decideRooms(trade, step)),
          ),
      ],
    );
  }
}

class _Approval extends StatelessWidget {
  const _Approval({
    required this.keyName,
    required this.title,
    required this.detail,
    required this.busy,
    required this.onDecide,
  });

  final String keyName;
  final String title;
  final String detail;
  final bool busy;
  final Future<void> Function(TradeStep step) onDecide;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      key: ValueKey(keyName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(title: Text(title), subtitle: Text(detail)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: ValueKey('$keyName-reject'),
                  onPressed: busy
                      ? null
                      : () => unawaited(onDecide(TradeStep.reject)),
                  child: const Text(Strings.reject),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: ValueKey('$keyName-approve'),
                  onPressed: busy
                      ? null
                      : () => unawaited(onDecide(TradeStep.approve)),
                  child: const Text(Strings.approve),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

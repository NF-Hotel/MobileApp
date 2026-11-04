import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/presentation/features/work/my_work_view_model.dart';
import 'package:mobil_application/presentation/shared/app_theme.dart';
import 'package:mobil_application/presentation/shared/form_page.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The own shifts and rooms of a member of staff, and the trades around them
/// (MIL-060): a tab of shifts for everybody, and a tab of rooms for a
/// housekeeper.
class MyWorkScreen extends StatefulWidget {
  /// Creates the screen over its [viewModel].
  const MyWorkScreen({required this.viewModel, super.key});

  /// What the screen shows and does.
  final MyWorkViewModel viewModel;

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final tabs = [
      const Tab(text: Strings.shiftsTab),
      if (viewModel.hasRooms) const Tab(text: Strings.roomsTab),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(Strings.myWork),
          actions: [
            IconButton(
              key: const ValueKey('refreshWork'),
              tooltip: Strings.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => unawaited(viewModel.load()),
            ),
          ],
          bottom: tabs.length > 1 ? TabBar(tabs: tabs) : null,
        ),
        body: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (!viewModel.knowsMe) {
              return const _Message(Strings.signInAgainForWork);
            }
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
                      if (viewModel.hasRooms) _RoomsTab(viewModel: viewModel),
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

/// Shows the receipt or the refusal of a step.
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
  Future<WorkOutcome> Function() step,
) async {
  final messenger = ScaffoldMessenger.of(context);
  _show(messenger, await step());
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const Divider(height: 1),
                child,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Two buttons side by side, the first filled.
class _Answer extends StatelessWidget {
  const _Answer({
    required this.keyPrefix,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
  });

  final String keyPrefix;
  final String primary;
  final VoidCallback? onPrimary;
  final String secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          key: ValueKey('$keyPrefix-secondary'),
          onPressed: onSecondary,
          child: Text(secondary),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: ValueKey('$keyPrefix-primary'),
          onPressed: onPrimary,
          child: Text(primary),
        ),
      ],
    ),
  );
}

class _ShiftsTab extends StatelessWidget {
  const _ShiftsTab({required this.viewModel});

  final MyWorkViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final busy = viewModel.isBusy;
    final swaps = viewModel.swapsForMe;
    final open = viewModel.openShifts;
    final trades = viewModel.myShiftTrades;
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (swaps.isNotEmpty)
            _Section(Strings.waitingForYou, [
              for (final trade in swaps)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: Text('${trade.offeredByName} asks to swap'),
                      subtitle: Text(
                        'You get ${_when(trade.shift)}\n'
                        'You give ${_when(trade.swapShift!)}',
                      ),
                      isThreeLine: true,
                    ),
                    _Answer(
                      keyPrefix: 'swap-${trade.id}',
                      primary: Strings.accept,
                      onPrimary: busy
                          ? null
                          : () => _run(
                              context,
                              () =>
                                  viewModel.stepShift(trade, TradeStep.accept),
                            ),
                      secondary: Strings.decline,
                      onSecondary: busy
                          ? null
                          : () => _run(
                              context,
                              () =>
                                  viewModel.stepShift(trade, TradeStep.decline),
                            ),
                    ),
                  ],
                ),
            ]),
          _Section(Strings.myShifts, [
            if (viewModel.myShifts.isEmpty)
              const ListTile(title: Text(Strings.noShifts)),
            for (final shift in viewModel.myShifts)
              _MyShiftTile(viewModel: viewModel, shift: shift),
          ]),
          if (open.isNotEmpty)
            _Section(Strings.openShifts, [
              for (final trade in open)
                ListTile(
                  key: ValueKey('open-${trade.id}'),
                  leading: const Icon(Icons.event_available),
                  title: Text(_when(trade.shift)),
                  subtitle: Text('From ${trade.offeredByName}'),
                  trailing: FilledButton(
                    key: ValueKey('take-${trade.id}'),
                    onPressed: busy
                        ? null
                        : () => _run(
                            context,
                            () => viewModel.stepShift(trade, TradeStep.take),
                          ),
                    child: const Text(Strings.take),
                  ),
                ),
            ]),
          if (trades.isNotEmpty)
            _Section(Strings.myTrades, [
              for (final trade in trades)
                ListTile(
                  key: ValueKey('myShiftTrade-${trade.id}'),
                  title: Text(_describe(trade)),
                  subtitle: Text(Strings.tradeState(trade.state)),
                  trailing: viewModel.canWithdrawShift(trade)
                      ? TextButton(
                          key: ValueKey('withdrawShift-${trade.id}'),
                          onPressed: busy
                              ? null
                              : () => _run(
                                  context,
                                  () => viewModel.stepShift(
                                    trade,
                                    TradeStep.withdraw,
                                  ),
                                ),
                          child: const Text(Strings.withdraw),
                        )
                      : null,
                ),
            ]),
        ],
      ),
    );
  }

  static String _when(Shift shift) =>
      Strings.shiftWhen(shift.startsAt, shift.endsAt);

  static String _describe(ShiftTrade trade) {
    final swap = trade.swapShift;
    return swap == null
        ? '${Strings.giveAway}: ${_when(trade.shift)}'
              '${trade.takenByName == null ? '' : ' to ${trade.takenByName}'}'
        : '${Strings.swap}: ${_when(trade.shift)} for ${_when(swap)}';
  }
}

class _MyShiftTile extends StatelessWidget {
  const _MyShiftTile({required this.viewModel, required this.shift});

  final MyWorkViewModel viewModel;
  final Shift shift;

  @override
  Widget build(BuildContext context) {
    final pending = viewModel.pendingTradeOn(shift);
    return ListTile(
      key: ValueKey('myShift-${shift.id}'),
      leading: const Icon(Icons.schedule),
      title: Text(Strings.day(shift.startsAt)),
      subtitle: Text(
        '${Strings.times(shift.startsAt, shift.endsAt)} · '
        '${Strings.role(shift.role)}'
        '${pending == null ? '' : '\n${Strings.tradeState(pending.state)}'}',
      ),
      isThreeLine: pending != null,
      trailing: viewModel.canOffer(shift)
          ? PopupMenuButton<String>(
              key: ValueKey('shiftMenu-${shift.id}'),
              tooltip: Strings.actions,
              enabled: !viewModel.isBusy,
              onSelected: (choice) => unawaited(_choose(context, choice)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: ValueKey('giveAway-${shift.id}'),
                  value: 'give',
                  child: const Text(Strings.giveAway),
                ),
                PopupMenuItem(
                  key: ValueKey('swap-${shift.id}'),
                  value: 'swap',
                  child: const Text('${Strings.swap}…'),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _choose(BuildContext context, String choice) async {
    final messenger = ScaffoldMessenger.of(context);
    if (choice == 'give') {
      _show(messenger, await viewModel.giveAway(shift));
      return;
    }
    final candidates = viewModel.swapCandidatesFor(shift);
    final other = await showDialog<Shift>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text(Strings.chooseSwap),
        children: [
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(Strings.noSwapCandidates),
            ),
          for (final candidate in candidates)
            SimpleDialogOption(
              key: ValueKey('swapOption-${candidate.id}'),
              onPressed: () => Navigator.of(context).pop(candidate),
              child: Text(
                '${Strings.shiftWhen(candidate.startsAt, candidate.endsAt)}\n'
                '${candidate.assigneeName ?? ''}',
              ),
            ),
        ],
      ),
    );
    if (other != null) {
      _show(messenger, await viewModel.swap(shift, other));
    }
  }
}

class _RoomsTab extends StatelessWidget {
  const _RoomsTab({required this.viewModel});

  final MyWorkViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final busy = viewModel.isBusy;
    final mine = viewModel.myRooms;
    final incoming = viewModel.roomTradesForMe;
    final trades = viewModel.myRoomTrades;
    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${Strings.myRooms} (${mine.length})',
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mine.isEmpty)
                    const Text(Strings.noRooms2)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final room in mine)
                          Chip(
                            key: ValueKey('myRoom-${room.roomId}'),
                            label: Text(room.roomNumber),
                          ),
                      ],
                    ),
                  if (mine.length < viewModel.minimumRooms) ...[
                    const SizedBox(height: 8),
                    Text(
                      'At least ${viewModel.minimumRooms} rooms each, unless '
                      'a Manager says otherwise.',
                      style: textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('tradeRooms'),
                    onPressed: busy || mine.isEmpty
                        ? null
                        : () => unawaited(_offer(context)),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text(Strings.giveOrTradeRooms),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (incoming.isNotEmpty)
            _Section(Strings.waitingForYou, [
              for (final trade in incoming)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.meeting_room),
                      title: Text('${trade.fromName} offers rooms'),
                      subtitle: Text(
                        'You get ${Strings.roomNumbers(trade.give)}'
                        '${trade.take.isEmpty ? '' : '\nYou give ${Strings.roomNumbers(trade.take)}'}',
                      ),
                      isThreeLine: trade.take.isNotEmpty,
                    ),
                    _Answer(
                      keyPrefix: 'roomTrade-${trade.id}',
                      primary: Strings.accept,
                      onPrimary: busy
                          ? null
                          : () => _run(
                              context,
                              () =>
                                  viewModel.stepRooms(trade, TradeStep.accept),
                            ),
                      secondary: Strings.decline,
                      onSecondary: busy
                          ? null
                          : () => _run(
                              context,
                              () =>
                                  viewModel.stepRooms(trade, TradeStep.decline),
                            ),
                    ),
                  ],
                ),
            ]),
          if (trades.isNotEmpty)
            _Section(Strings.myTrades, [
              for (final trade in trades)
                ListTile(
                  key: ValueKey('myRoomTrade-${trade.id}'),
                  title: Text(
                    viewModel.offeredRooms(trade)
                        ? 'To ${trade.toName}: ${Strings.roomNumbers(trade.give)}'
                              '${trade.take.isEmpty ? '' : ' for ${Strings.roomNumbers(trade.take)}'}'
                        : 'From ${trade.fromName}: '
                              '${Strings.roomNumbers(trade.give)}'
                              '${trade.take.isEmpty ? '' : ' for ${Strings.roomNumbers(trade.take)}'}',
                  ),
                  subtitle: Text(Strings.tradeState(trade.state)),
                  trailing: viewModel.canWithdrawRooms(trade)
                      ? TextButton(
                          key: ValueKey('withdrawRooms-${trade.id}'),
                          onPressed: busy
                              ? null
                              : () => _run(
                                  context,
                                  () => viewModel.stepRooms(
                                    trade,
                                    TradeStep.withdraw,
                                  ),
                                ),
                          child: const Text(Strings.withdraw),
                        )
                      : null,
                ),
            ]),
        ],
      ),
    );
  }

  Future<void> _offer(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<_RoomOffer>(
      context: context,
      builder: (_) => _RoomTradeDialog(viewModel: viewModel),
    );
    if (choice != null) {
      _show(
        messenger,
        await viewModel.offerRooms(choice.colleague, choice.give, choice.take),
      );
    }
  }
}

/// What the dialog of a trade of rooms answers.
typedef _RoomOffer = ({Housekeeper colleague, List<int> give, List<int> take});

class _RoomTradeDialog extends StatefulWidget {
  const _RoomTradeDialog({required this.viewModel});

  final MyWorkViewModel viewModel;

  @override
  State<_RoomTradeDialog> createState() => _RoomTradeDialogState();
}

class _RoomTradeDialogState extends State<_RoomTradeDialog> {
  Housekeeper? _colleague;
  final Set<int> _give = <int>{};
  final Set<int> _take = <int>{};

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final colleague = _colleague;
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text(Strings.giveOrTradeRooms),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (viewModel.colleagues.isEmpty)
              const Text(Strings.noColleagues)
            else
              DropdownButtonFormField<Housekeeper>(
                key: const ValueKey('tradeColleague'),
                initialValue: colleague,
                style: textTheme.bodyLarge,
                decoration: const InputDecoration(labelText: Strings.colleague),
                items: [
                  for (final keeper in viewModel.colleagues)
                    DropdownMenuItem(
                      value: keeper,
                      child: Text('${keeper.name} (${keeper.roomCount})'),
                    ),
                ],
                onChanged: (keeper) => setState(() {
                  _colleague = keeper;
                  _take.clear();
                }),
              ),
            const SizedBox(height: 16),
            Text(Strings.roomsToGive, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            _RoomChoice(
              keyPrefix: 'give',
              rooms: viewModel.myRooms,
              chosen: _give,
              onChanged: () => setState(() {}),
            ),
            if (colleague != null) ...[
              const SizedBox(height: 16),
              Text(Strings.roomsToTake, style: textTheme.titleSmall),
              const SizedBox(height: 8),
              _RoomChoice(
                keyPrefix: 'take',
                rooms: viewModel.roomsOf(colleague.id),
                chosen: _take,
                onChanged: () => setState(() {}),
              ),
              if (_give.isNotEmpty &&
                  viewModel.needsApproval(
                    _give.length,
                    _take.length,
                    colleague,
                  )) ...[
                const SizedBox(height: 16),
                Text(
                  Strings.needsManager,
                  key: const ValueKey('needsManager'),
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        TextButton(
          key: const ValueKey('sendRoomTrade'),
          onPressed: colleague == null || _give.isEmpty
              ? null
              : () => Navigator.of(context).pop<_RoomOffer>((
                  colleague: colleague,
                  give: _give.toList(),
                  take: _take.toList(),
                )),
          child: const Text(Strings.send),
        ),
      ],
    );
  }
}

class _RoomChoice extends StatelessWidget {
  const _RoomChoice({
    required this.keyPrefix,
    required this.rooms,
    required this.chosen,
    required this.onChanged,
  });

  final String keyPrefix;
  final List<RoomAssignment> rooms;
  final Set<int> chosen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final room in rooms)
        FilterChip(
          key: ValueKey('$keyPrefix-${room.roomId}'),
          label: Text(room.roomNumber),
          selected: chosen.contains(room.roomId),
          onSelected: (selected) {
            selected ? chosen.add(room.roomId) : chosen.remove(room.roomId);
            onChanged();
          },
        ),
    ],
  );
}

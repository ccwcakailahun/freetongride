import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../state/ride_controller.dart';

Future<void> showChatSheet(BuildContext context) {
  context.read<RideController>().loadMessages();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(value: context.read<RideController>(), child: const _ChatSheet()),
  );
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet();

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _text = TextEditingController();
  bool _sending = false;

  static const _quick = ["I'm on my way", "I'm at the pickup point", 'Please wait 2 minutes', 'Where are you?'];

  Future<void> _send([String? preset]) async {
    final t = (preset ?? _text.text).trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    try {
      await context.read<RideController>().send(t);
      _text.clear();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<RideController>();
    final me = context.read<Session>().user!.id;
    final other = rc.ride?.driver?.shortName ?? 'Driver';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(children: [
              Text('Chat with $other', style: FtrText.h2),
            ]),
          ),
          Expanded(
            child: rc.messages.isEmpty
                ? const FtrEmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'No messages yet', message: 'Send a quick note to help your driver find you.')
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: rc.messages.length,
                    itemBuilder: (_, i) {
                      final m = rc.messages[rc.messages.length - 1 - i];
                      final mine = m.senderId == me;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                          decoration: BoxDecoration(
                            color: mine ? FtrColors.blue : const Color(0xFFF0F3F9),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mine ? 18 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 18),
                            ),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(m.text, style: FtrText.body.copyWith(color: mine ? Colors.white : FtrColors.ink)),
                            Text(clock(m.createdAt), style: FtrText.small.copyWith(fontSize: 11, color: mine ? Colors.white70 : FtrColors.muted)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final q in _quick)
                  Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(q), onPressed: _sending ? null : () => _send(q))),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(children: [
                Expanded(child: FtrPlainField(hint: 'Type a message', controller: _text, height: 56, onSubmitted: (_) => _send())),
                const SizedBox(width: 10),
                Material(
                  color: FtrColors.blue,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

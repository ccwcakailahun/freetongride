import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import 'common.dart';
import 'shell.dart';

/// Canvas 9 — Wallet.
class WalletTab extends StatefulWidget {
  const WalletTab({super.key});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  WalletSummary? _wallet;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await context.read<Session>().api.wallet();
      if (mounted) setState(() => _wallet = w);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _addFunds() async {
    final amount = await showModalBottomSheet<double>(context: context, isScrollControlled: true, builder: (_) => const _AddFundsSheet());
    if (amount == null || !mounted) return;
    try {
      final w = await context.read<Session>().api.topUp(amount, PaymentMethod.orangeMoney);
      if (!mounted) return;
      setState(() => _wallet = w);
      context.read<Session>().refresh();
      showToast(context, '${le(amount)} added to your wallet.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _soon(String what) => showToast(context, '$what is coming soon.', icon: Icons.info_outline_rounded);

  @override
  Widget build(BuildContext context) {
    final w = _wallet;
    return Scaffold(
      drawer: PassengerDrawer(onTab: (i) => HomeShell.switchTab(context, i)),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
            children: [
              Builder(builder: (ctx) => FtrTopBar(onMenu: () => Scaffold.of(ctx).openDrawer())),
              const SizedBox(height: 6),
              const GreetingHeader(),
              const SizedBox(height: 18),
              _BalanceCard(
                balance: w?.balance,
                hidden: _hidden,
                onToggle: () => setState(() => _hidden = !_hidden),
                onAdd: _addFunds,
                onSend: () => _soon('Sending money'),
              ),
              const SizedBox(height: 24),
              FtrSectionHeader('Payment Methods', action: 'Manage', onAction: () => _soon('Managing payment methods')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _MethodTile(icon: Icons.credit_card_rounded, title: 'Card', subtitle: 'Coming soon', color: FtrColors.blue, onTap: () => _soon('Card payments'))),
                const SizedBox(width: 10),
                Expanded(child: _MethodTile(icon: Icons.phone_android_rounded, title: 'Mobile Money', subtitle: 'Orange, Afrimoney', color: FtrColors.orange, onTap: _addFunds)),
                const SizedBox(width: 10),
                Expanded(child: _MethodTile(icon: Icons.payments_rounded, title: 'Cash', subtitle: 'Pay on ride', color: FtrColors.green, onTap: () {})),
                const SizedBox(width: 10),
                Expanded(child: _MethodTile(icon: Icons.account_balance_wallet_rounded, title: 'App Wallet', subtitle: 'Use balance', color: FtrColors.blue, onTap: () {})),
              ]),
              const SizedBox(height: 16),
              Material(
                color: FtrColors.greenSoft.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const FtrIconTile(Icons.card_giftcard_rounded, color: FtrColors.green, background: Color(0xFFD4F3E2), size: 58, circle: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Rewards & Vouchers', style: FtrText.title.copyWith(fontSize: 17)),
                        const SizedBox(height: 2),
                        Text('Get discounts, earn points and ride more across Freetown.', style: FtrText.bodyMuted.copyWith(fontSize: 13.5)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    FtrChipButton(label: 'View all', color: FtrColors.green, height: 44, onPressed: () => _soon('Vouchers')),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              FtrCard(
                child: Row(children: [
                  const FtrIconTile(Icons.star_rounded, color: FtrColors.orange, background: FtrColors.orangeSoft, size: 56, circle: true),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('My Points', style: FtrText.bodyMuted),
                    Text('${w?.points ?? 0} points', style: FtrText.h2.copyWith(fontSize: 22)),
                  ]),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 44, color: FtrColors.border),
                  const SizedBox(width: 16),
                  Expanded(child: Text('Ride more.\nEarn rewards.', style: FtrText.bodyMuted)),
                  const Icon(Icons.chevron_right_rounded, color: FtrColors.blue, size: 28),
                ]),
              ),
              const SizedBox(height: 24),
              FtrSectionHeader('Transaction History', action: 'See all', onAction: _load),
              const SizedBox(height: 6),
              if (w == null)
                const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
              else if (w.recent.isEmpty)
                const FtrEmptyState(icon: Icons.receipt_long_rounded, title: 'No transactions yet', message: 'Top-ups and ride payments will appear here.')
              else
                for (final t in w.recent) _TxRow(tx: t),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.hidden, required this.onToggle, required this.onAdd, required this.onSend});
  final double? balance;
  final bool hidden;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: FtrColors.walletGradient, borderRadius: BorderRadius.circular(26), boxShadow: ftrButtonShadow),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(right: 28, top: 66, child: Opacity(opacity: 0.95, child: FtrLogoMark(size: 112))),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 18, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Wallet Balance', style: FtrText.body.copyWith(color: Colors.white, fontSize: 17))),
              Material(
                color: Colors.white.withValues(alpha: 0.18),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: hidden ? 'Show balance' : 'Hide balance',
                  onPressed: onToggle,
                  icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white),
                ),
              ),
            ]),
            Text(balance == null ? 'Le …' : (hidden ? 'Le ••••' : le(balance!)), style: FtrText.display.copyWith(color: Colors.white, fontSize: 40)),
            const SizedBox(height: 4),
            Text('Ready for your next ride', style: FtrText.body.copyWith(color: Colors.white.withValues(alpha: 0.9))),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: _CardButton(icon: Icons.add_circle_rounded, label: 'Add funds', bg: Colors.white, fg: FtrColors.blue, onTap: onAdd),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CardButton(icon: Icons.near_me_rounded, label: 'Send money', bg: FtrColors.green, fg: Colors.white, onTap: onSend),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({required this.icon, required this.label, required this.bg, required this.fg, required this.onTap});
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(27),
          child: InkWell(
            borderRadius: BorderRadius.circular(27),
            onTap: onTap,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: fg, size: 24),
              const SizedBox(width: 8),
              Text(label, style: FtrText.label.copyWith(color: fg, fontSize: 16)),
            ]),
          ),
        ),
      );
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 4, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Icon(icon, color: color, size: 40)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.title.copyWith(fontSize: 12.5, letterSpacing: -0.2))),
            ]),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.small.copyWith(fontSize: 11.5)),
          ]),
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});
  final WalletTx tx;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (tx.type) {
      WalletTxType.topUp || WalletTxType.refund => (Icons.add_rounded, FtrColors.blue),
      WalletTxType.tip => (Icons.favorite_rounded, FtrColors.orange),
      WalletTxType.adjustment => (Icons.card_giftcard_rounded, FtrColors.purple),
      _ => (Icons.directions_car_rounded, FtrColors.green),
    };
    final credit = tx.amount > 0;
    final filled = tx.type == WalletTxType.ridePayment;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: FtrColors.divider))),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: filled ? color : color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: filled ? Colors.white : color, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.title.copyWith(fontSize: 16)),
            Text(friendlyDateTime(tx.createdAt), style: FtrText.small.copyWith(fontSize: 13.5)),
          ]),
        ),
        Text(le(tx.amount, signed: true), style: FtrText.title.copyWith(fontSize: 17, color: credit ? FtrColors.green : FtrColors.ink)),
        const Icon(Icons.chevron_right_rounded, color: FtrColors.muted),
      ]),
    );
  }
}

class _AddFundsSheet extends StatefulWidget {
  const _AddFundsSheet();

  @override
  State<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<_AddFundsSheet> {
  double _amount = 100;
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add funds', style: FtrText.h2),
        const SizedBox(height: 4),
        Text('Top up with Orange Money.', style: FtrText.bodyMuted),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final a in [50.0, 100.0, 200.0, 500.0])
            ChoiceChip(
              label: Text(le(a)),
              selected: _amount == a && _custom.text.isEmpty,
              onSelected: (_) => setState(() {
                _amount = a;
                _custom.clear();
              }),
            ),
        ]),
        const SizedBox(height: 14),
        FtrPlainField(
          hint: 'Other amount',
          icon: Icons.edit_rounded,
          controller: _custom,
          keyboardType: TextInputType.number,
          onChanged: (v) => setState(() => _amount = double.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 18),
        FtrPrimaryButton(label: 'Add ${le(_amount)}', onPressed: _amount >= 10 ? () => Navigator.pop(context, _amount) : null),
      ]),
    );
  }
}

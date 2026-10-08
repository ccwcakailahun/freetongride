import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';

/// Driver version of Canvas 9: balance, today and this week, withdraw to Orange Money.
class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});

  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  Earnings? _e;
  List<Withdrawal> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<Session>().api;
    try {
      final results = await Future.wait([api.earnings(), api.withdrawals()]);
      if (!mounted) return;
      setState(() {
        _e = results[0] as Earnings;
        _withdrawals = results[1] as List<Withdrawal>;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _withdraw() async {
    final user = context.read<Session>().user!;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WithdrawSheet(balance: _e?.balance ?? 0, phone: user.phone),
    );
    if (ok == true) {
      _load();
      if (mounted) showToast(context, 'Withdrawal requested. We will pay it after approval.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), children: [
          const FtrTopBar(hasUnread: false, leading: SizedBox(width: 48)),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0E9F5C), Color(0xFF16B86C), Color(0xFF0B7A48)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x3319B868), blurRadius: 18, offset: Offset(0, 8))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              const Positioned(right: 24, top: 40, child: Opacity(opacity: 0.25, child: FtrLogoMark(size: 110))),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Available balance', style: FtrText.body.copyWith(color: Colors.white, fontSize: 17)),
                  Text(e == null ? 'Le …' : le(e.balance), style: FtrText.display.copyWith(color: Colors.white, fontSize: 40)),
                  Text('Earnings after commission', style: FtrText.body.copyWith(color: Colors.white70)),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(27),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(27),
                        onTap: e == null ? null : _withdraw,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.arrow_circle_down_rounded, color: FtrColors.green),
                          const SizedBox(width: 8),
                          Text('Withdraw to Orange Money', style: FtrText.label.copyWith(color: FtrColors.green, fontSize: 16)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Tile(label: 'Today', value: le(e?.today ?? 0), sub: '${e?.tripsToday ?? 0} trips', icon: Icons.today_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _Tile(label: 'This week', value: le(e?.thisWeek ?? 0), sub: '${e?.tripsThisWeek ?? 0} trips', icon: Icons.date_range_rounded)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _Tile(label: 'Commission', value: le(e?.commissionThisWeek ?? 0), sub: 'this week', icon: Icons.percent_rounded, color: FtrColors.orange)),
            const SizedBox(width: 10),
            Expanded(child: _Tile(label: 'Rating', value: '★ ${(e?.rating ?? 5).toStringAsFixed(2)}', sub: 'from passengers', icon: Icons.star_rounded, color: FtrColors.star)),
          ]),
          if (_withdrawals.isNotEmpty) ...[
            const SizedBox(height: 22),
            const FtrSectionHeader('Withdrawals'),
            const SizedBox(height: 8),
            for (final w in _withdrawals.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const FtrIconTile(Icons.arrow_circle_down_rounded, size: 46, color: FtrColors.green, background: FtrColors.greenSoft),
                title: Text('${w.method} ${w.accountNumber}', style: FtrText.title),
                subtitle: Text(friendlyDateTime(w.createdAt), style: FtrText.small),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(le(w.amount), style: FtrText.title),
                  Text(w.status, style: FtrText.small.copyWith(color: w.status == 'Approved' ? FtrColors.green : (w.status == 'Rejected' ? FtrColors.red : FtrColors.orange))),
                ]),
              ),
          ],
          const SizedBox(height: 22),
          const FtrSectionHeader('Recent activity'),
          const SizedBox(height: 8),
          if (e == null)
            const Center(child: CircularProgressIndicator())
          else if (e.recent.isEmpty)
            const FtrEmptyState(icon: Icons.receipt_long_rounded, title: 'No earnings yet', message: 'Completed trips will show here.')
          else
            for (final t in e.recent)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: FtrColors.divider))),
                child: Row(children: [
                  FtrIconTile(t.amount >= 0 ? Icons.directions_car_rounded : Icons.remove_circle_outline_rounded, size: 46,
                      circle: true, color: t.amount >= 0 ? FtrColors.green : FtrColors.orange, background: t.amount >= 0 ? FtrColors.greenSoft : FtrColors.orangeSoft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.title.copyWith(fontSize: 15)),
                      Text(friendlyDateTime(t.createdAt), style: FtrText.small),
                    ]),
                  ),
                  Text(le(t.amount, signed: true), style: FtrText.title.copyWith(color: t.amount >= 0 ? FtrColors.green : FtrColors.ink)),
                ]),
              ),
        ]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.sub, required this.icon, this.color = FtrColors.green});
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => FtrCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          FtrIconTile(icon, size: 44, color: color, background: color.withValues(alpha: 0.12)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: FtrText.small),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.h3.copyWith(fontSize: 17)),
              Text(sub, style: FtrText.small.copyWith(fontSize: 11.5)),
            ]),
          ),
        ]),
      );
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.balance, required this.phone});
  final double balance;
  final String phone;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final _amount = TextEditingController(text: widget.balance.floor().toString());
  late final _account = TextEditingController(text: prettyPhone(widget.phone));
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await context.read<Session>().api.withdraw(double.tryParse(_amount.text) ?? 0, 'Orange Money', _account.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Withdraw', style: FtrText.h2),
          Text('Available: ${le(widget.balance)}. Minimum Le 50.', style: FtrText.bodyMuted),
          const SizedBox(height: 16),
          FtrIconField(icon: Icons.payments_outlined, label: 'Amount (Le)', controller: _amount, keyboardType: TextInputType.number, valueStyleBold: true),
          const SizedBox(height: 12),
          FtrIconField(icon: Icons.phone_android_rounded, label: 'Orange Money number', controller: _account, keyboardType: TextInputType.phone, valueStyleBold: true),
          const SizedBox(height: 18),
          DriverButton(label: 'Request withdrawal', loading: _busy, onPressed: _submit),
        ]),
      );
}

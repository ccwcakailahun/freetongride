import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/driver_controller.dart';
import 'documents_screen.dart';

IconData serviceIcon(String name) => switch (name.toLowerCase()) {
      'okada' => Icons.two_wheeler_rounded,
      'keke' => Icons.electric_rickshaw_rounded,
      _ => Icons.directions_car_filled_rounded,
    };

/// Step 2: ride type and vehicle details.
class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  late final DriverProfile? _p = context.read<DriverController>().profile;
  List<ServiceInfo> _services = [];
  late String? _serviceId = _p?.serviceId;
  late final _make = TextEditingController(text: _p?.vehicleMake);
  late final _model = TextEditingController(text: _p?.vehicleModel);
  late final _color = TextEditingController(text: _p?.vehicleColor);
  late final _year = TextEditingController(text: _p?.vehicleYear?.toString());
  late final _plate = TextEditingController(text: _p?.plateNumber);
  late final _licence = TextEditingController(text: _p?.licenceNumber);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<Session>().api.services().then((s) {
      if (mounted) setState(() => _services = s);
    }).catchError((e) {
      if (mounted) showError(context, e);
    });
  }

  Future<void> _save() async {
    if (_serviceId == null) {
      showError(context, ApiException('Choose what you drive: Okada, Keke or Car.'));
      return;
    }
    setState(() => _busy = true);
    final dc = context.read<DriverController>();
    try {
      dc.profile = await dc.api.saveVehicle(
        serviceId: _serviceId!,
        licenceNumber: _licence.text.trim(),
        make: _make.text.trim(),
        model: _model.text.trim(),
        color: _color.text.trim(),
        year: int.tryParse(_year.text) ?? 0,
        plate: _plate.text.trim(),
      );
      if (!mounted) return;
      if (widget.editing) {
        Navigator.pop(context);
      } else {
        go(context, const DocumentsScreen());
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_make, _model, _color, _year, _plate, _licence]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
            Row(children: [
              if (widget.editing) const FtrBackButton() else const SizedBox(width: 48),
              const Expanded(child: Center(child: FtrBrandHeader(size: FtrBrandSize.compact))),
              const SizedBox(width: 48),
            ]),
            const SizedBox(height: 16),
            const _StepBar(step: 2),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Your '),
                TextSpan(text: 'vehicle', style: FtrText.display.copyWith(color: FtrColors.green)),
              ]),
              textAlign: TextAlign.center,
              style: FtrText.display.copyWith(fontSize: 34),
            ),
            const SizedBox(height: 6),
            Text('Passengers see these details when you accept their ride.', textAlign: TextAlign.center, style: FtrText.body.copyWith(color: FtrColors.muted)),
            const SizedBox(height: 20),
            Text('What do you drive?', style: FtrText.title.copyWith(fontSize: 17)),
            const SizedBox(height: 10),
            Row(children: [
              for (final s in _services) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _serviceId = s.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _serviceId == s.id ? FtrColors.greenSoft : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _serviceId == s.id ? FtrColors.green : FtrColors.border, width: _serviceId == s.id ? 2 : 1.2),
                        boxShadow: ftrSoftShadow,
                      ),
                      child: Column(children: [
                        Icon(serviceIcon(s.name), size: 38, color: _serviceId == s.id ? FtrColors.green : FtrColors.body),
                        const SizedBox(height: 6),
                        Text(s.name, style: FtrText.title),
                        Text('${s.seats} seat${s.seats == 1 ? '' : 's'}', style: FtrText.small),
                      ]),
                    ),
                  ),
                ),
                if (s != _services.last) const SizedBox(width: 10),
              ],
            ]),
            const SizedBox(height: 18),
            FtrIconField(icon: Icons.directions_car_outlined, label: 'Make', hint: 'e.g. Toyota', controller: _make, textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            FtrIconField(icon: Icons.category_outlined, label: 'Model', hint: 'e.g. Corolla', controller: _model, textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FtrIconField(icon: Icons.palette_outlined, label: 'Colour', hint: 'White', controller: _color, textCapitalization: TextCapitalization.words)),
              const SizedBox(width: 10),
              Expanded(
                child: FtrIconField(
                  icon: Icons.event_outlined,
                  label: 'Year',
                  hint: '2016',
                  controller: _year,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            FtrIconField(icon: Icons.pin_outlined, label: 'Plate number', hint: 'e.g. AFS 284', controller: _plate, textCapitalization: TextCapitalization.characters),
            const SizedBox(height: 12),
            FtrIconField(icon: Icons.badge_outlined, label: 'Driving licence number', hint: 'As printed on your licence', controller: _licence, textCapitalization: TextCapitalization.characters),
            const SizedBox(height: 22),
            DriverButton(label: widget.editing ? 'Save vehicle' : 'Continue to documents', loading: _busy, onPressed: _save),
          ]),
        ),
      ),
    );
  }
}

/// Account · Vehicle · Documents · Approval progress.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => StepBar(step: step);
}

class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Account', 'Vehicle', 'Documents', 'Approval'];
    return Row(children: [
      for (var i = 0; i < 4; i++) ...[
        Expanded(
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 6,
              decoration: BoxDecoration(color: i < step ? FtrColors.green : const Color(0xFFE2E7F0), borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 6),
            Text(labels[i], style: FtrText.small.copyWith(color: i < step ? FtrColors.green : FtrColors.muted, fontWeight: i == step - 1 ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
        if (i < 3) const SizedBox(width: 6),
      ],
    ]);
  }
}

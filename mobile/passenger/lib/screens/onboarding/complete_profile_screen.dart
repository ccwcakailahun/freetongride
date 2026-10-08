import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../ride/choose_destination_screen.dart';

/// Canvas 19 — Complete your profile. Also opened from Account → Edit Profile.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final AppUser _me = context.read<Session>().user!;
  late final _name = TextEditingController(text: _me.fullName);
  late final _email = TextEditingController(text: _me.email);
  late final _emergency = TextEditingController(text: _me.emergencyContact == null ? '' : prettyPhone(_me.emergencyContact!));
  late String? _area = _me.homeArea;
  String? _photo;
  List<SavedPlace> _places = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photo = context.read<Session>().client.absolute(_me.photoUrl);
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      final p = await context.read<Session>().api.places();
      if (mounted) setState(() => _places = p);
    } catch (_) {}
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 85);
    if (file == null || !mounted) return;
    final session = context.read<Session>();
    try {
      final u = await session.api.uploadPhoto(await file.readAsBytes(), file.name);
      session.setUser(u);
      setState(() => _photo = session.client.absolute(u.photoUrl));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pickArea() async {
    final place = await go<Place>(context, const ChooseDestinationScreen(pickOnly: true, title: 'Preferred home area'));
    if (place != null) setState(() => _area = place.address);
  }

  Future<void> _addPlace() async {
    final hasHome = _places.any((p) => p.label == 'Home');
    final label = hasHome ? (_places.any((p) => p.label == 'Work') ? 'Favourite' : 'Work') : 'Home';
    final place = await go<Place>(context, ChooseDestinationScreen(pickOnly: true, title: 'Add $label'));
    if (place == null || !mounted) return;
    try {
      await context.read<Session>().api.savePlace(label, place);
      _loadPlaces();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _removePlace(SavedPlace p) async {
    try {
      await context.read<Session>().api.deletePlace(p.id);
      _loadPlaces();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _save() async {
    if (_emergency.text.trim().isEmpty || _area == null) {
      showError(context, ApiException('Add an emergency contact and your home area so we can keep you safe.'));
      return;
    }
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      final u = await session.api.updateMe(fullName: _name.text.trim(), email: _email.text.trim(), emergencyContact: _emergency.text, homeArea: _area);
      session.setUser(u);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _emergency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: FtrFitScreen(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            children: [
              Row(children: [
                const FtrBackButton(),
                const Expanded(child: Center(child: FtrBrandHeader(size: FtrBrandSize.compact))),
                const SizedBox(width: 48),
              ]),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: widget.editing ? 'Edit' : 'Complete', style: FtrText.display.copyWith(color: FtrColors.blue)),
                  const TextSpan(text: ' your profile'),
                ]),
                textAlign: TextAlign.center,
                style: FtrText.display.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text('Add a few details to get the best experience on FreeTongRide.',
                  textAlign: TextAlign.center, style: FtrText.body.copyWith(fontSize: 16.5, color: FtrColors.muted)),
              const SizedBox(height: 18),
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: FtrAvatar(name: _name.text, photoUrl: _photo, size: 150, badge: const FtrCameraBadge(size: 50)),
                ),
              ),
              const SizedBox(height: 20),
              FtrIconField(icon: Icons.person_outline_rounded, label: 'Full name', controller: _name, valueStyleBold: true, textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              FtrIconField(icon: Icons.mail_outline_rounded, label: 'Email address', controller: _email, valueStyleBold: true, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              FtrIconField(
                icon: Icons.call_outlined,
                label: 'Emergency contact',
                hint: '+232 76 123 456',
                controller: _emergency,
                valueStyleBold: true,
                keyboardType: TextInputType.phone,
                trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: FtrColors.blue, size: 28),
              ),
              const SizedBox(height: 12),
              FtrIconField(
                icon: Icons.location_on_outlined,
                label: 'Preferred home area',
                hint: 'Choose your area',
                controller: TextEditingController(text: _area),
                valueStyleBold: true,
                readOnly: true,
                onTap: _pickArea,
                trailing: const Icon(Icons.chevron_right_rounded, color: FtrColors.ink, size: 28),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Saved places ', style: FtrText.title.copyWith(fontSize: 17)),
                  TextSpan(text: '(optional)', style: FtrText.bodyMuted.copyWith(fontSize: 15)),
                ])),
                const Spacer(),
                FtrLink('Add more', fontSize: 15.5, onTap: _addPlace),
              ]),
              const SizedBox(height: 10),
              if (_places.isEmpty)
                FtrCard(
                  onTap: _addPlace,
                  child: Row(children: [
                    const FtrIconTile(Icons.add_location_alt_rounded, size: 46),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Add Home and Work for one-tap booking', style: FtrText.bodyMuted)),
                  ]),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _places
                      .map((p) => SizedBox(
                            width: (MediaQuery.sizeOf(context).width - 54) / 2,
                            child: FtrCard(
                              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                              child: Row(children: [
                                FtrIconTile(p.label == 'Home' ? Icons.home_rounded : (p.label == 'Work' ? Icons.work_rounded : Icons.star_rounded), size: 44),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(p.label, style: FtrText.title.copyWith(fontSize: 15)),
                                    Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.small),
                                  ]),
                                ),
                                IconButton(
                                  tooltip: 'Remove ${p.label}',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _removePlace(p),
                                  icon: const Icon(Icons.close_rounded, size: 20, color: FtrColors.muted),
                                ),
                              ]),
                            ),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 16),
              const FtrSafetyBanner(
                compact: true,
                title: 'Your safety comes first',
                message: 'We verify riders to help create a safer, more trusted community in Freetown.',
              ),
              const SizedBox(height: 20),
              FtrPrimaryButton(label: widget.editing ? 'Save changes' : 'Continue', loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

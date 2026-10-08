import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/driver_controller.dart';
import 'review_status_screen.dart';
import 'vehicle_screen.dart';

extension DocumentLabel on DocumentType {
  String get label => switch (this) {
        DocumentType.drivingLicence => 'Driving licence',
        DocumentType.nationalId => 'National ID card',
        DocumentType.profilePhoto => 'Profile photo',
        DocumentType.vehiclePhoto => 'Vehicle photo',
        DocumentType.vehicleRegistration => 'Vehicle registration',
        DocumentType.insurance => 'Insurance certificate',
      };

  String get hint => switch (this) {
        DocumentType.drivingLicence => 'Front side, all text readable',
        DocumentType.nationalId => 'Front side of your NIN card',
        DocumentType.profilePhoto => 'Clear face photo, no sunglasses',
        DocumentType.vehiclePhoto => 'Whole vehicle with plate visible',
        DocumentType.vehicleRegistration => 'Optional',
        DocumentType.insurance => 'Optional',
      };

  IconData get icon => switch (this) {
        DocumentType.drivingLicence => Icons.badge_rounded,
        DocumentType.nationalId => Icons.credit_card_rounded,
        DocumentType.profilePhoto => Icons.face_rounded,
        DocumentType.vehiclePhoto => Icons.directions_car_rounded,
        DocumentType.vehicleRegistration => Icons.description_rounded,
        DocumentType.insurance => Icons.verified_rounded,
      };
}

/// Step 3: upload documents, then submit for review.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.viewOnly = false});
  final bool viewOnly;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  DocumentType? _uploading;
  bool _busy = false;

  Future<void> _upload(DocumentType t) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _uploading = t);
    final dc = context.read<DriverController>();
    try {
      dc.profile = await dc.api.uploadDocument(t, await file.readAsBytes(), file.name);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final dc = context.read<DriverController>();
    try {
      dc.profile = await dc.api.submitForReview();
      if (mounted) go(context, const ReviewStatusScreen(), clear: true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DriverController>().profile!;
    final types = [DocumentType.drivingLicence, DocumentType.nationalId, DocumentType.profilePhoto, DocumentType.vehiclePhoto, DocumentType.vehicleRegistration, DocumentType.insurance];
    final session = context.read<Session>();
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
            Row(children: [
              const FtrBackButton(),
              const Expanded(child: Center(child: FtrBrandHeader(size: FtrBrandSize.compact))),
              const SizedBox(width: 48),
            ]),
            const SizedBox(height: 16),
            if (!widget.viewOnly) ...[const StepBar(step: 3), const SizedBox(height: 18)],
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Your '),
                TextSpan(text: 'documents', style: FtrText.display.copyWith(color: FtrColors.green)),
              ]),
              textAlign: TextAlign.center,
              style: FtrText.display.copyWith(fontSize: 34),
            ),
            const SizedBox(height: 6),
            Text('Clear photos get approved faster. Our team usually reviews within one working day.',
                textAlign: TextAlign.center, style: FtrText.body.copyWith(color: FtrColors.muted)),
            const SizedBox(height: 20),
            for (final t in types) ...[
              _DocTile(
                type: t,
                doc: p.documents.where((d) => d.type == t).lastOrNull,
                required: !(t == DocumentType.vehicleRegistration || t == DocumentType.insurance),
                busy: _uploading == t,
                imageUrl: session.client.absolute(p.documents.where((d) => d.type == t).lastOrNull?.fileUrl),
                onTap: _uploading == null ? () => _upload(t) : null,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            if (!widget.viewOnly)
              DriverButton(
                label: p.missingDocuments.isEmpty ? 'Submit for review' : '${p.missingDocuments.length} required left',
                loading: _busy,
                onPressed: p.missingDocuments.isEmpty ? _submit : null,
              ),
          ]),
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.type, required this.doc, required this.required, required this.busy, required this.onTap, this.imageUrl});
  final DocumentType type;
  final DriverDocument? doc;
  final bool required;
  final bool busy;
  final VoidCallback? onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final done = doc != null;
    final rejected = doc?.approved == false;
    final (statusText, statusColor) = rejected
        ? ('Rejected, upload again', FtrColors.red)
        : doc?.approved == true
            ? ('Approved', FtrColors.green)
            : done
                ? ('Uploaded', FtrColors.green)
                : (required ? 'Required' : 'Optional', required ? FtrColors.orange : FtrColors.muted);
    return FtrCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 58,
            height: 58,
            child: done && imageUrl != null && !imageUrl!.endsWith('.pdf')
                ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => FtrIconTile(type.icon, color: FtrColors.green, background: FtrColors.greenSoft))
                : FtrIconTile(type.icon, color: done ? FtrColors.green : FtrColors.blue, background: done ? FtrColors.greenSoft : FtrColors.blueSoft),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(type.label, style: FtrText.title.copyWith(fontSize: 16)),
            Text(type.hint, style: FtrText.small),
            const SizedBox(height: 4),
            Row(children: [
              Icon(done && !rejected ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 16, color: statusColor),
              const SizedBox(width: 4),
              Text(statusText, style: FtrText.small.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        busy
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
            : Icon(done ? Icons.refresh_rounded : Icons.upload_rounded, color: FtrColors.green),
      ]),
    );
  }
}

/// Allows going back to fix the vehicle from the documents step.
void editVehicle(BuildContext context) => go(context, const VehicleScreen(editing: true));

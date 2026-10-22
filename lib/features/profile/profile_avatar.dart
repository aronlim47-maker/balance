import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/balance_colors.dart';
import 'avatar_store.dart';
import '../../core/l10n/tr.dart';

/// Picks a photo and returns its bytes, or null if the user cancelled.
typedef AvatarPicker = Future<Uint8List?> Function();

Future<Uint8List?> _pickFromGallery() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  if (file == null) return null;
  return file.readAsBytes();
}

/// Round profile picture with a small camera button to change it.
///
/// Shows the saved photo for [owner] or, without one, the first letter of
/// the name. The photo stays on this phone (see [AvatarStore]).
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.owner,
    required this.initial,
    this.radius = 32,
    this.store = const AvatarStore(),
    this.pickImage,
  });

  final String? owner;
  final String initial;
  final double radius;
  final AvatarStore store;

  /// Replaces the gallery picker in tests.
  final AvatarPicker? pickImage;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner) _load();
  }

  Future<void> _load() async {
    final photo = await widget.store.load(widget.owner);
    if (mounted) setState(() => _photo = photo);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _choose() async {
    Uint8List? bytes;
    try {
      bytes = await (widget.pickImage ?? _pickFromGallery)();
    } catch (_) {
      if (mounted) _say('Could not open your photos. Please try again.'.tr);
      return;
    }
    if (bytes == null || !mounted) return;
    final saved = await widget.store.save(widget.owner, bytes);
    if (!mounted) return;
    if (saved) {
      setState(() => _photo = bytes);
      _say('Profile picture updated.'.tr);
    } else {
      _say('Could not save the picture. Please try again.'.tr);
    }
  }

  Future<void> _remove() async {
    await widget.store.remove(widget.owner);
    if (!mounted) return;
    setState(() => _photo = null);
    _say('Profile picture removed.'.tr);
  }

  Future<void> _openMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                _photo == null ? 'Choose a photo'.tr : 'Choose a new photo'.tr,
              ),
              subtitle: Text('Saved on this phone only'.tr),
              onTap: () => Navigator.pop(sheetContext, 'choose'),
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text('Remove photo'.tr),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == 'choose') await _choose();
    if (action == 'remove') await _remove();
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final size = widget.radius * 2;
    // Room for the camera button's 48 px touch area at the corner.
    return SizedBox(
      width: size + 20,
      height: size + 20,
      child: Stack(
        children: [
          Semantics(
            image: true,
            label: photo == null ? null : 'Profile picture'.tr,
            child: CircleAvatar(
              radius: widget.radius,
              backgroundColor: BalanceColors.accentDim,
              foregroundColor: BalanceColors.text,
              backgroundImage: photo == null ? null : MemoryImage(photo),
              child: photo == null
                  ? Text(
                      widget.initial,
                      style: TextStyle(fontSize: widget.radius * 0.8),
                    )
                  : null,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton(
              tooltip: 'Change profile picture'.tr,
              onPressed: _openMenu,
              style: IconButton.styleFrom(
                backgroundColor: BalanceColors.surfaceRaised,
                foregroundColor: BalanceColors.text,
                side: BorderSide(color: BalanceColors.outline),
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

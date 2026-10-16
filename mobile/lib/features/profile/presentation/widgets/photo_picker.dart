import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Lets the user take or choose a photo. Resized on the phone to 400px so uploads are small and fast.
Future<Uint8List?> pickProfilePhoto(BuildContext context, {bool canRemove = false, VoidCallback? onRemove}) async {
  final source = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        if (canRemove) ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Remove photo'), onTap: () => Navigator.pop(ctx, 'remove')),
      ]),
    ),
  );
  if (source == 'remove') {
    onRemove?.call();
    return null;
  }
  if (source is! ImageSource) return null;
  final file = await ImagePicker().pickImage(source: source, maxWidth: 400, maxHeight: 400, imageQuality: 82, preferredCameraDevice: CameraDevice.front);
  if (file == null) return null;
  return file.readAsBytes();
}

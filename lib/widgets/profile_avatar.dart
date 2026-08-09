import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.avatarPath,
    this.radius = 24,
  });

  final String name;
  final String? avatarPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final file = avatarPath == null ? null : File(avatarPath!);
    final hasImage = file?.existsSync() ?? false;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFE3EC),
      foregroundImage: hasImage ? FileImage(file!) : null,
      child: hasImage
          ? null
          : Text(
              initialsFor(name),
              style: TextStyle(
                color: const Color(0xFF7A2848),
                fontSize: radius * .7,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class EditableProfileAvatar extends StatelessWidget {
  const EditableProfileAvatar({
    super.key,
    required this.name,
    required this.avatarPath,
    required this.onChanged,
    this.radius = 48,
  });

  final String name;
  final String? avatarPath;
  final ValueChanged<String?> onChanged;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: avatarPath == null ? 'Add profile photo' : 'Change profile photo',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _showOptions(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatar(name: name, avatarPath: avatarPath, radius: radius),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOptions(BuildContext context) async {
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, _AvatarAction.choose),
              ),
              if (avatarPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Use initials instead'),
                  onTap: () => Navigator.pop(context, _AvatarAction.remove),
                ),
            ],
          ),
        ),
      ),
    );

    if (action == _AvatarAction.choose) {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (picked == null) return;
      final directory = await getApplicationSupportDirectory();
      final extension = p.extension(picked.path).isEmpty
          ? '.jpg'
          : p.extension(picked.path);
      final destination = p.join(
        directory.path,
        'profile_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      await picked.saveTo(destination);
      await _deleteManagedAvatar(avatarPath, directory.path);
      onChanged(destination);
    } else if (action == _AvatarAction.remove) {
      final directory = await getApplicationSupportDirectory();
      await _deleteManagedAvatar(avatarPath, directory.path);
      onChanged(null);
    }
  }

  Future<void> _deleteManagedAvatar(String? filePath, String appPath) async {
    if (filePath == null || !p.isWithin(appPath, filePath)) return;
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}

String initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

enum _AvatarAction { choose, remove }

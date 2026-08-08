import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_fonts.dart';
import '../friends/friends_screen.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _name;
  late String _email;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    _name = user.displayName ?? '';
    _email = user.email ?? '';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Future<void> _signOut() async {
    Navigator.of(context).pop();
    await FirebaseAuth.instance.signOut();
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _name);
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => _EditNameDialog(
        controller: controller,
        formKey: formKey,
        onSave: (newName) async {
          if (newName == _name) return;
          final user = FirebaseAuth.instance.currentUser!;
          await user.updateDisplayName(newName);

          final doc = {
            'name': newName,
            'name_lower': newName.toLowerCase(),
            'photoUrl': user.photoURL,
          };
          final db = FirebaseFirestore.instance;
          await Future.wait([
            db.collection('users').doc(user.uid).set(doc),
            db.collection('userSearch').doc(user.uid).set(doc),
          ]);

          unawaited(user.reload());
        },
        onSuccess: (newName) {
          if (mounted) setState(() => _name = newName);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final initials = _initials(_name);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.appBarBackground,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.profileTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ).kr,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.colors.amberBorder),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(initials: initials),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _name,
                  style: GoogleFonts.newsreader(
                    color: context.colors.onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                  ).kr,
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _showEditNameDialog,
                  child: Icon(
                    Icons.edit_outlined,
                    color: context.colors.outline,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _email,
              style: GoogleFonts.workSans(
                color: context.colors.onSurfaceVariant,
                fontSize: 14,
              ).kr,
            ),
            const SizedBox(height: 40),
            Container(height: 1, color: context.colors.outlineVariant),
            GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.group_outlined,
                      color: context.colors.outline,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s.profileFriends,
                        style: GoogleFonts.workSans(
                          color: context.colors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ).kr,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: context.colors.outline,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: context.colors.outlineVariant),
            GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      color: context.colors.outline,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s.profileSettings,
                        style: GoogleFonts.workSans(
                          color: context.colors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ).kr,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: context.colors.outline,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: context.colors.outlineVariant),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, size: 18),
                label: Text(s.profileSignOut),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.primary,
                  side: BorderSide(color: context.colors.amberBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: GoogleFonts.workSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ).kr,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final Future<void> Function(String) onSave;
  final void Function(String) onSuccess;

  const _EditNameDialog({
    required this.controller,
    required this.formKey,
    required this.onSave,
    required this.onSuccess,
  });

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!widget.formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final newName = widget.controller.text.trim();
      await widget.onSave(newName);
      widget.onSuccess(newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).profileNameUpdated),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      debugPrint('Name update error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).profileNameUpdateFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AlertDialog(
      backgroundColor: context.colors.surface,
      title: Text(
        s.profileEditNameTitle,
        style: GoogleFonts.newsreader(
          color: context.colors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ).kr,
      ),
      content: Form(
        key: widget.formKey,
        child: TextFormField(
          controller: widget.controller,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          autofocus: true,
          style: TextStyle(color: context.colors.onSurface),
          decoration: InputDecoration(
            hintText: s.profileNameHint,
            hintStyle: TextStyle(color: context.colors.outline),
            filled: true,
            fillColor: context.colors.surfaceHigh,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.colors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.colors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return s.profileNameEmpty;
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            s.commonCancel,
            style: GoogleFonts.workSans(color: context.colors.onSurfaceVariant).kr,
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.onPrimary,
            disabledBackgroundColor: context.colors.primaryDim.withValues(
              alpha: 0.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.workSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ).kr,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.onPrimary,
                  ),
                )
              : Text(s.commonSave),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;

  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.55),
          width: 2,
        ),
        color: context.colors.surfaceHigh,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ).kr,
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      if (result.additionalUserInfo?.isNewUser == true) {
        final user = result.user!;
        final name = user.displayName ?? '';
        final doc = {
          'name': name,
          'name_lower': name.toLowerCase(),
          'photoUrl': user.photoURL,
        };
        final db = FirebaseFirestore.instance;
        await Future.wait([
          db.collection('users').doc(user.uid).set(doc),
          db.collection('userSearch').doc(user.uid).set(doc),
        ]);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } catch (_) {
      setState(() => _errorMessage = AppStrings.of(context).authGoogleFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegistering) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _friendlyError(e.code);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final s = AppStrings.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = s.authResetEmailNeeded);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showResetSent(email);
    } on FirebaseAuthException catch (e) {
      // Don't reveal whether an account exists for that address.
      if (e.code == 'user-not-found') {
        _showResetSent(email);
      } else {
        setState(() => _errorMessage = _friendlyError(e.code));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showResetSent(String email) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).authResetSent(email))),
    );
  }

  String _friendlyError(String code) {
    final s = AppStrings.of(context);
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return s.authErrorIncorrectCredentials;
      case 'email-already-in-use':
        return s.authErrorEmailInUse;
      case 'weak-password':
        return s.authErrorWeakPassword;
      case 'invalid-email':
        return s.authErrorInvalidEmail;
      case 'too-many-requests':
        return s.authErrorTooManyRequests;
      default:
        return s.authErrorGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  if (!_isRegistering) _buildForgotPassword(),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) _buildError(),
                  _buildSubmitButton(),
                  const SizedBox(height: 16),
                  _buildDivider(),
                  const SizedBox(height: 16),
                  _buildGoogleButton(),
                  const SizedBox(height: 20),
                  _buildToggle(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          AppStrings.of(context).appTitle,
          style: GoogleFonts.newsreader(
            color: context.colors.primary,
            fontSize: 40,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _isRegistering
              ? AppStrings.of(context).authSubtitleCreate
              : AppStrings.of(context).authSubtitleSignIn,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      style: TextStyle(color: context.colors.onSurface),
      decoration: _inputDecoration(
        AppStrings.of(context).authEmailLabel,
        Icons.mail_outline,
      ),
      validator: (v) {
        final s = AppStrings.of(context);
        if (v == null || v.trim().isEmpty) return s.authEmailRequired;
        if (!v.contains('@')) return s.authEmailInvalid;
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      style: TextStyle(color: context.colors.onSurface),
      decoration:
          _inputDecoration(
            AppStrings.of(context).authPasswordLabel,
            Icons.lock_outline,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: context.colors.outline,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
      validator: (v) {
        final s = AppStrings.of(context);
        if (v == null || v.isEmpty) return s.authPasswordRequired;
        if (_isRegistering && v.length < 6) {
          return s.authErrorWeakPassword;
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.colors.outline),
      prefixIcon: Icon(icon, color: context.colors.outline, size: 20),
      filled: true,
      fillColor: context.colors.surface,
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
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _isLoading ? null : _resetPassword,
        style: TextButton.styleFrom(
          foregroundColor: context.colors.primary,
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          AppStrings.of(context).authForgotPassword,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.primary,
          foregroundColor: context.colors.onPrimary,
          disabledBackgroundColor: context.colors.primaryDim.withValues(
            alpha: 0.4,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.workSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.onPrimary,
                ),
              )
            : Text(
                _isRegistering
                    ? AppStrings.of(context).authCreateAccount
                    : AppStrings.of(context).authSignIn,
              ),
      ),
    );
  }

  Widget _buildToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isRegistering
              ? AppStrings.of(context).authHaveAccount
              : AppStrings.of(context).authNoAccount,
          style: TextStyle(
            color: context.colors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() {
                  _isRegistering = !_isRegistering;
                  _errorMessage = null;
                }),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(
            _isRegistering
                ? AppStrings.of(context).authSignIn
                : AppStrings.of(context).authRegister,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: context.colors.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AppStrings.of(context).authOr,
            style: TextStyle(
              color: context.colors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.colors.outlineVariant)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.onSurface,
          side: BorderSide(color: context.colors.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.workSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(AppStrings.of(context).authContinueWithGoogle),
      ),
    );
  }
}

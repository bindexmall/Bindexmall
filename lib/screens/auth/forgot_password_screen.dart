// ============================================================================
// SCREEN: ForgotPasswordScreen
// ============================================================================
// Alur lupa password: input email -> kirim kode reset -> verifikasi kode -> set password baru,
// lewat AuthProvider/JWTAuthService.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/jwt_auth_service.dart';
import '../../l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    if (mounted) {
      setState(() {
        _currentLocale = Locale(languageCode);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload language preference when dependencies change
    _loadLanguagePreference();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await jwtAuthService.resetPassword(_emailController.text.trim());

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations(_currentLocale);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('resetPassword'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _isSuccess ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final l10n = AppLocalizations(_currentLocale);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_reset,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Title
          Text(
            l10n.translate('forgotYourPassword'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            l10n.translate('forgotPasswordDescription'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),
          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.translate('emailAddress'),
              hintText: l10n.translate('enterYourEmail'),
              prefixIcon: const Icon(Icons.email_outlined),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.translate('pleaseEnterEmail');
              }
              if (!value.contains('@') || !value.contains('.')) {
                return l10n.translate('pleaseEnterValidEmail');
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.translate('sendResetLink')),
            ),
          ),
          const SizedBox(height: 16),
          // Back to sign in
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(l10n.translate('backToSignIn')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final l10n = AppLocalizations(_currentLocale);

    return Column(
      children: [
        const SizedBox(height: 48),
        // Success icon
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 32),
        // Success title
        Text(
          l10n.translate('checkYourEmail'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '${l10n.translate('resetLinkSentTo')}\n${_emailController.text}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l10n.translate('checkEmailInstruction'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ),
        const SizedBox(height: 32),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _isSuccess = false;
            });
          },
          icon: const Icon(Icons.refresh),
          label: Text(l10n.translate('resendEmail')),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(l10n.translate('backToSignIn')),
          ),
        ),
      ],
    );
  }
}

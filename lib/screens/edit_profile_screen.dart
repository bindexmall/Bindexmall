// ============================================================================
// SCREEN: EditProfileScreen
// ============================================================================
// Form edit profil user (nama, no. HP, foto profil, ganti password) via UserProfileService.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/woocommerce_service.dart';
import '../l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = true;
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _checkAuthAndLoadData();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    setState(() {
      _currentLocale = Locale(languageCode);
    });
  }

  String _t(String key) {
    return AppLocalizations(_currentLocale).translate(key);
  }

  Future<void> _checkAuthAndLoadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('pleaseLogInFirst')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
      return;
    }

    await _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingData = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.userId != null) {
      try {
        final customerId = int.tryParse(authProvider.userId!);
        if (customerId != null) {
          final customer = await wooCommerceService.getCustomer(customerId);

          if (mounted) {
            setState(() {
              _firstNameController.text = customer['first_name'] ?? '';
              _lastNameController.text = customer['last_name'] ?? '';
              _phoneController.text = customer['billing']?['phone'] ?? '';

              // Load bio from meta_data
              final metaData = customer['meta_data'] as List?;
              if (metaData != null) {
                final bioMeta = metaData.firstWhere(
                  (meta) => meta['key'] == 'bio',
                  orElse: () => null,
                );
                if (bioMeta != null) {
                  _bioController.text = bioMeta['value'] ?? '';
                }
              }

              _isLoadingData = false;
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
        if (mounted) {
          setState(() {
            _isLoadingData = false;
          });
        }
      }
    } else {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        throw Exception(_currentLocale.languageCode == 'en'
            ? 'User ID not found. Please log in again.'
            : 'ID pengguna tidak ditemukan. Silakan login kembali.');
      }

      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        throw Exception(_currentLocale.languageCode == 'en'
            ? 'Invalid user ID'
            : 'ID pengguna tidak valid');
      }

      // Prepare update data
      final Map<String, dynamic> updateData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'billing': {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
        'shipping': {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
        },
      };

      // Add bio to meta_data if not empty
      if (_bioController.text.isNotEmpty) {
        updateData['meta_data'] = [
          {
            'key': 'bio',
            'value': _bioController.text.trim(),
          }
        ];
      }

      // Update via WooCommerce API
      debugPrint('Updating customer profile...');
      await wooCommerceService.updateCustomer(userIdInt, updateData);

      // Update auth provider with new name
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();
      if (fullName.isNotEmpty) {
        await authProvider.updateProfile(name: fullName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('profileUpdatedSuccessfully')),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('failedToUpdateProfile')}: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_t('editProfile')),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Header Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 80,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _t('editYourProfile'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Form Fields
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // First Name
                          _buildSectionTitle(_t('sectionFirstName')),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _firstNameController,
                            label: _t('labelFirstName'),
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _t('firstNameCannotBeBlank');
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // Last Name
                          _buildSectionTitle(_t('sectionLastName')),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _lastNameController,
                            label: _t('labelLastName'),
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _t('lastNameCannotBeEmpty');
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // Phone Number
                          _buildSectionTitle(_t('sectionPhoneNumber')),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _phoneController,
                            label: _t('labelPhoneNumber'),
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (value.length < 10) {
                                  return _t('phoneNumberMinDigits');
                                }
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // Bio
                          _buildSectionTitle(_t('sectionBio')),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _bioController,
                            label: _t('labelBio'),
                            icon: Icons.info_outline,
                            maxLines: 4,
                            isOptional: true,
                          ),

                          const SizedBox(height: 32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _saveProfile,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _isLoading ? _t('saving') : _t('saveChanges'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isOptional = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: isOptional ? null : validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Theme.of(context).cardColor,
        ),
      ),
    );
  }
}
// ============================================================================
// SCREEN: AddressesScreen
// ============================================================================
// Daftar semua alamat tersimpan milik user + aksi set default/hapus/edit,
// menggunakan AddressProvider.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../models/address.dart';
import '../l10n/app_localizations.dart';
import 'add_address_screen.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndLoadAddresses();
    });
  }

  Future<void> _checkAuthAndLoadAddresses() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      // Show login required dialog
      _showLoginRequiredDialog();
    } else {
      // Load addresses
      final addressProvider = Provider.of<AddressProvider>(context, listen: false);
      await addressProvider.initialize(authProvider.userId);
    }
  }

  void _showLoginRequiredDialog() {
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l10n.translate('loginRequiredTitle')),
          ],
        ),
        content: Text(
          l10n.translate('loginRequiredAddressMessage'),
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/signin');
            },
            child: Text(l10n.translate('login')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('myAddresses')),
        elevation: 0,
      ),
      body: Consumer2<AddressProvider, AuthProvider>(
        builder: (context, addressProvider, authProvider, child) {
          if (!authProvider.isAuthenticated) {
            return _buildLoginPrompt();
          }

          if (addressProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (addressProvider.addresses.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: addressProvider.addresses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final address = addressProvider.addresses[index];
              return _buildAddressCard(address, addressProvider);
            },
          );
        },
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (!authProvider.isAuthenticated) return const SizedBox();
          
          return FloatingActionButton.extended(
            onPressed: () => _navigateToAddAddress(),
            icon: const Icon(Icons.add),
            label: Text(l10n.translate('addAddress')),
          );
        },
      ),
    );
  }

  Widget _buildLoginPrompt() {
    final l10n = AppLocalizations.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('loginRequiredTitle'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('pleaseLoginToManageAddresses'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/signin');
              },
              icon: const Icon(Icons.login),
              label: Text(l10n.translate('loginNow')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('noAddresses'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('addFirstAddress'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(Address address, AddressProvider provider) {
    final l10n = AppLocalizations.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: address.isDefault
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _navigateToEditAddress(address),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      address.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.translate('default'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 20),
                            const SizedBox(width: 8),
                            Text(l10n.translate('edit')),
                          ],
                        ),
                      ),
                      if (!address.isDefault)
                        PopupMenuItem(
                          value: 'default',
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                              Text(l10n.translate('setAsDefault')),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              l10n.translate('delete'),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _navigateToEditAddress(address);
                          break;
                        case 'default':
                          provider.setDefaultAddress(address.id);
                          break;
                        case 'delete':
                          _showDeleteDialog(address, provider);
                          break;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                address.phone,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address.fullAddress,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddAddressScreen(),
      ),
    );

    if (result == true) {
      // Address added, refresh if needed
    }
  }

  void _navigateToEditAddress(Address address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAddressScreen(address: address),
      ),
    );

    if (result == true) {
      // Address updated, refresh if needed
    }
  }

  void _showDeleteDialog(Address address, AddressProvider provider) {
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(l10n.translate('deleteAddress')),
        content: Text(l10n.translate('deleteAddressConfirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteAddress(address.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.translate('addressDeleted'))),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );
  }
}
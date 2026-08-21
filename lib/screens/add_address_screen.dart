// ============================================================================
// SCREEN: AddAddressScreen + SelectLocationScreen
// ============================================================================
// Form tambah/edit alamat pengiriman, termasuk pemilihan lokasi berjenjang
// (provinsi/kota/kecamatan) yang terhubung ke ShippingProvider/RajaOngkirService.
//
// Catatan:
//  - SelectLocationScreen di file ini adalah versi lokal untuk alur tambah alamat —
//  -   ADA JUGA screens/select_shipping_screen.dart dengan class SelectLocationScreen
//  -   yang TERPISAH untuk alur checkout. Nama class sama tapi file & konteks beda,
//  -   jangan tertukar saat maintenance.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/address_provider.dart';
import '../providers/shipping_provider.dart';
import '../models/address.dart';
import '../services/rajaongkir_service.dart';
import '../l10n/app_localizations.dart';

class AddAddressScreen extends StatefulWidget {
  final Address? address;

  const AddAddressScreen({super.key, this.address});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _apartmentController = TextEditingController();

  bool _isDefault = false;
  bool _isLoading = false;

  // Selected RajaOngkir Location
  Province? _selectedProvince;
  City? _selectedCity;
  District? _selectedDistrict;
  Subdistrict? _selectedSubdistrict;

  @override
  void initState() {
    super.initState();
    
    if (widget.address != null) {
      _loadExistingAddress();
    }
  }

  void _loadExistingAddress() {
    final address = widget.address!;
    _firstNameController.text = address.firstName;
    _lastNameController.text = address.lastName;
    _companyController.text = address.company;
    _phoneController.text = address.phone;
    _emailController.text = address.email;
    _addressController.text = address.address;
    _apartmentController.text = address.apartment;
    _isDefault = address.isDefault;
    
    // Load existing location if available
    if (address.provinceId != null) {
      _selectedProvince = Province(
        id: address.provinceId!,
        name: address.provinceName ?? '',
      );
    }
    if (address.cityId != null) {
      _selectedCity = City(
        id: address.cityId!,
        name: address.cityName ?? '',
        zipCode: address.zipCode ?? '',
      );
    }
    if (address.districtId != null) {
      _selectedDistrict = District(
        id: address.districtId!,
        name: address.districtName ?? '',
        zipCode: address.zipCode ?? '',
      );
    }
    if (address.subdistrictId != null) {
      _selectedSubdistrict = Subdistrict(
        id: address.subdistrictId!,
        name: address.subdistrictName ?? '',
        zipCode: address.zipCode ?? '',
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _apartmentController.dispose();
    super.dispose();
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectLocationScreen(),
      ),
    );
    
    if (result != null && result['subdistrict'] is Subdistrict) {
      final shippingProvider = Provider.of<ShippingProvider>(
        context,
        listen: false,
      );
      
      setState(() {
        _selectedProvince = shippingProvider.selectedProvince;
        _selectedCity = shippingProvider.selectedCity;
        _selectedDistrict = shippingProvider.selectedDistrict;
        _selectedSubdistrict = result['subdistrict'] as Subdistrict;
      });
      
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.translate('locationSelected')}: ${_selectedSubdistrict!.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context);

    // Validate location
    if (_selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('pleaseSelectLocation')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final addressProvider = Provider.of<AddressProvider>(context, listen: false);

      final newAddress = Address(
        id: widget.address?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        company: _companyController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        apartment: _apartmentController.text.trim(),
        isDefault: _isDefault,
        provinceId: _selectedProvince?.id,
        provinceName: _selectedProvince?.name,
        cityId: _selectedCity?.id,
        cityName: _selectedCity?.name,
        districtId: _selectedDistrict?.id,
        districtName: _selectedDistrict?.name,
        subdistrictId: _selectedSubdistrict?.id,
        subdistrictName: _selectedSubdistrict?.name,
        zipCode: _selectedSubdistrict?.zipCode ?? _selectedDistrict?.zipCode,
      );

      if (widget.address != null) {
        await addressProvider.updateAddress(widget.address!.id, newAddress);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('addressUpdatedSuccessfully')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await addressProvider.addAddress(newAddress);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('addressAddedSuccessfully')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      setState(() => _isLoading = false);
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.address != null ? l10n.translate('editAddress') : l10n.translate('addNewAddress'),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate('locationInfoMessage'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Personal Info Section
            _buildSectionHeader(l10n.translate('personalInformation'), Icons.person),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: '${l10n.translate('firstName')} *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.translate('requiredField');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: '${l10n.translate('lastName')} *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.translate('requiredField');
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _companyController,
              decoration: InputDecoration(
                labelText: l10n.translate('companyOptional'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.business),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: '${l10n.translate('phoneNumber')} *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
                hintText: l10n.translate('phoneHint'),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.translate('requiredField');
                }
                if (value.trim().length < 10) {
                  return l10n.translate('phoneMinDigits');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: '${l10n.translate('email')} *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.translate('requiredField');
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return l10n.translate('invalidEmail');
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Location Section
            _buildSectionHeader(l10n.translate('shippingLocation'), Icons.location_on),
            const SizedBox(height: 8),
            Text(
              l10n.translate('selectLocationForAccurateShipping'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Location Selection Button
            if (_selectedDistrict == null)
              OutlinedButton.icon(
                onPressed: _selectLocation,
                icon: const Icon(Icons.location_searching),
                label: Text(l10n.translate('selectShippingLocation')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('selectedLocation'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_selectedSubdistrict != null)
                                Text(
                                  _selectedSubdistrict!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              Text(
                                _selectedDistrict!.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '${_selectedCity!.name}, ${_selectedProvince!.name}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (_selectedSubdistrict?.zipCode != null)
                                Text(
                                  '${l10n.translate('postalCode')}: ${_selectedSubdistrict!.zipCode}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _selectLocation,
                      icon: const Icon(Icons.edit_location, size: 18),
                      label: Text(l10n.translate('changeLocation')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        side: BorderSide(color: Colors.green.shade700),
                        foregroundColor: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Street Address Section
            _buildSectionHeader(l10n.translate('fullAddress'), Icons.home),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: '${l10n.translate('streetAddress')} *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.home_outlined),
                hintText: l10n.translate('streetAddressHint'),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.translate('requiredField');
                }
                if (value.trim().length < 10) {
                  return l10n.translate('addressTooShort');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _apartmentController,
              decoration: InputDecoration(
                labelText: l10n.translate('apartmentSuiteUnit'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.apartment),
                hintText: l10n.translate('apartmentHint'),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),

            // Default Address Checkbox
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: CheckboxListTile(
                value: _isDefault,
                onChanged: (value) {
                  setState(() => _isDefault = value ?? false);
                },
                title: Text(
                  l10n.translate('setAsDefaultAddress'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.translate('useAsDefaultForCheckout'),
                  style: const TextStyle(fontSize: 12),
                ),
                secondary: Icon(
                  _isDefault ? Icons.check_circle : Icons.check_circle_outline,
                  color: _isDefault ? Colors.green : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveAddress,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                widget.address != null ? l10n.translate('updateAddress') : l10n.translate('saveAddress'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon, 
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ShippingProvider>(context, listen: false);
      if (provider.provinces.isEmpty) {
        provider.loadProvinces();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('selectLocation')),
        elevation: 0,
      ),
      body: Consumer<ShippingProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Province
                Text(
                  l10n.translate('province'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (provider.isLoadingProvinces)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<Province>(
                    initialValue: provider.selectedProvince,
                    decoration: InputDecoration(
                      hintText: l10n.translate('selectProvince'),
                      border: const OutlineInputBorder(),
                    ),
                    items: provider.provinces.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.name));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) provider.selectProvince(value);
                    },
                  ),
                const SizedBox(height: 16),

                // City
                if (provider.selectedProvince != null) ...[
                  Text(
                    l10n.translate('cityRegency'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (provider.isLoadingCities)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<City>(
                      initialValue: provider.selectedCity,
                      decoration: InputDecoration(
                        hintText: l10n.translate('selectCity'),
                        border: const OutlineInputBorder(),
                      ),
                      items: provider.cities.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c.name));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) provider.selectCity(value);
                      },
                    ),
                  const SizedBox(height: 16),
                ],

                // District
                if (provider.selectedCity != null) ...[
                  Text(
                    l10n.translate('district'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (provider.isLoadingDistricts)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<District>(
                      initialValue: provider.selectedDistrict,
                      decoration: InputDecoration(
                        hintText: l10n.translate('selectDistrict'),
                        border: const OutlineInputBorder(),
                      ),
                      items: provider.districts.map((d) {
                        return DropdownMenuItem(value: d, child: Text(d.name));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) provider.selectDistrict(value);
                      },
                    ),
                  const SizedBox(height: 16),
                ],

                // Subdistrict List
                if (provider.selectedDistrict != null) ...[
                  Text(
                    l10n.translate('subdistrict'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (provider.isLoadingSubdistricts)
                    const Center(child: CircularProgressIndicator())
                  else if (provider.subdistricts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(l10n.translate('noSubdistrictFound')),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.subdistricts.length,
                      itemBuilder: (context, index) {
                        final sub = provider.subdistricts[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.blue),
                            title: Text(sub.name),
                            subtitle: Text('${l10n.translate('postalCode')}: ${sub.zipCode}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              provider.selectSubdistrict(sub);
                              Navigator.pop(context, {
                                'subdistrict': sub,
                              });
                            },
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
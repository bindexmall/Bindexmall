// ============================================================================
// SCREEN: SelectLocationScreen (versi shipping)
// ============================================================================
// Pemilihan wilayah pengiriman berjenjang untuk konteks shipping/ongkir.
//
// Catatan:
//  - PENTING: ada class dengan nama SAMA (SelectLocationScreen) juga di
//  -   add_address_screen.dart dan checkout_screen.dart. Tiga implementasi terpisah,
//  -   nama class sama — pastikan tahu file mana yang dipanggil dari mana sebelum edit.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shipping_provider.dart';
import '../providers/language_provider.dart';
import '../services/rajaongkir_service.dart';
import '../l10n/app_localizations.dart';

class SelectLocationScreen extends StatefulWidget {
  final int? cartWeight;
  
  const SelectLocationScreen({
    super.key,
    this.cartWeight,
  });

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

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(_t('selectShippingLocation', locale)),
            elevation: 0,
          ),
          body: _buildManualMode(locale),
        );
      },
    );
  }

  Widget _buildManualMode(Locale locale) {
    return Consumer<ShippingProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        locale.languageCode == 'en'
                            ? 'Select location step by step from province to subdistrict'
                            : 'Pilih lokasi secara bertahap dari provinsi hingga kelurahan',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Province Dropdown
              _buildSectionLabel(_t('province', locale)),
              const SizedBox(height: 8),
              if (provider.isLoadingProvinces)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                DropdownButtonFormField<Province>(
                  initialValue: provider.selectedProvince,
                  decoration: InputDecoration(
                    hintText: _t('selectProvince', locale),
                    prefixIcon: const Icon(Icons.map),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: provider.provinces.map((province) {
                    return DropdownMenuItem(
                      value: province,
                      child: Text(province.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      provider.selectProvince(value);
                    }
                  },
                ),
              const SizedBox(height: 16),

              // City Dropdown
              if (provider.selectedProvince != null) ...[
                _buildSectionLabel(_t('cityRegency', locale)),
                const SizedBox(height: 8),
                if (provider.isLoadingCities)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  DropdownButtonFormField<City>(
                    initialValue: provider.selectedCity,
                    decoration: InputDecoration(
                      hintText: _t('selectCity', locale),
                      prefixIcon: const Icon(Icons.location_city),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: provider.cities.map((city) {
                      return DropdownMenuItem(
                        value: city,
                        child: Text(city.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        provider.selectCity(value);
                      }
                    },
                  ),
                const SizedBox(height: 16),
              ],

              // District Dropdown
              if (provider.selectedCity != null) ...[
                _buildSectionLabel(_t('district', locale)),
                const SizedBox(height: 8),
                if (provider.isLoadingDistricts)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  DropdownButtonFormField<District>(
                    initialValue: provider.selectedDistrict,
                    decoration: InputDecoration(
                      hintText: _t('selectDistrict', locale),
                      prefixIcon: const Icon(Icons.place),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: provider.districts.map((district) {
                      return DropdownMenuItem(
                        value: district,
                        child: Text(district.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        provider.selectDistrict(value);
                      }
                    },
                  ),
                const SizedBox(height: 16),
              ],

              // Subdistrict List
              if (provider.selectedDistrict != null) ...[
                _buildSectionLabel(_t('subdistrict', locale)),
                const SizedBox(height: 8),
                if (provider.isLoadingSubdistricts)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (provider.subdistricts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.location_off, 
                               size: 48, 
                               color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _t('noSubdistrictFound', locale),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.subdistricts.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final subdistrict = provider.subdistricts[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            subdistrict.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${locale.languageCode == 'en' ? 'Postal Code' : 'Kode Pos'}: ${subdistrict.zipCode}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () => _selectSubdistrict(subdistrict, locale),
                        );
                      },
                    ),
                  ),
              ],

              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  void _selectSubdistrict(Subdistrict subdistrict, Locale locale) async {
    final provider = Provider.of<ShippingProvider>(context, listen: false);
    
    // Set selected subdistrict in provider
    provider.selectSubdistrict(subdistrict);

    // If cart weight provided, calculate shipping
    if (widget.cartWeight != null && widget.cartWeight! > 0) {
      try {
        // Show loading dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_t('calculatingShippingCosts', locale)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        await provider.calculateShipping(
          weight: widget.cartWeight!,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          _showShippingOptions(provider, locale);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                locale.languageCode == 'en'
                    ? 'Error calculating shipping: $e'
                    : 'Error menghitung ongkir: $e'
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      // Just return subdistrict
      Navigator.pop(context, subdistrict);
    }
  }

  void _showShippingOptions(ShippingProvider provider, Locale locale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _t('selectShippingMethod', locale),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Shipping Options
              Expanded(
                child: provider.shippingRates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(_t('noShippingOptionsAvailable', locale)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.shippingRates.length,
                        itemBuilder: (context, index) {
                          final rate = provider.shippingRates[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () {
                                provider.selectShippingOption(rate);
                                Navigator.pop(context);
                                Navigator.pop(context, {
                                  'subdistrict': provider.selectedSubdistrict,
                                  'shipping': rate,
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.local_shipping,
                                        color: Colors.blue,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rate.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            rate.service,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          if (rate.description.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              rate.description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_t('estimate', locale)}: ${rate.displayDuration}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          rate.displayPrice,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
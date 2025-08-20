import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../services/bluetooth_service.dart' as bike_ble;
import '../utils/ui_helpers.dart';
import '../utils/country_codes.dart';
import '../widgets/country_picker_dialog.dart';
import '../constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _intervalController = TextEditingController();
  
  final bike_ble.BikeBluetoothService _bleService = bike_ble.BikeBluetoothService();
  
  bool _alertsEnabled = true;
  bool _isSaving = false;
  bool _isLoading = true;
  
  // Use predefined interval options from constants
  final List<int> _intervalOptions = AppConstants.smsIntervalPresets;
  
  // Country code selection
  String _selectedCountryCode = '+1';
  CountryCode? _selectedCountry;
  bool _isDetectingLocation = false;
  
  // Phone number history
  List<String> _phoneNumberHistory = [];
  
  // Validation
  String? _phoneNumberError;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _detectCountryCode();
  }
  
  Future<void> _detectCountryCode() async {
    // Only detect if no saved phone number
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString(AppConstants.keyConfigPhone) ?? '';
    if (savedPhone.isNotEmpty) return;
    
    setState(() {
      _isDetectingLocation = true;
    });
    
    try {
      // Try to get country code based on location
      String? detectedCode = await CountryCodeHelper.getCountryCodeByLocation();
      if (detectedCode != null && mounted) {
        setState(() {
          _selectedCountryCode = detectedCode;
          _selectedCountry = CountryCodeHelper.getCountryByDialCode(detectedCode);
          _isDetectingLocation = false;
        });
        developer.log('Auto-detected country code: $detectedCode', name: 'Settings');
      } else {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    } catch (e) {
      developer.log('Error detecting country code: $e', name: 'Settings', error: e);
      setState(() {
        _isDetectingLocation = false;
      });
    }
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load saved phone number
      final savedPhone = prefs.getString(AppConstants.keyConfigPhone) ?? '';
      
      // Extract country code if present
      if (savedPhone.isNotEmpty) {
        // Try to match country code
        for (var country in CountryCodeHelper.countryCodes) {
          if (savedPhone.startsWith(country.code)) {
            _selectedCountryCode = country.code;
            _selectedCountry = country;
            // Remove country code from phone number
            _phoneController.text = savedPhone.substring(country.code.length).trim();
            break;
          }
        }
        // If no country code matched, assume the whole thing is the number
        if (_phoneController.text.isEmpty) {
          _phoneController.text = savedPhone;
        }
      }
      
      // Load phone number history
      _phoneNumberHistory = prefs.getStringList('phone_number_history') ?? [];
      
      setState(() {
        _intervalController.text = (prefs.getInt(AppConstants.keyConfigInterval) ?? AppConstants.defaultSmsInterval).toString();
        _alertsEnabled = prefs.getBool(AppConstants.keyConfigAlerts) ?? true;
        _isLoading = false;
      });
      
      developer.log('Settings loaded from preferences', name: 'Settings');
    } catch (e) {
      developer.log('Error loading settings: $e', name: 'Settings');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate phone number before saving
    final phoneText = _phoneController.text.trim();
    if (phoneText.isNotEmpty && !_validatePhoneNumber(phoneText)) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_phoneNumberError ?? 'Invalid phone number'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Combine country code with phone number
      final phoneNumber = phoneText.isNotEmpty 
        ? _selectedCountryCode + phoneText
        : '';
      final updateInterval = int.tryParse(_intervalController.text) ?? 300;
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyConfigPhone, phoneNumber);
      await prefs.setInt(AppConstants.keyConfigInterval, updateInterval);
      await prefs.setBool(AppConstants.keyConfigAlerts, _alertsEnabled);
      
      // Update phone number history
      if (phoneNumber.isNotEmpty && !_phoneNumberHistory.contains(phoneNumber)) {
        _phoneNumberHistory.insert(0, phoneNumber);
        // Keep only last 5 phone numbers
        if (_phoneNumberHistory.length > 5) {
          _phoneNumberHistory = _phoneNumberHistory.sublist(0, 5);
        }
        await prefs.setStringList('phone_number_history', _phoneNumberHistory);
      }
      
      developer.log('Settings saved to preferences', name: 'Settings');
      
      // Send to ESP32 if connected
      final success = await _bleService.sendConfiguration(
        phoneNumber: phoneNumber,
        updateInterval: updateInterval,
        alertEnabled: _alertsEnabled,
      );
      
      if (!mounted) return;
      
      if (success) {
        UIHelpers.showSuccess(context, 'Configuration sent to device successfully');
      } else {
        UIHelpers.showWarning(context, 'Settings saved locally. Connect to device to sync.');
      }
    } catch (e) {
      developer.log('Error saving settings: $e', name: 'Settings');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  Future<void> _clearConfiguration() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            const Text('Clear Configuration'),
          ],
        ),
        content: const Text(
          'This will permanently delete all SMS alert settings from both '
          'the app and the connected device.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Clear from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyConfigPhone);
      await prefs.remove(AppConstants.keyConfigInterval);
      await prefs.remove(AppConstants.keyConfigAlerts);
      
      // Optionally clear phone history
      if (!mounted) return;
      
      final clearHistory = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Phone History?'),
          content: const Text('Do you also want to clear saved phone numbers history?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep History'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Clear History'),
            ),
          ],
        ),
      );
      
      if (clearHistory == true) {
        await prefs.remove('phone_number_history');
        _phoneNumberHistory.clear();
      }
      
      developer.log('Configuration cleared from preferences', name: 'Settings');
      
      // Clear from ESP32 if connected
      final success = await _bleService.clearConfiguration();
      
      // Reset UI fields
      setState(() {
        _phoneController.clear();
        _intervalController.text = AppConstants.defaultSmsInterval.toString();
        _alertsEnabled = false;
        _selectedCountryCode = '+1';
        _isSaving = false;
      });
      
      if (!mounted) return;
      
      if (success) {
        UIHelpers.showSuccess(context, 'Configuration cleared from device and app');
      } else {
        UIHelpers.showWarning(context, 'Configuration cleared from app. Connect to device to clear device settings.');
      }
    } catch (e) {
      developer.log('Error clearing configuration: $e', name: 'Settings');
      
      setState(() {
        _isSaving = false;
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _formatInterval(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '$minutes minute${minutes > 1 ? 's' : ''}';
    } else {
      final hours = seconds ~/ 3600;
      return '$hours hour${hours > 1 ? 's' : ''}';
    }
  }
  
  void _selectPhoneFromHistory(String phoneNumber) {
    // Extract country code if present
    for (var country in CountryCodeHelper.countryCodes) {
      if (phoneNumber.startsWith(country.code)) {
        setState(() {
          _selectedCountryCode = country.code;
          _selectedCountry = country;
          _phoneController.text = phoneNumber.substring(country.code.length).trim();
          _validatePhoneNumber(_phoneController.text);
        });
        return;
      }
    }
    // If no country code matched, set the whole number
    setState(() {
      _phoneController.text = phoneNumber;
      _validatePhoneNumber(_phoneController.text);
    });
  }
  
  // Validate phone number based on country code
  bool _validatePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) {
      setState(() {
        _phoneNumberError = null;
      });
      return true; // Empty is valid (user clearing the field)
    }
    
    // Remove any non-digit characters for validation
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Define validation rules for each country
    Map<String, Map<String, dynamic>> validationRules = {
      '+1': {'minLength': 10, 'maxLength': 10, 'name': 'US/Canada'}, // US/Canada
      '+44': {'minLength': 10, 'maxLength': 11, 'name': 'UK'}, // UK
      '+91': {'minLength': 10, 'maxLength': 10, 'name': 'India'}, // India
      '+86': {'minLength': 11, 'maxLength': 11, 'name': 'China'}, // China
      '+81': {'minLength': 10, 'maxLength': 11, 'name': 'Japan'}, // Japan
      '+82': {'minLength': 9, 'maxLength': 11, 'name': 'South Korea'}, // South Korea
      '+49': {'minLength': 10, 'maxLength': 12, 'name': 'Germany'}, // Germany
      '+33': {'minLength': 9, 'maxLength': 9, 'name': 'France'}, // France
      '+39': {'minLength': 9, 'maxLength': 11, 'name': 'Italy'}, // Italy
      '+34': {'minLength': 9, 'maxLength': 9, 'name': 'Spain'}, // Spain
      '+61': {'minLength': 9, 'maxLength': 9, 'name': 'Australia'}, // Australia
      '+55': {'minLength': 10, 'maxLength': 11, 'name': 'Brazil'}, // Brazil
      '+52': {'minLength': 10, 'maxLength': 10, 'name': 'Mexico'}, // Mexico
      '+7': {'minLength': 10, 'maxLength': 10, 'name': 'Russia'}, // Russia
      '+31': {'minLength': 9, 'maxLength': 9, 'name': 'Netherlands'}, // Netherlands
      '+46': {'minLength': 7, 'maxLength': 13, 'name': 'Sweden'}, // Sweden
      '+47': {'minLength': 8, 'maxLength': 8, 'name': 'Norway'}, // Norway
      '+45': {'minLength': 8, 'maxLength': 8, 'name': 'Denmark'}, // Denmark
      '+358': {'minLength': 6, 'maxLength': 12, 'name': 'Finland'}, // Finland
      '+48': {'minLength': 9, 'maxLength': 9, 'name': 'Poland'}, // Poland
      '+90': {'minLength': 10, 'maxLength': 10, 'name': 'Turkey'}, // Turkey
      '+971': {'minLength': 8, 'maxLength': 9, 'name': 'UAE'}, // UAE
      '+966': {'minLength': 9, 'maxLength': 9, 'name': 'Saudi Arabia'}, // Saudi Arabia
      '+65': {'minLength': 8, 'maxLength': 8, 'name': 'Singapore'}, // Singapore
      '+60': {'minLength': 7, 'maxLength': 10, 'name': 'Malaysia'}, // Malaysia
      '+62': {'minLength': 8, 'maxLength': 13, 'name': 'Indonesia'}, // Indonesia
      '+63': {'minLength': 10, 'maxLength': 10, 'name': 'Philippines'}, // Philippines
      '+66': {'minLength': 9, 'maxLength': 9, 'name': 'Thailand'}, // Thailand
      '+84': {'minLength': 9, 'maxLength': 10, 'name': 'Vietnam'}, // Vietnam
      '+27': {'minLength': 9, 'maxLength': 9, 'name': 'South Africa'}, // South Africa
      '+234': {'minLength': 10, 'maxLength': 10, 'name': 'Nigeria'}, // Nigeria
      '+254': {'minLength': 9, 'maxLength': 9, 'name': 'Kenya'}, // Kenya
      '+20': {'minLength': 10, 'maxLength': 10, 'name': 'Egypt'}, // Egypt
      '+212': {'minLength': 9, 'maxLength': 9, 'name': 'Morocco'}, // Morocco
    };
    
    // Get validation rule for selected country
    var rule = validationRules[_selectedCountryCode];
    if (rule == null) {
      // Default validation for unknown countries
      if (digitsOnly.length < 4 || digitsOnly.length > 15) {
        setState(() {
          _phoneNumberError = 'Phone number should be between 4 and 15 digits';
        });
        return false;
      }
    } else {
      // Validate based on country-specific rules
      if (digitsOnly.length < rule['minLength']) {
        setState(() {
          _phoneNumberError = '${rule['name']} phone numbers should have at least ${rule['minLength']} digits';
        });
        return false;
      }
      if (digitsOnly.length > rule['maxLength']) {
        setState(() {
          _phoneNumberError = '${rule['name']} phone numbers should have at most ${rule['maxLength']} digits';
        });
        return false;
      }
    }
    
    // Additional validation: check if it starts with 0 for some countries
    if (_selectedCountryCode == '+44' && !digitsOnly.startsWith('0') && digitsOnly.length == 11) {
      setState(() {
        _phoneNumberError = 'UK mobile numbers typically start with 0';
      });
      return false;
    }
    
    setState(() {
      _phoneNumberError = null;
    });
    return true;
  }
  
  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return CountryPickerDialog(
              selectedCode: _selectedCountryCode,
              onCountrySelected: (CountryCode country) {
                setState(() {
                  _selectedCountryCode = country.code;
                  _selectedCountry = country;
                  // Revalidate phone number when country changes
                  _validatePhoneNumber(_phoneController.text);
                });
                Navigator.pop(context);
              },
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SMS Alert Configuration Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sms,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'SMS Alert Configuration',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Phone Number Field with Country Code
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Country Code Dropdown
                          SizedBox(
                            width: 130,
                            child: InkWell(
                              onTap: _showCountryPicker,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Country',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                                  suffixIcon: _isDetectingLocation 
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : const Icon(Icons.arrow_drop_down, size: 20),
                                ),
                                child: Row(
                                  children: [
                                    if (_selectedCountry != null) ...[
                                      Text(_selectedCountry!.flag, style: const TextStyle(fontSize: 18)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _selectedCountry!.code,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ] else
                                      Text(_selectedCountryCode, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Phone Number Input
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              onChanged: (value) {
                                _validatePhoneNumber(value);
                              },
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '1234567890',
                                prefixIcon: const Icon(Icons.phone),
                                border: const OutlineInputBorder(),
                                helperText: _phoneNumberError == null 
                                  ? 'Enter number without country code'
                                  : null,
                                errorText: _phoneNumberError,
                                suffixIcon: _phoneNumberHistory.isNotEmpty
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(Icons.history),
                                      tooltip: 'Previous numbers',
                                      onSelected: _selectPhoneFromHistory,
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          enabled: false,
                                          child: Text(
                                            'Previous Numbers',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        ..._phoneNumberHistory.map((phone) {
                                          return PopupMenuItem(
                                            value: phone,
                                            child: Row(
                                              children: [
                                                const Icon(Icons.phone, size: 16),
                                                const SizedBox(width: 8),
                                                Text(phone),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    )
                                  : null,
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(15),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a phone number';
                                }
                                if (value.length < 7) {
                                  return 'Phone number too short';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      // Display complete phone number
                      if (_phoneController.text.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Full number: $_selectedCountryCode${_phoneController.text}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // Update Interval Field
                      TextFormField(
                        controller: _intervalController,
                        decoration: InputDecoration(
                          labelText: 'Update Interval (seconds)',
                          hintText: '300',
                          prefixIcon: const Icon(Icons.timer),
                          border: const OutlineInputBorder(),
                          helperText: 'How often to send SMS alerts (10-3600 seconds)',
                          suffixIcon: PopupMenuButton<int>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (value) {
                              setState(() {
                                _intervalController.text = value.toString();
                              });
                            },
                            itemBuilder: (context) => _intervalOptions.map((interval) {
                              return PopupMenuItem(
                                value: interval,
                                child: Text(_formatInterval(interval)),
                              );
                            }).toList(),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an interval';
                          }
                          final interval = int.tryParse(value);
                          if (interval == null) {
                            return 'Please enter a valid number';
                          }
                          if (interval < 10 || interval > 3600) {
                            return 'Interval must be between 10 and 3600 seconds';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Quick interval selection chips
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('10s'),
                            onPressed: () {
                              _intervalController.text = '10';
                            },
                          ),
                          ActionChip(
                            label: const Text('30s'),
                            onPressed: () {
                              _intervalController.text = '30';
                            },
                          ),
                          ActionChip(
                            label: const Text('1 min'),
                            onPressed: () {
                              _intervalController.text = '60';
                            },
                          ),
                          ActionChip(
                            label: const Text('5 min'),
                            onPressed: () {
                              _intervalController.text = '300';
                            },
                          ),
                          ActionChip(
                            label: const Text('10 min'),
                            onPressed: () {
                              _intervalController.text = '600';
                            },
                          ),
                          ActionChip(
                            label: const Text('30 min'),
                            onPressed: () {
                              _intervalController.text = '1800';
                            },
                          ),
                          ActionChip(
                            label: const Text('1 hour'),
                            onPressed: () {
                              _intervalController.text = '3600';
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Alerts Enabled Switch
                      SwitchListTile(
                        title: const Text('Enable SMS Alerts'),
                        subtitle: const Text('Send alerts when theft is detected'),
                        value: _alertsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _alertsEnabled = value;
                          });
                        },
                        activeColor: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info Card
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Configuration Info',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• SMS alerts are sent from the SIM7070G module when theft is detected\n'
                        '• The phone number must include country code\n'
                        '• Shorter intervals use more battery\n'
                        '• Settings are saved locally and synced when connected',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Clear Configuration Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _clearConfiguration,
                  icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.clear_all),
                  label: Text(_isSaving ? 'Clearing...' : 'Clear Configuration'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _intervalController.dispose();
    super.dispose();
  }
}
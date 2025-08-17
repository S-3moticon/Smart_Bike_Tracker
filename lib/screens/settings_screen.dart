import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../services/bluetooth_service.dart' as bike_ble;
import '../utils/ui_helpers.dart';
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
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _phoneController.text = prefs.getString(AppConstants.keyConfigPhone) ?? '';
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
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final phoneNumber = _phoneController.text.trim();
      final updateInterval = int.tryParse(_intervalController.text) ?? 300;
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyConfigPhone, phoneNumber);
      await prefs.setInt(AppConstants.keyConfigInterval, updateInterval);
      await prefs.setBool(AppConstants.keyConfigAlerts, _alertsEnabled);
      
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
      
      developer.log('Configuration cleared from preferences', name: 'Settings');
      
      // Clear from ESP32 if connected
      final success = await _bleService.clearConfiguration();
      
      // Reset UI fields
      setState(() {
        _phoneController.clear();
        _intervalController.text = AppConstants.defaultSmsInterval.toString();
        _alertsEnabled = false;
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
                      
                      // Phone Number Field
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '+1234567890',
                          prefixIcon: const Icon(Icons.phone),
                          border: const OutlineInputBorder(),
                          helperText: 'Include country code (e.g., +1 for USA)',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s()]')),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a phone number';
                          }
                          if (!value.startsWith('+')) {
                            return 'Please include country code (e.g., +1)';
                          }
                          if (value.length < 10) {
                            return 'Phone number too short';
                          }
                          return null;
                        },
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
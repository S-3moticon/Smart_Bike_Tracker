import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../services/bluetooth_service.dart' as bike_ble;

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
  
  // Predefined interval options
  final List<int> _intervalOptions = [10, 30, 60, 120, 300, 600, 900, 1800, 3600];
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _phoneController.text = prefs.getString('config_phone') ?? '';
        _intervalController.text = (prefs.getInt('config_interval') ?? 300).toString();
        _alertsEnabled = prefs.getBool('config_alerts') ?? true;
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
      await prefs.setString('config_phone', phoneNumber);
      await prefs.setInt('config_interval', updateInterval);
      await prefs.setBool('config_alerts', _alertsEnabled);
      
      developer.log('Settings saved to preferences', name: 'Settings');
      
      // Send to ESP32 if connected
      final success = await _bleService.sendConfiguration(
        phoneNumber: phoneNumber,
        updateInterval: updateInterval,
        alertEnabled: _alertsEnabled,
      );
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration sent to device successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved locally. Connect to device to sync.'),
            backgroundColor: Colors.orange,
          ),
        );
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
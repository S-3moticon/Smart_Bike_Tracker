import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart';
import '../models/tracker_config.dart';

class ConfigProvider extends ChangeNotifier {
  final BikeBluetoothService _bleService = BikeBluetoothService();
  
  String _phoneNumber = '';
  int _updateInterval = 30;
  bool _alertEnabled = true;
  bool _isUpdating = false;
  bool _hasUnsavedChanges = false;
  
  static const String _phoneKey = 'emergency_phone';
  static const String _intervalKey = 'update_interval';
  static const String _alertKey = 'alert_enabled';
  static const String _deviceIdKey = 'last_device_id';
  
  String get phoneNumber => _phoneNumber;
  int get updateInterval => _updateInterval;
  bool get alertEnabled => _alertEnabled;
  bool get isUpdating => _isUpdating;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  String? _lastConnectedDeviceId;
  
  String? get lastConnectedDeviceId => _lastConnectedDeviceId;
  
  String get formattedInterval {
    if (_updateInterval < 60) {
      return '$_updateInterval seconds';
    } else if (_updateInterval < 3600) {
      final minutes = _updateInterval ~/ 60;
      final seconds = _updateInterval % 60;
      if (seconds == 0) {
        return '$minutes minute${minutes > 1 ? 's' : ''}';
      }
      return '$minutes min ${seconds}s';
    } else {
      final hours = _updateInterval ~/ 3600;
      final minutes = (_updateInterval % 3600) ~/ 60;
      if (minutes == 0) {
        return '$hours hour${hours > 1 ? 's' : ''}';
      }
      return '$hours hr $minutes min';
    }
  }
  
  ConfigProvider() {
    _loadConfiguration();
  }
  
  Future<void> _loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _phoneNumber = prefs.getString(_phoneKey) ?? '';
      _updateInterval = prefs.getInt(_intervalKey) ?? 30;
      _alertEnabled = prefs.getBool(_alertKey) ?? true;
      _lastConnectedDeviceId = prefs.getString(_deviceIdKey);
      
      notifyListeners();
      
      developer.log(
        'Configuration loaded: phone=$_phoneNumber, interval=$_updateInterval, alerts=$_alertEnabled',
        name: 'ConfigProvider',
      );
    } catch (e) {
      developer.log('Error loading configuration: $e', name: 'ConfigProvider');
    }
  }
  
  Future<void> _saveConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_phoneKey, _phoneNumber);
      await prefs.setInt(_intervalKey, _updateInterval);
      await prefs.setBool(_alertKey, _alertEnabled);
      
      if (_lastConnectedDeviceId != null) {
        await prefs.setString(_deviceIdKey, _lastConnectedDeviceId!);
      }
      
      developer.log('Configuration saved locally', name: 'ConfigProvider');
    } catch (e) {
      developer.log('Error saving configuration: $e', name: 'ConfigProvider');
    }
  }
  
  void setPhoneNumber(String number) {
    if (_phoneNumber != number) {
      _phoneNumber = number;
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }
  
  void setUpdateInterval(int interval) {
    if (_updateInterval != interval) {
      _updateInterval = interval.clamp(10, 3600);
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }
  
  void setAlertEnabled(bool enabled) {
    if (_alertEnabled != enabled) {
      _alertEnabled = enabled;
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }
  
  void setLastConnectedDeviceId(String? deviceId) {
    _lastConnectedDeviceId = deviceId;
    _saveConfiguration();
  }
  
  bool validatePhoneNumber() {
    if (_phoneNumber.isEmpty) return false;
    
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    return phoneRegex.hasMatch(_phoneNumber.replaceAll(' ', '').replaceAll('-', ''));
  }
  
  Future<bool> applyConfiguration() async {
    if (!validatePhoneNumber()) {
      developer.log('Invalid phone number format', name: 'ConfigProvider');
      return false;
    }
    
    _isUpdating = true;
    notifyListeners();
    
    try {
      final config = TrackerConfig(
        phoneNumber: _phoneNumber,
        updateInterval: _updateInterval,
        alertEnabled: _alertEnabled,
      );
      
      final success = await _bleService.writeConfig(config);
      
      if (success) {
        await _saveConfiguration();
        _hasUnsavedChanges = false;
        developer.log('Configuration applied successfully', name: 'ConfigProvider');
      } else {
        developer.log('Failed to apply configuration to device', name: 'ConfigProvider');
      }
      
      _isUpdating = false;
      notifyListeners();
      
      return success;
    } catch (e) {
      developer.log('Error applying configuration: $e', name: 'ConfigProvider');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> resetConfiguration() async {
    _phoneNumber = '';
    _updateInterval = 30;
    _alertEnabled = true;
    _hasUnsavedChanges = false;
    
    await _saveConfiguration();
    notifyListeners();
  }
  
  Future<void> clearStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      _phoneNumber = '';
      _updateInterval = 30;
      _alertEnabled = true;
      _lastConnectedDeviceId = null;
      _hasUnsavedChanges = false;
      
      notifyListeners();
      
      developer.log('All stored data cleared', name: 'ConfigProvider');
    } catch (e) {
      developer.log('Error clearing stored data: $e', name: 'ConfigProvider');
    }
  }
}
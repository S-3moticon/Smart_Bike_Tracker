
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../models/location_data.dart';
import '../constants/app_constants.dart';

class LocationStorageService {
  static const String _historyKey = AppConstants.keyLocationHistory;
  static const int _maxHistorySize = AppConstants.maxLocationHistory;
  
  Future<List<LocationData>> loadLocationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_historyKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => _locationFromJson(json)).toList();
    } catch (e) {
      developer.log('Error loading location history: $e', name: 'LocationStorage');
      return [];
    }
  }
  
  Future<void> saveLocationHistory(List<LocationData> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Limit history size
      final historyToSave = history.take(_maxHistorySize).toList();
      
      final jsonList = historyToSave.map((location) => _locationToJson(location)).toList();
      final jsonString = json.encode(jsonList);
      
      await prefs.setString(_historyKey, jsonString);
      developer.log('Saved ${historyToSave.length} locations to storage', name: 'LocationStorage');
    } catch (e) {
      developer.log('Error saving location history: $e', name: 'LocationStorage');
    }
  }
  
  Future<void> addLocation(LocationData location) async {
    final history = await loadLocationHistory();
    history.insert(0, location); // Add to beginning
    
    // Keep only the most recent locations
    if (history.length > _maxHistorySize) {
      history.removeRange(_maxHistorySize, history.length);
    }
    
    await saveLocationHistory(history);
  }
  
  Future<void> clearLocationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      developer.log('Location history cleared', name: 'LocationStorage');
    } catch (e) {
      developer.log('Error clearing location history: $e', name: 'LocationStorage');
    }
  }
  
  Map<String, dynamic> _locationToJson(LocationData location) {
    return {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'speed': location.speed,
      'accuracy': location.accuracy,
      'source': location.source,
      'timestamp': location.timestamp.toIso8601String(),
    };
  }
  
  LocationData _locationFromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude'],
      longitude: json['longitude'],
      speed: json['speed'] ?? 0.0,
      accuracy: json['accuracy'] ?? 10.0,
      source: json['source'] ?? 'phone',
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
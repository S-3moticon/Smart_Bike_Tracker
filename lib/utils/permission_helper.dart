import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:geolocator/geolocator.dart';

class PermissionHelper {
  // Check if all required permissions and services are enabled
  static Future<AppPermissionStatus> checkAllPermissions() async {
    try {
      // Check if location services are enabled
      bool locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        developer.log('Location services are disabled', name: 'Permissions');
        return AppPermissionStatus.locationServicesDisabled;
      }

      // Check Bluetooth permissions for Android 12+
      if (Platform.isAndroid) {
        Map<perm.Permission, perm.PermissionStatus> statuses = await [
          perm.Permission.bluetoothScan,
          perm.Permission.bluetoothConnect,
          perm.Permission.location,
        ].request();

        // Check if all permissions are granted
        bool allGranted = true;
        bool permanentlyDenied = false;
        
        statuses.forEach((permission, status) {
          developer.log('Permission $permission: $status', name: 'Permissions');
          if (!status.isGranted) {
            allGranted = false;
            if (status.isPermanentlyDenied) {
              permanentlyDenied = true;
            }
          }
        });

        if (!allGranted) {
          return permanentlyDenied ? AppPermissionStatus.permanentlyDenied : AppPermissionStatus.denied;
        }
      }

      developer.log('All permissions and services are enabled', name: 'Permissions');
      return AppPermissionStatus.allGranted;
    } catch (e) {
      developer.log('Error checking permissions: $e', name: 'Permissions', error: e);
      return AppPermissionStatus.error;
    }
  }

  // Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      developer.log('Error checking location service: $e', name: 'Permissions', error: e);
      return false;
    }
  }

  // Request user to enable location services
  static Future<bool> requestLocationServices(BuildContext context) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.orange),
              SizedBox(width: 8),
              Text('Location Services Required'),
            ],
          ),
          content: const Text(
            'Location services must be enabled to scan for Bluetooth devices.\n\n'
            'This is an Android requirement for BLE scanning. '
            'Your location data is not collected or stored.\n\n'
            'Please enable location services to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                await openLocationSettings();
              },
              child: const Text('Enable Location'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // Open location settings
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
      developer.log('Opened location settings', name: 'Permissions');
    } catch (e) {
      developer.log('Error opening location settings: $e', name: 'Permissions', error: e);
    }
  }

  // Open app settings for permission management
  static Future<void> openAppSettings() async {
    try {
      await perm.openAppSettings();
      developer.log('Opened app settings', name: 'Permissions');
    } catch (e) {
      developer.log('Error opening app settings: $e', name: 'Permissions', error: e);
    }
  }

  // Show permission denied dialog
  static Future<void> showPermissionDeniedDialog(BuildContext context, String permissionName) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Permission Required'),
            ],
          ),
          content: Text(
            '$permissionName permission is required for the app to function properly.\n\n'
            'Please grant the permission in app settings to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  // Show success dialog when all permissions are granted
  static Future<void> showPermissionsGrantedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Ready to Scan'),
            ],
          ),
          content: const Text(
            'All required permissions are granted.\n'
            'You can now scan for Bluetooth devices.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Check and request all permissions with UI feedback
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    // First check if location services are enabled
    bool locationEnabled = await isLocationServiceEnabled();
    if (!locationEnabled) {
      developer.log('Location services disabled, requesting user to enable', name: 'Permissions');
      if (!context.mounted) return false;
      bool userEnabledLocation = await requestLocationServices(context);
      
      if (!userEnabledLocation) {
        return false;
      }

      // Wait a bit for user to enable location and return from settings
      await Future.delayed(const Duration(seconds: 1));
      
      // Check again
      locationEnabled = await isLocationServiceEnabled();
      if (!locationEnabled) {
        developer.log('Location services still disabled after user action', name: 'Permissions');
        return false;
      }
    }

    // Now check permissions
    AppPermissionStatus status = await checkAllPermissions();
    
    switch (status) {
      case AppPermissionStatus.allGranted:
        developer.log('All permissions granted', name: 'Permissions');
        return true;
        
      case AppPermissionStatus.locationServicesDisabled:
        // This shouldn't happen as we checked above, but handle it anyway
        if (context.mounted) await requestLocationServices(context);
        return false;
        
      case AppPermissionStatus.denied:
      case AppPermissionStatus.permanentlyDenied:
        if (context.mounted) await showPermissionDeniedDialog(context, 'Bluetooth and Location');
        return false;
        
      default:
        developer.log('Unknown permission status: $status', name: 'Permissions');
        return false;
    }
  }
}

// Custom enum for permission status
enum AppPermissionStatus {
  allGranted,
  denied,
  permanentlyDenied,
  locationServicesDisabled,
  error,
}

// Extension to check AppPermissionStatus
extension AppPermissionStatusExtension on AppPermissionStatus {
  bool get isGranted => this == AppPermissionStatus.allGranted;
  bool get isDenied => this == AppPermissionStatus.denied || this == AppPermissionStatus.permanentlyDenied;
  bool get isLocationServicesDisabled => this == AppPermissionStatus.locationServicesDisabled;
}
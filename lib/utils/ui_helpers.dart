import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class for common UI operations
class UIHelpers {
  /// Shows a success snackbar with green background
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// Shows an error snackbar with red background
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Shows a warning snackbar with orange background
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// Shows an info snackbar with default theme colors
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// Copies text to clipboard and shows a confirmation snackbar
  static Future<void> copyToClipboard(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showInfo(context, '$label copied to clipboard');
    }
  }
  
  /// Shows a confirmation dialog and returns the user's choice
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
}
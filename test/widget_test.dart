import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_bike_tracker/main.dart';

void main() {
  testWidgets('App loads device scan screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartBikeTrackerApp());

    // Verify that the device scan screen is shown
    expect(find.text('Find Your Bike Tracker'), findsOneWidget);
    
    // Verify that key UI elements are present
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
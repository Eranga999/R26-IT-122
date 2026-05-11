// Widget tests for HeritageAR.
//
// Tests verify that the root widget renders correctly and that key UI
// elements (app bar title, initial loading state) are present on launch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r26_it_122/main.dart';

void main() {
  testWidgets('HeritageAR app smoke test – root widget renders',
      (WidgetTester tester) async {
    // Build the root app widget and trigger a frame.
    await tester.pumpWidget(const HeritageArApp());

    // The MaterialApp title should be set.
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'HeritageAR');

    // The AppBar title text should be visible.
    expect(find.text('HeritageAR'), findsOneWidget);

    // On launch the home screen is in its loading state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

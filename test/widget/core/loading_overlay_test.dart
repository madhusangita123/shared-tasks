import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/widgets/loading_overlay.dart';

void main() {
  group('LoadingOverlay', () {
    testWidgets('shows only the child when not loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingOverlay(isLoading: false, child: Text('content')),
        ),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows a spinner over the child when loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingOverlay(isLoading: true, child: Text('content')),
        ),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

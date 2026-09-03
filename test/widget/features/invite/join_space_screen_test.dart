import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/features/invite/presentation/join_space_screen.dart';

void main() {
  group('JoinSpaceScreen', () {
    testWidgets('shows a loading indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: JoinSpaceScreen(token: 'some-token')),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

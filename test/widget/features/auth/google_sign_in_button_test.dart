// Widget tests for GoogleSignInButton (issue #59).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/auth/presentation/widgets/google_sign_in_button.dart';

void main() {
  group('GoogleSignInButton — idle state', () {
    testWidgets('renders the "Continue with Google" label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GoogleSignInButton(onPressed: () {}, isLoading: false),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tapping invokes onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GoogleSignInButton(
            onPressed: () => tapped = true,
            isLoading: false,
          ),
        ),
      );

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('GoogleSignInButton — loading state', () {
    testWidgets('shows a centered spinner and hides the label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GoogleSignInButton(onPressed: () {}, isLoading: true),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('tapping while loading does not invoke onPressed',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: GoogleSignInButton(
            onPressed: () => tapped = true,
            isLoading: true,
          ),
        ),
      );

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();

      expect(tapped, isFalse);
    });
  });
}

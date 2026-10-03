// Unit tests for the two SpacesRemoteDatasource methods issue #64 added:
// `deleteSpace` (a Cloud Functions callable) and `countOpenTasks` (a
// Firestore aggregate query).
//
// Scope is deliberately narrow. The rest of this datasource (createSpace,
// watchSpace, getMemberAvatars) is exercised through the repository with
// the datasource itself mocked, and this project has no fake_cloud_firestore
// dependency — so the Firestore *query shape* is not asserted here, only the
// documented never-throw behaviour that the delete confirmation depends on.
//
// What IS worth asserting directly:
//   * the callable's name and payload. A rename or region mismatch is
//     exactly what produces the 'not-found' HttpsError that caused the
//     wrong-message bug in spaces_repository_impl.dart, and nothing else in
//     the test suite pins the string 'deleteSpace' or the key 'spaceId'.
//   * that countOpenTasks returns 0 instead of throwing when the query
//     fails. The dialog must never be blocked by a count it could not get.
//
// Never touches real Firebase.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/features/spaces/data/spaces_remote_datasource.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late SpacesRemoteDatasource datasource;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    datasource = SpacesRemoteDatasource(
      firestore: mockFirestore,
      functions: mockFunctions,
    );

    when(() => mockFunctions.httpsCallable(any())).thenReturn(mockCallable);
    when(
      () => mockCallable.call<Map<String, dynamic>>(any<dynamic>()),
    ).thenAnswer((_) async => MockHttpsCallableResult());
  });

  group('deleteSpace', () {
    test("calls the callable named exactly 'deleteSpace'", () async {
      await datasource.deleteSpace('space-1');

      verify(() => mockFunctions.httpsCallable('deleteSpace')).called(1);
    });

    test("passes the spaceId under the 'spaceId' key the function reads",
        () async {
      await datasource.deleteSpace('space-7');

      final captured = verify(
        () => mockCallable.call<Map<String, dynamic>>(captureAny<dynamic>()),
      ).captured.single;
      expect(captured, {'spaceId': 'space-7'});
    });

    // The repository's _mapFunctionsException is the only thing allowed to
    // turn these into failures, so the datasource must let them through
    // untouched.
    test('lets a FirebaseFunctionsException propagate rather than swallowing '
        'it', () async {
      when(() => mockCallable.call<Map<String, dynamic>>(any<dynamic>())).thenThrow(
        FirebaseFunctionsException(code: 'permission-denied', message: 'nope'),
      );

      expect(
        () => datasource.deleteSpace('space-1'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });
  });

  group('countOpenTasks', () {
    // Documented contract: "Returns 0 — never throws — if the subcollection
    // is empty, missing, or the query fails for any reason. The caller (the
    // delete confirmation) must never be blocked by a count it could not
    // get." Driven by making the very first call in the query chain throw.
    test('returns 0 instead of throwing when the query fails', () async {
      when(() => mockFirestore.collection(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      await expectLater(datasource.countOpenTasks(spaceId: 'space-1'), completion(0));
    });
  });
}

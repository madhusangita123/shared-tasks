import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/providers/firebase_providers.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/home/data/home_remote_datasource.dart';
import 'package:shared_tasks/features/home/data/home_repository_impl.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';
import 'package:shared_tasks/features/home/domain/repositories/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(
    datasource: HomeRemoteDatasource(firestore: ref.watch(firestoreProvider)),
  );
});

/// Emits every space the signed-in user owns or is a member of, ordered by
/// most recently updated. Matches docs/ARCHITECTURE.md's documented
/// `userSpacesProvider` example exactly.
final userSpacesProvider = StreamProvider.autoDispose<List<HomeSpace>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.id;
  if (uid == null) return const Stream.empty();
  return ref.watch(homeRepositoryProvider).watchUserSpaces(uid);
});

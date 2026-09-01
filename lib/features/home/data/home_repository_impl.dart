import 'package:shared_tasks/features/home/data/home_remote_datasource.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';
import 'package:shared_tasks/features/home/domain/repositories/home_repository.dart';

/// Firestore-backed [HomeRepository]. Thin pass-through to
/// [HomeRemoteDatasource] — matches the precedent of
/// `AuthRepositoryImpl.authStateChanges` for stream-returning methods.
class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl({required HomeRemoteDatasource datasource})
    : _datasource = datasource;

  final HomeRemoteDatasource _datasource;

  @override
  Stream<List<HomeSpace>> watchUserSpaces(String uid) =>
      _datasource.watchUserSpaces(uid);
}

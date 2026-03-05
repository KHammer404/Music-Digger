import 'package:get_it/get_it.dart';

import '../../data/datasources/remote_datasource.dart';
import '../../data/repositories/search_repository.dart';
import '../network/api_client.dart';
import '../services/user_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Network
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());

  // Services
  getIt.registerLazySingleton<UserService>(
    () => UserService(getIt<ApiClient>()),
  );

  // Data Sources
  getIt.registerLazySingleton<RemoteDataSource>(
    () => RemoteDataSource(getIt<ApiClient>()),
  );

  // Repositories
  getIt.registerLazySingleton<SearchRepository>(
    () => SearchRepository(getIt<RemoteDataSource>()),
  );
}

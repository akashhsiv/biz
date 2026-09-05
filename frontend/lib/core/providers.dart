import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import 'storage/app_storage.dart';

final appStorageProvider = Provider<AppStorage>((ref) => AppStorage());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(appStorageProvider)));

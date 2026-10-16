import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/di/injection.config.dart';

/// The service locator. Classes are registered by annotations (@injectable, @lazySingleton, …);
/// `dart run build_runner build` generates injection.config.dart.
final GetIt getIt = GetIt.instance;

@InjectableInit(preferRelativeImports: false)
Future<void> configureDependencies() async {
  await getIt.init();
}

import 'package:get_it/get_it.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../users_client.dart';
import '../services/otp_auth_service.dart';

import '../../features/registration/data/datasources/registration_local_data_source.dart';
import '../../features/registration/data/repositories/registration_repository_impl.dart';
import '../../features/registration/domain/repositories/registration_repository.dart';
import '../../features/registration/domain/usecases/register_user.dart';
import '../../features/registration/presentation/viewmodels/registration_viewmodel.dart';
import '../../features/call/data/datasources/call_data_source.dart';
import '../../features/call/data/repositories/call_repository_impl.dart';
import '../../features/call/domain/repositories/call_repository.dart';
import '../../features/call/domain/usecases/accept_call.dart';
import '../../features/call/domain/usecases/make_call.dart';
import '../../features/call/domain/usecases/hangup_call.dart';
import '../../features/call/presentation/viewmodels/call_viewmodel.dart';
import '../../features/dialpad/data/datasources/dialpad_local_data_source.dart';
import '../../features/dialpad/data/repositories/dialpad_repository_impl.dart';
import '../../features/dialpad/domain/repositories/dialpad_repository.dart';
import '../../features/dialpad/domain/usecases/save_destination.dart';
import '../../features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import '../../features/login/presentation/viewmodels/login_viewmodel.dart';
import '../../features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import '../../shared/theme/theme_provider.dart';

// Merged Imports
import '../../services/calling_service.dart';
import '../../services/shopping_service.dart';
import '../../services/utility_bills_service.dart';
import '../../services/auth_service.dart'; // New AuthService
import '../../features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import '../../features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import '../../features/utility_bills/presentation/viewmodels/utility_bills_viewmodel.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/calling/presentation/viewmodels/calling_viewmodel.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Core dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  
  final sipHelper = SIPUAHelper();
  getIt.registerSingleton<SIPUAHelper>(sipHelper);

  // Data sources
  getIt.registerLazySingleton<RegistrationLocalDataSource>(
    () => RegistrationLocalDataSourceImpl(getIt()),
  );
  getIt.registerLazySingleton<CallDataSource>(
    () => CallDataSourceImpl(getIt()),
  );
  getIt.registerLazySingleton<DialpadLocalDataSource>(
    () => DialpadLocalDataSourceImpl(getIt()),
  );

  // Repositories
  getIt.registerLazySingleton<RegistrationRepository>(
    () => RegistrationRepositoryImpl(getIt(), getIt()),
  );
  getIt.registerLazySingleton<CallRepository>(
    () => CallRepositoryImpl(getIt(), getIt()),
  );
  getIt.registerLazySingleton<DialpadRepository>(
    () => DialpadRepositoryImpl(getIt()),
  );

  // Use cases
  // API clients
  getIt.registerLazySingleton<UsersClient>(
    () => UsersClient(packageId: 'org.africom.catchapp', secure: false),
  );

  // Auth service for WhatsApp OTP
  getIt.registerLazySingleton<OtpAuthService>(
    () => OtpAuthService(getIt<UsersClient>()),
  );

  getIt.registerLazySingleton(() => RegisterUser(getIt()));
  getIt.registerLazySingleton(() => MakeCall(getIt()));
  getIt.registerLazySingleton(() => AcceptCall(getIt()));
  getIt.registerLazySingleton(() => HangupCall(getIt()));
  getIt.registerLazySingleton(() => SaveDestination(getIt()));

  // ViewModels
  getIt.registerFactory(() => RegistrationViewModel(getIt(), getIt(), getIt()));
  getIt.registerFactory(() => CallViewModel(getIt(), getIt(), getIt(), getIt()));
  getIt.registerLazySingleton(() => DialpadViewModel(getIt(), getIt(), getIt<OtpAuthService>(), getIt<DialpadRepository>()));
  getIt.registerFactory(() => LoginViewModel(getIt<OtpAuthService>(), getIt<RegisterUser>(), getIt<UsersClient>()));
  getIt.registerFactory(() => AccountSummaryViewModel(getIt<OtpAuthService>()));

  // Theme Provider
  getIt.registerSingleton<ThemeProvider>(ThemeProvider());

  // --- Merged Dependencies ---
  // Services
  getIt.registerLazySingleton<CallingService>(() => CallingService());
  getIt.registerLazySingleton<ShoppingService>(() => ShoppingService());
  getIt.registerLazySingleton<UtilityBillsService>(() => UtilityBillsService());
  getIt.registerLazySingleton<AuthService>(() => AuthService()); // New AppAuthService

  // ViewModels
  getIt.registerFactory(() => DashboardViewModel(getIt(), getIt(), getIt()));
  getIt.registerFactory(() => ShoppingViewModel(getIt()));
  getIt.registerFactory(() => UtilityBillsViewModel(getIt()));
  getIt.registerFactory(() => AuthViewModel(getIt())); // Inject AuthService
  getIt.registerFactory(() => CallingViewModel(getIt())); // Inejct CallingService
}

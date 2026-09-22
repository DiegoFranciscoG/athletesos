import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/admin/presentation/screens/admin_screen.dart';
import '../../features/rutas/presentation/screens/ruta_aprendizaje_screen.dart';
import '../../features/ajedrez/presentation/screens/ajedrez_screen.dart';
import '../../features/settings/presentation/screens/ajustes_screen.dart';
import '../../features/vocabulario/presentation/screens/vocabulario_screen.dart';
import '../../features/trivia/presentation/screens/trivia_screen.dart';
import '../../shared/widgets/main_scaffold.dart';

// Listenable para que GoRouter reaccione al cambio de auth state
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

final authStateNotifierProvider = Provider<AuthStateNotifier>((ref) {
  return AuthStateNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(authStateNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';

      // Mientras carga el estado inicial, no redirigir
      if (authState.isLoading) return null;

      // No autenticado → login
      if (!authState.isAuthenticated && !isLoggingIn) {
        return '/login';
      }
      if (authState.isAuthenticated && isLoggingIn) {
        // Autenticado, pero sin onboarding → generar su programa primero
        if (authState.profile?.onboardingCompletado == false) {
          return '/onboarding';
        }
        return '/';
      }
      // Autenticado sin onboarding y navegando a otra pantalla → forzar onboarding
      if (authState.isAuthenticated &&
          authState.profile?.onboardingCompletado == false &&
          !isOnboarding) {
        return '/onboarding';
      }
      // Ya completó onboarding pero sigue en esa pantalla → mándalo a Home
      if (authState.isAuthenticated &&
          authState.profile?.onboardingCompletado == true &&
          isOnboarding) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/ajustes',
            builder: (context, state) => const AjustesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/rutas/:dominio',
        builder: (context, state) => RutaAprendizajeScreen(dominio: state.pathParameters['dominio']!),
      ),
      GoRoute(
        path: '/ajedrez',
        builder: (context, state) => const AjedrezScreen(),
      ),
      GoRoute(
        path: '/vocabulario',
        builder: (context, state) => const VocabularioScreen(),
      ),
      GoRoute(
        path: '/trivia',
        builder: (context, state) => const TriviaScreen(),
      ),
    ],
  );
});

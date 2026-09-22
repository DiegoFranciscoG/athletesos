import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/dio_client.dart';

class UserProfile {
  final String nombre;
  final String? avatarUrl;
  final String? objetivoPrincipal;
  final String rol;
  final String? nivelHabilidad;
  final String? intensidad;
  final bool onboardingCompletado;

  UserProfile({
    required this.nombre,
    this.avatarUrl,
    this.objetivoPrincipal,
    this.rol = 'ATLETA',
    this.nivelHabilidad,
    this.intensidad,
    this.onboardingCompletado = false,
  });

  bool get isAdmin => rol == 'ADMIN';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      nombre: json['nombre'] ?? 'Atleta',
      avatarUrl: json['avatarUrl'],
      objetivoPrincipal: json['objetivoPrincipal'],
      rol: json['rol'] ?? 'ATLETA',
      nivelHabilidad: json['nivelHabilidad'],
      intensidad: json['intensidad'],
      onboardingCompletado: json['onboardingCompletado'] ?? false,
    );
  }
}

/// Evento de un solo disparo para que la UI muestre un SnackBar exacto por
/// cada acción (pedido explícito: "toda acción debe salir con un mensaje").
class AuthEvent {
  final String message;
  final bool isError;
  final int id;
  AuthEvent(this.message, this.isError, this.id);
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserProfile? profile;
  final String? error;
  final AuthEvent? event;

  AuthState({
    this.isLoading = true, // Starts as loading to check token
    this.isAuthenticated = false,
    this.profile,
    this.error,
    this.event,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserProfile? profile,
    String? error,
    AuthEvent? event,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      profile: profile ?? this.profile,
      error: error,
      event: event,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _googleInitialized = false;
  int _eventCounter = 0;

  AuthNotifier() : super(AuthState(isLoading: true)) {
    _initGoogle();
    _checkAuthStatus();
  }

  Future<void> _initGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: '711330016273-vq3bq50eehk8fm2m6va9nhbbmbldj4b0.apps.googleusercontent.com',
      );
      _googleInitialized = true;
    } catch (_) {
      // Si Google no inicializa (config pendiente), el login por correo sigue funcionando.
    }
  }

  void _emit(String message, {bool isError = false}) {
    _eventCounter++;
    state = state.copyWith(event: AuthEvent(message, isError, _eventCounter));
  }

  Future<void> _checkAuthStatus() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      await _fetchProfile(showErrorOnFail: false);
    } else {
      state = AuthState(isLoading: false, isAuthenticated: false);
    }
  }

  Future<void> _fetchProfile({bool showErrorOnFail = true}) async {
    try {
      final response = await dioClient.dio.get('/users/me');
      if (response.statusCode == 200) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          profile: UserProfile.fromJson(response.data),
        );
      } else {
        await _clearSession(mensaje: showErrorOnFail ? 'Tu sesión ya no es válida, inicia sesión de nuevo.' : null);
      }
    } catch (_) {
      // Si esto pasa justo después de crear la cuenta o iniciar sesión, no
      // borramos silenciosamente: avisamos, porque el usuario sí tiene una
      // sesión válida en el backend aunque esta llamada puntual haya fallado.
      if (showErrorOnFail) {
        state = state.copyWith(isLoading: false, error: 'No se pudo cargar tu perfil (backend no disponible). Intenta de nuevo.');
        _emit('No se pudo conectar con el servidor. Intenta de nuevo.', isError: true);
      } else {
        await _clearSession();
      }
    }
  }

  Future<void> _clearSession({String? mensaje}) async {
    await _storage.delete(key: 'jwt_token');
    state = AuthState(isLoading: false, isAuthenticated: false, error: mensaje);
    if (mensaje != null) _emit(mensaje, isError: true);
  }

  Future<void> _autenticarConCredenciales(String path, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await dioClient.dio.post('/auth/$path', data: {
        'email': email.trim(),
        'password': password,
      });
      final jwt = response.data['token'] as String;
      await _storage.write(key: 'jwt_token', value: jwt);
      _emit(path == 'registro' ? '¡Cuenta creada! Bienvenido a AthletesOS.' : '¡Sesión iniciada!');
      await _fetchProfile();
    } on DioException catch (e) {
      final mensaje = e.response?.data is Map ? e.response?.data['error'] as String? : null;
      final texto = mensaje ?? 'No se pudo conectar con el servidor.';
      state = state.copyWith(isLoading: false, error: texto);
      _emit(texto, isError: true);
    } catch (e) {
      final texto = 'Error inesperado: $e';
      state = state.copyWith(isLoading: false, error: texto);
      _emit(texto, isError: true);
    }
  }

  Future<void> login(String email, String password) => _autenticarConCredenciales('login', email, password);

  Future<void> registrar(String email, String password) => _autenticarConCredenciales('registro', email, password);

  Future<void> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (!_googleInitialized) {
        await _initGoogle();
      }
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        const texto = 'No se obtuvo el token de Google. Intenta de nuevo.';
        state = state.copyWith(isLoading: false, error: texto);
        _emit(texto, isError: true);
        return;
      }

      final response = await dioClient.dio.post('/auth/google', data: {'idToken': idToken});
      final jwt = response.data['token'] as String;
      await _storage.write(key: 'jwt_token', value: jwt);
      _emit('¡Sesión iniciada con Google!');
      await _fetchProfile();
    } catch (e) {
      final texto = 'No se pudo iniciar sesión con Google: $e';
      state = state.copyWith(isLoading: false, error: texto);
      _emit(texto, isError: true);
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }

  /// Refresca el perfil (usado tras completar el onboarding, para que
  /// `onboardingCompletado` pase a true y el router deje de forzar /onboarding).
  Future<void> refreshProfile() => _fetchProfile();

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _eventCounter++;
    state = AuthState(isLoading: false, isAuthenticated: false, event: AuthEvent('Sesión cerrada.', false, _eventCounter));
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

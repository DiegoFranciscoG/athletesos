import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _modoRegistro = false;
  bool _obscurePassword = true;

  static final _emailRegex = RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authProvider.notifier);
    if (_modoRegistro) {
      notifier.registrar(_emailController.text, _passwordController.text);
    } else {
      notifier.login(_emailController.text, _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cada AuthEvent (éxito o error) sale como SnackBar, sin excepción — una
    // acción nunca queda "en silencio".
    ref.listen<AuthState>(authProvider, (previous, next) {
      final event = next.event;
      if (event != null && event.id != previous?.event?.id) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.message, style: const TextStyle(fontFamily: 'PlusJakartaSans')),
            backgroundColor: event.isError ? AppColors.error : AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final authState = ref.watch(authProvider);

    if (authState.isLoading && authState.error == null && _emailController.text.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.12)),
                    child: Image.asset(
                      'assets/logo/logo.jpeg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.sports_soccer, size: 52, color: AppColors.primary)),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'ATHLETES OS',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: 3),
                ),
                const SizedBox(height: 10),
                Text(
                  _modoRegistro ? 'Crea tu cuenta para empezar' : 'Tu sistema operativo personal\nde 90 días',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, color: AppColors.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 40),
                if (authState.error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      authState.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.onErrorContainer, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Correo', hintText: 'tu@correo.com'),
                  validator: (value) {
                    if (value == null || !_emailRegex.hasMatch(value.trim())) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: authState.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          _modoRegistro ? 'CREAR CUENTA' : 'INICIAR SESIÓN',
                          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _modoRegistro = !_modoRegistro),
                  child: Text(
                    _modoRegistro ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Créala',
                    style: const TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.outlineVariant.withOpacity(0.5))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('o', style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.neutralSecondary, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: AppColors.outlineVariant.withOpacity(0.5))),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: authState.isLoading ? null : () => ref.read(authProvider.notifier).loginWithGoogle(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.outlineVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Center(
                          child: Text('G', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Continuar con Google',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

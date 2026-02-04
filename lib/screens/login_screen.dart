import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/main.dart'; // IMPORTANTE: Para acessar o MyApp.setLocale
import 'home_screen.dart';
import 'signup_screen.dart'; // Importante: Garanta que este arquivo existe

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        if (mounted) {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    });
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.vlinix://login-callback',
        scopes: 'https://www.googleapis.com/auth/calendar',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao iniciar Google Login'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro inesperado.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar Transparente para o Seletor de Línguas
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Color(0xFF1E88E5)),
            onSelected: (String langCode) {
              MyApp.setLocale(context, Locale(langCode));
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem(value: 'pt', child: Text('🇧🇷 Português')),
              const PopupMenuItem(value: 'en', child: Text('🇺🇸 English')),
              const PopupMenuItem(value: 'es', child: Text('🇪🇸 Español')),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions_car_filled,
                size: 80,
                color: Color(0xFF1E88E5),
              ),
              const SizedBox(height: 20),
              const Text(
                'VLINIX',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
              const Text(
                'Gestão Automotiva Inteligente',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              if (!_isLoading) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.login, color: Colors.red),
                    label: const Text('Entrar com Google'),
                    onPressed: _googleSignIn,
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text("OU"),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),

              _isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('ENTRAR'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // --- AQUI ESTÁ A MUDANÇA PRINCIPAL ---
                        TextButton(
                          onPressed: () {
                            // Navega para a nova tela de cadastro (SignUpScreen)
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: const Text('Criar conta agora'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

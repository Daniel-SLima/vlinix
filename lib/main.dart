import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'package:vlinix/theme/app_colors.dart'; // Importante: Nosso arquivo de cores

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  await Supabase.initialize(
    url: 'https://hjjsohmziddrlqggaimm.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqanNvaG16aWRkcmxxZ2dhaW1tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwODIwMDMsImV4cCI6MjA4NTY1ODAwM30.3Rb_RDwKmNDhuB_1ViqwQm35WUBaq2_9iLtr-cWsg2Y',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // Função estática para permitir a troca de língua de qualquer tela
  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale; // Se for null, usa o padrão do sistema

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vlinix',
      debugShowCheckedModeBanner: false,

      // --- AQUI ESTÁ A MUDANÇA VISUAL (CSS GLOBAL) ---
      theme: ThemeData(
        useMaterial3: true,

        // 1. Cores Principais
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background, // Fundo gelo padrão
        // 2. Esquema de Cores do Material 3
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: Colors.white,
        ),

        // 3. Estilo da AppBar (Topo)
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary, // Chumbo
          foregroundColor: Colors.white, // Texto/Ícones brancos
          elevation: 0,
          centerTitle: true,
        ),

        // 4. Botões Flutuantes (FAB) - O botão "+"
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent, // Dourado
          foregroundColor: Colors.white,
        ),

        // 5. Botões Elevados (ElevatedButton) - Ex: "Salvar", "Entrar"
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, // Chumbo
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // 6. Estilo dos Inputs (Caixas de Texto) - A Borda Dourada!
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.accent,
              width: 2,
            ), // Borda Dourada ao focar!
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIconColor: AppColors.primary, // Ícones internos na cor chumbo
        ),
      ),

      // ------------------------------------------------
      locale: _locale,

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt'), Locale('en'), Locale('es')],
      home: const LoginScreen(),
    );
  }
}

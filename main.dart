import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'state.dart';
import 'widgets.dart';
import 'screens/landing.dart';
import 'screens/patient_home.dart';
import 'screens/admin_home.dart';

void main() => runApp(ChangeNotifierProvider(
      create: (_) => AuthState()..init(),
      child: const App(),
    ));

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: kTeal, primary: kTeal, secondary: kAmber);
    return MaterialApp(
      title: clinicName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: kSand,
        textTheme: GoogleFonts.manropeTextTheme(),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
      home: Consumer<AuthState>(builder: (_, auth, __) {
        if (auth.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (auth.user == null) return const LandingScreen();
        return auth.isAdmin ? const AdminHome() : const PatientHome();
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/store_list_screen.dart';
import 'services/database_service.dart';
import 'services/license_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database (without sample data)
  await DatabaseService().initializeDatabase();

  // Check license before starting app
  final licenseValid = await LicenseService().checkLicense();

  runApp(StockTakeApp(licenseValid: licenseValid));
}

class StockTakeApp extends StatelessWidget {
  final bool licenseValid;

  const StockTakeApp({super.key, required this.licenseValid});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Take SA',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: licenseValid ? '/login' : '/license-error',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/store-list': (context) => StoreListScreen(), // Remove const
        '/license-error': (context) => const LicenseErrorScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class LicenseErrorScreen extends StatelessWidget {
  const LicenseErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'License Error',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'This account has been deactivated. Please contact support.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  LicenseService().checkLicense().then((valid) {
                    if (valid) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  });
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart'; // 🔔 Bildirim servisi
import 'theme_manager.dart'; // ✅ Tema yöneticisi

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  initializeDateFormatting('tr_TR', null); // 🇹🇷 Türkçe tarih formatı

  // ✅ Tema tercihini yükle
  await ThemeManager.loadThemeMode();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final UserService _userService = UserService();
  final FirebaseNotificationService _notificationService = FirebaseNotificationService();

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _currentUser = user;
      if (user != null) {
        _onUserLogin();
      } else {
        _onUserLogout();
      }
    });
  }

  void _onUserLogin() async {
    await _userService.saveUserToken();
    await _notificationService.connectNotification();
    await _userService.setUserOnline();
    await _userService.clearInactiveUsers();
  }

  void _onUserLogout() async {
    await _userService.setUserOffline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentUser != null) {
      if (state == AppLifecycleState.resumed) {
        _userService.setUserOnline();
      } else if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        _userService.setUserOffline();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeManager.themeMode,
      builder: (context, ThemeMode mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Mockers Chat",
          theme: ThemeData(
            useMaterial3: true,
            primarySwatch: Colors.blue,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            primarySwatch: Colors.blue,
            brightness: Brightness.dark,
          ),
          themeMode: mode,
          initialRoute: '/home',
          routes: {
            '/home': (context) => HomeScreen(),
            '/login': (context) => LoginScreen(),
            // Diğer route'lar eklenebilir
          },
          home: _buildHomeScreen(),
        );
      },
    );
  }

  Widget _buildHomeScreen() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return HomeScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

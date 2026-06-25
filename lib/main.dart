import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/accounting_provider.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/calendar_page.dart';
import 'pages/stats_page.dart';
import 'pages/profile_page.dart';
import 'pages/login_page.dart';
import 'pages/add_transaction_page.dart';
import 'pages/voice_input.dart';
import 'pages/search_page.dart';
import 'models/transaction.dart';

import 'services/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final AuthService _authService = AuthService(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey);
  final SyncService _syncService = SyncService(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountingProvider()..refreshAll()),
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _syncService),
      ],
      child: MaterialApp(
        title: 'L&W',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        locale: const Locale('zh', 'CN'),
        home: const AuthGate(),
        onGenerateRoute: (settings) {
          if (settings.name == '/add') {
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('date')) {
              return MaterialPageRoute(
                builder: (_) => AddTransactionPage(initialDate: args['date'] as DateTime?),
                settings: settings,
              );
            }
            return MaterialPageRoute(
              builder: (_) => const AddTransactionPage(),
              settings: settings,
            );
          }
          if (settings.name == '/edit') {
            final tx = settings.arguments as Transaction;
            return MaterialPageRoute(
              builder: (_) => AddTransactionPage(editTransaction: tx),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }
}

/// 登录判断
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  void _checkAuth() {
    final auth = context.read<AuthService>();
    // 如果已登录，设置 sync 的 auth 信息
    if (auth.isLoggedIn && auth.userId != null && auth.accessToken != null) {
      final sync = context.read<SyncService>();
      sync.setAuth(auth.userId!, auth.accessToken!);
      sync.initialSync();
      sync.startAutoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.status == AuthStatus.uninitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginPage();
    }

    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _authSetupDone = false;

  final List<Widget> _pages = const [
    HomePage(),
    CalendarPage(),
    StatsPage(),
    ProfilePage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_authSetupDone) {
      _authSetupDone = true;
      final auth = context.read<AuthService>();
      if (auth.isLoggedIn && auth.accessToken != null) {
        final sync = context.read<SyncService>();
        sync.setAuth(auth.userId!, auth.accessToken!);
        sync.initialSync();
        sync.startAutoSync();
      }
    }
  }

  void _addVoiceResult(Map<String, dynamic> result) {
    if (!mounted) return;
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    provider.addTransaction(Transaction(
      type: result['type'],
      amount: (result['amount'] as double),
      category: result['category'] as String,
      note: result['note'] as String,
      date: DateTime.now(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记录一笔${result['type'] == 'expense' ? '支出' : '收入'}'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet,
                color: AppTheme.primaryGreen, size: 24),
            const SizedBox(width: 8),
            const Text('L&W'),
          ],
        ),
        actions: [
          Consumer<SyncService>(
            builder: (_, sync, __) {
              if (sync.status == SyncStatus.syncing) {
                return const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.sync),
                tooltip: '手动同步',
                onPressed: () async {
                  await sync.incrementalSync();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(sync.lastSyncTime != null ? '同步完成' : '同步失败'),
                        backgroundColor: sync.lastSyncTime != null ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SearchPage()));
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: _currentIndex <= 1
          ? _currentIndex == 0
              ? SpeechRecordButton(
                  onResult: (result) {
                    if (!mounted) return;
                    _addVoiceResult(result);
                  },
                )
              : FloatingActionButton(
                  onPressed: () {
                    final provider = Provider.of<AccountingProvider>(context, listen: false);
                    Navigator.pushNamed(context, '/add', arguments: {
                      'date': provider.selectedDate,
                    });
                  },
                  child: const Icon(Icons.add),
                )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: '日历'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_emotions_outlined), label: '我的'),
        ],
      ),
    );
  }
}

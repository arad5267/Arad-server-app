import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyVpnApp());
}

class MyVpnApp extends StatelessWidget {
  const MyVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VPN App',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0F16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          surface: Color(0xFF161925),
        ),
      ),
      home: const AuthCheckScreen(),
    );
  }
}

const String remoteJsonUrl =
    "https://gist.githubusercontent.com/arad5267/2ee95e127056159b607ac3f9abac6783/raw/config.json";

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkSavedUser();
  }

  Future<void> _checkSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSub = prefs.getString('user_sub_url');
    final savedUsername = prefs.getString('username');

    if (savedSub != null && savedUsername != null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            username: savedUsername,
            subUrl: savedSub,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'لطفاً نام کاربری و رمز عبور را وارد کنید');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(Uri.parse(remoteJsonUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final users = data['users'] as Map<String, dynamic>?;

        if (users != null && users.containsKey(username)) {
          final userObj = users[username];
          if (userObj['pass'].toString() == password) {
            String subUrl = userObj['sub_url'];

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('username', username);
            await prefs.setString('user_sub_url', subUrl);

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  username: username,
                  subUrl: subUrl,
                ),
              ),
            );
            return;
          }
        }
        setState(() => _errorMessage = 'نام کاربری یا رمز عبور اشتباه است');
      } else {
        setState(() => _errorMessage = 'خطا در دریافت اطلاعات از سرور');
      }
    } catch (e) {
      setState(() => _errorMessage = 'خطای شبکه! اتصال اینترنت را بررسی کنید');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 80, color: Color(0xFF6C5CE7)),
              const SizedBox(height: 16),
              const Text(
                'ورود به حساب کاربری',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'نام کاربری',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFF161925),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'رمز عبور',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFF161925),
                ),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ورود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String username;
  final String subUrl;

  const HomeScreen({super.key, required this.username, required this.subUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  bool isLoading = false;
  List<String> configs = [];
  String activeConfig = "در حال دریافت کانفیگ...";

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
  }

  Future<void> _fetchConfigs() async {
    setState(() => isLoading = true);

    String input = widget.subUrl.trim();

    if (input.startsWith("vless://") ||
        input.startsWith("vmess://") ||
        input.startsWith("ss://") ||
        input.startsWith("trojan://") ||
        input.startsWith("tuic://") ||
        input.startsWith("hysteria2://")) {
      setState(() {
        configs = [input];
        activeConfig = input;
        isLoading = false;
      });
      return;
    }

    try {
      final subResponse = await http.get(Uri.parse(input));
      if (subResponse.statusCode == 200) {
        String rawBody = subResponse.body.trim();
        String decoded = rawBody;

        try {
          decoded = utf8.decode(base64.decode(base64.normalize(rawBody)));
        } catch (_) {}

        List<String> list = decoded.split('\n').where((c) => c.trim().isNotEmpty).toList();

        setState(() {
          configs = list;
          if (configs.isNotEmpty) {
            activeConfig = configs.first;
          } else {
            activeConfig = "هیچ کانفیگی یافت نشد";
          }
        });
      } else {
        setState(() => activeConfig = "خطا در دریافت سابسکریپشن");
      }
    } catch (e) {
      setState(() => activeConfig = "خطا در اتصال به لینک ساب");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void toggleConnection() {
    if (configs.isEmpty || isLoading || activeConfig.contains("خطا") || activeConfig.contains("یافت نشد")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هیچ کانفیگی برای اتصال وجود ندارد!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() {
      isConnected = !isConnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('خوش آمدید، ${widget.username}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_bulleted_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConfigsScreen(
                    configs: configs,
                    onSelect: (selected) {
                      setState(() {
                        activeConfig = selected;
                      });
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161925),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF6C5CE7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isLoading ? "در حال دریافت کانفیگ..." : activeConfig,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: toggleConnection,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? const Color(0xFF00B894) : const Color(0xFFD63031),
                boxShadow: [
                  BoxShadow(
                    color: (isConnected ? const Color(0xFF00B894) : const Color(0xFFD63031)).withOpacity(0.4),
                    blurRadius: 35,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                size: 85,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            isConnected ? 'متصل شد' : 'قطع می‌باشد',
            style: TextStyle(
              color: isConnected ? const Color(0xFF00B894) : Colors.white54,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ConfigsScreen extends StatelessWidget {
  final List<String> configs;
  final Function(String) onSelect;

  const ConfigsScreen({super.key, required this.configs, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لیست کانفیگ‌ها'),
        backgroundColor: Colors.transparent,
      ),
      body: configs.isEmpty
          ? const Center(child: Text("کانفیگی دریافت نشد"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: configs.length,
              itemBuilder: (context, index) {
                return Card(
                  color: const Color(0xFF161925),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key_outlined, color: Color(0xFF6C5CE7)),
                    title: Text(
                      configs[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      onSelect(configs[index]);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
    );
  }
}

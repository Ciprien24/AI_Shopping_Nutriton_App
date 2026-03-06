import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smart_cart/core/local_auth_store.dart';
import 'package:smart_cart/features/auth/registration_screen.dart';
import 'package:smart_cart/features/carts/carts_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _pageBackground = Color(0xFFF4F5F9);
  static const Color _headerBlue = Color(0xFF1800AD);
  static const Color _accentOrange = Color(0xFFFF751F);
  static const Color _textDark = Color(0xFF141414);
  static const Color _textMuted = Color(0xFF74788C);

  final LocalAuthStore _authStore = LocalAuthStore();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter email and password.');
      return;
    }

    setState(() => _isLoading = true);
    final saved = await _authStore.loadCredentials();
    if (!mounted) return;

    if (saved == null) {
      setState(() => _isLoading = false);
      _showMessage('No account found. Create one first.');
      return;
    }

    if (saved.email == email && saved.password == password) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CartsScreen()),
      );
      return;
    }

    setState(() => _isLoading = false);
    _showMessage('Invalid email or password.');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFFFFE2CF), width: 1),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double topInset) {
    return Container(
      height: 150 + topInset,
      padding: EdgeInsets.fromLTRB(24, topInset + 2, 24, 0),
      decoration: const BoxDecoration(color: _headerBlue),
      child: Align(
        alignment: const Alignment(0, -0.45),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Image.asset(
                'lib/app/assets/logo_smart_cart.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  CupertinoIcons.shopping_cart,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'SmartCart',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _textDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  InputDecoration get _inputDecoration => InputDecoration(
    filled: true,
    fillColor: const Color(0xFFF2F3F8),
    border: OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.circular(14),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  Future<void> _goToRegister() async {
    final registeredEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegistrationScreen()),
    );
    if (!mounted || registeredEmail == null) return;
    _emailController.text = registeredEmail;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _pageBackground,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(color: _pageBackground),
          _buildHeader(topInset),
          Positioned(
            top: 110 + topInset,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _inputCard(
                      title: 'Email',
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _inputCard(
                      title: 'Password',
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _inputDecoration,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: _goToRegister,
                        child: const Text(
                          'No account? Create one',
                          style: TextStyle(
                            color: _textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _actionBubble(
                  icon: CupertinoIcons.person_add,
                  onTap: _goToRegister,
                ),
                _actionBubble(
                  icon: CupertinoIcons.check_mark,
                  onTap: _isLoading ? null : _login,
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBubble({
    required IconData icon,
    required VoidCallback? onTap,
    Widget? child,
  }) {
    return Container(
      width: 68,
      height: 68,
      decoration: const BoxDecoration(color: _accentOrange, shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: child ?? Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

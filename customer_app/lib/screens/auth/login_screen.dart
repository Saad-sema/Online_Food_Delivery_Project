import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final err = await context.read<AuthProvider>().login(_emailC.text.trim(), _passC.text);
    setState(() => _loading = false);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B35), Color(0xFFFF8F65), Color(0xFFFFF3E0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, spreadRadius: 5)],
                      ),
                      child: const Icon(Icons.fastfood_rounded, size: 56, color: Color(0xFFFF6B35)),
                    ),
                    const SizedBox(height: 20),
                    Text('FoodDash', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Delicious food, delivered fast', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 40),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Welcome Back', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Sign in to continue', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailC,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration('Email', Icons.email_outlined),
                              validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passC,
                              obscureText: _obscure,
                              decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6B35),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: _loading
                                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ", style: TextStyle(color: Colors.white70)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: const Text('Sign Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFFF6B35)),
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.5)),
    );
  }
}

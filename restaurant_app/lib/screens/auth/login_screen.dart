import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFFD1FAE5)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30)]),
                  child: const Icon(Icons.restaurant_rounded, size: 56, color: Color(0xFF059669)),
                ),
                const SizedBox(height: 20),
                const Text('FoodDash Restaurant', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                const Text('Manage your restaurant', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))]),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Sign In', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailC,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec('Email', Icons.email_outlined),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passC,
                        obscureText: _obscure,
                        decoration: _dec('Password', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setState(() => _obscure = !_obscure)),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                          child: _loading
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text(
                    'Don\'t have an account? Sign Up',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF059669)),
    filled: true, fillColor: const Color(0xFFF8F9FA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final err = await context.read<AuthProvider>().register({
      'name': _nameC.text.trim(),
      'phone': _phoneC.text.trim(),
      'email': _emailC.text.trim(),
      'password': _passC.text,
      'role': 'customer',
    });
    setState(() => _loading = false);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.person_add_rounded, size: 48, color: Color(0xFFFF6B35)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Create Account', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 30),
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
                          _field(_nameC, 'Full Name', Icons.person_outline, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                          const SizedBox(height: 14),
                          _field(_phoneC, 'Phone', Icons.phone_outlined, keyboard: TextInputType.phone, validator: (v) => (v == null || v.length < 10) ? 'Enter valid phone' : null),
                          const SizedBox(height: 14),
                          _field(_emailC, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null),
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
                              onPressed: _loading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? ', style: TextStyle(color: Colors.white70)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
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
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboard, String? Function(String?)? validator}) {
    return TextFormField(controller: c, keyboardType: keyboard, decoration: _dec(label, icon), validator: validator);
  }

  InputDecoration _dec(String label, IconData icon) {
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

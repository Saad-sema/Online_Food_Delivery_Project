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
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _passC = TextEditingController();
  
  bool _loading = false;
  bool _obscure = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    final data = {
      'name': _nameC.text.trim(),
      'email': _emailC.text.trim(),
      'phone': _phoneC.text.trim(),
      'password': _passC.text,
      'role': 'delivery_boy',
    };
    
    final err = await context.read<AuthProvider>().register(data);
    
    if (!mounted) return;
    setState(() => _loading = false);
    
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [Color(0xFF4F46E5), Color(0xFF818CF8), Color(0xFFEEF2FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, size: 40, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Partner with Us',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text(
                    'Become a delivery hero',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Your Profile',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          _buildField(_nameC, 'Full Name', Icons.person_outline),
                          const SizedBox(height: 12),
                          _buildField(_emailC, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _buildField(_phoneC, 'Phone Number', Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passC,
                            obscureText: _obscure,
                            decoration: _dec('Password', Icons.lock_outline).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Already have an account? Sign In',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _dec(label, icon),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
      );
}

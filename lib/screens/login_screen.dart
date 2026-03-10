import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboards/hospital_dashboard.dart';
import 'dashboards/distributor_dashboard.dart';
import 'dashboards/transport_dashboard.dart';
import 'dashboards/lab_dashboard.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'Hospital';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4F80FF), Color(0xFF3CD3C1)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
                    Row(
                      children: const [
                        Icon(Icons.local_hospital, color: Colors.white, size: 34),
                        SizedBox(width: 12),
                        Text(
                          'Healthcare Logistics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 42),
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue to your dashboard',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 30),

                    // Role selector (for quick access and clarity)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoleButton(
                          label: 'Hospital',
                          selected: selectedRole == 'Hospital',
                          onTap: () => setState(() => selectedRole = 'Hospital'),
                        ),
                        _RoleButton(
                          label: 'Distributor',
                          selected: selectedRole == 'Distributor',
                          onTap: () => setState(() => selectedRole = 'Distributor'),
                        ),
                        _RoleButton(
                          label: 'Transport',
                          selected: selectedRole == 'Transport',
                          onTap: () => setState(() => selectedRole = 'Transport'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: "Email",
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            decoration: const InputDecoration(
                              labelText: "Password",
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  final userCredential =
                                      await FirebaseAuth.instance
                                          .signInWithEmailAndPassword(
                                    email: emailController.text.trim(),
                                    password: passwordController.text.trim(),
                                  );

                                  final userData = await FirebaseFirestore.instance
                                      .collection("users")
                                      .doc(userCredential.user!.uid)
                                      .get();

                                  final role = userData["role"] as String? ?? '';

                                  if (role != selectedRole) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'You are registered as $role. Please select the correct role.'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (role == "Hospital") {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const HospitalDashboard()),
                                    );
                                  } else if (role == "Distributor") {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const DistributorDashboard()),
                                    );
                                  } else if (role == "Transport") {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const TransportDashboard()),
                                    );
                                  } else if (role == "Lab") {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const LabDashboard()),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Login failed: $e')),
                                  );
                                }
                              },
                              child: const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Securely manage medicine, transport & delivery in one app.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Version 1.0',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.white : Colors.white54,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.indigo : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

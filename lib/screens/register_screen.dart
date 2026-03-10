import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = "Hospital";

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            DropdownButtonFormField(
              value: selectedRole,
              items: const [
                DropdownMenuItem(value: "Hospital", child: Text("Hospital")),
                DropdownMenuItem(value: "Distributor", child: Text("Distributor")),
                DropdownMenuItem(value: "Transport", child: Text("Transport Provider")),
                DropdownMenuItem(value: "Lab", child: Text("Laboratory")),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value!;
                });
              },
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  UserCredential userCredential =
                      await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );

                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(userCredential.user!.uid)
                      .set({
                    "name": nameController.text.trim(),
                    "email": emailController.text.trim(),
                    "role": selectedRole,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Account created successfully")),
                  );

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}
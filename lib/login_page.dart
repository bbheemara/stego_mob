import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLogin = true;
  String? errorMessage;
  bool isLoading = false;

  Future<void> submit() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (emailController.text.isEmpty || passwordController.text.isEmpty) {
        setState(() {
          errorMessage = 'Please enter both email and password';
          isLoading = false;
        });
        return;
      }
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential') {
        setState(() {
          errorMessage = 'Incorrect email or password!! or Register yourself';
        });
      } else if (e.code == 'invalid-email') {
        setState(() {
          errorMessage = 'Please enter a valid email address';
        });
      } else {
        setState(() {
          errorMessage = e.message;
        });
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome to Stego Mob'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLogin ? 'Login' : 'Register',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color.fromARGB(255, 204, 204, 204),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (errorMessage != null)
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  135,
                                  255,
                                  169,
                                ),
                              ),
                              onPressed: submit,
                              child: Text(isLogin ? 'Login' : 'Register'),
                            ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isLogin = !isLogin;
                          });
                        },
                        child: Text(
                          style: TextStyle(color: Colors.black),

                          isLogin
                              ? "Don't have an account? Register"
                              : 'Already have an account? Login',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

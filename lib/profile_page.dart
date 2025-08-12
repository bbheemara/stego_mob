import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;

  Future<int> getUsagecount() async {
    if (user == null) return 0;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('usageCount')) {
          final count = data['usageCount'];
          if (count is int) return count;
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching usageCount: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Center(child: const Text('Profile'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email: ${user?.email ?? 'No email'}',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Password:XXXXXXXXXX',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color.fromARGB(255, 12, 12, 12),
                      ),
                    ),
                    SizedBox(height: 10),
                    FutureBuilder<int>(
                      future: getUsagecount(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return const Text('Error loading usage count');
                        } else {
                          return Text(
                            'Stego Count: ${snapshot.data}',
                            style: const TextStyle(fontSize: 16),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UpdatePasswordPage()),
                  );
                },
                child: Text('Update Password'),
              ),

              SizedBox(height: 14),

              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: Text('Logout', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdatePasswordPage extends StatefulWidget {
  const UpdatePasswordPage({super.key});

  @override
  State<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends State<UpdatePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception("No logged-in user.");
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPassController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(_newPassController.text.trim());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Password updated successfully!")));

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Update Password")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage != null)
                Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              TextFormField(
                controller: _currentPassController,
                obscureText: true,
                decoration: InputDecoration(labelText: "Current Password"),
                validator: (value) =>
                    value!.isEmpty ? "Enter current password" : null,
              ),
              TextFormField(
                controller: _newPassController,
                obscureText: true,
                decoration: InputDecoration(labelText: "New Password"),
                validator: (value) =>
                    value!.length < 6 ? "At least 6 characters" : null,
              ),
              SizedBox(height: 20),
              _loading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _updatePassword,
                      child: Text("Update Password"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

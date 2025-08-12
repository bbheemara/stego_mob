import 'package:flutter/material.dart';
import 'package:stego_mob/embed_page.dart';
import 'package:stego_mob/extract_page.dart';
import 'package:stego_mob/main.dart';
import 'package:stego_mob/profile_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Stego Mob',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
          ),
          centerTitle: true,
          backgroundColor: const Color.fromARGB(255, 203, 255, 198),
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
            icon: const Icon(Icons.settings),
            onPressed: (){
              Navigator.push(context, 
              MaterialPageRoute(builder: (_)=> const settingsPage())
              );
            },
            )
          ],



          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Color.fromARGB(255, 154, 160, 150),
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Embed Data'),
              Tab(text: 'Extract Data'),
              Tab(text: 'My profile'),
            ],
          ),
        ),
        body: const TabBarView(
          children:
           [
            EmbedPage(),
           ExtractPage(),
            ProfilePage()
            ],
            ),
      ),
    );
  }
}

class settingsPage extends StatefulWidget {
  const settingsPage({super.key});

  @override
  State<settingsPage> createState() => _settingsPageState();
}

class _settingsPageState extends State<settingsPage> {
  bool? isDark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isDark == null) {
      final appState = MyApp.of(context);
      setState(() {
        isDark = appState?.themeMode  == ThemeMode.dark;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context);

    if (isDark == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Stego Mob Settings',
                style: TextStyle(fontSize: 25),
              ),
            ),
            const SizedBox(height: 20),
            
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dark Mode',
                  style: TextStyle(fontSize: 18),
                ),
                Switch(
                  value: isDark!,
                  onChanged: (val) {
                    setState(() {
                      isDark = val;
                      appState?.toggleTheme(val);
                    });
                  },
                ),
              ],

            ), 
            SizedBox(height: 20,),
            
            Center(
              child: const Text(
                'App Version: 1.0.1',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

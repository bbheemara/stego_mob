import 'package:flutter/material.dart';
import 'package:stego_mob/home_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_mgr.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}
 
class MyApp extends StatefulWidget {
  const MyApp({super.key});



  @override
  State<MyApp> createState()=> _MyAppState();

  static _MyAppState ? of(BuildContext context) => 
         context.findAncestorStateOfType<_MyAppState>();

}


class _MyAppState extends State<MyApp>{


      ThemeMode _themeMode= ThemeMode.light;

      ThemeMode get themeMode => _themeMode;

      void toggleTheme(bool isDark){
        setState(() {
          _themeMode = isDark? ThemeMode.dark :ThemeMode.light;
        });
      }


 
  
  @override 
  Widget build(BuildContext context) {
    return MaterialApp(        
      title: 'Stego',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'stego',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(104, 255, 104, 1),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'stego',
        colorScheme: ColorScheme.fromSeed(seedColor:Colors.greenAccent,
        brightness: Brightness.dark )
      ),
      home: const LoginMgr(),
    );
  }

}
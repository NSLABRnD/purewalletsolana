// ignore_for_file: prefer_const_constructors
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pure_wallet_2/pages/hompage.dart';
import 'package:pure_wallet_2/static/init_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'static/scaled_size_custom.dart';

Future<void> main() async {
  await initializeApp();
  // Run the app with the initial locale
  // SharedPreferences prefs = await SharedPreferences.getInstance();
  runApp(MyApp());
}

Future<void> initializeApp() async {
  // Set up the global client
  web3Client.setClient();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // _router = router;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScaledSizeCustom.setInitMediaQuerySize(context);
    return MaterialApp(
      home: HomePage()
    );
  }
}

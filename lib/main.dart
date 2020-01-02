import 'package:flutter/material.dart';

import 'support.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: CS.title,
      theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto'
      ),
      home: Pages.splash,
    );
  }
}


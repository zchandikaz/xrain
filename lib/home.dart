import 'package:flutter/material.dart';
import 'dart:io';

import 'support.dart';

class HomePage extends StatefulWidget {


  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  homeButton({icon, text, onPressed})=>RaisedButton(
    onPressed: onPressed,
    color: CS.bgColor1,
    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(15),
          child: Icon(icon, color: CS.fgColor1, size: 45,),
        ),
        Text(text.toUpperCase(), style: TextStyle(color: CS.fgColor1, letterSpacing: 2, fontSize: 18),)
      ],
    ),
  );

  void _send(context){
    CA.pickFile().then((File file){
      CA.navigate(context, Pages.send(file));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              new Image(
                image: AssetImage('assets/images/logo.png'),
                width: 170,
                height: 170,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text("Synchronize using internet"),
                  Switch(
                    value: CS.isSynchronousTransmission,
                    onChanged: (value) {
                      setState(() {
                        CS.isSynchronousTransmission = value;
                      });
                    },
                    activeTrackColor: Colors.lightBlue[100],
                    activeColor: Colors.blue,
                  )
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  homeButton(text: "Send", icon: Icons.send, onPressed: ()=>_send(context) ),
                  homeButton(text: "Receive", icon: Icons.save_alt , onPressed: ()=>CA.navigate(context, Pages.scan)), //archive
                ],
              )
            ],
          ),
        )
    );
  }
}
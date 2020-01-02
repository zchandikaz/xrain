import 'package:flutter/material.dart';

import 'support.dart';

class LoginPage extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: new Container(
//          decoration: BoxDecoration(
//            image: DecorationImage(
//              image: AssetImage("assets/images/back1.jpg"),
//              fit: BoxFit.cover,
//            ),
//          ),
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Image(
                  image: AssetImage('assets/images/logo.png'),
                  width: 130,
                  height: 130,
                ),
                new Padding(padding: EdgeInsets.all(15.0)),
                new Text(
                  "Journey Mate".toUpperCase(),
                  style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      shadows: [new Shadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: Offset(0, 0), // changes position of shadow
                      )],
                      letterSpacing: 1
                  ),
                ),
                new Padding(padding: EdgeInsets.all(40.0)),
                new RaisedButton(
                  onPressed: () => SignInSupport.signIn().
                  then((var user){
                      CA.navigateWithoutBack(context, Pages.home);
                    })
                    .catchError((e)=>print(e)),

                  padding: EdgeInsets.only(top: 3.0,bottom: 3.0,left: 3.0),
                  color: const Color(0xFF4285F4),

                  child: new Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      new Container(
                        padding: EdgeInsets.all(7),
                        color: Colors.white,
                        child: new Image.asset(
                          'assets/images/google.png',
                          height: 35.0,
                        ),
                      ),
                      new Container(
                          padding: EdgeInsets.only(left: 20.0,right: 23.0),
                          child: new Text("Sign in with Google",style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                          )
                      ),
                    ],
                  )
                )
              ],
            ),
          ),
        )
    );
  }
}

class SplashPage extends StatefulWidget {
  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    SignInSupport.getCurrentUser().then((var user){
      if(user==null)
        CA.navigateWithoutBack(context, Pages.login);
      else
        CA.navigateWithoutBack(context, Pages.home);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: new Container(
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:barcode_scan/barcode_scan.dart';

import 'support.dart';

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String result = "Hi";

  Future _scanQR() async{
    try{
      String qrResult = await BarcodeScanner.scan();
      setState(() {
        result = qrResult;
        _scanQR();
      });
    }on PlatformException catch(ex){
      if(ex.code==BarcodeScanner.CameraAccessDenied){
        CA.alert(context, "Camera permission was denied");
      } else {
        CA.alert(context, "Unknown Error $ex");
      }
    } on FormatException {
      CA.alert(context, "You pressed the back button before scanning anything");
    } catch (ex){
      CA.alert(context, "Unknown Error $ex");
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(CS.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(result),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(Icons.camera_alt),
        label: Text("Scan"),
        onPressed: _scanQR,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

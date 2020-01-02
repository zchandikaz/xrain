import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:firebase_database/firebase_database.dart';

import 'support.dart';

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String result = "Hi";

  Future scanQR() async{
    try{
      String qrResult = await BarcodeScanner.scan();
      return qrResult;
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

  void pairDevice(@deprecated void onConnected(String syncTempId, int bulkSize)) async {
    String syncTempId = await scanQR();
    var initStatusRef = dbRef.child('sync_tmp').child(syncTempId).child('init_status');

    dbRef.child('sync_tmp').child(syncTempId).once().then((DataSnapshot snapshot) {
      if(snapshot.value==null) return;

      var status = snapshot.value["init_status"];
      if(status==0) {
        initStatusRef.set(1);
        onConnected(syncTempId, snapshot.value["bulk_size"]);
      }
    });
  }

  receiveBulk(String syncTempId, String str, int bulkSize) async {
    var sendStatusRef = dbRef.child('sync_tmp').child(syncTempId).child('send_status');
    String qrData = await scanQR();
    print(qrData);
    //ti:verify data
    sendStatusRef.once().then((DataSnapshot snapshot) {
      var status = snapshot.value;
      if(status>=0) {
        sendStatusRef.set(status + 0.5);
        receiveBulk(syncTempId, str + qrData, bulkSize);
      }else if(status==-1){
        storeReceivedFile(str);
      }
    });
  }

  void storeReceivedFile(String str){
    print("Full File: $str");
  }

  void receiveFile() async {
    pairDevice((String syncTempId, int bulkSize){
      receiveBulk(syncTempId, "", bulkSize);
    });
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
        onPressed: receiveFile,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

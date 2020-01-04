import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';

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

    try {
      dbRef.child('sync_tmp').child(syncTempId).once().then((
          DataSnapshot snapshot) {
        if (snapshot.value == null) return;

        var status = snapshot.value["init_status"];
        CA.log("scan pairing - $status");
        if (status == 0) {
          initStatusRef.set(1);

          onConnected(syncTempId, snapshot.value["bulk_size"]);
        }
      });
    }catch (e){
      CA.log("ERROR: ${e.toString()}");
    }
  }

  String unwrap(String str){
    CA.log(str);
    RegExp exp = new RegExp(r"☺(.*)☺");
    List<Match> matches = exp.allMatches(str).toList();
    if(matches.length==1){
      var s = matches[0].group(0);
      return s.substring(1,s.length-1);
    }else{
      throw Exception("Format mismatch of data bulk");
    }
  }

  receiveBulk(String syncTempId, String str, int bulkCount, int bulkSize) async {
    var sendStatusRef = dbRef.child('sync_tmp').child(syncTempId).child('send_status');

    sendStatusRef.once().then((DataSnapshot snapshot) async {
      var status = snapshot.value??0;
      CA.log("receive bulk| $bulkCount, $status");
      if(status==bulkCount+1) {
        String qrData = await scanQR();
        sendStatusRef.set(status + 0.5);
        try {
          receiveBulk(
              syncTempId, str + unwrap(qrData), bulkCount + 1, bulkSize);
        }catch(e){
          sendStatusRef.set(-2);
          CA.log("ERROR: ${e.toString()}");
          return;
        }
      }else if(status==-1){
        storeReceivedFile(str);
      }else if(status==-2){
        CA.alert(context, "Sharing Aborted!");
        return;
      }
    });
  }

  Uint8List decodeData(String data){
     Uint8List.fromList(CA.splitByLength(data, 2).map((String h){
      if(h[0]=='0')
        h = h[1];
      return int.parse(h, radix: 16);
    }));
  }

  void storeReceivedFile(String str) async {
    var d = str.split("☻▬☻");
    String fileName =  d[0];
    Uint8List fileData = decodeData(d[1]);
    Directory dir = await getExternalStorageDirectory();
    writeToFile(fileData, dir.path + "/xrain/" + fileName);
  }

  Future<void> writeToFile(Uint8List data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  void receiveFile() async {
    pairDevice((String syncTempId, int bulkSize){
      receiveBulk(syncTempId, "", -1, bulkSize);
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

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

  String syncTempId;
  int bulkSize, bulkCount;
  String receivedStr = "";
  DatabaseReference sendStatusRef;
  String result = "wait";

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

  void pairDevice(@deprecated void onConnected()) async {
    syncTempId = await scanQR();
    var initStatusRef = dbRef.child('sync_tmp').child(syncTempId).child('init_status');
    sendStatusRef = dbRef.child('sync_tmp').child(syncTempId).child('send_status');

    var sRef = dbRef.child('sync_tmp').child(syncTempId);
    sRef.once().then((
      DataSnapshot snapshot) {
      if (snapshot.value == null) return;

      var status = snapshot.value["init_status"];
      CA.log("scan pairing - $status");
      if (status == 0) {
        initStatusRef.set(1);

        bulkSize = snapshot.value["bulk_size"];
        onConnected();
      }
    });
  }

  String unwrap(String str){
    RegExp exp = new RegExp(r"☺(.*)☺");
    List<Match> matches = exp.allMatches(str).toList();
    if(matches.length==1){
      var s = matches[0].group(0);
      CA.log(s.substring(1,s.length-1));
      return s.substring(1,s.length-1);
    }else{
      throw Exception("Format mismatch of data bulk");
    }
  }

  onReceiveStatusChanged(v){
    sendStatusRef.once().then((DataSnapshot snapshot) async {
      var status = snapshot.value;
      if(status==null) return;
      status = double.parse(status.toString());
      if(status-status.toInt()>0) return;
      status = status.toInt();
      CA.log("receive bulk| $bulkCount, $status");
      if(status==bulkCount+1) {
        String qrData = await scanQR();
        sendStatusRef.set(status + 0.5);
        CA.log("status changed by 0.5");
        try {
          bulkCount++;
          receivedStr += unwrap(qrData);
          CA.log(receivedStr);
        }catch(e){
          CA.log("ERROR: ${e.toString()}");
          sendStatusRef.set(-2);
          return;
        }
      }else if(status==-1){
        CA.log("stored");
        storeReceivedFile();
      }else if(status==-2){
        CA.alert(context, "Sharing Aborted!");
        return;
      }
    });
  }

  Uint8List decodeData(String data){
    List<int> intList = CA.splitByLength(data, 2).map((String h){
      if(h[0]=='0')
        h = h[1];
      return int.parse(h, radix: 16);
    }).toList();
    //return new Uint8List(0);
    return Uint8List.fromList(intList);
  }

  void storeReceivedFile() async {
    var d = receivedStr.split("☻▬☻");
    String fileName =  d[0];
    Uint8List fileData = decodeData(d[1]);
    Directory dir = await getExternalStorageDirectory();

//    SecurityContext clientContext = new SecurityContext()
//        ..setTrustedCertificates(dir.path + "/xrain");
//    var client = new HttpClient(context: clientContext);

    CA.log(dir.path +"/"+ fileName);
    writeToFile(fileData, dir.path + "/" + fileName).then((v){
      CA.navigateWithoutBack(context, Pages.home);
    });
  }

  Future<void> writeToFile(Uint8List data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  void beginReceiveFile() async {
    pairDevice((){
      receivedStr = "";
      bulkCount = -1;
      sendStatusRef.onValue.listen(onReceiveStatusChanged);
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
        onPressed: beginReceiveFile,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

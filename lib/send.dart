import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:path/path.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

import 'support.dart';


class SendPage extends StatefulWidget {
  final File file;

  SendPage(this.file);

  @override
  _SendPageState createState() => _SendPageState(file);
}

class _SendPageState extends State<SendPage>{
  final File file;
  String notifyText = "Please wait";
  String qrData = "";
  static const int BULK_SIZE = 1000;

  _SendPageState(this.file);

  Future<Uint8List> readFile() async {
    try {
      return await file.readAsBytes();
    } catch (e) {
      setState(() {
        notifyText = "Error occured while reading the file ${file.path}.";
      });
      return null;
    }
  }

  void pairDevice(@deprecated void onConnected(String syncTempId, int bulkSize)){
    DateTime now = DateTime.now();
    var syncTempId = SignInSupport.currentUser.uid + '${now.year}${now.month}${now.day}${now.hour}${now.minute}${now.second}';
    var initStatusRef = dbRef.child('sync_tmp').child(syncTempId).child('init_status');
    initStatusRef.set(0);
    dbRef.child('sync_tmp').child(syncTempId).child('bulk_size').set(BULK_SIZE);

    setState(() {
      qrData = syncTempId;
    });

    initStatusRef.onValue.listen((v){
      dbRef.child('sync_tmp').child(syncTempId).once().then((DataSnapshot snapshot) {
        if(snapshot.value==null) return;
        var status = snapshot.value["init_status"];
        if(status==1) {
          onConnected(syncTempId, snapshot.value["bulk_size"]);
        }
      });
    });
  }

  /*
  SEND STATUS

  0 - start
  {n|n>0, n is int} - bulk count(sent)
  {n+0.5|n>0, n is int} - bulk count(received)
  -1  - finished
  -2  - error
   */

  String wrapBulk(bulk){
    return "☺$bulk☺";
  }

  sendBulk(String syncTempId, String str, int bulkSize, int bulkCount){
    var sendStatusRef = dbRef.child('sync_tmp').child(syncTempId).child('send_status');

    String sendStr;
    if(bulkCount*bulkSize>=str.length) {
      sendStatusRef.set(-1);
      //goto home
      return;
    }

    sendStatusRef.set(bulkCount);

    if(bulkCount*bulkSize+bulkSize>=str.length){
      sendStr = str.substring(bulkCount*bulkSize,str.length-bulkCount*bulkSize);
      print("last");
    }else{
      sendStr = str.substring(bulkCount*bulkSize,bulkCount*bulkSize+bulkSize);
      print("inner");
    }

    sendStr = wrapBulk(sendStr);

    setState(() {
      print("send str $bulkCount $bulkSize $sendStr");
      qrData = sendStr;
    });

    sendStatusRef.onValue.listen((v){
      sendStatusRef.once().then((DataSnapshot snapshot) {
        var status = snapshot.value;
        CA.log("send status changed - $status");
        if(status==bulkCount+0.5) {
          sendBulk(syncTempId, wrapBulk(str), bulkSize, bulkCount+1);
        }else if(status==-2){
          CA.log("Transmision aborted.Please try again.");
          return;
        }
      });
    });
  }

  String encodeData(Uint8List data){
    return basename(file.path) + "☻▬☻" + data.toList().map((v){
      var h = v.toRadixString(16).toString();
      h += h.length==1?"0":"";
      return h;
    }).toList().join();
  }

  sendFile(Uint8List fileData) async {
    String str = encodeData(fileData);

    pairDevice((String syncTempId, int bulkSize){
      sendBulk(syncTempId, str, bulkSize, 0);
    });
  }

  @override
  void initState() {
    super.initState();

    readFile().then((Uint8List fileData){
      setState(() {
        if(fileData!=null){
          notifyText = "";
          sendFile(fileData);
        }
      });
    });
  }

  str(n){
    String s = "";
    for(int i=0;i<n;i++)
      s += '${i%10}';
    return s;
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(CS.title),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(notifyText),
            QrImage(
              data: qrData,
              version: QrVersions.auto,
              size: CA.getScreenWidth(context)-10,
            )
          ],
        ),
      )
    );
  }
}

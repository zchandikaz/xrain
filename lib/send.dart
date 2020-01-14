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
  static const int BULK_SIZE = 1100;

  int bulkSize;
  int bulkCount;
  int totalBulkCount;
  int asynchronousInterval;
  DatabaseReference sendStatusRef;
  var syncTempId;
  String fullStr;

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

  void pairDevice(@deprecated void onConnected()){
    bool paired = false;

    DateTime now = DateTime.now();
    syncTempId = SignInSupport.currentUser.uid + '${now.year}${now.month}${now.day}${now.hour}${now.minute}${now.second}';
    var initStatusRef = dbRef.child('sync_tmp').child(syncTempId).child('init_status');
    sendStatusRef = dbRef.child('sync_tmp').child(syncTempId).child('send_status');
    initStatusRef.set(0);
    dbRef.child('sync_tmp').child(syncTempId).child('bulk_size').set(BULK_SIZE);
    dbRef.child('sync_tmp').child(syncTempId).child('total_bulk_count').set(fullStr.length/BULK_SIZE);

    setState(() {
      qrData = syncTempId;
    });

    initStatusRef.onValue.listen((v){
      dbRef.child('sync_tmp').child(syncTempId).once().then((DataSnapshot snapshot) {
        if(snapshot.value==null) return;
        var status = snapshot.value["init_status"];
        if(status==1 && paired==false) {
          paired = true;

          bulkSize = snapshot.value["bulk_size"];
          sendStatusRef.onValue.listen(onSendStatusChanged);
          onConnected();
        }
      });
    });
  }

  onSendStatusChanged(v){
    sendStatusRef.once().then((DataSnapshot snapshot) {
      var status = snapshot.value;
      CA.log("send status changed - $status");
      if(status==bulkCount+0.5) {
        bulkCount++;
        sendBulk();
      } else if(status==-1){
        CA.navigateWithoutBack(this.context, Pages.home);
      }else if(status==-2){
        CA.log("Transmision aborted.Please try again.");
        CA.navigateWithoutBack(this.context, Pages.home);
      }
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

  sendBulk(){
    String sendStr;
    if(bulkCount*bulkSize>=fullStr.length) {
      sendStatusRef.set(-1);
      //goto home
      return;
    }

    sendStatusRef.set(bulkCount);

    CA.log("$bulkSize, $bulkCount, ${fullStr.length}");
    if(bulkCount*bulkSize+bulkSize>=fullStr.length){
      sendStr = fullStr.substring(bulkCount*bulkSize,fullStr.length);
      print("last");
    }else{
      sendStr = fullStr.substring(bulkCount*bulkSize,bulkCount*bulkSize+bulkSize);
      print("inner");
    }

    sendStr = wrapBulk(sendStr);

    setState(() {
      print("send str $bulkCount $bulkSize $sendStr");
      qrData = sendStr;
    });

  }
  String encodeData(Uint8List data){
    return basename(file.path) + "☻▬☻" + data.toList().map((v){ //ALT+258
      var h = v.toRadixString(16).toString();
      h = h.length==1?"0$h":h;
      return h;
    }).toList().join();
  }

  beginSendFile(Uint8List fileData) async {
    fullStr = encodeData(fileData);
    bulkCount = 0;
    if(CS.isSynchronousTransmission) {
      pairDevice(() {
        sendBulk();
      });
    }else{
      bulkSize = BULK_SIZE~/3;
      totalBulkCount = (fullStr.length~/bulkSize) + (fullStr.length%bulkSize!=0?1:0);
      asynchronousInterval = CS.asynchronousInterval;
      initializeAsynchronousTransmission();
      Future.delayed(Duration(milliseconds: asynchronousInterval), () {
        sendBulkAsync();
      });
    }
  }

  void sendBulkAsync(){
    String sendStr;
    if(bulkCount*bulkSize>=fullStr.length) {
      CA.navigateWithoutBack(this.context, Pages.home);
      return;
    }

    CA.log("$bulkSize, $bulkCount, ${fullStr.length}");
    if(bulkCount*bulkSize+bulkSize>=fullStr.length){
      sendStr = fullStr.substring(bulkCount*bulkSize,fullStr.length);
      print("last");
    }else{
      sendStr = fullStr.substring(bulkCount*bulkSize,bulkCount*bulkSize+bulkSize);
      print("inner");
    }

    sendStr = wrapBulk("$bulkCount♫"+sendStr); //ALT+14

    setState(() {
      print("send str $bulkCount $bulkSize $sendStr");
      qrData = sendStr;
    });

    Future.delayed(Duration(milliseconds: asynchronousInterval), () {
      bulkCount++;
      sendBulkAsync();
    });
  }

  void initializeAsynchronousTransmission(){
    setState(() {
      qrData = "INIT_ASYNC_TRANS,$bulkSize,$totalBulkCount,${CS.asynchronousInterval}";
      CA.logi(0.1, qrData);
    });
  }

  @override
  void initState() {
    super.initState();

    readFile().then((Uint8List fileData){
      setState(() {
        if(fileData!=null){
          notifyText = "";
          beginSendFile(fileData);
        }
      });
    });
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import 'support.dart';

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {

  String syncTempId;

  int bulkSize;
  int bulkCount;
  int totalBulkCount;
  int asynchronousInterval = CS.asynchronousInterval;

  String receivedStr = "";
  DatabaseReference sendStatusRef;
  String result = "wait";
  bool paired = false;

  Future scanQR() async{
    try{
      String qrResult = await BarcodeScanner.scan();
      return qrResult;
    }on PlatformException catch(ex){
      CA.logi('ERR', ex.toString());
      if(ex.code==BarcodeScanner.CameraAccessDenied){
        CA.alert(context, "Camera permission was denied");
      } else {
        CA.alert(context, "Unknown Error $ex");
      }
    } on FormatException {
      CA.alert(context, "You pressed the back button before scanning anything", onPressed: (){
        CA.navigateWithoutBack(context, Pages.home);
      });
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
        paired = true;
        bulkSize = snapshot.value["bulk_size"];
        double _totalBulkCount = snapshot.value["total_bulk_count"];
        totalBulkCount = _totalBulkCount.ceil();
        onConnected();
      }
    });
  }

  String unwrap(String str){
    RegExp exp = new RegExp(r"☺(.*)☺");
    List<Match> matches = exp.allMatches(str).toList();
    if(matches.length==1){
      var s = matches[0].group(0);
//      CA.log(s.substring(1,s.length-1));
      return s.substring(1,s.length-1);
    }else{
      CA.logi('Format Mismatch',str);
      throw BulkFormatMismatchException();
    }
  }

  List unwrapAsync(String str){
    try {
      List d = unwrap(str).split("♫");
      int.parse(d[0]); //test is valid
      return d;
    } on Exception catch(e){
      CA.logi('ERR', e.toString());
      throw e;
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
      CA.log("tbc $totalBulkCount $bulkCount");
      setState(() {});
      if(status==bulkCount+1) {
        String qrData = await scanQR();
        sendStatusRef.set(status + 0.5);
        CA.log("status changed by 0.5");
        try {
          receivedStr += unwrap(qrData);
          bulkCount++;
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
        CA.alert(this.context, "Sharing Aborted!", onPressed: (){
          CA.navigateWithoutBack(this.context, Pages.home);
        });
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
    writeToFile(fileData, dir.path + "/" + fileName).then((File v){
      CA.log(v.path);
      CA.navigateWithoutBack(this.context, Pages.home);
    });
  }

  Future<File> writeToFile(Uint8List data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  void beginReceiveFile() async {
    CA.log("begin receiving");
    if(CS.isSynchronousTransmission) {
      pairDevice(() {
        receivedStr = "";
        bulkCount = -1;
        sendStatusRef.onValue.listen(onReceiveStatusChanged);
      });
    }else{
      await initializeAsynchronousTransmission();
      bulkCount = 0;

      receiveBulkAsync();
    }
  }

  Future initializeAsynchronousTransmission() async {
    try{
      String qrResult = await BarcodeScanner.scan();
      List<String> initData = qrResult.split(",");
      bulkSize = int.parse(initData[1]);
      totalBulkCount = int.parse(initData[2]);
      asynchronousInterval = int.parse(initData[3]);
      CA.logi(0.1, '$bulkSize, $totalBulkCount, $asynchronousInterval');
    } on Exception catch(e){
      CA.logi('ERR', e.toString());
      CA.alert(this.context, "Inalid initialization, Sharing Aborted!", onPressed: (){
        CA.navigateWithoutBack(this.context, Pages.home);
      });
      return;
    }
  }

  void receiveBulkAsync() async {
    try {
      String qrData = await scanQR();

      if(qrData.length>16 && qrData.substring(0,16)=='INIT_ASYNC_TRANS'){
        receiveBulkAsync();
        return;
      }
      List unwrapData = unwrapAsync(qrData);
      int rBulkCount = int.parse(unwrapData[0]);
      if(rBulkCount>bulkCount){
        CA.alert(this.context, "Data bulk is missing, Sharing Aborted!", onPressed: (){
          CA.navigateWithoutBack(this.context, Pages.home);
        });
        return;
      } else if(rBulkCount==bulkCount) {
        bulkCount++;
        receivedStr += unwrapData[1];
        CA.logi(10, receivedStr);
        CA.logi(10.1, '$rBulkCount, $bulkCount, $totalBulkCount');
        if (bulkCount == totalBulkCount) {
          storeReceivedFile();
          return;
        }

      }
      receiveBulkAsync();
    }
    on BulkFormatMismatchException catch(e){
      receiveBulkAsync();
    }
    on Exception catch(e){
      CA.logi('ERR', e.toString());
      CA.alert(this.context, "Error occured while data transmission, Sharing Aborted!", onPressed: (){
        CA.navigateWithoutBack(this.context, Pages.home);
      });
      return;
    }
  }

  @override
  void initState() {
    super.initState();

    beginReceiveFile();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(CS.title),
      ),
      body: Center(
        child: CS.isSynchronousTransmission?getProgressWidget():Container()
      )
    );
  }

  getProgressWidget(){
    double curPercent = (bulkCount==0 || bulkCount==null)?0:(bulkCount+1)/totalBulkCount;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
        new CircularPercentIndicator(
            radius: CA.getScreenWidth(context)/1.4,
            lineWidth: 10.0,
            percent: curPercent,
            center: new Image(
            image: AssetImage('assets/images/logo.png'),
            width: 130,
            height: 130,
            ),
            backgroundColor: Colors.grey[400],
            progressColor: Colors.blue,
          ),
          Padding(padding: EdgeInsets.all(25),),
          Text(paired?"${(curPercent*100).toStringAsFixed(2)}%":"CONNECTING", style: TextStyle(
              fontSize: 50,
              color: CS.bgColor1
            ),
          )
      ]
    );
  }
}

class BulkFormatMismatchException implements Exception{
  String errorMessage(){
    return "Format mismatch of data bulk";
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:wear/wear.dart';
import 'package:requests/requests.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screen_wake/flutter_screen_wake.dart';
import 'package:html/parser.dart' show parse;

AndroidOptions _getAndroidOptions() => const AndroidOptions(
      encryptedSharedPreferences: true,
    );

Uint8List dataFromBase64String(String base64String) {
  return base64Decode(base64String);
}

String base64String(List<int> data) {
  return base64Encode(data);
}

void main() {
  runApp(MyApp());
}

Future<List<String>> getData(user, password) async {
  // Bypass form verification token
  var get_verif_code = await Requests.get("https://mon-espace.izly.fr/");
  get_verif_code.raiseForStatus();
  var homepage = parse(get_verif_code.content());
  var veriftoken =
      homepage.getElementsByClassName("form-horizontal")[0].getElementsByTagName("input")[0].attributes["value"];

  var login_req = await Requests.post("https://mon-espace.izly.fr/Home/Logon",
      body: {"Username": user, "Password": password, "__RequestVerificationToken": veriftoken});
  login_req.raiseForStatus();
  var status = login_req.statusCode.toString();
  var cookies = await Requests.getStoredCookies(Requests.getHostname("https://mon-espace.izly.fr/Home/Logon"));

  // If login error then return status code
  if (status != "302") {
    return [status];
  }

  var qrcode_req = await Requests.post("https://mon-espace.izly.fr/Home/CreateQrCodeImg", body: {"nbrOfQrCode": 1});
  qrcode_req.throwForStatus();
  var qrcode_base64 = qrcode_req.json()[0]["Src"].split(",")[1];

  var balance_req = await Requests.get("https://mon-espace.izly.fr/Home/");
  balance_req.raiseForStatus();
  var izlyhomepage = parse(balance_req.content());
  var data = izlyhomepage.getElementsByClassName("balance-text order-2")[0].innerHtml;
  String balance_formated = data.split("+")[1].split("<")[0] + "€";

  return [status, balance_formated, qrcode_base64];
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() {
    return _MyAppState();
  }
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _controller = TextEditingController();
  Future<List<String>>? izly_data;
  bool showForm = false;

  String? username;
  String? password;

  // Create storage
  final storage = new FlutterSecureStorage();

  Future writeSecureData(String key, String value) async {
    var writeData = await storage.write(key: key, value: value);
    return writeData;
  }

  Future<String?> readSecureData(String key) async {
    String? readData = await storage.read(key: key);
    return readData;
  }

  void initapp() async {
    FlutterScreenWake.keepOn(true);
    username = await readSecureData("username");
    password = await readSecureData("password");
    setState(() {
      if (username != null && password != null) {
        showForm = false;
        FlutterScreenWake.setBrightness(1.0);
        izly_data = getData(username, password);
      } else {
        showForm = true;
      }
    });
  }

  void initState() {
    super.initState();
    initapp();
  }

  // This widget is the root the app.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: WatchShape(
            builder: (BuildContext context, WearShape shape, Widget? child) {
              return showForm ? loginForm(context) : buildQRCodeContainer();
            },
          ),
        ),
      ),
    );
  }

  Container buildQRCodeContainer() {
    return Container(
      child: new GestureDetector(
          onTap: () {
            setState(() {
              izly_data = getData(username, password);
            });
          },
          onLongPress: () {
            setState(() {
              showForm = true;
            });
          },
          child: new Container(
            child: buildFutureQRcode(),
          )),
    );
  }

  FutureBuilder<List<String>> buildFutureQRcode() {
    return FutureBuilder<List<String>>(
      future: izly_data,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data![0] == "302") {
          String qrcode = snapshot.data![2];
          String balance = snapshot.data![1];
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  balance,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(0.0),
                child: Image.memory(
                  dataFromBase64String(qrcode),
                  fit: BoxFit.contain,
                  width: 150,
                  height: 150,
                ),
              ),
            ],
          );
        } else if (snapshot.hasError) {
          return Text("No QR code");
        }

        return CircularProgressIndicator();
      },
    );
  }

  // Show login form
  Form loginForm(BuildContext context) {
    final UsernameController = TextEditingController();
    final PasswordController = TextEditingController();

    @override
    void dispose() {
      // Clean up the controller when the widget is removed from the
      // widget tree.
      UsernameController.dispose();
      PasswordController.dispose();
      super.dispose();
    }

    final _formKey = GlobalKey<FormState>();
    return Form(
      key: _formKey,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          height: 45.0,
          width: 150.0,
          child: TextFormField(
            controller: UsernameController,
            decoration: const InputDecoration(
              icon: Icon(Icons.person),
              hintText: 'User',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ne peut pas être vide';
              }
              return null;
            },
          ),
        ),
        SizedBox(
          height: 45.0,
          width: 150.0,
          child: TextFormField(
            controller: PasswordController,
            decoration: const InputDecoration(
              icon: Icon(Icons.lock),
              hintText: 'Password',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ne peut pas être vide';
              }
              return null;
            },
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10.0),
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                writeSecureData("username", UsernameController.text);
                writeSecureData("password", PasswordController.text);
                setState(() {
                  FlutterScreenWake.setBrightness(1.0);
                  izly_data = getData(UsernameController.text, PasswordController.text);
                  showForm = false;
                });
              }
            },
            child: const Text('Connexion'),
          ),
        ),
      ]),
    );
  }
}

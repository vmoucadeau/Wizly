import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:wear/wear.dart';
import 'package:requests/requests.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:screen/screen.dart';

Uint8List dataFromBase64String(String base64String) {
  return base64Decode(base64String);
}

String base64String(List<int> data) {
  return base64Encode(data);
}

void main() {
  runApp(MyApp());
}

Future<List<Map<String, String>>> izlylogin(user, password) async {
  var r1 = await Requests.post("https://mon-espace.izly.fr/Home/Logon", body: {"username": user, "password": password});
  r1.raiseForStatus();
  var hostname = Requests.getHostname("https://mon-espace.izly.fr/Home/Logon");
  var cookies = await Requests.getStoredCookies(hostname);
  return [
    {'status': r1.statusCode.toString()},
    cookies
  ];
}

Future<String> getQrCode(user, password, cookies) async {
  // this will re-use the persisted cookies
  await Requests.setStoredCookies("mon-espace.izly.fr", cookies);
  var r2 = await Requests.post("https://mon-espace.izly.fr/Home/CreateQrCodeImg", body: {"nbrOfQrCode": 1});
  r2.raiseForStatus();
  var base64 = "";
  // On essaye de réutiliser le cookie obtenu au démarrage de l'app (vachement plus rapide)
  if (r2.statusCode == 200) {
    base64 = r2.json()[0]["Src"].split(",")[1];
  } else {
    // Sinon on récupère le cookie obtenu après le login
    var r1 =
        await Requests.post("https://mon-espace.izly.fr/Home/Logon", body: {"username": user, "password": password});
    r1.raiseForStatus();
    var r2 = await Requests.post("https://mon-espace.izly.fr/Home/CreateQrCodeImg", body: {"nbrOfQrCode": 1});
    r2.raiseForStatus();
    base64 = r2.json()[0]["Src"].split(",")[1];
  }
  return (base64);
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
  Future<String>? qrcode;
  bool showForm = false;

  String? username;
  String? password;
  Map<String, String>? cookies;

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
    username = await readSecureData("username");
    password = await readSecureData("password");
    if (username != null && password != null) {
      izlylogin(username, password).then((value) {
        if (value[0]["status"] == "302") {
          cookies = value[1];
          setState(() {
            qrcode = getQrCode(username, password, cookies);
            showForm = false;
            Screen.setBrightness(1.0);
            Screen.keepOn(true);
          });
        } else {
          setState(() {
            showForm = true;
          });
        }
      });
    } else {
      setState(() {
        showForm = true;
      });
    }
  }

  void initState() {
    super.initState();
    initapp();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: WatchShape(
            builder: (BuildContext context, WearShape shape, Widget? child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    child: showForm ? loginForm(context) : buildQRCodeColumn(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Column buildQRCodeColumn() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        new GestureDetector(
            onTap: () {
              setState(() {
                qrcode = getQrCode(username, password, cookies);
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
      ],
    );
  }

  FutureBuilder<String> buildFutureQRcode() {
    return FutureBuilder<String>(
      future: qrcode,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != "") {
          return Image.memory(
            dataFromBase64String(snapshot.data!),
            fit: BoxFit.contain,
            width: 150,
            height: 150,
          );
        } else if (snapshot.hasError || snapshot.data == "") {
          return Text("No QR code");
        }

        return const CircularProgressIndicator();
      },
    );
  }

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          // margin: EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
          child: Column(children: [
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
                  // Validate returns true if the form is valid, or false otherwise.
                  if (_formKey.currentState!.validate()) {
                    // If the form is valid, display a snackbar. In the real world,
                    // you'd often call a server or save the information in a database.
                    writeSecureData("username", UsernameController.text);
                    writeSecureData("password", PasswordController.text);
                    izlylogin(UsernameController.text, PasswordController.text).then((value) => {
                          if (value[0]['status'] == "302")
                            {
                              cookies = value[1],
                              setState(() {
                                Screen.setBrightness(1.0);
                                Screen.keepOn(true);
                                qrcode = getQrCode(UsernameController.text, PasswordController.text, cookies);
                                showForm = false;
                              })
                            }
                        });
                  }
                },
                child: const Text('Envoyer'),
              ),
            ),
          ]),
        )
      ]),
    );
  }
}

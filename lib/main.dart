import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC MANAGER',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (context) => NFCNotifier(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text("NFC READ/WRITE"),
          ),
          body: Builder(
            builder: (BuildContext context) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        scanningDialog(context);
                        Provider.of<NFCNotifier>(context, listen: false)
                            .startNFCOperation(nfcOperation: NFCOperation.read);
                      },
                      child: const Text("READ NFC"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        scanningDialog(context);
                        Provider.of<NFCNotifier>(context, listen: false)
                            .startNFCOperation(
                          nfcOperation: NFCOperation.write,
                          dataType: "PLAIN_TEXT",
                        );
                      },
                      child: const Text("WRITE CONTACT"),
                    ),
                    Consumer<NFCNotifier>(
                      builder: (context, provider, _) {
                        if (provider.isProcessing) {
                          return const CircularProgressIndicator();
                        }
                        if (provider.message.isNotEmpty) {
                          WidgetsBinding.instance!.addPostFrameCallback((_) {
                            Navigator.pop(context);
                            showResultDialog(context, provider.message);
                          });
                        }
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

void scanningDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const AlertDialog(
        title: Text('Escaneando Tarjeta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Acerque la Tejeta NFC...'),
          ],
        ),
      );
    },
  );
}

void showResultDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Texto en la tarjeta'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

class NFCNotifier extends ChangeNotifier {
  bool _isProcessing = false;
  String _message = "";

  bool get isProcessing => _isProcessing;

  String get message => _message;

  Future<void> startNFCOperation({
    required NFCOperation nfcOperation,
    String dataType = "",
  }) async {
    try {
      _isProcessing = true;
      notifyListeners();

      bool isAvail = await NfcManager.instance.isAvailable();

      if (isAvail) {
        if (nfcOperation == NFCOperation.read) {
          _message = "Escaneando";
        } else if (nfcOperation == NFCOperation.write) {
          _message = "Escribiendo en la Tarjeta";
        }

        notifyListeners();

        NfcManager.instance.startSession(onDiscovered: (NfcTag nfcTag) async {
          if (nfcOperation == NFCOperation.read) {
            _readFromTag(tag: nfcTag);
          } else if (nfcOperation == NFCOperation.write) {
            _writeToTag(nfcTag: nfcTag, dataType: dataType);
            _message = "COMPLETADO";
          }

          _isProcessing = false;
          notifyListeners();
          await NfcManager.instance.stopSession();
        }, onError: (e) async {
          _isProcessing = false;
          _message = e.toString();
          notifyListeners();
        });
      } else {
        _isProcessing = false;
        _message = "Por favor, habilita NFC desde la configuración";
        notifyListeners();
      }
    } catch (e) {
      _isProcessing = false;
      _message = e.toString();
      notifyListeners();
    }
  }

  Future<void> _readFromTag({required NfcTag tag}) async {
    Map<String, dynamic> nfcData = {
      'nfca': tag.data['nfca'],
      'mifareultralight': tag.data['mifareultralight'],
      'ndef': tag.data['ndef']
    };

    String? decodedText;
    if (nfcData.containsKey('ndef')) {
      List<int> payload =
      nfcData['ndef']['cachedMessage']?['records']?[0]['payload'];
      decodedText = String.fromCharCodes(payload);
    }

    _message = decodedText ?? "No Data Found";
  }

  Future<void> _writeToTag(
      {required NfcTag nfcTag, required String dataType}) async {
    NdefMessage message = _createNdefMessage(dataType: dataType);
    await Ndef.from(nfcTag)?.write(message);
  }

  NdefMessage _createNdefMessage({required String dataType}) {
    switch (dataType) {
      case 'PLAIN_TEXT':
        {
          String randomText = "hello como estas";
          Uint8List textBytes = utf8.encode(randomText);
          return NdefMessage([
            NdefRecord.createMime(
              'text/plain',
              textBytes,
            )
          ]);
        }
      default:
        return const NdefMessage([]);
    }
  }
}

enum NFCOperation { read, write }

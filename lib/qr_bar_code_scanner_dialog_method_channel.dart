import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'qr_bar_code_scanner_dialog_platform_interface.dart';

/// An implementation of [QrBarCodeScannerDialogPlatform] that uses method channels.
class MethodChannelQrBarCodeScannerDialog
    extends QrBarCodeScannerDialogPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('qr_bar_code_scanner_dialog');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  void scanBarOrQrCode(
      {BuildContext? context, required Function(String? code) onScanSuccess, List<String>? aux}) {
    /// context is required to show alert in non-web platforms
    assert(context != null);

    showDialog(
        context: context!,
        builder: (context) => Container(
              alignment: Alignment.center,
              child: Container(
                height: 400,
                width: 600,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ScannerWidget(aux: aux, onScanSuccess: (code) {
                  if (code != null) {
                    Navigator.pop(context);
                    onScanSuccess(code);
                  }
                }),
              ),
            ));
  }
}

class ScannerWidget extends StatefulWidget {
  final void Function(String? code) onScanSuccess;
  final List<String>? aux;

  const ScannerWidget({super.key, required this.onScanSuccess, required this.aux});

  @override
  createState() => _ScannerWidgetState();
}

class _ScannerWidgetState extends State<ScannerWidget> {
  QRViewController? controller;
  GlobalKey qrKey = GlobalKey(debugLabel: 'scanner');

  bool isScanned = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  void dispose() {
    /// dispose the controller
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildQrView(context),
          ),
        ),
        Visibility(
            visible: widget.aux!.isNotEmpty, child:
            Padding(
                padding: const EdgeInsets.all(8.0), child:
                Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom:10.0), child:
                          Text("Resumo das quantidades recolhidas:")),
                      for(var item in widget.aux!)
                        Text(item.toString()),
                    ]
                ),
            )
        ),

        Visibility(
            visible: widget.aux!.isNotEmpty, child:
                Divider(height: 20,thickness: 1),
        ),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              primary: Color.fromRGBO(59, 89, 153, 1),
                              textStyle: const TextStyle(
                                  color: Color.fromRGBO(34, 36, 44, 1),
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal)),
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Fechar"),
        ),
      ],
    );
  }

  Widget _buildQrView(BuildContext context) {
    double smallestDimension = min(
        MediaQuery.of(context).size.width, MediaQuery.of(context).size.height);

    smallestDimension = min(smallestDimension, 550);

    return QRView(
      key: qrKey,
      onQRViewCreated: (controller) {
        _onQRViewCreated(controller);
      },
      overlay: QrScannerOverlayShape(
          borderColor: Colors.black,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: smallestDimension - 140),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((Barcode scanData) async {
      if (!isScanned) {
        isScanned = true;
        widget.onScanSuccess(scanData.code);
      }
    });
  }
}

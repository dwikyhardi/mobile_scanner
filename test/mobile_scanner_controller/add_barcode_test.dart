import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
          (_) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
          null,
        );
  });

  test('gallery results reach the barcode stream; null is ignored', () async {
    final controller = MobileScannerController(autoStart: false);
    const capture = BarcodeCapture(
      barcodes: [Barcode(rawValue: 'MONIT-1862')],
    );
    final results = <BarcodeCapture>[];
    final subscription = controller.barcodes.listen(results.add);
    final otherResults = <BarcodeCapture>[];
    final otherSubscription = controller.barcodes.listen(otherResults.add);

    controller
      ..addBarcode(null)
      ..addBarcode(capture);
    await Future<void>.delayed(Duration.zero);

    expect(results, [same(capture)]);
    expect(otherResults, [same(capture)]);

    final disposal = controller.dispose();
    expect(() => controller.addBarcode(capture), returnsNormally);
    expect(() => controller.addBarcode(null), returnsNormally);
    await disposal;
    expect(() => controller.addBarcode(capture), returnsNormally);
    expect(() => controller.addBarcode(null), returnsNormally);
    await Future<void>.delayed(Duration.zero);
    expect(results, [same(capture)]);
    expect(otherResults, [same(capture)]);
    await subscription.cancel();
    await otherSubscription.cancel();
  });

  testWidgets('gallery analysis can be published to onDetect', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
          (call) async {
            if (call.method == 'analyzeImage') {
              expect(call.arguments, {
                'filePath': '/gallery/qr.png',
                'formats': [BarcodeFormat.qrCode.rawValue],
              });
              return {
                'data': [
                  {
                    'rawValue': 'MONIT-2031',
                    'format': BarcodeFormat.qrCode.rawValue,
                  },
                ],
              };
            }
            return null;
          },
        );
    final controller = MobileScannerController(autoStart: false);
    final results = <BarcodeCapture>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MobileScanner(controller: controller, onDetect: results.add),
      ),
    );
    await tester.pumpAndSettle();

    final capture = await controller.analyzeImage(
      '/gallery/qr.png',
      formats: [BarcodeFormat.qrCode],
    );
    expect(capture, isNotNull);
    expect(results, isEmpty);
    controller
      ..addBarcode(null)
      ..addBarcode(capture);
    await tester.pump();

    expect(results, [same(capture)]);
    expect(results.single.barcodes.single.rawValue, 'MONIT-2031');
    expect(controller.value.isRunning, isFalse);

    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

    controller
      ..addBarcode(null)
      ..addBarcode(capture);
    await Future<void>.delayed(Duration.zero);

    expect(results, [same(capture)]);

    await controller.dispose();
    expect(() => controller.addBarcode(capture), returnsNormally);
    await subscription.cancel();
  });
}

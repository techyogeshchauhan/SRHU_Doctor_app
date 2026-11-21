// Host side of `flutter drive` for the on-device tests in integration_test/.
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/app_test.dart -d DEVICE_ID \
//       --dart-define-from-file=dev.env
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();

import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';

class LocalCache {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(AppConstants.hiveBox);
  }

  static Box get box => Hive.box(AppConstants.hiveBox);
}

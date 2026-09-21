import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Edge is local-first on the web too: this persists SQLite in the browser's
/// IndexedDB rather than attempting to open a native database path.
Future<void> configureDatabaseFactory() async {
  databaseFactory = databaseFactoryFfiWeb;
}

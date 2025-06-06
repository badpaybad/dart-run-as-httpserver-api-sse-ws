// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';

// class DbContext{
//   static Database? _db;

//   static Future<Database> get database async {
//     if (_db != null) return _db!;
//     _db = await _initDB();
//     return _db!;
//   }

//   static Future<Database> _initDB() async {
//     final dir = await getApplicationDocumentsDirectory();
//     final path = join(dir.path, 'blockchain.db');

//     return await openDatabase(
//       path,
//       version: 1,
//       onCreate: _onCreate,
//     );
//   }

//   static Future _onCreate(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE blocks (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         index_no INTEGER,
//         previous_hash TEXT,
//         timestamp INTEGER,
//         data TEXT,
//         hash TEXT
//       )
//     ''');
//   }
// }
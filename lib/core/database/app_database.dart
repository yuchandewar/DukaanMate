import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Shops, Products, Bills, BillItems, Customers, Settings, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(settings);
        }
        if (from < 3) {
          try {
            await m.addColumn(customers, customers.alternatePhone);
          } catch (e) {
            // Column might already exist if a previous migration crashed midway
          }
          try {
            await m.addColumn(customers, customers.photoPath);
          } catch (e) {
            // Column might already exist
          }
        }
        if (from < 4) {
          try {
            await m.createTable(expenses);
          } catch (e) {
            // Table might already exist
          }
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dukaan_mate.sqlite'));

    // Workaround removed because it's no longer present in newer versions

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}

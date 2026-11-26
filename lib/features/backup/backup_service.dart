import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dukaan_mate/core/database/app_database.dart';

class BackupService {
  Future<void> exportBackup(AppDatabase db) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final originalDbPath = p.join(dbFolder.path, 'dukaan_mate.sqlite');

      if (!await File(originalDbPath).exists()) {
        throw Exception('Database file not found.');
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final backupFileName = 'DukaanMate_Backup_$dateStr.sqlite';
      
      final tempDir = await getTemporaryDirectory();
      
      // SYNC SharedPreferences to SQLite BEFORE EXPORTING
      final prefs = await SharedPreferences.getInstance();
      await db.delete(db.settings).go(); // clear old settings
      
      final keys = prefs.getKeys();
      for (final key in keys) {
        final val = prefs.get(key);
        if (val is String) {
          await db.into(db.settings).insert(SettingsCompanion.insert(key: key, value: val));
        } else if (val is List<String>) {
          await db.into(db.settings).insert(SettingsCompanion.insert(key: key, value: jsonEncode(val)));
        } else if (val is bool) {
          await db.into(db.settings).insert(SettingsCompanion.insert(key: key, value: val.toString()));
        }
      }
      
      // Safely merge any pending Write-Ahead Log (WAL) data into the main database file
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

      final exportPath = p.join(tempDir.path, backupFileName);
      
      final dbFile = File(originalDbPath);
      if (!dbFile.existsSync() || dbFile.lengthSync() == 0) {
        throw Exception('Original database file is empty or missing!');
      }
      
      // Directly copy the file to avoid any ZIP encoding bugs
      dbFile.copySync(exportPath);

      final exportFile = File(exportPath);
      if (!exportFile.existsSync() || exportFile.lengthSync() < 100) {
        throw Exception('Failed to copy database file. File is too small.');
      }

      final xFile = XFile(exportPath, mimeType: 'application/octet-stream');
      await Share.shareXFiles([xFile], text: 'DukaanMate Backup');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> importBackup(AppDatabase db) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true, // Loads file directly into memory, bypassing strict Android 11+ path permissions!
      );

      if (result != null) {
        final platformFile = result.files.single;
        final fileName = platformFile.name.toLowerCase();
        
        List<int>? bytes = platformFile.bytes;
        // If file_picker returns an empty list (which happens on some Android storage providers), fallback to path
        if ((bytes == null || bytes.isEmpty) && platformFile.path != null) {
          bytes = File(platformFile.path!).readAsBytesSync();
        }
        
        if (bytes == null || bytes.isEmpty) {
          throw Exception('The selected file is 0 bytes (empty). It might be corrupted or still downloading from cloud storage.');
        }

        final dbFolder = await getApplicationDocumentsDirectory();
        final targetDbPath = p.join(dbFolder.path, 'dukaan_mate.sqlite');

        // Check if the file is a raw SQLite database by reading its header signature
        // SQLite files always start with 'SQLite format 3\000'
        bool isRawSqlite = false;
        if (bytes.length > 16) {
          final header = String.fromCharCodes(bytes.sublist(0, 16));
          if (header.contains('SQLite format 3')) {
            isRawSqlite = true;
          }
        }

        List<int>? dataToWrite;

        if (isRawSqlite) {
          // It's a raw database file, ignore the extension and just use it!
          dataToWrite = bytes;
        } else {
          // Fallback if they pick a file without .zip but it wasn't recognized as raw SQLite
          // We'll just assume they know what they are doing and write it.
          dataToWrite = bytes;
        }

        // Critical: Close the database ONLY when we are 100% sure we are overwriting it!
        await db.close();
        
        // Critical: Delete any existing WAL or SHM files
        final walFile = File('$targetDbPath-wal');
        final shmFile = File('$targetDbPath-shm');
        if (walFile.existsSync()) walFile.deleteSync();
        if (shmFile.existsSync()) shmFile.deleteSync();

        File(targetDbPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(dataToWrite);

        // RESTORE SharedPreferences from the newly imported SQLite!
        final newDb = AppDatabase();
        final storedSettings = await newDb.select(newDb.settings).get();
        final prefs = await SharedPreferences.getInstance();
        
        for (final setting in storedSettings) {
          final key = setting.key;
          final value = setting.value;
          
          if (key == 'dark_mode') {
            await prefs.setBool(key, value == 'true');
          } else if (key == 'payment_qrs') {
            try {
              final list = jsonDecode(value) as List;
              await prefs.setStringList(key, list.map((e) => e.toString()).toList());
            } catch (e) {
              // ignore parse errors for older versions
            }
          } else {
            await prefs.setString(key, value);
          }
        }
        
        // Close the temporary newDb since we invalidate the provider downstream anyway
        await newDb.close();

        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'database.dart';

enum BackupFailureCode {
  databaseNotFound,
  sourceNotFound,
  sourceIsActiveDatabase,
  invalidSqlite,
  incompatibleSchema,
  requiredTablesMissing,
  copyFailed,
  closeFailed,
  replacementFailed,
  reopenFailed,
  rollbackFailed,
  insufficientStorage,
  permissionDenied,
  unknown,
}

class BackupFailure {
  const BackupFailure(this.code, {this.cause});

  final BackupFailureCode code;
  final Object? cause;
}

class BackupArtifact {
  const BackupArtifact({
    required this.file,
    required this.fileName,
    required this.size,
  });

  final File file;
  final String fileName;
  final int size;

  Future<void> dispose() async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class BackupExportResult {
  const BackupExportResult._({this.artifact, this.failure});

  const BackupExportResult.success(BackupArtifact artifact)
    : this._(artifact: artifact);

  const BackupExportResult.failed(BackupFailure failure)
    : this._(failure: failure);

  final BackupArtifact? artifact;
  final BackupFailure? failure;
  bool get isSuccess => artifact != null;
}

class BackupValidationResult {
  const BackupValidationResult._({
    required this.isValid,
    this.schemaVersion,
    this.failure,
  });

  const BackupValidationResult.valid(int schemaVersion)
    : this._(isValid: true, schemaVersion: schemaVersion);

  const BackupValidationResult.invalid(BackupFailure failure)
    : this._(isValid: false, failure: failure);

  final bool isValid;
  final int? schemaVersion;
  final BackupFailure? failure;
}

class BackupRestoreResult {
  const BackupRestoreResult._({
    required this.activeDatabase,
    required this.isSuccess,
    this.failure,
  });

  const BackupRestoreResult.success(AppDatabase database)
    : this._(activeDatabase: database, isSuccess: true);

  const BackupRestoreResult.failed(AppDatabase database, BackupFailure failure)
    : this._(activeDatabase: database, isSuccess: false, failure: failure);

  final AppDatabase activeDatabase;
  final bool isSuccess;
  final BackupFailure? failure;
}

class LocalBackupService {
  LocalBackupService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _requiredTables = {
    'products',
    'customers',
    'sales',
    'installments',
    'payments',
  };
  static const _requiredColumns = {
    'products': {
      'id',
      'name',
      'price',
      'is_deleted',
      'created_at',
      'updated_at',
    },
    'customers': {'id', 'name', 'address', 'phone', 'is_deleted', 'created_at'},
    'sales': {
      'id',
      'customer_id',
      'product_id',
      'original_price',
      'interest_amount',
      'total_amount',
      'months',
      'monthly_with_interest',
      'monthly_without_interest',
      'start_date',
      'is_deleted',
      'created_at',
    },
    'installments': {
      'id',
      'sale_id',
      'month_number',
      'due_date',
      'base_amount',
      'carried_balance',
      'actual_due',
      'total_paid',
      'is_paid',
    },
    'payments': {'id', 'installment_id', 'amount', 'payment_date', 'note'},
  };

  final DateTime Function() _clock;

  String createBackupFileName({DateTime? dateTime}) {
    final value = dateTime ?? _clock();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return 'offline_pos_backup_${value.year}-'
        '${twoDigits(value.month)}-${twoDigits(value.day)}_'
        '${twoDigits(value.hour)}${twoDigits(value.minute)}'
        '${twoDigits(value.second)}.db';
  }

  Future<BackupExportResult> createExportSnapshot(AppDatabase database) async {
    File? snapshot;
    try {
      final databaseFile = await _discoverDatabaseFile(database);
      if (!await databaseFile.exists()) {
        return const BackupExportResult.failed(
          BackupFailure(BackupFailureCode.databaseNotFound),
        );
      }

      final fileName = createBackupFileName();
      snapshot = File(
        p.join(databaseFile.parent.path, '.export_${_uniqueSuffix()}.db'),
      );
      final escapedPath = snapshot.path.replaceAll("'", "''");
      await database.customStatement("VACUUM INTO '$escapedPath'");

      final validation = await validateBackup(snapshot.path);
      if (!validation.isValid) {
        await _deleteIfExists(snapshot);
        return BackupExportResult.failed(validation.failure!);
      }

      return BackupExportResult.success(
        BackupArtifact(
          file: snapshot,
          fileName: fileName,
          size: await snapshot.length(),
        ),
      );
    } on FileSystemException catch (error) {
      await _deleteIfExists(snapshot);
      return BackupExportResult.failed(
        BackupFailure(_fileFailureCode(error), cause: error),
      );
    } catch (error) {
      await _deleteIfExists(snapshot);
      return BackupExportResult.failed(
        BackupFailure(BackupFailureCode.unknown, cause: error),
      );
    }
  }

  Future<BackupValidationResult> validateBackup(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      return const BackupValidationResult.invalid(
        BackupFailure(BackupFailureCode.sourceNotFound),
      );
    }

    sqlite.Database? validationDatabase;
    try {
      final header = await source
          .openRead(0, 16)
          .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
      const expectedHeader = [
        83,
        81,
        76,
        105,
        116,
        101,
        32,
        102,
        111,
        114,
        109,
        97,
        116,
        32,
        51,
        0,
      ];
      if (header.length != expectedHeader.length ||
          !_listEquals(header, expectedHeader)) {
        return const BackupValidationResult.invalid(
          BackupFailure(BackupFailureCode.invalidSqlite),
        );
      }

      validationDatabase = sqlite.sqlite3.open(
        source.path,
        mode: sqlite.OpenMode.readOnly,
      );
      final integrityRows = validationDatabase.select('PRAGMA quick_check');
      if (integrityRows.isEmpty || integrityRows.first.values.first != 'ok') {
        return const BackupValidationResult.invalid(
          BackupFailure(BackupFailureCode.invalidSqlite),
        );
      }

      final versionRows = validationDatabase.select('PRAGMA user_version');
      final schemaVersion = versionRows.first.values.first as int;
      if (schemaVersion != 1) {
        return const BackupValidationResult.invalid(
          BackupFailure(BackupFailureCode.incompatibleSchema),
        );
      }

      final tableRows = validationDatabase.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = tableRows.map((row) => row['name'] as String).toSet();
      if (!_requiredTables.every(tables.contains)) {
        return const BackupValidationResult.invalid(
          BackupFailure(BackupFailureCode.requiredTablesMissing),
        );
      }

      for (final entry in _requiredColumns.entries) {
        final escapedTable = entry.key.replaceAll("'", "''");
        final columnRows = validationDatabase.select(
          "PRAGMA table_info('$escapedTable')",
        );
        final columns = columnRows.map((row) => row['name'] as String).toSet();
        if (!entry.value.every(columns.contains)) {
          return const BackupValidationResult.invalid(
            BackupFailure(BackupFailureCode.requiredTablesMissing),
          );
        }
      }

      return BackupValidationResult.valid(schemaVersion);
    } on FileSystemException catch (error) {
      return BackupValidationResult.invalid(
        BackupFailure(_fileFailureCode(error), cause: error),
      );
    } catch (error) {
      return BackupValidationResult.invalid(
        BackupFailure(BackupFailureCode.invalidSqlite, cause: error),
      );
    } finally {
      validationDatabase?.close();
    }
  }

  Future<BackupRestoreResult> restoreBackup({
    required AppDatabase currentDatabase,
    required String sourcePath,
  }) async {
    File? staging;
    File? displacedDatabase;
    File? recoverySnapshot;
    File? activeDatabaseFile;
    var databaseClosed = false;

    try {
      final databaseFile = await _discoverDatabaseFile(currentDatabase);
      activeDatabaseFile = databaseFile;
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return BackupRestoreResult.failed(
          currentDatabase,
          const BackupFailure(BackupFailureCode.sourceNotFound),
        );
      }
      if (p.equals(
        p.absolute(sourceFile.path),
        p.absolute(databaseFile.path),
      )) {
        return BackupRestoreResult.failed(
          currentDatabase,
          const BackupFailure(BackupFailureCode.sourceIsActiveDatabase),
        );
      }

      staging = File(
        p.join(databaseFile.parent.path, '.restore_${_uniqueSuffix()}.db'),
      );
      await _copyStreamed(sourceFile, staging);
      final validation = await validateBackup(staging.path);
      if (!validation.isValid) {
        await _deleteIfExists(staging);
        return BackupRestoreResult.failed(currentDatabase, validation.failure!);
      }

      recoverySnapshot = File(
        p.join(databaseFile.parent.path, '.recovery_${_uniqueSuffix()}.db'),
      );
      final escapedRecoveryPath = recoverySnapshot.path.replaceAll("'", "''");
      await currentDatabase.customStatement(
        "VACUUM INTO '$escapedRecoveryPath'",
      );

      try {
        await currentDatabase.close();
        databaseClosed = true;
      } catch (error) {
        await _deleteIfExists(staging);
        await _deleteIfExists(recoverySnapshot);
        return BackupRestoreResult.failed(
          currentDatabase,
          BackupFailure(BackupFailureCode.closeFailed, cause: error),
        );
      }

      displacedDatabase = File(
        p.join(databaseFile.parent.path, '.previous_${_uniqueSuffix()}.db'),
      );
      await databaseFile.rename(displacedDatabase.path);
      await _deleteSidecars(databaseFile);
      await staging.rename(databaseFile.path);
      staging = null;

      final replacement = AppDatabase();
      try {
        await replacement.customSelect('SELECT 1').getSingle();
      } catch (error) {
        await replacement.close();
        throw _ReopenException(error);
      }

      try {
        await _deleteIfExists(displacedDatabase);
        await _deleteIfExists(recoverySnapshot);
      } on FileSystemException {
        // The replacement is already open and verified. Leftover hidden
        // recovery files are safer than rolling back a successful restore.
      }
      return BackupRestoreResult.success(replacement);
    } catch (error) {
      if (!databaseClosed) {
        await _deleteIfExists(staging);
        await _deleteIfExists(recoverySnapshot);
        return BackupRestoreResult.failed(
          currentDatabase,
          BackupFailure(_failureCode(error), cause: error),
        );
      }

      try {
        if (activeDatabaseFile == null) {
          throw StateError('Missing database path');
        }
        await _deleteIfExists(activeDatabaseFile);
        await _deleteSidecars(activeDatabaseFile);
        if (await displacedDatabase!.exists()) {
          await displacedDatabase.rename(activeDatabaseFile.path);
        } else if (recoverySnapshot != null &&
            await recoverySnapshot.exists()) {
          await recoverySnapshot.rename(activeDatabaseFile.path);
        } else {
          throw StateError('No recovery database is available');
        }
        final recovered = AppDatabase();
        await recovered.customSelect('SELECT 1').getSingle();
        await _deleteIfExists(staging);
        await _deleteIfExists(recoverySnapshot);
        return BackupRestoreResult.failed(
          recovered,
          BackupFailure(_failureCode(error), cause: error),
        );
      } catch (rollbackError) {
        final fallback = AppDatabase();
        return BackupRestoreResult.failed(
          fallback,
          BackupFailure(BackupFailureCode.rollbackFailed, cause: rollbackError),
        );
      }
    }
  }

  Future<File> _discoverDatabaseFile(AppDatabase database) async {
    final rows = await database.customSelect('PRAGMA database_list').get();
    final mainRow = rows.firstWhere(
      (row) => row.read<String>('name') == 'main',
    );
    final path = mainRow.read<String>('file');
    if (path.isEmpty) {
      throw const FileSystemException('The active database has no file path');
    }
    return File(path);
  }

  Future<void> _copyStreamed(File source, File destination) async {
    final sink = destination.openWrite(mode: FileMode.writeOnly);
    try {
      await sink.addStream(source.openRead());
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (await destination.length() != await source.length()) {
      throw const FileSystemException('Copied file size does not match source');
    }
  }

  Future<void> _deleteSidecars(File databaseFile) async {
    await _deleteIfExists(File('${databaseFile.path}-wal'));
    await _deleteIfExists(File('${databaseFile.path}-shm'));
  }

  Future<void> _deleteIfExists(File? file) async {
    if (file != null && await file.exists()) await file.delete();
  }

  String _uniqueSuffix() => _clock().microsecondsSinceEpoch.toString();

  bool _listEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  BackupFailureCode _fileFailureCode(FileSystemException error) {
    final code = error.osError?.errorCode;
    if (code == 13 || code == 5) return BackupFailureCode.permissionDenied;
    if (code == 28 || code == 112) return BackupFailureCode.insufficientStorage;
    return BackupFailureCode.copyFailed;
  }

  BackupFailureCode _failureCode(Object error) {
    if (error is _ReopenException) return BackupFailureCode.reopenFailed;
    if (error is FileSystemException) return _fileFailureCode(error);
    return BackupFailureCode.replacementFailed;
  }
}

class _ReopenException implements Exception {
  const _ReopenException(this.cause);
  final Object cause;
}

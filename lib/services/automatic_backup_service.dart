import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'automatic_backup_storage.dart';
import 'database.dart';
import 'local_backup_service.dart';

enum AutomaticBackupStatus { created, notDue, alreadyRunning, failed }

class AutomaticBackupResult {
  const AutomaticBackupResult(this.status, {this.failure});

  final AutomaticBackupStatus status;
  final Object? failure;
}

abstract interface class AutomaticBackupTimestampStore {
  Future<DateTime?> readLastSuccessfulBackupUtc();

  Future<void> writeLastSuccessfulBackupUtc(DateTime value);
}

class SharedPreferencesAutomaticBackupTimestampStore
    implements AutomaticBackupTimestampStore {
  SharedPreferencesAutomaticBackupTimestampStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _lastSuccessfulBackupKey =
      'automatic_backup.last_successful_utc';

  final SharedPreferencesAsync _preferences;

  @override
  Future<DateTime?> readLastSuccessfulBackupUtc() async {
    final value = await _preferences.getString(_lastSuccessfulBackupKey);
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  @override
  Future<void> writeLastSuccessfulBackupUtc(DateTime value) {
    return _preferences.setString(
      _lastSuccessfulBackupKey,
      value.toUtc().toIso8601String(),
    );
  }
}

class AutomaticBackupService {
  AutomaticBackupService({
    required this._localBackupService,
    required this._storage,
    required this._timestampStore,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static final RegExp _automaticBackupName = RegExp(
    r'^offline_pos_auto_backup_\d{4}-\d{2}-\d{2}_\d{6}\.db$',
  );
  static const _minimumInterval = Duration(hours: 24);
  static const _retainedBackups = 15;
  static bool _isRunning = false;

  final LocalBackupService _localBackupService;
  final AutomaticBackupStorage _storage;
  final AutomaticBackupTimestampStore _timestampStore;
  final DateTime Function() _clock;

  Future<AutomaticBackupResult> runIfDue(AppDatabase database) async {
    return _run(database, enforceMinimumInterval: true);
  }

  Future<AutomaticBackupResult> runNow(AppDatabase database) async {
    return _run(database, enforceMinimumInterval: false);
  }

  Future<AutomaticBackupResult> _run(
    AppDatabase database, {
    required bool enforceMinimumInterval,
  }) async {
    if (_isRunning) {
      return const AutomaticBackupResult(AutomaticBackupStatus.alreadyRunning);
    }
    _isRunning = true;

    try {
      final nowUtc = _clock().toUtc();
      final storedBackups = await _ownedBackups();
      await _applyRetention(storedBackups);

      DateTime? savedTimestamp;
      try {
        savedTimestamp = await _timestampStore.readLastSuccessfulBackupUtc();
      } catch (_) {
        // The newest stored file still prevents a duplicate backup.
      }
      final newestFileTimestamp = storedBackups.isEmpty
          ? null
          : storedBackups.first.modifiedAtUtc;
      final lastSuccess = _latest(savedTimestamp, newestFileTimestamp);
      if (enforceMinimumInterval &&
          lastSuccess != null &&
          nowUtc.isBefore(lastSuccess.add(_minimumInterval))) {
        return const AutomaticBackupResult(AutomaticBackupStatus.notDue);
      }

      final snapshotResult = await _localBackupService.createExportSnapshot(
        database,
      );
      if (!snapshotResult.isSuccess) {
        return AutomaticBackupResult(
          AutomaticBackupStatus.failed,
          failure: snapshotResult.failure,
        );
      }

      final artifact = snapshotResult.artifact!;
      try {
        await _storage.storeFile(
          sourcePath: artifact.file.path,
          fileName: _createFileName(nowUtc.toLocal()),
        );
      } finally {
        await artifact.dispose();
      }

      Object? timestampFailure;
      try {
        await _timestampStore.writeLastSuccessfulBackupUtc(nowUtc);
      } catch (error) {
        timestampFailure = error;
      }

      await _applyRetention(await _ownedBackups());
      return AutomaticBackupResult(
        AutomaticBackupStatus.created,
        failure: timestampFailure,
      );
    } catch (error) {
      return AutomaticBackupResult(
        AutomaticBackupStatus.failed,
        failure: error,
      );
    } finally {
      _isRunning = false;
    }
  }

  Future<List<StoredAutomaticBackup>> _ownedBackups() async {
    final backups = await _storage.listAutomaticBackups();
    final owned = backups
        .where((backup) => _automaticBackupName.hasMatch(backup.name))
        .toList();
    owned.sort((first, second) {
      final dateOrder = second.modifiedAtUtc.compareTo(first.modifiedAtUtc);
      return dateOrder != 0 ? dateOrder : second.name.compareTo(first.name);
    });
    return owned;
  }

  Future<void> _applyRetention(List<StoredAutomaticBackup> backups) async {
    for (final backup in backups.skip(_retainedBackups)) {
      try {
        await _storage.deleteBackup(backup);
      } catch (_) {
        // Cleanup is retried the next time the application opens.
      }
    }
  }

  DateTime? _latest(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.isAfter(second) ? first : second;
  }

  String _createFileName(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return 'offline_pos_auto_backup_${value.year}-'
        '${twoDigits(value.month)}-${twoDigits(value.day)}_'
        '${twoDigits(value.hour)}${twoDigits(value.minute)}'
        '${twoDigits(value.second)}.db';
  }
}

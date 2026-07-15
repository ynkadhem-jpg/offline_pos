import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radius.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/automatic_backup_service.dart';
import '../services/automatic_backup_storage.dart';
import '../services/database.dart';
import '../services/local_backup_service.dart';
import 'widgets/app_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.database,
    required this.backupService,
    required this.onDatabaseChanged,
    super.key,
  });

  final AppDatabase database;
  final LocalBackupService backupService;
  final ValueChanged<AppDatabase> onDatabaseChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _manualBackupTimestampKey = 'backup.last_manual_export_utc';

  SharedPreferencesAsync? _preferences;
  AutomaticBackupTimestampStore? _automaticBackupTimestampStore;
  AutomaticBackupStorage? _automaticBackupStorage;
  Future<_LastBackupInfo>? _lastBackupFuture;

  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _lastBackupFuture = _loadLastBackupInfo();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastBackupFuture = _loadLastBackupInfo();
  }

  void _refreshLastBackupInfo() {
    setState(() {
      _lastBackupFuture = _loadLastBackupInfo();
    });
  }

  SharedPreferencesAsync get _prefs {
    return _preferences ??= SharedPreferencesAsync();
  }

  AutomaticBackupTimestampStore get _autoTimestampStore {
    return _automaticBackupTimestampStore ??=
        SharedPreferencesAutomaticBackupTimestampStore(preferences: _prefs);
  }

  AutomaticBackupStorage get _autoStorage {
    return _automaticBackupStorage ??= const AndroidAutomaticBackupStorage();
  }

  Future<_LastBackupInfo> get _currentLastBackupFuture {
    return _lastBackupFuture ??= _loadLastBackupInfo();
  }

  Future<_LastBackupInfo> _loadLastBackupInfo() async {
    DateTime? manualBackupUtc;
    DateTime? automaticBackupUtc;
    DateTime? newestStoredAutomaticBackupUtc;

    try {
      final value = await _prefs.getString(_manualBackupTimestampKey);
      manualBackupUtc = value == null
          ? null
          : DateTime.tryParse(value)?.toUtc();
    } catch (_) {
      // The page can still show automatic backup information.
    }

    try {
      automaticBackupUtc = await _autoTimestampStore
          .readLastSuccessfulBackupUtc();
    } catch (_) {
      // The stored automatic files below are a fallback.
    }

    try {
      final backups = await _autoStorage.listAutomaticBackups();
      backups.sort(
        (first, second) => second.modifiedAtUtc.compareTo(first.modifiedAtUtc),
      );
      newestStoredAutomaticBackupUtc =
          backups.isEmpty ? null : backups.first.modifiedAtUtc;
    } catch (_) {
      // Some platforms do not expose the Android storage bridge.
    }

    final automaticUtc = _latest(
      automaticBackupUtc,
      newestStoredAutomaticBackupUtc,
    );
    final latestUtc = _latest(manualBackupUtc, automaticUtc);
    if (latestUtc == null) {
      return const _LastBackupInfo.empty();
    }

    final source = manualBackupUtc != null &&
            manualBackupUtc.isAtSameMomentAs(latestUtc)
        ? _LastBackupSource.manual
        : _LastBackupSource.automatic;
    return _LastBackupInfo(timestampUtc: latestUtc, source: source);
  }

  DateTime? _latest(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.isAfter(second) ? first : second;
  }

  Future<void> _exportBackup() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    BackupArtifact? artifact;
    try {
      final result = await widget.backupService.createExportSnapshot(
        widget.database,
      );
      if (!result.isSuccess) {
        _showFailure(result.failure!);
        return;
      }

      artifact = result.artifact!;
      final destination = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: artifact.fileName,
        type: FileType.custom,
        allowedExtensions: const ['db'],
        bytes: await artifact.file.readAsBytes(),
      );
      if (destination == null || !mounted) return;
      try {
        await _prefs.setString(
          _manualBackupTimestampKey,
          DateTime.now().toUtc().toIso8601String(),
        );
      } catch (_) {
        // Export succeeded; only the local display timestamp failed to persist.
      }
      if (mounted) _refreshLastBackupInfo();
      _showMessage('تم تصدير النسخة الاحتياطية بنجاح');
    } catch (_) {
      if (mounted) _showMessage('تعذر تصدير النسخة الاحتياطية', isError: true);
    } finally {
      await artifact?.dispose();
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importBackup() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختيار نسخة احتياطية',
        type: FileType.custom,
        allowedExtensions: const ['db'],
        allowMultiple: false,
        withData: false,
      );
      final sourcePath = selection?.files.single.path;
      if (sourcePath == null) return;

      final validation = await widget.backupService.validateBackup(sourcePath);
      if (!validation.isValid) {
        _showFailure(validation.failure!);
        return;
      }

      if (!mounted || !await _confirmRestore()) return;
      final result = await widget.backupService.restoreBackup(
        currentDatabase: widget.database,
        sourcePath: sourcePath,
      );
      if (!identical(result.activeDatabase, widget.database)) {
        widget.onDatabaseChanged(result.activeDatabase);
      }
      if (!mounted) return;
      if (result.isSuccess) {
        _showMessage('تم استيراد النسخة الاحتياطية بنجاح');
        _refreshLastBackupInfo();
      } else {
        _showFailure(result.failure!);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر استيراد النسخة الاحتياطية', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _backupNow() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final service = AutomaticBackupService(
        localBackupService: widget.backupService,
        storage: _autoStorage,
        timestampStore: _autoTimestampStore,
      );
      final result = await service.runNow(widget.database);
      if (!mounted) return;

      if (result.status == AutomaticBackupStatus.created) {
        _refreshLastBackupInfo();
        _showMessage('تم إنشاء نسخة احتياطية الآن');
      } else if (result.status == AutomaticBackupStatus.alreadyRunning) {
        _showMessage('يوجد نسخ احتياطي قيد التنفيذ حالياً');
      } else {
        _showMessage('تعذر إنشاء نسخة احتياطية الآن', isError: true);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر إنشاء نسخة احتياطية الآن', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restoreLatestBackup() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    String? cachedBackupPath;
    try {
      final latestBackup = await _latestStoredBackup();
      if (latestBackup == null) {
        if (mounted) {
          _showMessage('لا توجد نسخة محفوظة للاستعادة', isError: true);
        }
        return;
      }

      cachedBackupPath = await _autoStorage.copyBackupToCache(latestBackup);
      final validation = await widget.backupService.validateBackup(
        cachedBackupPath,
      );
      if (!validation.isValid) {
        _showFailure(validation.failure!);
        return;
      }

      if (!mounted || !await _confirmRestoreLatest(latestBackup)) return;
      final result = await widget.backupService.restoreBackup(
        currentDatabase: widget.database,
        sourcePath: cachedBackupPath,
      );
      if (!identical(result.activeDatabase, widget.database)) {
        widget.onDatabaseChanged(result.activeDatabase);
      }
      if (!mounted) return;
      if (result.isSuccess) {
        _showMessage('تمت استعادة آخر نسخة احتياطية بنجاح');
        _refreshLastBackupInfo();
      } else {
        _showFailure(result.failure!);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر استعادة آخر نسخة احتياطية', isError: true);
      }
    } finally {
      if (cachedBackupPath != null) {
        try {
          await File(cachedBackupPath).delete();
        } catch (_) {
          // Temporary restore files can be cleaned by the OS later.
        }
      }
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<StoredAutomaticBackup?> _latestStoredBackup() async {
    final backups = await _autoStorage.listAutomaticBackups();
    final ownedBackups = backups
        .where((backup) => _isAutomaticBackupName(backup.name))
        .toList();
    ownedBackups.sort((first, second) {
      final dateOrder = second.modifiedAtUtc.compareTo(first.modifiedAtUtc);
      return dateOrder != 0 ? dateOrder : second.name.compareTo(first.name);
    });
    return ownedBackups.isEmpty ? null : ownedBackups.first;
  }

  bool _isAutomaticBackupName(String name) {
    return RegExp(
      r'^offline_pos_auto_backup_\d{4}-\d{2}-\d{2}_\d{6}\.db$',
    ).hasMatch(name);
  }

  Future<bool> _confirmRestore() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded),
            title: const Text('استيراد النسخة الاحتياطية؟'),
            content: const Text(
              'سيتم استبدال جميع البيانات الحالية بالبيانات الموجودة في '
              'النسخة المختارة. لا يمكن دمج البيانات.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('استبدال واستعادة'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmRestoreLatest(StoredAutomaticBackup backup) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded),
            title: const Text('استعادة آخر نسخة؟'),
            content: Text(
              'سيتم استبدال جميع البيانات الحالية بآخر نسخة محفوظة:\n'
              '${backup.name}\n\n'
              'لا يمكن دمج البيانات.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('استعادة واستبدال'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showFailure(BackupFailure failure) {
    _showMessage(_failureMessage(failure.code), isError: true);
  }

  String _failureMessage(BackupFailureCode code) {
    return switch (code) {
      BackupFailureCode.databaseNotFound => 'تعذر العثور على قاعدة البيانات',
      BackupFailureCode.sourceNotFound => 'تعذر العثور على ملف النسخة',
      BackupFailureCode.sourceIsActiveDatabase =>
        'لا يمكن استيراد ملف قاعدة البيانات المستخدم حالياً',
      BackupFailureCode.invalidSqlite => 'ملف النسخة غير صالح أو تالف',
      BackupFailureCode.incompatibleSchema =>
        'النسخة أُنشئت بإصدار أحدث من التطبيق',
      BackupFailureCode.requiredTablesMissing =>
        'الملف لا يحتوي على بيانات تطبيق التقسيط',
      BackupFailureCode.insufficientStorage => 'لا توجد مساحة تخزين كافية',
      BackupFailureCode.permissionDenied => 'لا توجد صلاحية للوصول إلى الملف',
      BackupFailureCode.rollbackFailed =>
        'فشلت الاستعادة وتعذر إعادة فتح البيانات السابقة',
      BackupFailureCode.reopenFailed =>
        'فشلت الاستعادة وتمت المحافظة على البيانات السابقة',
      _ => 'تعذر إكمال عملية النسخ الاحتياطي',
    };
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppPageHeader(
              title: 'النسخ الاحتياطي',
              subtitle: 'حماية بيانات التقسيط بالتصدير والاستعادة المحلية.',
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.xxl * 14,
                ),
                child: AppPanel(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LastBackupCard(
                        lastBackupFuture: _currentLastBackupFuture,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const AppSectionHeader(
                        title: 'إدارة النسخ',
                        icon: Icons.backup_outlined,
                        subtitle:
                            'أنشئ نسخة مباشرة أو استعد آخر نسخة محفوظة.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 620;
                          final backupNow = FilledButton.icon(
                            onPressed: _isBusy ? null : _backupNow,
                            icon: const Icon(Icons.backup_outlined),
                            label: const Text('نسخ الآن'),
                          );
                          final restoreLatest = OutlinedButton.icon(
                            onPressed: _isBusy ? null : _restoreLatestBackup,
                            icon: const Icon(Icons.restore_outlined),
                            label: const Text('استعادة آخر نسخة'),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                backupNow,
                                const SizedBox(height: AppSpacing.md),
                                restoreLatest,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: backupNow),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: restoreLatest),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          TextButton.icon(
                            onPressed: _isBusy ? null : _exportBackup,
                            icon: const Icon(Icons.file_upload_outlined),
                            label: const Text('تصدير إلى ملف'),
                          ),
                          TextButton.icon(
                            onPressed: _isBusy ? null : _importBackup,
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text('استيراد من ملف'),
                          ),
                        ],
                      ),
                      if (_isBusy) ...[
                        const SizedBox(height: AppSpacing.lg),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LastBackupSource { manual, automatic }

class _LastBackupInfo {
  const _LastBackupInfo({required this.timestampUtc, required this.source});

  const _LastBackupInfo.empty()
      : timestampUtc = null,
        source = null;

  final DateTime? timestampUtc;
  final _LastBackupSource? source;
}

class _LastBackupCard extends StatelessWidget {
  const _LastBackupCard({required this.lastBackupFuture});

  final Future<_LastBackupInfo> lastBackupFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LastBackupInfo>(
      future: lastBackupFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final timestamp = info?.timestampUtc;
        final isLoading = snapshot.connectionState != ConnectionState.done;
        final hasBackup = timestamp != null;
        final sourceText = switch (info?.source) {
          _LastBackupSource.manual => 'تصدير يدوي',
          _LastBackupSource.automatic => 'نسخ تلقائي',
          null => 'لم يتم إنشاء نسخة بعد',
        };

        return Container(
          padding: const EdgeInsets.all(AppSpacing.card),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [AppColors.primary, AppColors.primaryHover],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  hasBackup
                      ? Icons.cloud_done_outlined
                      : Icons.backup_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'آخر نسخة احتياطية',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.74),
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isLoading
                          ? 'جاري التحقق...'
                          : hasBackup
                              ? _formatTimestamp(timestamp!)
                              : 'لا توجد نسخة مسجلة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      sourceText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.70),
                          ),
                    ),
                  ],
                ),
              ),
              AppStatusChip(
                label: hasBackup ? 'محمي' : 'بانتظار نسخة',
                icon: hasBackup
                    ? Icons.verified_outlined
                    : Icons.info_outline,
                tone: hasBackup ? AppStatusTone.success : AppStatusTone.accent,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatTimestamp(DateTime timestampUtc) {
    final baghdadTime = timestampUtc.toUtc().add(const Duration(hours: 3));
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final date =
        '${baghdadTime.year}/${twoDigits(baghdadTime.month)}/'
        '${twoDigits(baghdadTime.day)}';
    final period = baghdadTime.hour < 12 ? 'ص' : 'م';
    final hour12 = baghdadTime.hour % 12 == 0 ? 12 : baghdadTime.hour % 12;
    final time = '$hour12:${twoDigits(baghdadTime.minute)} $period';
    return '$date  •  $time';
  }
}

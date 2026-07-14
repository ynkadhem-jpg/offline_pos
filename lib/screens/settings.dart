import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../design_system/tokens/app_spacing.dart';
import '../services/database.dart';
import '../services/local_backup_service.dart';

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
  bool _isBusy = false;

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
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.xxl * 14),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.backup_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'النسخ الاحتياطي المحلي',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'صدّر قاعدة البيانات إلى ملف واحد أو استبدل البيانات '
                      'الحالية بنسخة محفوظة سابقاً.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _exportBackup,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('تصدير نسخة احتياطية'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _importBackup,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('استيراد نسخة احتياطية'),
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
        ),
      ),
    );
  }
}

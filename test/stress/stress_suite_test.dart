import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'stress_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const runStressTests = bool.fromEnvironment('RUN_STRESS_TESTS');
  final preset = stressPresetFromEnvironment();
  final config = StressDatasetConfig.fromPreset(preset);

  testWidgets(
    'production stress suite generates data and measures critical flows',
    (tester) async {
      final fixture = StressDatabaseFixture();
      _log('setting up temporary database...');
      await tester.runAsync(fixture.setUp);
      _log('temporary database ready.');
      addTearDown(() => tester.runAsync(fixture.tearDown));

      final memorySampler = StressMemorySampler();
      _log('generating ${config.preset.label} dataset...');
      final generation = await tester.runAsync(
        () => StressDataGenerator(
          fixture.database,
          config,
        ).generate(memorySampler: memorySampler),
      );
      if (generation == null) {
        throw StateError('Stress data generation did not complete.');
      }
      _log('generation complete.');

      final runner = StressBenchmarkRunner(
        tester: tester,
        database: fixture.database,
        fixture: fixture,
        memorySampler: memorySampler,
      );

      _log('measuring startup proxy...');
      await runner.measureAppStartupProxy();
      _log('measuring backup export...');
      await runner.measureBackupExport();
      _log('measuring dashboard...');
      await runner.measureDashboardOpening();
      _log('measuring customers...');
      await runner.measureCustomerListOpening();
      await runner.measureCustomerSearchLatency();
      await runner.measureCustomerDetailsOpening();
      _log('measuring payment...');
      await runner.measurePaymentExecution();
      _log('measuring reports...');
      await runner.measureReportsOpening();
      _log('measuring scrolling...');
      await runner.measureScrolling();
      runner.drainWidgetExceptions();

      _log('writing report...');
      final report = StressReport(
        config: config,
        generation: generation,
        databaseSizeBytes:
            await tester.runAsync(fixture.databaseSizeBytes) ?? 0,
        measurements: runner.measurements,
        memory: memorySampler.summarize(),
        widgetIssues: runner.widgetIssues,
        generatedAt: DateTime.now().toUtc(),
      );
      final reportFile = await tester.runAsync(() => writeStressReport(report));
      if (reportFile == null) {
        throw StateError('Stress report was not written.');
      }
      _log('report written.');

      expect(generation.statusCounts.total, config.expectedInstallments);
      expect(runner.measurements, isNotEmpty);
      expect(await tester.runAsync(reportFile.exists), isTrue);

      _log('report: ${reportFile.path}');
    },
    skip: !runStressTests,
    timeout: const Timeout(Duration(hours: 2)),
  );
}

void _log(String message) {
  stderr.writeln('Stress suite: $message');
}

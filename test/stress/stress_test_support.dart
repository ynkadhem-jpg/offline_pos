import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:taqseet/screens/accounts.dart';
import 'package:taqseet/screens/customers.dart';
import 'package:taqseet/screens/customers/customer_details_screen.dart';
import 'package:taqseet/screens/dashboard.dart';
import 'package:taqseet/screens/products.dart';
import 'package:taqseet/services/database.dart';
import 'package:taqseet/services/local_backup_service.dart';
import 'package:taqseet/services/payment_dao.dart';
import 'package:taqseet/services/product_dao.dart';
import 'package:taqseet/services/sale_dao.dart';

enum StressPreset { small, medium, large, extreme }

extension StressPresetName on StressPreset {
  String get label => name;
}

class StressDatasetConfig {
  const StressDatasetConfig({
    required this.preset,
    required this.customers,
    required this.sales,
    required this.installmentsPerSale,
    required this.products,
    this.seed = 4308,
  });

  final StressPreset preset;
  final int customers;
  final int sales;
  final int installmentsPerSale;
  final int products;
  final int seed;

  int get expectedInstallments => sales * installmentsPerSale;

  static StressDatasetConfig fromPreset(StressPreset preset) {
    return switch (preset) {
      StressPreset.small => const StressDatasetConfig(
        preset: StressPreset.small,
        customers: 100,
        sales: 500,
        installmentsPerSale: 6,
        products: 50,
      ),
      StressPreset.medium => const StressDatasetConfig(
        preset: StressPreset.medium,
        customers: 1000,
        sales: 5000,
        installmentsPerSale: 12,
        products: 150,
      ),
      StressPreset.large => const StressDatasetConfig(
        preset: StressPreset.large,
        customers: 5000,
        sales: 25000,
        installmentsPerSale: 12,
        products: 400,
      ),
      StressPreset.extreme => const StressDatasetConfig(
        preset: StressPreset.extreme,
        customers: 10000,
        sales: 50000,
        installmentsPerSale: 24,
        products: 600,
      ),
    };
  }
}

class StressStatusCounts {
  const StressStatusCounts({
    required this.paid,
    required this.partial,
    required this.upcoming,
    required this.overdue,
  });

  final int paid;
  final int partial;
  final int upcoming;
  final int overdue;

  int get total => paid + partial + upcoming + overdue;

  Map<String, Object> toJson() => {
    'paid': paid,
    'partial': partial,
    'upcoming': upcoming,
    'overdue': overdue,
    'total': total,
  };
}

class StressGenerationResult {
  const StressGenerationResult({
    required this.duration,
    required this.statusCounts,
    required this.paymentRows,
  });

  final Duration duration;
  final StressStatusCounts statusCounts;
  final int paymentRows;
}

class StressMeasurement {
  const StressMeasurement({
    required this.name,
    required this.duration,
    required this.memoryBeforeBytes,
    required this.memoryAfterBytes,
  });

  final String name;
  final Duration duration;
  final int memoryBeforeBytes;
  final int memoryAfterBytes;

  int get memoryDeltaBytes => memoryAfterBytes - memoryBeforeBytes;

  Map<String, Object> toJson() => {
    'name': name,
    'durationMs': duration.inMilliseconds,
    'memoryBeforeBytes': memoryBeforeBytes,
    'memoryAfterBytes': memoryAfterBytes,
    'memoryDeltaBytes': memoryDeltaBytes,
  };
}

class StressMemorySummary {
  const StressMemorySummary({
    required this.peakBytes,
    required this.averageBytes,
    required this.samples,
  });

  final int peakBytes;
  final int averageBytes;
  final int samples;

  Map<String, Object> toJson() => {
    'peakBytes': peakBytes,
    'averageBytes': averageBytes,
    'samples': samples,
  };
}

class StressMemorySampler {
  final List<int> _samples = [];

  int sample() {
    final value = ProcessInfo.currentRss;
    _samples.add(value);
    return value;
  }

  StressMemorySummary summarize() {
    if (_samples.isEmpty) {
      return const StressMemorySummary(
        peakBytes: 0,
        averageBytes: 0,
        samples: 0,
      );
    }
    final total = _samples.fold<int>(0, (sum, value) => sum + value);
    return StressMemorySummary(
      peakBytes: _samples.reduce(max),
      averageBytes: total ~/ _samples.length,
      samples: _samples.length,
    );
  }
}

class StressReport {
  StressReport({
    required this.config,
    required this.generation,
    required this.databaseSizeBytes,
    required this.measurements,
    required this.memory,
    required this.widgetIssues,
    required this.generatedAt,
  });

  final StressDatasetConfig config;
  final StressGenerationResult generation;
  final int databaseSizeBytes;
  final List<StressMeasurement> measurements;
  final StressMemorySummary memory;
  final List<String> widgetIssues;
  final DateTime generatedAt;

  Map<String, Object> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'dataset': {
      'preset': config.preset.label,
      'customers': config.customers,
      'products': config.products,
      'sales': config.sales,
      'installmentsPerSale': config.installmentsPerSale,
      'expectedInstallments': config.expectedInstallments,
      'seed': config.seed,
    },
    'generation': {
      'durationMs': generation.duration.inMilliseconds,
      'payments': generation.paymentRows,
      'installmentStatuses': generation.statusCounts.toJson(),
    },
    'databaseSizeBytes': databaseSizeBytes,
    'memory': memory.toJson(),
    'measurements': measurements.map((item) => item.toJson()).toList(),
    'widgetIssues': widgetIssues,
    'detectedBottlenecks': detectedBottlenecks,
    'potentialFutureOptimizations': potentialFutureOptimizations,
  };

  List<String> get detectedBottlenecks {
    return [
      for (final item in measurements)
        if (item.duration > const Duration(seconds: 2))
          '${item.name} took ${item.duration.inMilliseconds}ms',
    ];
  }

  List<String> get potentialFutureOptimizations => const [
    'Add measured SQLite indexes for frequent filters only after comparing EXPLAIN QUERY PLAN results.',
    'Move report filtering into bounded SQL queries if report opening or search latency grows with dataset size.',
    'Introduce pagination/lazy loading for very large customer and report lists if widget scroll measurements exceed frame budget.',
    'Keep backup export off the UI isolate if export time becomes user-visible on large databases.',
  ];

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Stress Test Report')
      ..writeln()
      ..writeln('- Generated at: ${generatedAt.toIso8601String()}')
      ..writeln('- Preset: ${config.preset.label}')
      ..writeln('- Customers: ${config.customers}')
      ..writeln('- Products: ${config.products}')
      ..writeln('- Sales: ${config.sales}')
      ..writeln('- Installments per sale: ${config.installmentsPerSale}')
      ..writeln('- Expected installments: ${config.expectedInstallments}')
      ..writeln('- Payment rows: ${generation.paymentRows}')
      ..writeln('- Database size: ${_formatBytes(databaseSizeBytes)}')
      ..writeln(
        '- Generation duration: ${generation.duration.inMilliseconds}ms',
      )
      ..writeln()
      ..writeln('## Installment Statuses')
      ..writeln()
      ..writeln('| Status | Count |')
      ..writeln('| --- | ---: |')
      ..writeln('| Paid | ${generation.statusCounts.paid} |')
      ..writeln('| Partial | ${generation.statusCounts.partial} |')
      ..writeln('| Upcoming | ${generation.statusCounts.upcoming} |')
      ..writeln('| Overdue | ${generation.statusCounts.overdue} |')
      ..writeln()
      ..writeln('## Timings')
      ..writeln()
      ..writeln('| Measurement | Duration | Memory delta |')
      ..writeln('| --- | ---: | ---: |');

    for (final measurement in measurements) {
      buffer.writeln(
        '| ${measurement.name} | ${measurement.duration.inMilliseconds}ms | '
        '${_formatBytes(measurement.memoryDeltaBytes)} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Memory')
      ..writeln()
      ..writeln('- Peak RSS: ${_formatBytes(memory.peakBytes)}')
      ..writeln('- Average RSS: ${_formatBytes(memory.averageBytes)}')
      ..writeln('- Samples: ${memory.samples}')
      ..writeln()
      ..writeln('## Widget / Rendering Issues')
      ..writeln();

    if (widgetIssues.isEmpty) {
      buffer.writeln('- No Flutter widget exceptions were captured.');
    } else {
      for (final issue in widgetIssues) {
        buffer.writeln('- `${issue.replaceAll('\n', ' ')}`');
      }
    }

    buffer
      ..writeln()
      ..writeln('## Detected Bottlenecks')
      ..writeln();

    if (detectedBottlenecks.isEmpty) {
      buffer.writeln(
        '- No measurement exceeded the 2-second reporting threshold.',
      );
    } else {
      for (final bottleneck in detectedBottlenecks) {
        buffer.writeln('- $bottleneck');
      }
    }

    buffer
      ..writeln()
      ..writeln('## Potential Future Optimizations')
      ..writeln();
    for (final item in potentialFutureOptimizations) {
      buffer.writeln('- $item');
    }

    buffer
      ..writeln()
      ..writeln('## Notes')
      ..writeln()
      ..writeln(
        '- This suite is stored under `test/stress/` and is not included in release builds.',
      )
      ..writeln(
        '- Widget opening and scrolling timings are Flutter test measurements, not physical-device frame timing.',
      )
      ..writeln(
        '- App startup is measured as database-open readiness plus first app screen pump, not APK cold-start from Android launcher.',
      );

    return buffer.toString();
  }

  static String _formatBytes(int bytes) {
    final sign = bytes < 0 ? '-' : '';
    final absolute = bytes.abs();
    if (absolute < 1024) return '$bytes B';
    if (absolute < 1024 * 1024) {
      return '$sign${(absolute / 1024).toStringAsFixed(1)} KB';
    }
    return '$sign${(absolute / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class StressDatabaseFixture {
  static const _pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  late final Directory temporaryDirectory;
  late AppDatabase database;

  Future<void> setUp() async {
    stderr.writeln('Stress fixture: creating workspace database directory...');
    final parent = Directory(
      p.join(Directory.current.path, 'build', 'stress_databases'),
    );
    await parent.create(recursive: true);
    temporaryDirectory = Directory(
      p.join(parent.path, 'run_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await temporaryDirectory.create(recursive: true);
    stderr.writeln('Stress fixture: temp directory ${temporaryDirectory.path}');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _pathProviderChannel,
          (_) async => temporaryDirectory.path,
        );
    stderr.writeln('Stress fixture: creating AppDatabase...');
    database = AppDatabase();
    stderr.writeln('Stress fixture: AppDatabase created.');
  }

  Future<AppDatabase> reopenDatabase() async {
    await database.close();
    database = AppDatabase();
    await database.customSelect('SELECT 1').getSingle();
    return database;
  }

  Future<int> databaseSizeBytes() async {
    var total = 0;
    final files = temporaryDirectory.listSync().whereType<File>().where(
      (file) => p.basename(file.path).startsWith('offline_pos.sqlite'),
    );
    for (final file in files) {
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }

  Future<void> tearDown() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  }
}

class StressDataGenerator {
  StressDataGenerator(this.database, this.config)
    : _random = Random(config.seed);

  final AppDatabase database;
  final StressDatasetConfig config;
  final Random _random;

  int _paid = 0;
  int _partial = 0;
  int _upcoming = 0;
  int _overdue = 0;
  int _paymentRows = 0;

  static const _firstNames = [
    'أحمد',
    'علي',
    'حسين',
    'مصطفى',
    'حيدر',
    'محمد',
    'سجاد',
    'كرار',
    'نور',
    'زينب',
    'فاطمة',
    'مريم',
  ];
  static const _lastNames = [
    'التميمي',
    'الشمري',
    'الجبوري',
    'اللامي',
    'الكعبي',
    'الساعدي',
    'الخفاجي',
    'المالكي',
  ];
  static const _addresses = [
    'Baghdad - Karrada',
    'Baghdad - Mansour',
    'Basra - Ashar',
    'Najaf - Old City',
    'Karbala - Center',
    'Erbil - Ankawa',
    'Mosul - Left Coast',
    'Dhi Qar - Nasiriyah',
  ];
  static const _productNames = [
    'iPhone',
    'Samsung Galaxy',
    'Laptop Lenovo',
    'Laptop HP',
    'PlayStation',
    'ثلاجة',
    'غسالة',
    'مكيف',
    'شاشة',
    'طباخ',
    'مكنسة',
    'جهاز لوحي',
  ];
  static const _phonePrefixes = ['077', '078', '075', '076', '079'];

  Future<StressGenerationResult> generate({
    StressMemorySampler? memorySampler,
  }) async {
    final stopwatch = Stopwatch()..start();
    await _insertProducts();
    memorySampler?.sample();
    await _insertCustomers();
    memorySampler?.sample();
    await _insertSalesInstallmentsAndPayments(memorySampler: memorySampler);
    stopwatch.stop();
    return StressGenerationResult(
      duration: stopwatch.elapsed,
      paymentRows: _paymentRows,
      statusCounts: StressStatusCounts(
        paid: _paid,
        partial: _partial,
        upcoming: _upcoming,
        overdue: _overdue,
      ),
    );
  }

  Future<void> _insertProducts() async {
    final now = DateTime(2026, 1);
    final rows = [
      for (var id = 1; id <= config.products; id++)
        ProductsCompanion(
          id: Value(id),
          name: Value(_productName(id)),
          price: Value(_productPrice(id)),
          isDeleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
    ];
    await database.batch((batch) => batch.insertAll(database.products, rows));
  }

  Future<void> _insertCustomers() async {
    const chunkSize = 1000;
    final rows = <CustomersCompanion>[];
    for (var id = 1; id <= config.customers; id++) {
      rows.add(
        CustomersCompanion(
          id: Value(id),
          name: Value(_customerName(id)),
          address: Value(_addresses[id % _addresses.length]),
          phone: Value(_phoneNumber(id)),
          isDeleted: const Value(false),
          createdAt: Value(DateTime(2025, 1, 1).add(Duration(days: id % 420))),
        ),
      );
      if (rows.length >= chunkSize) {
        await _flushCustomers(rows);
      }
    }
    await _flushCustomers(rows);
  }

  Future<void> _insertSalesInstallmentsAndPayments({
    StressMemorySampler? memorySampler,
  }) async {
    const salesChunkSize = 400;
    var installmentId = 1;
    var paymentId = 1;
    final today = DateTime(2026, 7, 16);
    final salesRows = <SalesCompanion>[];
    final installmentRows = <InstallmentsCompanion>[];
    final paymentRows = <PaymentsCompanion>[];

    for (var saleId = 1; saleId <= config.sales; saleId++) {
      final productId = (saleId % config.products) + 1;
      final customerId = (saleId % config.customers) + 1;
      final price = _productPrice(productId);
      final interest = _roundToNearest(
        price * (0.06 + _random.nextDouble() * 0.22),
        250,
      );
      final total = price + interest;
      final monthlyWithInterest = total / config.installmentsPerSale;
      final monthlyWithoutInterest = price / config.installmentsPerSale;
      final startDate = today.subtract(Duration(days: _random.nextInt(760)));

      salesRows.add(
        SalesCompanion(
          id: Value(saleId),
          customerId: Value(customerId),
          productId: Value(productId),
          originalPrice: Value(price),
          interestAmount: Value(interest),
          totalAmount: Value(total),
          months: Value(config.installmentsPerSale),
          monthlyWithInterest: Value(monthlyWithInterest),
          monthlyWithoutInterest: Value(monthlyWithoutInterest),
          startDate: Value(startDate),
          isDeleted: const Value(false),
          createdAt: Value(startDate),
        ),
      );

      for (var month = 1; month <= config.installmentsPerSale; month++) {
        final dueDate = _addCalendarMonths(startDate, month);
        final totalPaid = _paidAmountFor(dueDate, monthlyWithInterest, today);
        final isPaid = totalPaid >= monthlyWithInterest;
        final currentInstallmentId = installmentId++;
        installmentRows.add(
          InstallmentsCompanion(
            id: Value(currentInstallmentId),
            saleId: Value(saleId),
            monthNumber: Value(month),
            dueDate: Value(dueDate),
            baseAmount: Value(monthlyWithInterest),
            carriedBalance: const Value(0),
            actualDue: Value(monthlyWithInterest),
            totalPaid: Value(totalPaid),
            isPaid: Value(isPaid),
          ),
        );

        if (totalPaid > 0) {
          _paymentRows++;
          paymentRows.add(
            PaymentsCompanion(
              id: Value(paymentId++),
              installmentId: Value(currentInstallmentId),
              amount: Value(totalPaid),
              paymentDate: Value(
                dueDate.subtract(Duration(days: _random.nextInt(5))),
              ),
              note: const Value('Stress test payment'),
            ),
          );
        }
      }

      if (salesRows.length >= salesChunkSize) {
        await _flushSalesData(salesRows, installmentRows, paymentRows);
        memorySampler?.sample();
      }
    }

    await _flushSalesData(salesRows, installmentRows, paymentRows);
  }

  Future<void> _flushCustomers(List<CustomersCompanion> rows) async {
    if (rows.isEmpty) return;
    await database.batch((batch) => batch.insertAll(database.customers, rows));
    rows.clear();
  }

  Future<void> _flushSalesData(
    List<SalesCompanion> salesRows,
    List<InstallmentsCompanion> installmentRows,
    List<PaymentsCompanion> paymentRows,
  ) async {
    if (salesRows.isNotEmpty) {
      await database.batch(
        (batch) => batch.insertAll(database.sales, salesRows),
      );
      salesRows.clear();
    }
    if (installmentRows.isNotEmpty) {
      await database.batch(
        (batch) => batch.insertAll(database.installments, installmentRows),
      );
      installmentRows.clear();
    }
    if (paymentRows.isNotEmpty) {
      await database.batch(
        (batch) => batch.insertAll(database.payments, paymentRows),
      );
      paymentRows.clear();
    }
  }

  String _customerName(int id) {
    final firstName = _firstNames[id % _firstNames.length];
    final lastName = _lastNames[(id ~/ _firstNames.length) % _lastNames.length];
    return '$firstName $lastName $id';
  }

  String _phoneNumber(int id) {
    final prefix = _phonePrefixes[id % _phonePrefixes.length];
    return '$prefix${(10000000 + id).toString().padLeft(8, '0')}';
  }

  String _productName(int id) {
    final base = _productNames[id % _productNames.length];
    return '$base ${id.toString().padLeft(3, '0')}';
  }

  double _productPrice(int id) {
    final base = 150000 + (id % 18) * 75000;
    return _roundToNearest((base + _random.nextInt(1500000)).toDouble(), 1000);
  }

  double _paidAmountFor(DateTime dueDate, double amount, DateTime today) {
    if (dueDate.isAfter(today)) {
      if (_random.nextDouble() < 0.05) {
        _paid++;
        return amount;
      }
      _upcoming++;
      return 0;
    }

    final roll = _random.nextDouble();
    if (roll < 0.52) {
      _paid++;
      return amount;
    }
    if (roll < 0.74) {
      _partial++;
      return _roundToNearest(amount * (0.15 + _random.nextDouble() * 0.7), 250);
    }
    _overdue++;
    return 0;
  }
}

class StressBenchmarkRunner {
  StressBenchmarkRunner({
    required this.tester,
    required this.database,
    required this.fixture,
    required this.memorySampler,
  });

  final WidgetTester tester;
  AppDatabase database;
  final StressDatabaseFixture fixture;
  final StressMemorySampler memorySampler;

  final _measurements = <StressMeasurement>[];
  final _widgetIssues = <String>[];

  List<StressMeasurement> get measurements => List.unmodifiable(_measurements);
  List<String> get widgetIssues => List.unmodifiable(_widgetIssues);

  Future<void> measureAppStartupProxy() async {
    await _measure('App startup proxy', () async {
      await _clearScreen();
      database =
          await tester.runAsync(fixture.reopenDatabase) ??
          (throw StateError('Database reopen did not complete.'));
      await _pumpScreen(DashboardScreen(database: database));
    });
    await _clearScreen();
  }

  Future<void> measureDashboardOpening() async {
    await _measure('Dashboard opening time', () async {
      await _pumpScreen(DashboardScreen(database: database));
    });
  }

  Future<void> measureCustomerListOpening() async {
    await _measure('Customer list opening time', () async {
      await _pumpScreen(
        CustomersScreen(database: database, onDataChanged: () async {}),
      );
    });
  }

  Future<void> measureCustomerSearchLatency() async {
    await _pumpScreen(
      CustomersScreen(database: database, onDataChanged: () async {}),
    );
    await _waitForCustomerSearchField();
    await _measure('Customer search latency', () async {
      final searchField = _findCustomerSearchField();
      if (searchField.evaluate().isEmpty) {
        _widgetIssues.add(
          'Customer search field was not found during the stress benchmark.',
        );
        return;
      }
      await tester.enterText(searchField.first, 'علي');
      await tester.pump();
    });
  }

  Future<void> measureCustomerDetailsOpening() async {
    final customer = await tester.runAsync(
      () =>
          (database.select(database.customers)
                ..where((row) => row.isDeleted.equals(false))
                ..limit(1))
              .getSingle(),
    );
    if (customer == null) {
      throw StateError('No customer was available for details benchmark.');
    }
    await _measure('Customer details opening time', () async {
      await _pumpScreen(
        CustomerDetailsScreen(
          customer: customer,
          paymentDao: PaymentDao(database),
          productDao: ProductDao(database),
          saleDao: SaleDao(database),
          onDataChanged: () async {},
        ),
      );
    });
  }

  Future<void> measurePaymentExecution() async {
    final installment = await tester.runAsync(
      () =>
          (database.select(database.installments)
                ..where((row) => row.isPaid.equals(false))
                ..limit(1))
              .getSingleOrNull(),
    );
    if (installment == null) return;

    final remaining = installment.actualDue - installment.totalPaid;
    await _measure('Payment execution time', () async {
      await tester.runAsync(
        () => PaymentDao(database).recordPayment(
          installmentId: installment.id,
          amount: remaining < 1000 ? remaining : 1000,
          paymentDate: DateTime(2026, 7, 16),
          note: 'Stress test payment',
        ),
      );
    });
  }

  Future<void> measureReportsOpening() async {
    await _measure('Reports opening time', () async {
      await _pumpScreen(AccountsScreen(database: database));
    });
  }

  Future<void> measureBackupExport() async {
    final backupService = LocalBackupService(
      clock: () => DateTime(2026, 7, 16),
    );
    await _measure('Backup export time', () async {
      await _clearScreen();
      final result = await tester.runAsync(
        () => backupService.createExportSnapshot(database),
      );
      if (result == null) {
        throw StateError('Backup export did not complete.');
      }
      final artifact = result.artifact;
      if (artifact != null) {
        await tester.runAsync(artifact.dispose);
      }
      if (!result.isSuccess) {
        throw StateError('Backup export failed: ${result.failure?.code}');
      }
    });
  }

  Future<void> measureScrolling() async {
    stderr.writeln('Stress suite: scrolling customers...');
    await _measure('Customer list scrolling', () async {
      await _pumpScreen(
        CustomersScreen(database: database, onDataChanged: () async {}),
      );
      await _scrollPrimary();
    });
    stderr.writeln('Stress suite: customers scrolling complete.');
    await _clearScreen();
    stderr.writeln('Stress suite: scrolling products...');
    await _measure('Product list scrolling', () async {
      await _pumpScreen(
        ProductsScreen(database: database, onDataChanged: () async {}),
      );
      await _scrollPrimary();
    });
    stderr.writeln('Stress suite: products scrolling complete.');
    await _clearScreen();
    stderr.writeln('Stress suite: scrolling reports...');
    await _measure('Reports scrolling', () async {
      await _pumpScreen(AccountsScreen(database: database));
      await _scrollPrimary();
    });
    stderr.writeln('Stress suite: reports scrolling complete.');
    await _clearScreen();
    stderr.writeln('Stress suite: scrolling customer details...');
    final customer = await tester.runAsync(
      () =>
          (database.select(database.customers)
                ..where((row) => row.isDeleted.equals(false))
                ..limit(1))
              .getSingle(),
    );
    if (customer == null) {
      throw StateError('No customer was available for scrolling benchmark.');
    }
    await _measure('Customer details scrolling', () async {
      await _measure('Customer details scroll setup', () async {
        await _pumpScreen(
          CustomerDetailsScreen(
            customer: customer,
            paymentDao: PaymentDao(database),
            productDao: ProductDao(database),
            saleDao: SaleDao(database),
            onDataChanged: () async {},
          ),
        );
      });
      await _measure('Customer details scroll operation', () async {
        await _scrollPrimary(steps: 1);
      });
    });
    stderr.writeln('Stress suite: customer details scrolling complete.');
    await _clearScreen();
  }

  Future<void> _measure(String name, Future<void> Function() action) async {
    final before = memorySampler.sample();
    final stopwatch = Stopwatch()..start();
    await action();
    stopwatch.stop();
    final after = memorySampler.sample();
    _measurements.add(
      StressMeasurement(
        name: name,
        duration: stopwatch.elapsed,
        memoryBeforeBytes: before,
        memoryAfterBytes: after,
      ),
    );
  }

  Future<void> _pumpScreen(Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder _findCustomerSearchField() {
    final byHint = find.byWidgetPredicate((widget) {
      return widget is TextField &&
          widget.decoration?.hintText == 'ابحث باسم الزبون';
    });
    if (byHint.evaluate().isNotEmpty) {
      return byHint;
    }

    final textFields = find.byType(TextField);
    if (textFields.evaluate().isNotEmpty) {
      return textFields;
    }

    return find.byType(EditableText);
  }

  Future<void> _waitForCustomerSearchField() async {
    for (var attempt = 0; attempt < 50; attempt++) {
      if (_findCustomerSearchField().evaluate().isNotEmpty) {
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Future<void> _clearScreen() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> _scrollPrimary({int steps = 8}) async {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) return;
    final target = scrollable.first;
    final state = tester.state<ScrollableState>(target);
    final position = state.position;
    for (var i = 0; i < steps; i++) {
      final nextOffset = (position.pixels + 700).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      position.jumpTo(nextOffset);
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  void drainWidgetExceptions() {
    for (var i = 0; i < 20; i++) {
      final exception = tester.takeException();
      if (exception == null) return;
      _widgetIssues.add(exception.toString());
    }
  }
}

Future<File> writeStressReport(StressReport report) async {
  final directory = Directory(
    p.join(Directory.current.path, 'build', 'stress_reports'),
  );
  await directory.create(recursive: true);
  final stamp = report.generatedAt
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '');
  final baseName = 'stress_${report.config.preset.label}_$stamp';
  final jsonFile = File(p.join(directory.path, '$baseName.json'));
  final markdownFile = File(p.join(directory.path, '$baseName.md'));
  await jsonFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report.toJson()),
  );
  await markdownFile.writeAsString(report.toMarkdown());
  return markdownFile;
}

StressPreset stressPresetFromEnvironment() {
  const value = String.fromEnvironment('STRESS_PRESET', defaultValue: 'small');
  return StressPreset.values.firstWhere(
    (preset) => preset.name == value.toLowerCase(),
    orElse: () => StressPreset.small,
  );
}

double _roundToNearest(double value, int nearest) {
  return (value / nearest).round() * nearest.toDouble();
}

DateTime _addCalendarMonths(DateTime date, int monthsToAdd) {
  final monthIndex = date.year * 12 + date.month - 1 + monthsToAdd;
  final targetYear = monthIndex ~/ 12;
  final targetMonth = monthIndex % 12 + 1;
  final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
  final targetDay = date.day <= lastDayOfTargetMonth
      ? date.day
      : lastDayOfTargetMonth;
  return DateTime(
    targetYear,
    targetMonth,
    targetDay,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

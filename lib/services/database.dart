import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get address => text()();
  TextColumn get phone => text()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get originalPrice => real()();
  RealColumn get interestAmount => real()();
  RealColumn get totalAmount => real()();
  IntColumn get months => integer()();
  RealColumn get monthlyWithInterest => real()();
  RealColumn get monthlyWithoutInterest => real()();
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class Installments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get monthNumber => integer()();
  DateTimeColumn get dueDate => dateTime()();
  RealColumn get baseAmount => real()();
  RealColumn get carriedBalance => real()();
  RealColumn get actualDue => real()();
  RealColumn get totalPaid => real()();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get installmentId => integer().references(Installments, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get paymentDate => dateTime()();
  TextColumn get note => text().nullable()();
}

@DriftDatabase(tables: [Products, Customers, Sales, Installments, Payments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'offline_pos.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

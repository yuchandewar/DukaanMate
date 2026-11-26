import 'package:drift/drift.dart';

@DataClassName('Shop')
class Shops extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get ownerName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Product')
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get sellingPrice => real()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get unit => text()();
  RealColumn get gstPercentage => real().withDefault(const Constant(0.0))();
  TextColumn get barcode => text().nullable()();
  RealColumn get stockQuantity => real().withDefault(const Constant(0.0))();
  RealColumn get minStockLevel => real().withDefault(const Constant(0.0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Bill')
class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get billNumber => text().unique()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get gstAmount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('Cash'))();
  IntColumn get customerId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('BillItem')
class BillItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get billId => integer().references(Bills, #id)();
  IntColumn get productId => integer().nullable().references(Products, #id)();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  RealColumn get price => real()(); 
  RealColumn get total => real()();
}

@DataClassName('Customer')
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get alternatePhone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  RealColumn get creditBalance => real().withDefault(const Constant(0.0))(); // Positive means they owe money
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  
  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('Expense')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get category => text().withDefault(const Constant('General'))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

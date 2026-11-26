import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'app_database.dart';
import 'database_provider.dart';

// --- Providers ---
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProductRepository(db);
});

final billRepositoryProvider = Provider<BillRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BillRepository(db);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CustomerRepository(db);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ExpenseRepository(db);
});

// --- Repositories ---

class ProductRepository {
  final AppDatabase _db;
  ProductRepository(this._db);

  Stream<List<Product>> watchAllProducts() {
    return _db.select(_db.products).watch();
  }

  Future<List<Product>> searchProducts(String query) {
    if (query.isEmpty) return Future.value([]);
    return (_db.select(_db.products)..where((tbl) => tbl.name.like('%$query%'))).get();
  }

  Stream<List<Product>> watchFavoriteProducts() {
    return (_db.select(_db.products)..where((tbl) => tbl.isFavorite.equals(true))).watch();
  }

  Stream<List<Product>> watchLowStockProducts({double threshold = 5.0}) {
    return (_db.select(_db.products)
          ..where((tbl) => tbl.stockQuantity.isSmallerOrEqualValue(threshold))
          ..orderBy([(t) => OrderingTerm(expression: t.stockQuantity, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<int> addProduct(ProductsCompanion product) {
    return _db.into(_db.products).insert(product);
  }

  Future<bool> updateProduct(Product product) {
    return _db.update(_db.products).replace(product);
  }

  Future<int> deleteProduct(int id) {
    return (_db.delete(_db.products)..where((tbl) => tbl.id.equals(id))).go();
  }
}

class BillRepository {
  final AppDatabase _db;
  BillRepository(this._db);

  Stream<List<Bill>> watchAllBills() {
    return (_db.select(_db.bills)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<Bill>> watchTodaysBills() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return (_db.select(_db.bills)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startOfDay))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<Bill>> watchMonthlyBills(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    
    return (_db.select(_db.bills)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<BillItem>> getBillItems(int billId) {
    return (_db.select(_db.billItems)..where((tbl) => tbl.billId.equals(billId))).get();
  }

  Stream<List<Bill>> watchBillsForCustomer(int customerId) {
    return (_db.select(_db.bills)
          ..where((tbl) => tbl.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  // Transactions are critical so we don't save a partial bill.
  Future<void> saveCompleteBill({
    required BillsCompanion bill,
    required List<BillItemsCompanion> items,
  }) async {
    await _db.transaction(() async {
      // 1. Insert the Bill
      final billId = await _db.into(_db.bills).insert(bill);

      // 1.5 Update customer credit if this is a credit bill and customer is linked
      if (bill.paymentMethod.present && bill.paymentMethod.value == 'Credit') {
        if (bill.customerId.present && bill.customerId.value != null) {
          final customerId = bill.customerId.value!;
          final unpaidAmount = bill.total.value - bill.amountPaid.value;
          
          if (unpaidAmount > 0) {
            final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(customerId))).getSingleOrNull();
            if (customer != null) {
              final newBalance = customer.creditBalance + unpaidAmount;
              await _db.update(_db.customers).replace(customer.copyWith(
                creditBalance: newBalance,
                updatedAt: DateTime.now(),
              ));
            }
          }
        }
      }

      // 2. Insert all Bill Items with the returned Bill ID
      for (var item in items) {
        final itemWithBillId = item.copyWith(billId: Value(billId));
        await _db.into(_db.billItems).insert(itemWithBillId);
        
        // 3. Optional: Deduct stock if product is linked
        if (item.productId.present && item.productId.value != null) {
          final productId = item.productId.value!;
          final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(productId))).getSingleOrNull();
          
          if (product != null && item.quantity.present) {
            final newStock = product.stockQuantity - item.quantity.value;
            await _db.update(_db.products).replace(product.copyWith(
              stockQuantity: newStock,
              updatedAt: DateTime.now(),
            ));
          }
        }
      }
    });
  }

  Future<void> settleCustomerCredit(int customerId, double paymentAmount) async {
    await _db.transaction(() async {
      // 1. Fetch all unpaid credit bills (amountPaid < total) for this customer, oldest first
      final unpaidBills = await (_db.select(_db.bills)
            ..where((tbl) => tbl.customerId.equals(customerId) & tbl.amountPaid.isSmallerThan(tbl.total))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
          .get();

      double remainingPayment = paymentAmount;

      for (var bill in unpaidBills) {
        if (remainingPayment <= 0) break;

        final unpaidAmount = bill.total - bill.amountPaid;

        if (remainingPayment >= unpaidAmount) {
          // Pay this bill completely
          await _db.update(_db.bills).replace(bill.copyWith(amountPaid: bill.total));
          remainingPayment -= unpaidAmount;
        } else {
          // Pay this bill partially
          await _db.update(_db.bills).replace(bill.copyWith(amountPaid: bill.amountPaid + remainingPayment));
          remainingPayment = 0;
        }
      }

      // 2. Update Customer's overall credit balance
      final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(customerId))).getSingleOrNull();
      if (customer != null) {
        final newBalance = customer.creditBalance - paymentAmount;
        await _db.update(_db.customers).replace(customer.copyWith(
          creditBalance: newBalance < 0 ? 0 : newBalance, // Prevent negative balance if they overpay
          updatedAt: DateTime.now(),
        ));
      }
    });
  }

  Future<void> settleSpecificBill(int billId, double paymentAmount) async {
    await _db.transaction(() async {
      final bill = await (_db.select(_db.bills)..where((t) => t.id.equals(billId))).getSingleOrNull();
      if (bill == null) return;

      final unpaidAmount = bill.total - bill.amountPaid;
      final actualPayment = paymentAmount > unpaidAmount ? unpaidAmount : paymentAmount;

      if (actualPayment <= 0) return;

      // Update bill
      await _db.update(_db.bills).replace(bill.copyWith(amountPaid: bill.amountPaid + actualPayment));

      // Update customer balance if linked
      if (bill.customerId != null) {
        final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(bill.customerId!))).getSingleOrNull();
        if (customer != null) {
          final newBalance = customer.creditBalance - actualPayment;
          await _db.update(_db.customers).replace(customer.copyWith(
            creditBalance: newBalance < 0 ? 0 : newBalance,
            updatedAt: DateTime.now(),
          ));
        }
      }
    });
  }
}

class CustomerRepository {
  final AppDatabase _db;
  CustomerRepository(this._db);

  Stream<List<Customer>> watchAllCustomers() {
    return (_db.select(_db.customers)
          ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<Customer?> getCustomerById(int id) {
    return (_db.select(_db.customers)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Stream<Customer> watchCustomerById(int id) {
    return (_db.select(_db.customers)..where((tbl) => tbl.id.equals(id))).watchSingle();
  }

  Future<int> addCustomer(CustomersCompanion customer) {
    return _db.into(_db.customers).insert(customer);
  }

  Future<bool> updateCustomer(Customer customer) {
    return _db.update(_db.customers).replace(customer);
  }

  Future<int> deleteCustomer(int id) {
    return (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();
  }
}

class ExpenseRepository {
  final AppDatabase _db;
  ExpenseRepository(this._db);

  Stream<List<Expense>> watchAllExpenses() {
    return (_db.select(_db.expenses)
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<Expense>> watchMonthlyExpenses(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    
    return (_db.select(_db.expenses)
          ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> addExpense(ExpensesCompanion expense) {
    return _db.into(_db.expenses).insert(expense);
  }

  Future<bool> updateExpense(Expense expense) {
    return _db.update(_db.expenses).replace(expense);
  }

  Future<int> deleteExpense(int id) {
    return (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();
  }
}

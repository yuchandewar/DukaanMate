import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:dukaan_mate/core/database/repositories.dart';
import 'package:dukaan_mate/core/database/app_database.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productRepo = ref.watch(productRepositoryProvider);
    final productsStream = productRepo.watchAllProducts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: productsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final products = snapshot.data ?? [];
          
          if (products.isEmpty) {
            return const Center(
              child: Text('No products added yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product, context, productRepo);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, productRepo),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildProductCard(Product product, BuildContext context, ProductRepository repo) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _showProductDialog(context, repo, existingProduct: product),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Stock: ${product.stockQuantity} ${product.unit}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₹${product.sellingPrice}/${product.unit}', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)
            ),
            IconButton(
              icon: Icon(
                product.isFavorite ? Icons.star : Icons.star_border,
                color: product.isFavorite ? Colors.orange : Colors.grey,
              ),
              onPressed: () {
                repo.updateProduct(product.copyWith(isFavorite: !product.isFavorite));
              },
            )
          ],
        ),
      ),
    );
  }

  void _showProductDialog(BuildContext context, ProductRepository repo, {Product? existingProduct}) {
    final nameCtrl = TextEditingController(text: existingProduct?.name ?? '');
    final priceCtrl = TextEditingController(text: existingProduct?.sellingPrice.toString() ?? '');
    final stockCtrl = TextEditingController(text: existingProduct?.stockQuantity.toString() ?? '');
    String unit = existingProduct?.unit ?? 'kg';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingProduct == null ? 'Add New Product' : 'Edit Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Product Name (e.g. Rice)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Selling Price (₹)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: stockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Current Stock'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: ['kg', 'g', 'litre', 'ml', 'piece', 'dozen'].map((u) {
                        return DropdownMenuItem(value: u, child: Text(u));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => unit = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                    
                    if (existingProduct == null) {
                      final newProduct = ProductsCompanion(
                        name: drift.Value(nameCtrl.text),
                        sellingPrice: drift.Value(double.tryParse(priceCtrl.text) ?? 0.0),
                        stockQuantity: drift.Value(double.tryParse(stockCtrl.text) ?? 0.0),
                        unit: drift.Value(unit),
                      );
                      repo.addProduct(newProduct);
                    } else {
                      repo.updateProduct(existingProduct.copyWith(
                        name: nameCtrl.text,
                        sellingPrice: double.tryParse(priceCtrl.text) ?? 0.0,
                        stockQuantity: double.tryParse(stockCtrl.text) ?? 0.0,
                        unit: unit,
                      ));
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}

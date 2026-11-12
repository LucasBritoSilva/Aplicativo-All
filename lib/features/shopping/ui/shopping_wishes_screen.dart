import 'package:flutter/material.dart';

import '../../wishes/ui/wishes_tab.dart';
import 'shopping_screen.dart';

/// Lista de compras e desejos: duas áreas no mesmo módulo.
class ShoppingWishesScreen extends StatelessWidget {
  const ShoppingWishesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compras e desejos'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Mercado'),
              Tab(icon: Icon(Icons.card_giftcard), text: 'Desejos'),
            ],
          ),
        ),
        body: const TabBarView(children: [ShoppingScreen(), WishesTab()]),
      ),
    );
  }
}

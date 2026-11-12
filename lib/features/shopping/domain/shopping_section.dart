import 'package:flutter/material.dart';

/// Seções do mercado, na ordem em que aparecem na lista.
enum ShoppingSection {
  hortifruti('Hortifrúti', Icons.eco_outlined),
  acougue('Açougue', Icons.set_meal_outlined),
  laticinios('Laticínios', Icons.egg_outlined),
  limpeza('Limpeza', Icons.cleaning_services_outlined),
  higiene('Higiene', Icons.soap_outlined),
  mercearia('Mercearia', Icons.shopping_basket_outlined),
  outros('Outros', Icons.more_horiz);

  const ShoppingSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

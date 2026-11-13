import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Texto do rodapé, exatamente como deve aparecer.
const appFooterText = 'BrutAll - App desenvolvido por Lucas Brito Silva';

/// Rodapé discreto exibido no fim de todas as páginas.
///
/// Fica numa faixa própria abaixo do conteúdo (não flutua sobre ele) e
/// respeita a área segura da tela (barra de navegação do Android).
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: const Text(
            appFooterText,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontSize: 11, color: AppColors.textFaint),
          ),
        ),
      ),
    );
  }
}

/// Coloca o [AppFooter] abaixo de todas as páginas do app.
///
/// Usado no `builder` do MaterialApp: assim toda rota (tela inicial,
/// módulos, configurações) ganha o rodapé sem repetir código. Com o
/// teclado aberto, o rodapé sai do caminho para não ocupar espaço.
class WithAppFooter extends StatelessWidget {
  const WithAppFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    if (keyboardOpen) return child;
    return Column(
      children: [
        Expanded(
          // O rodapé já cuida da área segura de baixo.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .removeViewPadding(removeBottom: true),
              child: child,
            ),
          ),
        ),
        const AppFooter(),
      ],
    );
  }
}

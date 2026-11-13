import 'package:flutter/material.dart';

/// Opções de cor principal (Configurações → Cor do aplicativo).
const accentChoices = <(String, Color)>[
  ('Roxo (original)', Color(0xFF9D7BFF)),
  ('Azul', Color(0xFF6EA8FE)),
  ('Ciano', Color(0xFF4DD0E1)),
  ('Verde', Color(0xFF66D19E)),
  ('Lima', Color(0xFFB5D94A)),
  ('Âmbar', Color(0xFFF5B942)),
  ('Laranja', Color(0xFFFF8A4C)),
  ('Vermelho', Color(0xFFFF5C5C)),
  ('Rosa', Color(0xFFF178B6)),
];

/// Cores do app: fundo quase preto e uma cor de destaque escolhida pelo
/// usuário (roxo por padrão). As cores de estado (erro, sucesso, atenção)
/// não mudam com a escolha.
abstract final class AppColors {
  static const background = Color(0xFF0C0C0F);
  static const surface = Color(0xFF15151A);
  static const surfaceHigh = Color(0xFF1D1D24);
  static const outline = Color(0xFF2A2A33);

  /// Roxo original.
  static const defaultPrimary = Color(0xFF9D7BFF);

  /// Cor de destaque atual (muda com [applyAccent]).
  static Color primary = defaultPrimary;

  /// Versão escura do destaque (barras, contêineres).
  static Color primaryDim = _dim(defaultPrimary);

  /// Cor do texto sobre o destaque, sempre com bom contraste.
  static Color onPrimary = _on(defaultPrimary);

  /// Fundo de contêineres do destaque (chips selecionados etc.).
  static Color primaryContainer = _container(defaultPrimary);

  static void applyAccent(Color color) {
    primary = color;
    primaryDim = _dim(color);
    onPrimary = _on(color);
    primaryContainer = _container(color);
  }

  static Color _dim(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.72).clamp(0.0, 1.0)).toColor();
  }

  static Color _container(Color c) =>
      Color.alphaBlend(c.withValues(alpha: 0.22), surface);

  static Color _on(Color c) =>
      c.computeLuminance() > 0.35 ? const Color(0xFF111114) : Colors.white;
  static const text = Color(0xFFEDEDF2);
  static const textMuted = Color(0xFF9A9AA6);
  static const textFaint = Color(0xFF65656F);
  static const danger = Color(0xFFF07A74);

  /// Estados: concluído, atenção (parcial/pausado) e informação (retomada).
  static const success = Color(0xFF6FCF97);
  static const warning = Color(0xFFE5B567);
  static const info = Color(0xFF6FB6E8);
}

/// Tema escuro único do app (sem modo claro nesta versão).
ThemeData buildAppTheme() {
  const radius = 14.0;
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
  );

  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.text,
    secondary: AppColors.primary,
    onSecondary: AppColors.onPrimary,
    secondaryContainer: AppColors.primaryContainer,
    onSecondaryContainer: AppColors.text,
    surface: AppColors.background,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.background,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceHigh,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
    error: AppColors.danger,
    onError: const Color(0xFF130A26),
    shadow: Colors.transparent,
    scrim: Colors.black,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
  );

  final text = base.textTheme.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w500),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: rounded,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.primary.withValues(alpha: 0.18),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? AppColors.text
              : AppColors.textMuted,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      hintStyle: const TextStyle(color: AppColors.textFaint),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryDim),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: AppColors.textFaint, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(AppColors.onPrimary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.onPrimary
            : AppColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.surfaceHigh,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.2),
        selectedForegroundColor: AppColors.text,
        foregroundColor: AppColors.textMuted,
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.primary.withValues(alpha: 0.22),
      side: BorderSide.none,
      labelStyle: const TextStyle(color: AppColors.text, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      showCheckmark: false,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.outline,
      circularTrackColor: AppColors.outline,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      thickness: 0.6,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textMuted,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: AppColors.outline,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: AppColors.text),
      actionTextColor: AppColors.primary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

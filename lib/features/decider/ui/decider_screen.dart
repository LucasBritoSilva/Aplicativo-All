import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/decider_logic.dart';

/// Decisor aleatório: sorteio de números e de opções escritas.
/// Os últimos valores digitados ficam guardados para a próxima vez.
class DeciderScreen extends ConsumerStatefulWidget {
  const DeciderScreen({super.key});

  @override
  ConsumerState<DeciderScreen> createState() => _DeciderScreenState();
}

class _DeciderScreenState extends ConsumerState<DeciderScreen> {
  final _min = TextEditingController(text: '1');
  final _max = TextEditingController(text: '10');
  final _options = TextEditingController();
  String? _numberResult;
  String? _optionResult;
  String? _numberError;
  String? _optionError;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final raw = await ref
        .read(settingsRepositoryProvider)
        .read(SettingKeys.decider);
    if (raw == null || !mounted) return;
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      setState(() {
        _min.text = '${m['min'] ?? 1}';
        _max.text = '${m['max'] ?? 10}';
        _options.text = (m['options'] as String?) ?? '';
      });
    } on Object {
      // Valores antigos ilegíveis: começa com os padrões.
    }
  }

  Future<void> _remember() => ref
      .read(settingsRepositoryProvider)
      .write(
        SettingKeys.decider,
        jsonEncode({
          'min': _min.text,
          'max': _max.text,
          'options': _options.text,
        }),
      );

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _options.dispose();
    super.dispose();
  }

  void _drawNumber() {
    final min = int.tryParse(_min.text.trim());
    final max = int.tryParse(_max.text.trim());
    final error = validateRange(min, max);
    setState(() {
      _numberError = error;
      _numberResult = error == null ? '${drawNumber(min!, max!)}' : null;
    });
    if (error == null) {
      HapticFeedback.lightImpact();
      _remember();
    }
  }

  void _drawOption() {
    final options = parseOptions(_options.text);
    setState(() {
      _optionError = options.length < 2
          ? 'Escreva pelo menos duas opções.'
          : null;
      _optionResult = options.length < 2 ? null : drawOption(options);
    });
    if (options.length >= 2) {
      HapticFeedback.lightImpact();
      _remember();
    }
  }

  Widget _result(String? value, String placeholder) => Container(
    height: 96,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
    ),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Text(
        value ?? placeholder,
        key: ValueKey('$value${DateTime.now().microsecondsSinceEpoch}'),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: value == null
            ? const TextStyle(color: AppColors.textMuted)
            : const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget numberField(TextEditingController c, String label) => Expanded(
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
        ],
        decoration: InputDecoration(labelText: label),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Decisor aleatório')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sortear número',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      numberField(_min, 'Mínimo'),
                      const SizedBox(width: 12),
                      numberField(_max, 'Máximo'),
                    ],
                  ),
                  if (_numberError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _numberError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _result(_numberResult, 'O número sorteado aparece aqui'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _drawNumber,
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(
                      _numberResult == null ? 'Sortear' : 'Sortear de novo',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sortear opção',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _options,
                    minLines: 3,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText:
                          'Opções (uma por linha ou separadas por vírgula)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_optionError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _optionError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _result(_optionResult, 'A opção sorteada aparece aqui'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _drawOption,
                    icon: const Icon(Icons.shuffle),
                    label: Text(
                      _optionResult == null ? 'Sortear' : 'Sortear de novo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

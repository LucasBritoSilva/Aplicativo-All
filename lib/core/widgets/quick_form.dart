import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'common.dart';

/// Descrição de um campo de formulário.
///
/// Os módulos descrevem seus campos com estas classes e o
/// [showQuickForm] monta a tela, valida e devolve os valores. Assim todo
/// cadastro do app tem a mesma aparência e as mesmas validações.
sealed class FieldSpec {
  const FieldSpec(this.key, this.label);
  final String key;
  final String label;
}

/// Campo de texto (uma ou várias linhas).
class TextSpec extends FieldSpec {
  const TextSpec(
    super.key,
    super.label, {
    this.initial,
    this.required = false,
    this.lines = 1,
    this.keyboard,
    this.capitalization = TextCapitalization.sentences,
    this.autofocus = false,
  });

  final String? initial;
  final bool required;
  final int lines;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;
  final bool autofocus;
}

/// Campo numérico. Aceita vírgula ou ponto como separador decimal.
class NumberSpec extends FieldSpec {
  const NumberSpec(
    super.key,
    super.label, {
    this.initial,
    this.required = false,
    this.decimal = true,
    this.min,
    this.max,
    this.suffix,
  });

  final double? initial;
  final bool required;
  final bool decimal;
  final double? min;
  final double? max;
  final String? suffix;
}

/// Data (sem hora).
class DateSpec extends FieldSpec {
  const DateSpec(super.key, super.label, {this.initial, this.required = false});

  final DateTime? initial;
  final bool required;
}

/// Horário, em minutos desde a meia-noite.
class TimeSpec extends FieldSpec {
  const TimeSpec(super.key, super.label, {this.initial, this.required = false});

  final int? initial;
  final bool required;
}

/// Escolha de uma entre várias opções.
class ChoiceSpec<T> extends FieldSpec {
  const ChoiceSpec(
    super.key,
    super.label, {
    required this.options,
    required this.initial,
  });

  /// Cada opção é (valor, texto mostrado).
  final List<(T, String)> options;
  final T initial;
}

/// Liga/desliga.
class SwitchSpec extends FieldSpec {
  const SwitchSpec(
    super.key,
    super.label, {
    this.initial = false,
    this.subtitle,
  });

  final bool initial;
  final String? subtitle;
}

/// Valores preenchidos em um [showQuickForm].
class FormResult {
  FormResult(this._values, {this.deleted = false});

  final Map<String, Object?> _values;

  /// Verdadeiro se o usuário tocou no botão de excluir.
  final bool deleted;

  /// Texto já sem espaços nas pontas ('' se vazio).
  String text(String key) => (_values[key] as String?) ?? '';

  /// Texto, ou nulo se o campo ficou vazio.
  String? textOrNull(String key) {
    final t = text(key);
    return t.isEmpty ? null : t;
  }

  double? number(String key) => _values[key] as double?;

  int? integer(String key) => number(key)?.round();

  DateTime? date(String key) => _values[key] as DateTime?;

  /// Minutos desde a meia-noite.
  int? time(String key) => _values[key] as int?;

  T choice<T>(String key) => _values[key] as T;

  bool flag(String key) => (_values[key] as bool?) ?? false;
}

/// Abre um formulário em folha inferior e devolve os valores preenchidos.
///
/// Devolve nulo se o usuário fechou sem salvar. Se [deleteLabel] for
/// informado, aparece um botão de excluir e o resultado vem com
/// [FormResult.deleted] verdadeiro (quem chamou confirma e apaga).
Future<FormResult?> showQuickForm(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  String submitLabel = 'Salvar',
  String? deleteLabel,
  String? Function(FormResult values)? validate,
}) {
  return showFormSheet<FormResult>(
    context,
    title: title,
    builder: (_) => _QuickForm(
      fields: fields,
      submitLabel: submitLabel,
      deleteLabel: deleteLabel,
      validate: validate,
    ),
  );
}

class _QuickForm extends StatefulWidget {
  const _QuickForm({
    required this.fields,
    required this.submitLabel,
    required this.deleteLabel,
    required this.validate,
  });

  final List<FieldSpec> fields;
  final String submitLabel;
  final String? deleteLabel;
  final String? Function(FormResult values)? validate;

  @override
  State<_QuickForm> createState() => _QuickFormState();
}

class _QuickFormState extends State<_QuickForm> {
  final _controllers = <String, TextEditingController>{};
  final _values = <String, Object?>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      switch (f) {
        case TextSpec():
          _controllers[f.key] = TextEditingController(text: f.initial);
        case NumberSpec():
          _controllers[f.key] = TextEditingController(
            text: f.initial == null ? '' : formatNumber(f.initial!),
          );
        case DateSpec():
          _values[f.key] = f.initial == null ? null : dateOnly(f.initial!);
        case TimeSpec():
          _values[f.key] = f.initial;
        case ChoiceSpec():
          _values[f.key] = f.initial;
        case SwitchSpec():
          _values[f.key] = f.initial;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  FormResult? _fail(String message) {
    setState(() => _error = message);
    return null;
  }

  FormResult? _collect() {
    final out = Map<String, Object?>.of(_values);
    for (final f in widget.fields) {
      switch (f) {
        case TextSpec():
          final t = _controllers[f.key]!.text.trim();
          if (f.required && t.isEmpty) return _fail('Preencha "${f.label}".');
          out[f.key] = t;
        case NumberSpec():
          final raw = _controllers[f.key]!.text.trim();
          final n = parseNumber(raw);
          if (raw.isNotEmpty && n == null) {
            return _fail('"${f.label}" precisa ser um número.');
          }
          if (f.required && n == null) return _fail('Preencha "${f.label}".');
          if (n != null) {
            if (!f.decimal && n != n.roundToDouble()) {
              return _fail('"${f.label}" precisa ser um número inteiro.');
            }
            if (f.min != null && n < f.min!) {
              return _fail(
                '"${f.label}" não pode ser menor que ${formatNumber(f.min!)}.',
              );
            }
            if (f.max != null && n > f.max!) {
              return _fail(
                '"${f.label}" não pode ser maior que ${formatNumber(f.max!)}.',
              );
            }
          }
          out[f.key] = n;
        case DateSpec():
          if (f.required && out[f.key] == null) {
            return _fail('Escolha "${f.label}".');
          }
        case TimeSpec():
          if (f.required && out[f.key] == null) {
            return _fail('Escolha "${f.label}".');
          }
        case ChoiceSpec():
        case SwitchSpec():
          break;
      }
    }
    final result = FormResult(out);
    final message = widget.validate?.call(result);
    if (message != null) return _fail(message);
    return result;
  }

  void _submit() {
    final result = _collect();
    if (result != null) Navigator.pop(context, result);
  }

  Widget _choice(ChoiceSpec<Object?> f) {
    final value = _values[f.key];
    if (f.options.length <= 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(f.label, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          SegmentedButton<Object?>(
            showSelectedIcon: false,
            segments: [
              for (final (v, label) in f.options)
                ButtonSegment(value: v, label: Text(label)),
            ],
            selected: {value},
            onSelectionChanged: (s) => setState(() => _values[f.key] = s.first),
          ),
        ],
      );
    }
    return DropdownButtonFormField<Object?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: f.label),
      items: [
        for (final (v, label) in f.options)
          DropdownMenuItem(value: v, child: Text(label)),
      ],
      onChanged: (v) => setState(() => _values[f.key] = v),
    );
  }

  Widget _field(FieldSpec f) {
    switch (f) {
      case TextSpec():
        return TextField(
          controller: _controllers[f.key],
          autofocus: f.autofocus,
          minLines: f.lines > 1 ? 2 : 1,
          maxLines: f.lines,
          keyboardType:
              f.keyboard ?? (f.lines > 1 ? TextInputType.multiline : null),
          textCapitalization: f.capitalization,
          decoration: InputDecoration(labelText: f.label),
        );
      case NumberSpec():
        return TextField(
          controller: _controllers[f.key],
          keyboardType: TextInputType.numberWithOptions(
            decimal: f.decimal,
            signed: (f.min ?? 0) < 0,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(f.decimal ? r'[0-9.,\-]' : r'[0-9\-]'),
            ),
          ],
          decoration: InputDecoration(labelText: f.label, suffixText: f.suffix),
        );
      case DateSpec():
        final date = _values[f.key] as DateTime?;
        return PickerField(
          icon: Icons.event_outlined,
          label: date == null
              ? f.label
              : '${f.label}: ${weekdayShort(date)}, ${formatDate(date)}',
          onTap: () async {
            final picked = await pickDate(
              context,
              initial: date,
              first: DateTime(1900),
            );
            if (picked != null) {
              setState(() => _values[f.key] = dateOnly(picked));
            }
          },
          onClear: f.required || date == null
              ? null
              : () => setState(() => _values[f.key] = null),
        );
      case TimeSpec():
        final minute = _values[f.key] as int?;
        return PickerField(
          icon: Icons.schedule,
          label: minute == null
              ? f.label
              : '${f.label}: ${formatMinute(minute)}',
          onTap: () async {
            final picked = await pickTime(
              context,
              initial: minute == null
                  ? null
                  : TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
            );
            if (picked != null) {
              setState(() => _values[f.key] = picked.hour * 60 + picked.minute);
            }
          },
          onClear: f.required || minute == null
              ? null
              : () => setState(() => _values[f.key] = null),
        );
      case ChoiceSpec():
        return _choice(f);
      case SwitchSpec():
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          subtitle: f.subtitle == null
              ? null
              : Text(
                  f.subtitle!,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
          value: (_values[f.key] as bool?) ?? false,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in widget.fields) ...[
          _field(f),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
        if (widget.deleteLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () =>
                Navigator.pop(context, FormResult(const {}, deleted: true)),
            child: Text(widget.deleteLabel!),
          ),
        ],
      ],
    );
  }
}

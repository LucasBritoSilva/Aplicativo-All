import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../notes/data/notes_repository.dart';

void openVoiceCapture(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const VoiceCaptureScreen()));
}

enum _VoiceState { starting, ready, listening, unavailable }

/// Captura de ideias por voz. O texto reconhecido é salvo como anotação.
/// Se o reconhecimento não estiver disponível, a ideia pode ser digitada.
///
/// O reconhecimento é pedido somente no aparelho (offline), para que o áudio
/// não saia do celular (ver DECISOES.md).
class VoiceCaptureScreen extends ConsumerStatefulWidget {
  const VoiceCaptureScreen({super.key});

  @override
  ConsumerState<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends ConsumerState<VoiceCaptureScreen> {
  final SpeechToText _speech = SpeechToText();
  final _text = TextEditingController();
  _VoiceState _state = _VoiceState.starting;
  String? _notice;
  String? _localeId;
  String _base = '';
  bool _usedVoice = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _speech.errorListener = null;
    _speech.statusListener = null;
    if (_speech.isListening) _speech.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final mic = await ref.read(permissionServiceProvider).requestMicrophone();
    if (mic != PermissionState.granted) {
      _setUnavailable(
        'Sem permissão para usar o microfone. Você pode digitar a ideia '
        'abaixo, ou liberar o microfone nas configurações do Android.',
      );
      return;
    }
    bool ok;
    try {
      ok = await _speech.initialize(onError: _onError, onStatus: _onStatus);
      // O plugin é único no app: garante que os avisos venham para esta tela.
      _speech.errorListener = _onError;
      _speech.statusListener = _onStatus;
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      _setUnavailable(
        'O reconhecimento de voz não está disponível neste celular. '
        'Digite sua ideia abaixo.',
      );
      return;
    }
    try {
      final locales = await _speech.locales();
      final pt = locales.where(
        (l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'pt_br',
      );
      _localeId = pt.isNotEmpty
          ? pt.first.localeId
          : (await _speech.systemLocale())?.localeId;
    } catch (_) {
      _localeId = null;
    }
    if (mounted) setState(() => _state = _VoiceState.ready);
  }

  void _setUnavailable(String message) {
    if (!mounted) return;
    setState(() {
      _state = _VoiceState.unavailable;
      _notice = message;
    });
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      if (_state == _VoiceState.listening) {
        setState(() => _state = _VoiceState.ready);
      }
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    final msg = error.errorMsg;
    String text;
    if (msg.contains('language') ||
        msg.contains('network') ||
        msg.contains('server')) {
      text =
          'O reconhecimento offline em português não está disponível neste '
          'celular. Você pode digitar a ideia abaixo (veja no README como '
          'baixar o idioma para uso offline).';
    } else if (msg.contains('no_match') || msg.contains('speech_timeout')) {
      text = 'Não consegui entender. Toque no microfone e tente de novo.';
    } else if (msg.contains('permission')) {
      text = 'Sem permissão para usar o microfone.';
    } else {
      text = 'O reconhecimento falhou ($msg). Tente de novo ou digite abaixo.';
    }
    setState(() {
      _notice = text;
      if (_state == _VoiceState.listening) _state = _VoiceState.ready;
    });
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords;
    final joined = _base.isEmpty || words.isEmpty ? '$_base$words' : '$_base $words';
    setState(() {
      _usedVoice = true;
      _text.text = joined;
      _text.selection = TextSelection.collapsed(offset: joined.length);
    });
  }

  Future<void> _toggleListening() async {
    if (_state == _VoiceState.listening) {
      await _speech.stop();
      setState(() => _state = _VoiceState.ready);
      return;
    }
    _base = _text.text.trim();
    setState(() {
      _notice = null;
      _state = _VoiceState.listening;
    });
    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          onDevice: true,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _onError(SpeechRecognitionError('$e', true));
    }
  }

  Future<void> _save() async {
    final body = _text.text.trim();
    if (body.isEmpty) {
      showMessage(context, 'Nada para salvar ainda.');
      return;
    }
    if (_speech.isListening) await _speech.stop();
    await ref
        .read(notesRepositoryProvider)
        .save(body: body, fromVoice: _usedVoice);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Ideia salva em Notas.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listening = _state == _VoiceState.listening;
    final canListen =
        _state == _VoiceState.ready || _state == _VoiceState.listening;

    return Scaffold(
      appBar: AppBar(title: const Text('Ideia por voz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_state != _VoiceState.unavailable) ...[
                const SizedBox(height: 16),
                Center(
                  child: _MicButton(
                    listening: listening,
                    enabled: canListen,
                    onTap: _toggleListening,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  switch (_state) {
                    _VoiceState.starting => 'Preparando o microfone...',
                    _VoiceState.listening => 'Ouvindo... toque para parar',
                    _ => 'Toque no microfone e fale sua ideia',
                  },
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
              ],
              if (_notice != null) ...[
                if (_state == _VoiceState.unavailable)
                  const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _notice!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: TextField(
                  controller: _text,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: _state == _VoiceState.unavailable
                        ? 'Digite sua ideia...'
                        : 'O texto aparece aqui. Você pode corrigir antes '
                              'de salvar, ou digitar.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar como anotação'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.enabled,
    required this.onTap,
  });

  final bool listening;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Parar de ouvir' : 'Começar a ouvir',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: enabled ? 0.16 : 0.06),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: listening ? 1 : 0.4),
              width: listening ? 6 : 1.5,
            ),
          ),
          child: Icon(
            listening ? Icons.stop : Icons.mic,
            size: 40,
            color: listening
                ? AppColors.onPrimary
                : (enabled ? AppColors.primary : AppColors.textFaint),
          ),
        ),
      ),
    );
  }
}

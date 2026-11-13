import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/native/native_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';
import '../data/vault_repository.dart';

/// Cofre de informações.
///
/// Segurança: o conteúdo é cifrado com AES-256-GCM por uma chave que fica
/// no Android Keystore e só pode ser usada depois da biometria ou do
/// PIN/padrão/senha do aparelho. A tela fica protegida contra capturas e
/// contra a prévia na lista de apps recentes, e o cofre tranca sozinho
/// quando o app sai da tela.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  late final AppLifecycleListener _lifecycle;
  late final NativeBridge _native;
  VaultState? _state;
  List<VaultItem>? _items;
  String _query = '';
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _native = ref.read(nativeBridgeProvider);
    _native.setSecureScreen(true);
    _lifecycle = AppLifecycleListener(onHide: _lock);
    _refreshState();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _native.vaultLock();
    _native.setSecureScreen(false);
    super.dispose();
  }

  Future<void> _refreshState() async {
    final s = await _native.vaultState();
    if (!mounted) return;
    setState(() => _state = s);
    if (s == VaultState.unlocked) await _load();
  }

  Future<void> _lock() async {
    await _native.vaultLock();
    if (!mounted) return;
    setState(() {
      _items = null;
      _state = VaultState.locked;
    });
  }

  Future<void> _load() async {
    final items = await ref.read(vaultRepositoryProvider).loadAll();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await _native.vaultUnlock();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case VaultUnlockResult.ok:
        setState(() => _state = VaultState.unlocked);
        await _load();
      case VaultUnlockResult.canceled:
        setState(() => _message = 'Desbloqueio cancelado.');
      case VaultUnlockResult.noLockScreen:
        setState(() => _state = VaultState.noLockScreen);
      case VaultUnlockResult.invalidated:
        setState(
          () => _message =
              'A chave do cofre foi invalidada pelo Android (por exemplo, o '
              'bloqueio de tela foi removido). Os registros antigos não podem '
              'mais ser lidos. Use "Apagar o cofre" para recomeçar.',
        );
      case VaultUnlockResult.error:
        setState(() => _message = 'Não foi possível destrancar o cofre.');
    }
  }

  Future<void> _edit([VaultItem? item]) async {
    final rec = item?.record;
    final r = await showQuickForm(
      context,
      title: item == null ? 'Novo registro' : 'Editar registro',
      deleteLabel: item == null ? null : 'Excluir registro',
      fields: [
        TextSpec(
          'title',
          'Título',
          initial: rec?.title,
          required: true,
          autofocus: item == null,
        ),
        TextSpec(
          'category',
          'Categoria (ex.: Documentos, Contas)',
          initial: rec?.category,
        ),
        TextSpec(
          'content',
          'Informação',
          initial: rec?.content,
          required: true,
          lines: 8,
          keyboard: TextInputType.visiblePassword,
          capitalization: TextCapitalization.none,
        ),
      ],
    );
    if (r == null || !mounted) return;
    final repo = ref.read(vaultRepositoryProvider);
    if (r.deleted) {
      final ok = await confirm(
        context,
        title: 'Excluir registro',
        message: '"${rec?.title ?? 'Registro'}" será apagado.',
        confirmLabel: 'Excluir',
        destructive: true,
      );
      if (ok) {
        await repo.delete(item!.entry.id);
        await _load();
      }
      return;
    }
    try {
      await repo.save(
        id: item?.entry.id,
        record: VaultRecord(
          title: r.text('title'),
          category: r.textOrNull('category'),
          content: r.text('content'),
        ),
      );
      await _load();
    } on VaultLockedError {
      if (mounted) {
        showMessage(context, 'O cofre trancou. Destranque e tente de novo.');
        await _lock();
      }
    }
  }

  Future<void> _wipe() async {
    final ok = await confirm(
      context,
      title: 'Apagar o cofre?',
      message:
          'TODOS os registros do cofre e a chave de cifragem serão apagados '
          'deste aparelho. Isso não pode ser desfeito.',
      confirmLabel: 'Apagar tudo',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(vaultRepositoryProvider).wipe();
    if (!mounted) return;
    setState(() {
      _items = null;
      _message = null;
    });
    await _refreshState();
  }

  void _show(VaultItem item) {
    final rec = item.record!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(rec.title, style: Theme.of(context).textTheme.titleLarge),
            if (rec.category != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Pill(rec.category!),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                rec.content,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                await _native.copySensitive(rec.content);
                if (sheet.mounted && mounted) {
                  Navigator.pop(sheet);
                  showMessage(
                    context,
                    'Copiado. A prévia fica oculta por ser sensível.',
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar informação'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheet);
                _edit(item);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedBody() {
    final s = _state;
    if (s == null) return const Loading();
    if (s == VaultState.unavailable) {
      return const EmptyState(
        icon: Icons.lock_outline,
        title: 'Cofre indisponível',
        message: 'O armazenamento seguro do Android não respondeu.',
      );
    }
    if (s == VaultState.noLockScreen) {
      return EmptyState(
        icon: Icons.phonelink_lock,
        title: 'Ative o bloqueio de tela',
        message:
            'O cofre usa o bloqueio do próprio celular (digital, rosto, PIN, '
            'padrão ou senha) para proteger a chave de cifragem. Configure um '
            'bloqueio de tela nas configurações do Android e volte aqui.',
      );
    }
    final created = s != VaultState.notCreated;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              created ? 'Cofre trancado' : 'Criar o cofre',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              created
                  ? 'Use a digital, o rosto ou o bloqueio de tela para abrir.'
                  : 'Será criada uma chave de cifragem guardada no Android '
                        'Keystore. Você confirma com a digital, o rosto ou o '
                        'bloqueio de tela.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _unlock,
              icon: const Icon(Icons.fingerprint),
              label: Text(created ? 'Destrancar' : 'Criar e destrancar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unlockedBody() {
    final items = _items;
    if (items == null) return const Loading();
    final shown = [
      for (final i in items)
        if (i.record == null ||
            matchesQuery(_query, [i.record!.title, i.record!.category]))
          i,
    ];
    return Column(
      children: [
        SearchField(
          hint: 'Buscar no cofre',
          onChanged: (v) => setState(() => _query = v),
        ),
        Expanded(
          child: shown.isEmpty
              ? EmptyState(
                  icon: Icons.lock_open,
                  title: items.isEmpty ? 'Cofre vazio' : 'Nada encontrado',
                  message: items.isEmpty
                      ? 'Guarde informações privadas: números de documentos, '
                            'códigos, senhas de Wi-Fi...'
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = shown[i];
                    final rec = item.record;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: rec == null ? null : () => _show(item),
                        leading: Icon(
                          rec == null ? Icons.error_outline : Icons.key,
                          color: rec == null
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                        title: Text(rec?.title ?? 'Registro ilegível'),
                        subtitle: Text(
                          rec == null
                              ? 'Não pôde ser decifrado com a chave atual.'
                              : (rec.category ?? 'Sem categoria'),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        trailing: rec == null
                            ? IconButton(
                                tooltip: 'Excluir',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await ref
                                      .read(vaultRepositoryProvider)
                                      .delete(item.entry.id);
                                  await _load();
                                },
                              )
                            : const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _state == VaultState.unlocked;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cofre'),
        actions: [
          if (unlocked)
            IconButton(
              tooltip: 'Trancar',
              icon: const Icon(Icons.lock_outline),
              onPressed: _lock,
            ),
          if (_state != null &&
              _state != VaultState.noLockScreen &&
              _state != VaultState.unavailable)
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (_) => _wipe(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'wipe', child: Text('Apagar o cofre')),
              ],
            ),
        ],
      ),
      floatingActionButton: unlocked
          ? FloatingActionButton(
              tooltip: 'Novo registro',
              onPressed: _edit,
              child: const Icon(Icons.add),
            )
          : null,
      body: unlocked ? _unlockedBody() : _lockedBody(),
    );
  }
}

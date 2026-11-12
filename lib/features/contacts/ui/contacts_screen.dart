import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/native/native_bridge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/text.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/extras.dart';
import '../../../core/widgets/quick_form.dart';

class ContactsRepository {
  ContactsRepository(this._db);
  final AppDatabase _db;

  Stream<List<UsefulContact>> watchAll() =>
      (_db.select(
            _db.usefulContacts,
          )..orderBy([(c) => OrderingTerm.asc(c.name.collate(Collate.noCase))]))
          .watch();

  Future<void> save({
    int? id,
    required String name,
    String? phone,
    String? description,
    String? category,
    String? address,
    String? notes,
  }) async {
    final data = UsefulContactsCompanion(
      name: Value(name),
      phone: Value(phone),
      description: Value(description),
      category: Value(category),
      address: Value(address),
      notes: Value(notes),
    );
    if (id == null) {
      await _db.into(_db.usefulContacts).insert(data);
    } else {
      await (_db.update(
        _db.usefulContacts,
      )..where((c) => c.id.equals(id))).write(data);
    }
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.usefulContacts)..where((c) => c.id.equals(id))).go();
}

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepository(ref.watch(databaseProvider)),
);

final contactsProvider = StreamProvider<List<UsefulContact>>(
  (ref) => ref.watch(contactsRepositoryProvider).watchAll(),
);

/// Contatos úteis, cadastrados só no app (sem ler a agenda do celular).
///
/// Ligar e WhatsApp apenas abrem o app correspondente com o número
/// preenchido: nada é enviado nem discado sem o usuário confirmar lá.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _query = '';
  String? _category;

  Future<void> _open([UsefulContact? c]) async {
    final r = await showQuickForm(
      context,
      title: c == null ? 'Novo contato' : 'Editar contato',
      deleteLabel: c == null ? null : 'Excluir contato',
      fields: [
        TextSpec(
          'name',
          'Nome',
          initial: c?.name,
          required: true,
          autofocus: c == null,
          capitalization: TextCapitalization.words,
        ),
        TextSpec(
          'phone',
          'Telefone',
          initial: c?.phone,
          keyboard: TextInputType.phone,
        ),
        TextSpec(
          'category',
          'Categoria (ex.: Saúde, Serviços)',
          initial: c?.category,
        ),
        TextSpec(
          'description',
          'Descrição (ex.: encanador)',
          initial: c?.description,
        ),
        TextSpec('address', 'Endereço', initial: c?.address, lines: 2),
        TextSpec('notes', 'Observações', initial: c?.notes, lines: 3),
      ],
    );
    if (r == null || !mounted) return;
    final repo = ref.read(contactsRepositoryProvider);
    if (r.deleted) {
      final ok = await confirm(
        context,
        title: 'Excluir contato',
        message: '"${c!.name}" será apagado do app.',
        confirmLabel: 'Excluir',
        destructive: true,
      );
      if (ok) await repo.delete(c.id);
      return;
    }
    await repo.save(
      id: c?.id,
      name: r.text('name'),
      phone: r.textOrNull('phone'),
      category: r.textOrNull('category'),
      description: r.textOrNull('description'),
      address: r.textOrNull('address'),
      notes: r.textOrNull('notes'),
    );
  }

  Future<void> _dial(String phone) async {
    final ok = await ref.read(nativeBridgeProvider).dial(phone);
    if (!ok && mounted) {
      showMessage(context, 'Nenhum app de telefone disponível.');
    }
  }

  Future<void> _whatsApp(String phone) async {
    final number = whatsAppNumber(phone);
    if (number == null) {
      showMessage(context, 'Número incompleto para o WhatsApp.');
      return;
    }
    final ok = await ref
        .read(nativeBridgeProvider)
        .openUrl('https://wa.me/$number');
    if (!ok && mounted) {
      showMessage(context, 'Não foi possível abrir o WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Contatos úteis')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo contato',
        onPressed: _open,
        child: const Icon(Icons.person_add_alt),
      ),
      body: Column(
        children: [
          SearchField(
            hint: 'Buscar por nome, número ou descrição',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: contacts.view((all) {
              final categories = {
                for (final c in all)
                  if (c.category != null) c.category!,
              }.toList()..sort();
              final shown = [
                for (final c in all)
                  if ((_category == null || c.category == _category) &&
                      matchesQuery(_query, [
                        c.name,
                        c.phone,
                        c.description,
                        c.category,
                        c.address,
                        c.notes,
                      ]))
                    c,
              ];
              return Column(
                children: [
                  if (categories.isNotEmpty)
                    FilterBar<String?>(
                      options: [
                        (null, 'Todos'),
                        for (final c in categories) (c, c),
                      ],
                      selected: _category,
                      onSelected: (c) => setState(() => _category = c),
                    ),
                  Expanded(
                    child: shown.isEmpty
                        ? EmptyState(
                            icon: Icons.contact_phone_outlined,
                            title: all.isEmpty
                                ? 'Nenhum contato'
                                : 'Nada encontrado',
                            message: all.isEmpty
                                ? 'Guarde aqui números úteis: médico, eletricista, '
                                      'pizzaria... Os dados ficam só no app.'
                                : null,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: shown.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final c = shown[i];
                              final sub = [
                                if (c.description != null) c.description!,
                                if (c.phone != null) c.phone!,
                              ].join(' · ');
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  onTap: () => _open(c),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.surfaceHigh,
                                    child: Text(
                                      c.name.characters.first.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  title: Text(c.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (sub.isNotEmpty)
                                        Text(
                                          sub,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      if (c.address != null)
                                        Text(
                                          c.address!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textFaint,
                                            fontSize: 12,
                                          ),
                                        ),
                                      if (c.category != null) ...[
                                        const SizedBox(height: 4),
                                        Pill(c.category!),
                                      ],
                                    ],
                                  ),
                                  trailing: c.phone == null
                                      ? null
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Ligar',
                                              icon: const Icon(
                                                Icons.call_outlined,
                                              ),
                                              onPressed: () => _dial(c.phone!),
                                            ),
                                            IconButton(
                                              tooltip: 'Abrir no WhatsApp',
                                              icon: const Icon(
                                                Icons.chat_outlined,
                                              ),
                                              onPressed: () =>
                                                  _whatsApp(c.phone!),
                                            ),
                                          ],
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

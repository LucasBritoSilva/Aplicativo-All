# Decisões técnicas

Registro das escolhas técnicas do BrutAll e do motivo de cada uma.

## Identidade

- Nome exibido: **BrutAll**. `applicationId`:
  `io.github.lucasbritosilva.aplicativoall`. A URL do repositório
  (`Aplicativo-All`) foi mantida para não quebrar links.
- A versão técnica (`versionName`/`versionCode`) existe só porque o Android
  exige; ela não aparece na interface e o app não tem atualização.
- Ícone gerado da arte do BrutAll, com ícone adaptativo (fundo preto e arte
  em 62% da camada, inteira mesmo na máscara redonda).

## Arquitetura

- Flutter + Riverpod + banco local drift (SQLite).
- Gráficos desenhados no próprio app (`core/widgets/charts.dart`), sem
  biblioteca de gráficos.
- O que depende do Android sem pacote Dart no projeto (abrir links e
  discador, cofre com Keystore e biometria, uso de apps e sobreposição,
  alarmes exatos, seletor de fotos) está num canal nativo em Kotlin
  (`aplicativo_all/native`), só com o framework do Android.
- Formulários simples usam um formulário genérico com validação
  (`core/widgets/quick_form.dart`).
- Datas sem hora são guardadas como número do dia (dias desde 01/01/1970) e
  horários como minutos desde a meia-noite, para não depender de fuso.
- **Telas que juntam várias tabelas** usam `watchTables`. O drift
  reaproveita streams iguais pela consulta SQL e pelos valores, sem olhar as
  tabelas observadas; por isso cada conjunto de tabelas entra como valor da
  consulta e tem o seu próprio stream. Sem isso, uma tela "roubava" o
  stream de outra e as listas só atualizavam ao reabrir o app (teste em
  `test/reactivity_test.dart`).
- Esquema do banco versionado com migrações (`createTable`/`addColumn`),
  testadas em `test/migration_test.dart`.

## Navegação e tela inicial

- Menu lateral com as 6 categorias em blocos expansíveis.
- Tela inicial com **Fixados** (escolhidos pelo usuário) e **Recentes** (os
  6 abertos por último que não estão fixados). Abrir a tela inicial ou o
  menu não conta como acesso. Sem histórico, os recentes mostram sugestões
  com aparência diferente.
- Fixados e ocultos ficam como listas de ids no banco. Ocultar também
  desafixa. O histórico guarda 30 acessos para sempre sobrarem 6 recentes.
- Rodapé (`AppFooter`) colocado pelo `builder` do `MaterialApp`, abaixo de
  todas as rotas, numa faixa própria que respeita a área segura e some com o
  teclado aberto.

## Aparência

- Cor de destaque escolhida pelo usuário (`AppColors.primary` é variável);
  o tema e todas as telas abertas são redesenhados na hora da troca. Cores
  de estado (erro, sucesso, atenção) não mudam. A escolha fica no banco.

## Rotina

- Ver [ROTINA.md](ROTINA.md). Término acima de 1440 minutos = dia seguinte.
- Notificações da rotina usam ids na faixa 1.000.000.000+; lembretes usam o
  id do banco; pausas usam 900.000.001. A ressincronização de cada módulo só
  mexe na sua faixa.
- Tolerância padrão: 15 minutos (configurável de 0 a 240). Horizonte de
  agendamento: 21 dias.

## Alarmes exatos

- O `permission_handler` consulta se a permissão está declarada no
  manifesto. Como a `SCHEDULE_EXACT_ALARM` vai só até o Android 12
  (`maxSdkVersion 32`), no 13+ ela some da lista do app e o plugin
  respondia "negada" sem abrir nada. Por isso a consulta é direta no
  `AlarmManager.canScheduleExactAlarms()` e o botão abre
  `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`. Ao voltar para o app, avisos e
  rotina são reagendados no modo certo.

## Outros módulos

- **Tarefas:** "concluída em" é gravado para as estatísticas.
- **Prioridades:** limite de 3 por dia; "Trazer as pendentes de ontem" copia
  (não move) as não concluídas.
- **Desafios:** concluído automaticamente ao atingir o alvo (desfeito se um
  registro for apagado); interromper nunca zera o progresso.
- **Pausas:** padrão 50 min de foco e 10 de pausa; estado gravado no banco e
  aviso agendado para o fim do período, sem serviço em segundo plano.
- **Notas:** imagens escolhidas pelo seletor de fotos do Android (sem pedir
  permissão de armazenamento) e copiadas para a pasta privada do app; a nota
  guarda só o caminho. Remover a imagem ou excluir a nota apaga o arquivo.
- **Compras e desejos:** excluir uma pasta pergunta para onde vão os itens
  ("Sem pasta" ou outra pasta).
- **Contatos:** números com 10 ou 11 dígitos são tratados como brasileiros
  (código 55) no WhatsApp; com "+" o número é usado como está.
- **Faculdade:** uma prova é uma avaliação do tipo "Prova"; Controle de
  notas e Controle de provas leem a mesma tabela. A "nota necessária" é a
  mesma nota em todas as avaliações restantes.
- **Academia:** histórico de carga registrado quando a carga muda (um por
  exercício e dia). A meta de peso é só um número do usuário.
- **Entretenimento:** categorias (`media_categories`) com a opção
  "acompanhar episódios"; a instalação cria Filmes e Séries. Excluir
  categoria com títulos exige escolher mover ou confirmar a exclusão. Nota de
  0 a 10; ranking só com assistidos que têm nota.
- **Bíblia:** cânon padrão protestante até o usuário escolher; trocar não
  apaga marcações.
- **Limite de apps:** tempo calculado pelos eventos de uso desde a
  meia-noite local; serviço em primeiro plano do tipo `specialUse`. Cada app
  tem um modo (`overlay` ou `notify`); a notificação de limite atingido é
  registrada por dia e por app para não repetir.
- **Estatísticas:** períodos de 7, 30, 90 dias e 1 ano.

## Segurança e privacidade

- Cofre: ver [SEGURANCA_DO_COFRE.md](SEGURANCA_DO_COFRE.md).
- Sem permissão de internet, sem serviços em nuvem, sem backup, exportação
  ou restauração. `allowBackup=false` e regras de extração que excluem tudo.

## Publicação

- Ver [PUBLICACAO.md](PUBLICACAO.md). A assinatura de produção é feita
  localmente (a chave não fica no GitHub) e o fluxo Release só publica o
  arquivo já assinado.
- Commits com o e-mail "noreply" do GitHub do proprietário, para não expor o
  e-mail pessoal no histórico público.
- Licença: nenhuma escolhida (decisão do proprietário).

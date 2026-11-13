# Decisões técnicas

Registro das escolhas feitas e do motivo. A versão final (BrutAll, 3.0.0,
13/11/2026) está na primeira seção; as seguintes vêm da versão 2.0.0.

## Versão final: BrutAll

- **Nome:** BrutAll (antes "All"). O `applicationId`
  (`io.github.lucasbritosilva.aplicativoall`), a chave de assinatura e a
  URL do repositório foram mantidos, para o BrutAll instalar por cima da
  2.0.0 sem perder dados. Versão técnica 3.0.0 (código 3); ela não aparece
  na interface.
- **Telas que não atualizavam:** a causa era o `watchTables`. O drift
  reaproveita streams iguais pela consulta SQL e pelos valores, sem olhar as
  tabelas observadas. Todas as consultas combinadas usavam `SELECT 1`, então
  a primeira criada (em geral a da rotina) passava a valer para Tarefas,
  Desejos, Disciplinas e Fichas, que deixavam de ser avisadas das mudanças.
  Agora cada conjunto de tabelas entra como valor da consulta e tem o seu
  próprio stream (teste em `test/reactivity_test.dart`).
- **Botão de alarmes:** o `permission_handler` consulta se a permissão está
  declarada no manifesto. Como a `SCHEDULE_EXACT_ALARM` vai só até o
  Android 12 (`maxSdkVersion 32`), no 13+ ela some da lista do app e o
  plugin respondia "negada" sem abrir nada. Agora a consulta é direta no
  `AlarmManager.canScheduleExactAlarms()` e o botão abre
  `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`. Ao voltar para o app, avisos e
  rotina são reagendados no modo certo.
- **Rotina após a meia-noite:** ver [ROTINA.md](ROTINA.md). Término acima de
  1440 minutos = dia seguinte; sem mudança de tabela.
- **Limite de apps:** cada app tem um modo (`overlay` ou `notify`), gravado
  numa coluna nova. O mesmo serviço em primeiro plano atende os dois modos;
  a notificação de limite atingido é registrada por dia e por app para não
  repetir.
- **Cor do aplicativo:** `AppColors.primary` virou variável; o tema e todas
  as telas abertas são redesenhados na hora da troca. Cores de estado
  (erro, sucesso, atenção) não mudam. A escolha fica no banco.
- **Fixar e ocultar:** listas de ids no banco. Ocultar também desafixa. O
  histórico de recentes guarda 30 acessos para sempre sobrarem 6 recentes
  depois de tirar fixados e ocultos.
- **Entretenimento:** tabela de categorias (`media_categories`) com a opção
  "acompanhar episódios". Instalação nova cria Filmes e Séries; a migração
  da 2.0.0 coloca cada título na categoria do seu tipo antigo e só cria
  "Animes" se já havia animes. Excluir categoria com títulos exige escolher
  mover ou confirmar a exclusão.
- **Banco versão 3:** migração com `createTable`/`addColumn`, testada em
  `test/migration_test.dart` a partir das tabelas da 2.0.0.
- **Rodapé:** um componente (`AppFooter`) colocado pelo `builder` do
  `MaterialApp`, abaixo de todas as rotas, numa faixa própria que respeita a
  área segura e some com o teclado aberto.
- **Backup removido:** código do Google Drive, dependências
  (`google_sign_in`, `googleapis`, `http`), arquivo de configuração e a
  permissão `INTERNET` saíram. O app não tem exportação, importação nem
  restauração; o backup automático e a transferência do Android seguem
  desligados.
- **Versão e atualizações:** nenhuma tela mostra versão ou oferece
  atualização.
- **Ícone:** gerado da arte do BrutAll, com ícone adaptativo (fundo preto e
  arte em 62% da camada, inteira mesmo na máscara redonda).

## Versão 2.0.0 (All)

## Fonte e reconstrução

- **Fonte encontrada:** o projeto Flutter do "App Pessoal" 1.0.0 estava no
  computador (não no GitHub). Ele foi importado no repositório como base,
  com a tag `v1.0.0`, e então atualizado, em vez de reconstruído do zero:
  a base (tema, banco drift, notificações, lembretes, hábitos, metas,
  notas, voz, backup) era aproveitável.
- **Módulos substituídos:** a Agenda foi removida (a especificação proíbe
  calendário geral; compromissos com data única entram na Rotina) e a
  rotina antiga de checklist deu lugar à rotina híbrida. A barra inferior
  deu lugar ao menu lateral.
- **Mantidos do app original:** Lembretes, Hábitos e Metas, na categoria
  Organização pessoal, marcados como fora da contagem dos 21.

## Identidade

- `applicationId`: `io.github.lucasbritosilva.aplicativoall` (estável a
  partir desta versão). O antigo `com.example.app_pessoal` não servia para
  publicação. Os dois apps podem ficar instalados ao mesmo tempo.
- Nome exibido: **All**. Versão 2.0.0 (código 2).
- Banco novo `aplicativo_all`, esquema 2; sem migração do app antigo
  (autorizado pelo proprietário).

## Arquitetura

- Flutter + Riverpod + drift, como no app original. Nenhuma dependência
  Dart nova foi adicionada.
- Gráficos desenhados no próprio app (`core/widgets/charts.dart`) em vez de
  uma biblioteca de gráficos.
- O que depende do Android sem pacote Dart no projeto (abrir links e
  discador, cofre com Keystore e biometria, uso de apps e sobreposição)
  está num canal nativo em Kotlin (`aplicativo_all/native`), sem
  bibliotecas extras (usa só o framework do Android).
- Formulários simples usam um formulário genérico com validação
  (`core/widgets/quick_form.dart`).
- Telas que juntam várias tabelas usam `watchTables` (consulta reativa que
  recalcula quando qualquer tabela envolvida muda).
- Datas sem hora são guardadas como número do dia (dias desde 01/01/1970) e
  horários como minutos desde a meia-noite, para não depender de fuso.

## Navegação e recentes

- Menu lateral com as 6 categorias em blocos expansíveis.
- Tela inicial com os 6 módulos abertos por último, gravados no banco.
  Abrir a tela inicial ou o menu não conta como acesso. Sem histórico,
  as posições vazias mostram **sugestões** com aparência diferente
  (contorno e etiqueta "Sugestão").

## Rotina

- Ver [ROTINA.md](ROTINA.md). Notificações da rotina usam ids na faixa
  1.000.000.000+; lembretes usam o id do banco; pausas usam 900.000.001.
  A ressincronização de cada módulo só mexe na sua faixa.
- Tolerância padrão: 15 minutos (configurável de 0 a 240).
- Horizonte de agendamento: 21 dias.

## Outros módulos

- **Tarefas:** "concluída em" é gravado para as estatísticas.
- **Prioridades:** limite de 3 por dia; "Trazer as pendentes de ontem" copia
  (não move) as não concluídas.
- **Desafios:** concluído automaticamente ao atingir o alvo (desfeito se um
  registro for apagado); interromper nunca zera o progresso.
- **Pausas:** padrão 50 min de foco e 10 de pausa; estado gravado no banco e
  aviso agendado para o fim do período, sem serviço em segundo plano.
- **Compras e desejos:** excluir uma pasta pergunta para onde vão os itens
  ("Sem pasta" ou outra pasta).
- **Contatos:** números com 10 ou 11 dígitos são tratados como brasileiros
  (código 55) no WhatsApp; com "+" o número é usado como está.
- **Faculdade:** uma prova é uma avaliação do tipo "Prova"; Controle de
  notas e Controle de provas leem a mesma tabela. A "nota necessária" é a
  mesma nota em todas as avaliações restantes.
- **Academia:** histórico de carga registrado quando a carga muda (um por
  exercício e dia). A meta de peso é só um número do usuário.
- **Filmes:** nota de 0 a 10; ranking só com assistidos que têm nota.
- **Bíblia:** cânon padrão protestante até o usuário escolher; trocar não
  apaga marcações.
- **Limite de apps:** tempo calculado pelos eventos de uso desde a
  meia-noite local; serviço em primeiro plano do tipo `specialUse`.
- **Estatísticas:** períodos de 7, 30, 90 dias e 1 ano.

## Segurança e privacidade

- Cofre: ver [SEGURANCA_DO_COFRE.md](SEGURANCA_DO_COFRE.md).
- `allowBackup=false` e regras de extração que excluem tudo.
- Backup no Google Drive: código mantido, desligado até configurar o
  cliente OAuth (ver [BACKUP_GOOGLE_DRIVE.md](BACKUP_GOOGLE_DRIVE.md)). O
  cofre fica fora dele.

## Publicação

- Ver [PUBLICACAO.md](PUBLICACAO.md). Os secrets do GitHub não puderam ser
  configurados (não há GitHub CLI nem token de API neste computador), então
  a assinatura de produção é feita localmente e o fluxo Release só publica
  os arquivos já assinados.
- Commits feitos com o e-mail "noreply" do GitHub do proprietário, para não
  expor o e-mail pessoal no histórico público.
- Licença: nenhuma escolhida (decisão do proprietário).

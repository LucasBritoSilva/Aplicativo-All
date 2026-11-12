# Limitações técnicas e funcionamento offline

## Funcionamento offline

Tudo funciona sem internet. O banco é local (SQLite) e não há servidor.
A internet só é usada quando você abre um link (desejos, WhatsApp) ou usa
o backup no Google Drive.

## O que não foi validado

- **O app não foi testado num celular de verdade nem em emulador** durante
  esta entrega: o computador usado não tem virtualização disponível para o
  emulador e nenhum celular estava conectado.
- O que foi verificado: análise estática sem avisos, 182 testes automáticos
  (regras, banco de dados e abertura de todas as 25 telas numa tela de
  360 px), compilação de debug e de release, e a assinatura do APK.
- Por isso, estes pontos precisam ser conferidos no aparelho:
  notificações da rotina e das pausas no horário, desbloqueio do cofre por
  biometria e por PIN, contador flutuante do limite de apps, captura por
  voz, discador e WhatsApp.

## Limite de uso de aplicativos

- O tempo vem das estatísticas de uso do próprio Android
  (`UsageStatsManager`). Ele pode diferir alguns minutos do "Bem-estar
  digital", que usa regras internas próprias.
- O contador flutuante usa a permissão "Sobrepor a outros apps" e um
  serviço em primeiro plano com **notificação fixa** (exigência do
  Android). Com a tela desligada, o serviço não faz leituras.
- O app **não bloqueia** nenhum app e não usa o serviço de acessibilidade.
- Alguns fabricantes (Xiaomi, Samsung, Huawei...) encerram serviços para
  economizar bateria. Se o contador sumir, abra o All (ele religa sozinho)
  ou libere o All na otimização de bateria do aparelho.
- Depois de reiniciar o celular, o Android 15 ou mais novo pode não deixar
  o contador voltar sozinho; ele volta ao abrir o All.
- Na lista de escolha aparecem os apps que têm ícone na tela inicial.

## Ideias por voz

- O reconhecimento é feito **no próprio aparelho** (o áudio não sai do
  celular). Em aparelhos sem o pacote de português offline, o app avisa e
  oferece digitar a ideia.

## Notificações

- Sem permissão de notificação, rotina, lembretes e pausas funcionam, mas
  não avisam. Sem alarme exato, o aviso pode atrasar alguns minutos.
- Fabricantes com economia de bateria agressiva podem atrasar avisos.

## Cofre

- Exige bloqueio de tela. Os dados do cofre não podem ser recuperados em
  outro aparelho (ver [SEGURANCA_DO_COFRE.md](SEGURANCA_DO_COFRE.md)).

## Leitura da Bíblia

- O app traz só a lista de livros e capítulos, não o texto (que tem
  direitos autorais conforme a tradução).
- A divisão de capítulos segue a usual nas Bíblias em português. No cânon
  católico, Daniel tem 14 capítulos e entram os 7 deuterocanônicos; as
  partes gregas de Ester não são contadas como capítulos à parte.

## Backup no Google Drive

- O código está pronto, mas **desligado nesta versão pública**: ele exige
  um cadastro no Google Cloud ligado à chave de assinatura (ver
  [BACKUP_GOOGLE_DRIVE.md](BACKUP_GOOGLE_DRIVE.md)).

## Dados do app antigo

- O "App Pessoal" anterior não é migrado (decisão do proprietário).

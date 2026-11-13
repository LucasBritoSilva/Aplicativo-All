# Limitações técnicas e funcionamento offline

## Funcionamento offline

Tudo funciona sem internet. O banco é local (SQLite), não há servidor e o
app nem tem permissão de internet. Links (desejos, WhatsApp) são abertos em
outros apps do celular.

## Armazenamento

- Os dados ficam só no aparelho. **Não existe backup nem recuperação**: ao
  desinstalar o BrutAll ou apagar os dados do app, as informações são
  perdidas. O backup automático e a transferência entre aparelhos do Android
  estão desligados de propósito.

## O que não foi validado

- **O app não foi testado num celular de verdade nem em emulador**: o
  computador usado não tem virtualização disponível para o emulador e
  nenhum celular estava conectado.
- O que foi verificado: análise estática sem avisos, 208 testes automáticos
  (regras, banco de dados, migração da versão 2.0.0, atualização imediata
  das listas e abertura de todas as telas numa tela de 360 px), compilação
  de release e a assinatura do APK.
- Precisam ser conferidos no aparelho: notificações da rotina, das pausas e
  do limite de apps no horário; o botão de alarmes exatos no Android 12;
  desbloqueio do cofre por biometria e por PIN; contador flutuante; captura
  por voz; discador e WhatsApp; troca de cor do app.

## Limite de uso de aplicativos

- O tempo vem das estatísticas de uso do próprio Android
  (`UsageStatsManager`). Ele pode diferir alguns minutos do "Bem-estar
  digital", que usa regras internas próprias.
- Os dois modos (contador flutuante e notificação ao atingir o limite)
  dependem de um serviço em primeiro plano com **notificação fixa**
  (exigência do Android). Com a tela desligada, o serviço não faz leituras.
- No modo notificação, o aviso sai quando o limite é atingido **enquanto o
  app monitorado está em uso** e o monitoramento está ligado; ele é enviado
  no máximo uma vez por app e por dia.
- O app **não bloqueia** nenhum app e não usa o serviço de acessibilidade.
- Alguns fabricantes (Xiaomi, Samsung, Huawei...) encerram serviços para
  economizar bateria. Se o monitoramento parar, abra o BrutAll (ele religa
  sozinho) ou libere o BrutAll na otimização de bateria do aparelho.
- Depois de reiniciar o celular, o Android 15 ou mais novo pode não deixar
  o monitoramento voltar sozinho; ele volta ao abrir o BrutAll.
- Na lista de escolha aparecem os apps que têm ícone na tela inicial.

## Alarmes exatos

- No Android 13 ou mais novo, o app usa a permissão de alarme exato
  concedida na instalação: o item aparece como "Permitido".
- No Android 12, o botão abre a tela "Alarmes e lembretes" do sistema; ao
  voltar, o app confere de novo e reagenda os avisos.
- No Android 11 ou anterior, alarmes exatos não precisam de permissão.
- Sem alarme exato, os avisos ainda saem, mas podem atrasar alguns minutos.

## Ideias por voz

- O reconhecimento é feito **no próprio aparelho** (o áudio não sai do
  celular). Em aparelhos sem o pacote de português offline, o app avisa e
  oferece digitar a ideia.

## Notificações

- Sem permissão de notificação, rotina, lembretes, pausas e limite de apps
  funcionam, mas não avisam.
- Fabricantes com economia de bateria agressiva podem atrasar avisos.

## Cofre

- Exige bloqueio de tela. O conteúdo do cofre não pode ser recuperado em
  outro aparelho (ver [SEGURANCA_DO_COFRE.md](SEGURANCA_DO_COFRE.md)).

## Rodapé

- O texto "BrutAll - App desenvolvido por Lucas Brito Silva" fica numa faixa
  própria no fim de todas as páginas, abaixo do conteúdo (não por cima
  dele). Com o teclado aberto, a faixa sai do caminho.

## Leitura da Bíblia

- O app traz só a lista de livros e capítulos, não o texto (que tem
  direitos autorais conforme a tradução).
- A divisão de capítulos segue a usual nas Bíblias em português. No cânon
  católico, Daniel tem 14 capítulos e entram os 7 deuterocanônicos; as
  partes gregas de Ester não são contadas como capítulos à parte.

## Dados de versões anteriores

- Quem tem o "All" 2.0.0 instala o BrutAll por cima e mantém os dados.
- O "App Pessoal" original é outro app e não é migrado.

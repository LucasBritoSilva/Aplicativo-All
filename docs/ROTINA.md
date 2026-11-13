# Rotina: como funciona

O módulo segue a especificação funcional da rotina híbrida: **o usuário
planeja; o app organiza, acompanha e ajuda na execução.** Nada é criado,
movido ou encerrado automaticamente.

## Modelo de dados

| Entidade | Tabela | O que guarda |
| --- | --- | --- |
| Atividade recorrente | `routine_activities` | Nome, descrição, tipo (fixo, flexível, descanso), início e fim, dias da semana (ou data única), cronômetro |
| Ocorrência | `routine_occurrences` | A atividade num dia: cópia do nome e do horário planejado, horário atual (após reagendar), estado, data de encerramento |
| Sessão de execução | `routine_sessions` | Cada período de execução: início, fim, segundos acumulados e "contando desde" |
| Retomada pendente | `routine_resumes` | Ocorrência interrompida: data de entrada na Lista de Retomadas e continuação agendada |

- Uma atividade tem **no máximo uma ocorrência por dia planejado**
  (chave única `atividade + dia original`): reagendar altera a mesma linha,
  então nunca duplica.
- Uma ocorrência tem **no máximo uma retomada** (`occurrence_id` único).
- Editar a atividade recorrente só refaz as ocorrências futuras que ainda
  estão intocadas. O que já começou, terminou ou foi reagendado à mão fica
  como está, e o passado nunca muda.
- Remover uma atividade do planejamento preserva o histórico.

## Atividades que passam da meia-noite

- Se o término escolhido for antes do início (ex.: 23h às 3h), a atividade
  termina **no dia seguinte**. O término é guardado como minutos acima de
  24h00 (3h do dia seguinte = 1620), sempre relativo ao dia de início.
- A duração planejada é calculada pelo intervalo real (23h às 3h = 4 horas)
  e precisa ser menor que 24 horas.
- A ocorrência pertence ao dia em que começa. No dia seguinte ela aparece
  como "continua de ontem", sem ser contada de novo nos indicadores.
- Conflitos são verificados em minutos absolutos, então uma atividade das
  23h às 3h de segunda conflita com outra às 2h de terça. Domingo à noite
  também conflita com segunda de madrugada no planejamento recorrente.
- O aviso continua no horário de início e as sessões do cronômetro ficam
  na ocorrência original, mesmo depois da meia-noite.

## Estados

Gravados: pendente, em andamento, pausada, aguardando retomada, concluída,
parcial, não realizada. Calculados na hora de mostrar: **atrasada**
(pendente além da tolerância) e **reagendada** (pendente com horário
alterado). "Atrasada" é só uma indicação: a ocorrência não vira "não
realizada" sozinha. Descanso nunca fica atrasado nem conta como falha.

As mudanças de estado permitidas estão em `allowedActions`
(`lib/features/routine/domain/routine_logic.dart`); o repositório recusa
qualquer outra.

## Notificações

- Uma notificação por atividade, **no horário de início**. Sem aviso
  antecipado, sem repetição, sem cobrança por atraso.
- Iniciar antes da hora, encerrar, reagendar ou remover cancela/troca o
  aviso. Uma continuação agendada avisa só no seu horário.
- O app mantém agendados os próximos 21 dias e confere tudo ao abrir, ao
  voltar para a tela, na virada do dia e após cada ação. Depois de
  reiniciar o celular, o plugin de notificações reagenda o que estava
  marcado.
- Tocar na notificação abre a atividade. A notificação **não** inicia a
  atividade.
- Sem permissão de notificação, a rotina funciona normalmente, só sem aviso.
  Sem alarme exato, o aviso pode atrasar alguns minutos.

## Tempo

- Horários planejados são minutos desde a meia-noite e dias são números de
  calendário: mudar de fuso não embaralha o planejamento.
- O cronômetro conta pelo horário gravado (`running_since`), não pela
  memória: fechar o app, reiniciar o celular ou trocar de tela não perde
  tempo. Pausado, nada é somado. Se o relógio voltar no tempo, o trecho
  conta como zero em vez de negativo.
- Concluir com menos tempo que o planejado é válido (ex.: 40 de 60 min).

## Lista de Retomadas

- Entra quando o usuário interrompe e escolhe "Continuar mais tarde →
  Adicionar à Lista de Retomadas".
- Ordem: **mais antigas primeiro, pela data de entrada**. Consultar não
  muda a ordem; retomar e interromper de novo mantém a data original.
- Nada sai sozinho: só ao concluir, encerrar como parcial ou agendar a
  continuação. Encerrada, continua no histórico.
- Não há exclusão automática nem alerta por antiguidade (decisão ainda não
  tomada pelo usuário).

## O que não foi implementado (propostas não confirmadas)

- **Modo Mínimo** (sessão curta para começar): não implementado.
- Tratamento especial de retomadas muito antigas: não implementado.

## Testes

`test/routine_logic_test.dart` e `test/routine_repository_test.dart`
cobrem recorrência, independência das ocorrências, tolerância, cronômetro,
sessões múltiplas, Lista de Retomadas, reorganização e notificações.

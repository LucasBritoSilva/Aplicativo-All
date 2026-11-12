# All

> **Sobre este projeto:** criei o All por dois motivos. O primeiro foi ter,
> num só lugar, as funcionalidades que eu achava importantes para o meu dia
> a dia, como rotina, tarefas, faculdade e treinos. O
> segundo foi entender melhor, na prática, como funciona o
> [Claude Code](https://claude.com/claude-code), que foi essencial na
> criação do app: do planejamento ao código, aos testes e à publicação.

Aplicativo Android de organização pessoal, em português, que funciona
**offline**: todos os dados ficam guardados no próprio celular. São 21
módulos organizados em 6 categorias, num menu lateral, e uma tela inicial
com os 6 módulos que você abriu por último.

> **Baixar o app:** vá em [Releases](https://github.com/LucasBritoSilva/Aplicativo-All/releases)
> e baixe o arquivo `.apk` da versão mais recente. O passo a passo está em
> [Como instalar](#como-instalar).

---

## Os módulos

O menu lateral (botão ☰ no canto superior esquerdo) mostra as categorias.
Toque numa categoria para ver os módulos dela.

### 1. Organização pessoal
| Módulo | O que faz |
| --- | --- |
| **Tarefas** | Criar, editar, concluir e reabrir tarefas, com descrição, prazo, prioridade (alta, média, baixa) e subtarefas. Filtros por pendentes/concluídas e busca. |
| **Rotina** | Rotina híbrida planejada por você: compromissos fixos, atividades flexíveis e descanso, repetidos nos dias da semana escolhidos. Visão do dia e da semana, uma notificação só no início de cada atividade, tolerância de atraso configurável, cronômetro opcional, sessões múltiplas, Lista de Retomadas, Reorganizar e histórico com indicadores. [Detalhes](docs/ROTINA.md). |
| **Prioridades diárias** | Até 3 prioridades por dia, com reordenação e conclusão. Cada dia começa com uma lista nova; os dias anteriores ficam no histórico. |
| **Contador de dias** | Quantos dias faltam para uma data ou quantos dias se passaram desde ela. |
| **Desafios pessoais** | Desafios por número de dias ou por quantidade, com registros, porcentagem, sequência atual e lista de concluídos. Interromper não apaga o progresso. |
| **Pausas para descanso** | Cronômetro de foco e pausa configurável: iniciar, pausar, continuar, reiniciar. Um aviso no fim de cada período. |
| Lembretes *(do app original)* | Avisos em horário exato, mantidos depois de reiniciar o celular. |
| Hábitos *(do app original)* | Hábitos com meta semanal e o progresso da semana. |
| Metas *(do app original)* | Metas de longo prazo com barra de progresso. |

### 2. Anotações e desenvolvimento
| Módulo | O que faz |
| --- | --- |
| **Notas e ideias por voz** | Notas com título opcional, busca, fixar no topo e captura de ideias por voz (com alternativa digitada). |
| **Conhecimentos** | Assuntos com descrição, categoria e domínio avaliado de 1 a 5 estrelas. Busca e ordenação. |
| **Ideias de projetos** | Título, descrição, ferramentas planejadas, observações e estágio (Ideia, Planejado, Em andamento, Concluído). |

### 3. Compras e vida pessoal
| Módulo | O que faz |
| --- | --- |
| **Lista de compras e desejos** | Aba **Mercado** (itens por seção, quantidade, comprado) e aba **Desejos** (produtos com link e preço, em pastas que você cria, renomeia e exclui sem perder itens). |
| **Contatos úteis** | Nome, número, descrição, categoria, endereço e observações. Botões para abrir o discador e o WhatsApp (nada é enviado sozinho). |
| **Cofre de informações** | Informações privadas cifradas de verdade (AES-256 com chave no Android Keystore), abertas com digital, rosto ou o bloqueio de tela. [Detalhes](docs/SEGURANCA_DO_COFRE.md). |
| **Eventos sociais** | Data, horário, local, convidados com resposta (confirmado, recusado, aguardando), checklist, itens necessários, orçamento e gastos. |

### 4. Faculdade
| Módulo | O que faz |
| --- | --- |
| **Controle de notas** | Semestres, disciplinas, avaliações, pesos e média mínima. Média simples ou ponderada, nota necessária nas avaliações restantes e situação (aprovada, em andamento, reprovada). |
| **Controle de provas** | Provas com data, horário, conteúdo, tópicos de revisão e nota. A nota é a mesma do Controle de notas (sem lançar duas vezes). |

### 5. Saúde e entretenimento
| Módulo | O que faz |
| --- | --- |
| **Academia** | Fichas Treino A, B, C... com exercícios (séries, repetições e carga) e histórico de carga. Peso corporal com meta, histórico, gráfico e diferença para a meta. |
| **Filmes, séries e animes** | Três abas independentes, lista para assistir, assistidos, nota, ranking dos assistidos, temporada e episódio, e o sorteio "O que assistir?". |
| **Leitura da Bíblia** | Checklist de todos os livros e capítulos (cânon protestante de 66 livros ou católico de 73), progresso por livro, por testamento e geral, e "Continuar". Não inclui o texto bíblico. |

### 6. Ferramentas e análise
| Módulo | O que faz |
| --- | --- |
| **Decisor aleatório** | Sorteia um número num intervalo ou uma opção de uma lista escrita por você. |
| **Limite de uso de aplicativos** | Limite diário por app, tempo usado e restante, e um contador flutuante sobre o app monitorado. Não bloqueia nada. [Limitações](docs/LIMITACOES.md#limite-de-uso-de-aplicativos). |
| **Estatísticas pessoais** | Indicadores reais por período (7, 30, 90 dias, 1 ano): tarefas, rotina, prioridades, hábitos, desafios, conhecimentos, treinos, peso, leitura. Sem dados, mostra vazio. |

---

## Requisitos

- Android **7.0 (API 24) ou mais novo**. Testado por compilação para o
  Android 16 (API 36).
- Cerca de 150 MB livres para instalar.
- Internet: **não é necessária**. Só é usada se você abrir um link (desejos,
  WhatsApp) ou usar o backup no Google Drive (desligado nesta versão; ver
  [docs/BACKUP_GOOGLE_DRIVE.md](docs/BACKUP_GOOGLE_DRIVE.md)).

## Permissões

Cada permissão só é pedida quando a função que precisa dela é usada. Negar
uma permissão não trava o app: só aquela função fica limitada.

| Permissão | Para quê | Quando é pedida |
| --- | --- | --- |
| Notificações | Aviso no início de cada atividade da rotina, lembretes e fim das pausas | Ao salvar a primeira atividade, lembrete ou iniciar uma pausa |
| Alarmes e lembretes (alarme exato) | Avisar no minuto certo | Concedida na instalação no Android 13+; no 12 pode ser ligada em Configurações |
| Iniciar com o sistema | Reagendar avisos e o contador de uso após reiniciar | Automática |
| Microfone | Ideias por voz | Ao abrir a captura por voz |
| Biometria | Abrir o cofre | Ao abrir o cofre |
| Acesso ao uso | Ler o tempo de uso de cada app (Limite de apps) | Você libera na tela do módulo |
| Sobrepor a outros apps | Contador flutuante do Limite de apps | Você libera na tela do módulo |
| Serviço em primeiro plano | Manter o contador flutuante ligado (com notificação fixa) | Ao ligar o contador |
| Internet | Abrir links e o backup opcional | Automática |

## Privacidade

- Os dados ficam **só no celular**, num banco SQLite privado do app. Não há
  servidor, conta, anúncio nem coleta de dados.
- O backup automático do Android está **desligado**: nada é copiado para a
  nuvem sem você pedir.
- O cofre é cifrado com uma chave que não sai do aparelho; ele fica de fora
  de qualquer backup. A tela do cofre não aparece em capturas de tela nem na
  lista de apps recentes.
- O repositório público contém só o código e o APK. Nenhum dado de quem usa
  o app vai para o GitHub.

---

## Como instalar

### Instalação nova
1. No celular, abra a página de
   [Releases](https://github.com/LucasBritoSilva/Aplicativo-All/releases).
2. Na versão mais recente, toque em **`All-2.0.0.apk`** (funciona em qualquer
   celular) ou em **`All-2.0.0-arm64.apk`** (menor, para quase todos os
   celulares atuais).
3. Quando o download terminar, toque no arquivo.
4. Se aparecer "Por segurança, seu telefone não permite instalar apps
   desconhecidos desta fonte", toque em **Configurações**, ative **Permitir
   desta fonte** e volte.
5. Toque em **Instalar** e depois em **Abrir**.

> O Google Play Protect pode avisar que o app é desconhecido (ele não está
> na Play Store). Toque em **Mais detalhes → Instalar assim mesmo**.

### Se você tinha o "App Pessoal" (versão anterior)
O All tem outro identificador, então ele **não substitui** o App Pessoal:
os dois podem ficar instalados. Os dados do App Pessoal não passam para o
All. Se quiser, desinstale o App Pessoal (segure o ícone → Desinstalar).

### Atualizações futuras
As próximas versões serão assinadas com a mesma chave. Basta baixar o novo
APK na página de Releases e instalar por cima: os dados são mantidos.

---

## Para quem programa

Projeto Flutter (Dart) com banco local **drift** (SQLite), estado com
**Riverpod** e uma pequena parte nativa em **Kotlin** (cofre, uso de apps).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --debug
```

- O código do banco (`*.g.dart`) é gerado pelo `build_runner` e não fica no
  repositório.
- Sem `android/key.properties`, o build de release é assinado com a chave
  de debug (só para teste). A publicação está em
  [docs/PUBLICACAO.md](docs/PUBLICACAO.md).
- No Windows, se a pasta do projeto tiver acentos, use o `gerar_apk.bat`.

| Pasta | Conteúdo |
| --- | --- |
| `lib/core/` | Banco, navegação, notificações, permissões, tema, componentes, backup, ponte nativa |
| `lib/features/<módulo>/` | Um módulo por pasta (`data`, `domain`, `ui`) |
| `android/app/src/main/kotlin/` | Cofre (Keystore), uso de apps e contador flutuante |
| `test/` | Testes automáticos (regras, banco e abertura de todas as telas) |
| `docs/` | Rotina, segurança do cofre, limitações, publicação, decisões |

Documentos: [Decisões técnicas](docs/DECISOES.md) ·
[Limitações e funcionamento offline](docs/LIMITACOES.md) ·
[Rotina](docs/ROTINA.md) · [Cofre](docs/SEGURANCA_DO_COFRE.md) ·
[Publicação](docs/PUBLICACAO.md).

## Licença

Nenhuma licença de código aberto foi escolhida. O código pode ser visto e
o APK pode ser baixado e usado, mas os direitos de redistribuição e
modificação continuam reservados ao autor.

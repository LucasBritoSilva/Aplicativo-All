<p align="center">
  <img src="assets/brand/brutall.png" alt="Ícone do BrutAll" width="128">
</p>

# BrutAll

> **Sobre este projeto:** criei o BrutAll por dois motivos. O primeiro foi
> ter, num só lugar, as funcionalidades que eu achava importantes para o meu
> dia a dia, como rotina, tarefas, faculdade e treinos. O segundo foi
> entender melhor, na prática, como funciona o
> [Claude Code](https://claude.com/claude-code), que foi essencial na
> criação do app: do planejamento ao código, aos testes e à publicação.

Aplicativo Android de organização pessoal, em português, que funciona
**offline**: todos os dados ficam guardados no próprio celular. São 21
módulos organizados em 6 categorias, num menu lateral, e uma tela inicial
com os módulos fixados por você e os 6 usados por último.

> **Baixar o app:** [**BrutAll.apk**](https://github.com/LucasBritoSilva/Aplicativo-All/releases/latest/download/BrutAll.apk)
> (versão final). O passo a passo está em [Como instalar](#como-instalar).

---

## Os módulos

O menu lateral (botão ☰ no canto superior esquerdo) mostra as categorias.
Toque numa categoria para ver os módulos dela. **Toque e segure** um módulo
(no menu ou na tela inicial) para fixá-lo na tela inicial ou ocultá-lo.

### 1. Organização pessoal
| Módulo | O que faz |
| --- | --- |
| **Tarefas** | Criar, editar, concluir e reabrir tarefas, com descrição, prazo, prioridade (alta, média, baixa) e subtarefas. Filtros por pendentes/concluídas e busca. |
| **Rotina** | Rotina híbrida planejada por você: compromissos fixos, atividades flexíveis e descanso, repetidos nos dias da semana escolhidos, inclusive atividades que passam da meia-noite (ex.: 23h às 3h). Visão do dia e da semana, uma notificação só no início, tolerância de atraso configurável, cronômetro opcional, sessões múltiplas, Lista de Retomadas, Reorganizar e histórico com indicadores. [Detalhes](docs/ROTINA.md). |
| **Prioridades diárias** | Até 3 prioridades por dia, com reordenação e conclusão. Cada dia começa com uma lista nova; os dias anteriores ficam no histórico. |
| **Contador de dias** | Quantos dias faltam para uma data ou quantos dias se passaram desde ela. |
| **Desafios pessoais** | Desafios por número de dias ou por quantidade, com registros, porcentagem, sequência atual e lista de concluídos. Interromper não apaga o progresso. |
| **Pausas para descanso** | Cronômetro de foco e pausa configurável: iniciar, pausar, continuar, reiniciar. Um aviso no fim de cada período. |
| Lembretes | Avisos em horário exato, mantidos depois de reiniciar o celular. |
| Hábitos | Hábitos com meta semanal e o progresso da semana. |
| Metas | Metas de longo prazo com barra de progresso. |

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
| **Entretenimento** | Categorias que você cria, renomeia, organiza e exclui (começa com Filmes e Séries). Em cada uma: para assistir, assistidos, nota, ranking dos assistidos, temporada e episódio quando a categoria usa episódios, e o sorteio "O que assistir?". |
| **Leitura da Bíblia** | Checklist de todos os livros e capítulos (cânon protestante de 66 livros ou católico de 73), progresso por livro, por testamento e geral, e "Continuar". Não inclui o texto bíblico. |

### 6. Ferramentas e análise
| Módulo | O que faz |
| --- | --- |
| **Decisor aleatório** | Sorteia um número num intervalo ou uma opção de uma lista escrita por você. |
| **Limite de uso de aplicativos** | Limite diário por app, tempo usado e restante. Para cada app você escolhe o modo: **contador flutuante** sobre o app ou **notificação ao atingir o limite**. Não bloqueia nada. [Limitações](docs/LIMITACOES.md#limite-de-uso-de-aplicativos). |
| **Estatísticas pessoais** | Indicadores reais por período (7, 30, 90 dias, 1 ano): tarefas, rotina, prioridades, hábitos, desafios, conhecimentos, treinos, peso, leitura. Sem dados, mostra vazio. |

### Personalização (Configurações)
- **Cor do aplicativo:** escolha a cor de destaque (o roxo é a original e
  pode ser restaurado). A escolha vale na hora e fica salva.
- **Fixar e ocultar módulos:** fixados aparecem primeiro na tela inicial;
  ocultos somem do menu e da tela inicial, sem apagar os dados.
- **Funcionalidades ocultadas:** lista do que foi ocultado, para restaurar
  um por um ou todos de uma vez.

---

## Requisitos

- Android **7.0 (API 24) ou mais novo**.
- Cerca de 150 MB livres para instalar.
- Internet: **não é usada**. O BrutAll não tem permissão de internet; links
  (desejos, WhatsApp) são abertos em outros apps.

## Permissões

Cada permissão só é pedida quando a função que precisa dela é usada. Negar
uma permissão não trava o app: só aquela função fica limitada.

| Permissão | Para quê | Quando é pedida |
| --- | --- | --- |
| Notificações | Aviso no início das atividades da rotina, lembretes, fim das pausas e limite de apps atingido | Ao usar uma dessas funções |
| Alarmes e lembretes (alarme exato) | Avisar no minuto certo | Concedida na instalação no Android 13+; no Android 12, o botão em Configurações abre a tela certa |
| Iniciar com o sistema | Reagendar avisos e o monitor de uso após reiniciar | Automática |
| Microfone | Ideias por voz | Ao abrir a captura por voz |
| Biometria | Abrir o cofre | Ao abrir o cofre |
| Acesso ao uso | Ler o tempo de uso de cada app (Limite de apps) | Você libera na tela do módulo |
| Sobrepor a outros apps | Contador flutuante do Limite de apps | Você libera na tela do módulo |
| Serviço em primeiro plano | Manter o monitor de uso ligado (com notificação fixa) | Ao ligar o monitoramento |

## Privacidade e armazenamento

- Os dados ficam **só no celular**, num banco SQLite privado do app. Não há
  servidor, conta, anúncio, coleta de dados nem sincronização em nuvem.
- **O app não tem backup nem recuperação de dados.** O backup automático e a
  transferência entre aparelhos do Android também estão desligados. Ao
  desinstalar o BrutAll, as informações são perdidas.
- O cofre é cifrado com uma chave que não sai do aparelho. A tela do cofre
  não aparece em capturas de tela nem na lista de apps recentes.
- O repositório público contém só o código e o APK. Nenhum dado de quem usa
  o app vai para o GitHub.

---

## Como instalar

1. No celular, abra o link
   [**BrutAll.apk**](https://github.com/LucasBritoSilva/Aplicativo-All/releases/latest/download/BrutAll.apk).
2. Quando o download terminar, toque no arquivo.
3. Se aparecer "Por segurança, seu telefone não permite instalar apps
   desconhecidos desta fonte", toque em **Configurações**, ative **Permitir
   desta fonte** e volte.
4. Toque em **Instalar** e depois em **Abrir**.

> O Google Play Protect pode avisar que o app é desconhecido (ele não está
> na Play Store). Toque em **Mais detalhes → Instalar assim mesmo**.

- **Se você tem o "All" 2.0.0 instalado:** o BrutAll instala por cima e
  mantém os dados (filmes, séries e animes viram categorias do
  Entretenimento).
- **Se você tem o "App Pessoal" antigo:** ele é outro app; os dois podem
  ficar instalados e os dados dele não passam para o BrutAll.

---

## Para quem programa

Projeto Flutter (Dart) com banco local **drift** (SQLite), estado com
**Riverpod** e uma pequena parte nativa em **Kotlin** (cofre, uso de apps,
alarmes exatos).

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
  de debug (só para teste). Ver [docs/PUBLICACAO.md](docs/PUBLICACAO.md).
- No Windows, se a pasta do projeto tiver acentos, use o `gerar_apk.bat`.

| Pasta | Conteúdo |
| --- | --- |
| `lib/core/` | Banco, navegação, notificações, permissões, tema, componentes, ponte nativa |
| `lib/features/<módulo>/` | Um módulo por pasta (`data`, `domain`, `ui`) |
| `android/app/src/main/kotlin/` | Cofre (Keystore), uso de apps, monitor e alarmes exatos |
| `test/` | Testes automáticos (regras, banco, migração e abertura de todas as telas) |
| `docs/` | Rotina, segurança do cofre, limitações, publicação, decisões |

Documentos: [Decisões técnicas](docs/DECISOES.md) ·
[Limitações e funcionamento offline](docs/LIMITACOES.md) ·
[Rotina](docs/ROTINA.md) · [Cofre](docs/SEGURANCA_DO_COFRE.md) ·
[Publicação](docs/PUBLICACAO.md).

## Licença

Nenhuma licença de código aberto foi escolhida. O código pode ser visto e
o APK pode ser baixado e usado, mas os direitos de redistribuição e
modificação continuam reservados ao autor.

---

<p align="center"><sub>BrutAll - App desenvolvido por Lucas Brito Silva</sub></p>

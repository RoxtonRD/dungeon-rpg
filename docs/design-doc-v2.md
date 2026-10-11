# Design Doc — v2: Dungeon de Salas + Cidade

> Dungeons of Praesidium. Substitui o mapa de nós da v1 por andares de salas
> exploráveis. Reaproveita integralmente: combate, eventos, itens, loja,
> formação, save, scaling. **Trocamos o mapa, não o jogo.**

## Fase 1 — Dungeon de salas (esta missão)

### Estrutura

- Cada dungeon tem **4 andares** de salas quadradas em grade.
- Salas por andar (base ± aleatório): andar 1: 5±1 · andar 2: 7±1 ·
  andar 3: 9±1 · andar 4: 6±1 **+ boss room**.
- Geração aleatória por andar: salas conectadas ortogonalmente
  (norte/sul/leste/oeste), layout sempre totalmente conectado
  (toda sala é alcançável).
- Cada andar tem uma **sala da escada** em posição aleatória (nunca a
  sala inicial). Entrar nela dá a opção de descer — ou continuar
  explorando o andar. No andar 4 não há escada; há a **boss room**,
  visualmente destacada.

### Visibilidade e navegação

- O jogador está sempre em uma sala. Movimento: tocar em uma sala
  adjacente conectada.
- **Salas adjacentes conectadas mostram seu tipo** (combate, tesouro,
  evento, descanso, vazia, escada/boss).
- Salas a 2+ de distância: não visíveis (névoa).
- Salas já visitadas: visíveis no mapa, estado "explorada".
- Revisitar salas é grátis — sem encontros aleatórios, sem custo.
- Conteúdo de sala (combate, tesouro, evento) é consumido ao resolver:
  sala vira "vazia/explorada".

### Conteúdo das salas

- Tipos sorteados na geração, com pesos por andar (mais combates e
  eventos em andares fundos; ajustáveis em constantes).
- Reusa 100% do existente: os 4 eventos (fonte, mercador, altar, baú),
  descanso, tesouro. A sala de combate abre a tela de combate atual.
  *(Atualizado em 2026-10: os encontros agora vêm de **grupos autorados por
  andar** e há **salas de elite** opcionais; veja "Encontros v3" abaixo.)*
- Scaling de dificuldade: manter a fórmula
  `pow(1.5, dungeon_level−1) × (1 + (andar−1)×0.15)` — agora com 4 andares.
  O escalonamento por masmorra é **exponencial** porque o poder do grupo
  é composto (níveis + ultimates no nível 5); com a rampa linear antiga
  as masmorras profundas ficavam *mais fáceis* que a primeira.

### Fim de dungeon

- Derrotar o boss do andar 4 → tela/mensagem de conclusão → única
  opção: **voltar para a cidade**.
- TPK e fuga: regras atuais mantidas (revive 25% HP, perde 20% ouro),
  retorno para a cidade.

## Fase 2 — Cidade (missão seguinte, NÃO nesta)

- A cidade vira o hub entre dungeons: Mercado, Personagens, Formação,
  Entrar na Masmorra.
- Mercado: itens fixos (poções) + itens aleatórios com estoque
  limitado, resetando ao completar/fugir/morrer na dungeon.
- Menu principal permanece: Continuar / Nova Aventura.

### Personalização do grupo (implementado)

- **Nova Aventura abre a tela de Criação de Personagem** (após a
  confirmação digitada quando existe save). Nada é apagado até confirmar
  a criação — voltar preserva o save.
- **Os 4 heróis são criados pelo jogador**, um por vez (abas de slot):
  nome digitado (≤16, não-vazio), classe escolhida e skin escolhida
  (com prévia). O slot 0 é marcado como personagem principal.
- **Máximo de 2 heróis por classe** no grupo. As classes já cheias nos
  outros slots ficam travadas ao editar um slot. O grupo é sempre de 4
  (grade 2x2 da formação).
- Na cidade (tela **Personagens**) dá para **renomear e trocar a skin**
  de qualquer herói — só cosmético, a classe nunca muda.
- **Skins são drop-in**: `HeroArt` resolve a arte pela skin com fallback
  para a classe; ver `assets/heroes/README.md`. Skins numeradas por classe.
- **Skins comuns e desbloqueáveis**: skins comuns (arte neutra, qualquer
  classe) e skins travadas por ouro/nível/evento vivem no catálogo
  `resources/skins/catalog.tres` (`SkinData`); posse por save em
  `GameState.owned_skins`. Compra na tela Personagens; nível libera na
  subida de nível (qualquer herói); evento pela **sala Santuário** rara
  (`SHRINE_CHANCE` por andar) que concede uma skin de evento ainda não
  possuída via `GameState.unlock_skin()` — ou ouro de consolação se já
  tiver todas. IAP real fica para o futuro; a posse é offline/cliente
  por enquanto.
- Save versão 3: `custom_name`, `skin_id`, `is_main` por herói. Saves v2
  são rejeitados (começa jogo novo).

## Classes novas (Conjuradora e Alquimista)

- **Conjuradora** (frente ou fundo): luta com "magias físicas" — armas
  conjuradas que **escalam com MAG mas resolvem como dano físico** (DEF
  cheia, ao contrário da magia que sofre 40% da DEF). Habilita-se pelo
  novo `SkillData.damage_stat` (AUTO/ATK/MAG); `AUTO` mantém o
  comportamento histórico de todas as habilidades existentes.
- **Alquimista** (fundo): buffs, cura leve e **auto-buff** (Poção de
  Batalha, +ATQ/+DEF) que a deixa segurar a linha de frente. Usa o novo
  **REGEN** (`CombatStatus.Kind.REGEN` + `heal_over_time`/`hot_duration`),
  cura por rodada que espelha o DoT e escala por tier igual.
- O grupo continua com **4 heróis**: `Party.CLASS_PATHS` é só o grupo
  padrão (limitado a `PARTY_SIZE`), enquanto `Party.ALL_CLASS_IDS` lista
  as 6 classes jogáveis para a criação.
- Arte: sem `assets/heroes/<classe>/`, `HeroArt` cai no placeholder
  colorido por classe — as classes já são jogáveis; a arte entra depois.

## Status effects persistentes + contador global de turnos

- Buffs, debuffs e regeneração **vivem no Hero**, não no Battler descartado a
  cada combate: o Battler compartilha a lista por referência, então tudo que o
  combate aplica/consome já é a lista persistente.
- `GameState.turn_counter` avança a cada rodada de combate **e a cada sala
  nova explorada** (revisitar salas já exploradas não conta, D-038/E3); as
  durações caem junto (`Party.tick_statuses`).
- Andar aplica regeneração e veneno. Veneno nunca mata fora de combate (piso de
  1 HP) — não existe caminho de derrota fora do combate.
- **Pré-buff é intencional**: curas e buffs podem ser lançados na tela
  Personagens gastando MP, e permanecem ao entrar na sala de combate.
- O descanso limpa **debuffs e DoT** (buffs ficam); tudo é limpo ao
  terminar/abandonar a run e no TPK.
- Resolvido (E3): o tick só acontece em sala nova, então andar entre salas
  conhecidas não re-aplica regeneração.

## Encontros v3 (E1–E3, outubro 2026)

Resumo; a especificação completa está na skill `design-encounter` e em
D-038..D-041.

- **Papéis de IA** (`EnemyData.ai_role`): BRUTE, SKIRMISHER, CASTER e
  SUPPORT, cada um com seu jeito de escolher alvo; provocar (taunt) sempre
  tem prioridade.
- **Ataques telegrafados** (`SkillData.telegraph_turns`): o inimigo gasta
  um turno "carregando" (status CHARGING + banner) e o golpe cai no turno
  seguinte; se ele morrer antes, o golpe se perde.
- **Grupos de encontro** (`EncounterGroupData` em `resources/encounters/`):
  5 grupos normais por andar e 2 grupos de elite nos andares 2–4.
- **Salas de elite**: opcionais (nunca no único caminho até a escada), nos
  andares 2–4; recompensa XP ×1,5, ouro ×2 e um item garantido.
- **Pressão no calabouço** (E3):
  - descanso: +50% do HP máx. e +25% do MP máx.; heróis caídos voltam
    com 25% de HP e 25% de MP;
  - Fonte: +30% do HP;
  - cota de lutas por andar: mín. 2/3/4/3, máx. = mín. + 2 (o descanso
    é o último tipo convertido em luta);
  - sem tick ao revisitar salas.
- Os números são ajustados pelo bot (E4, skill `balance-loop`).

## Loot (tiers + drops)

- **Tiers de raridade** por item (Comum/Incomum/Raro/Épico) em `ItemData.tier`;
  coloridos na Loja e em Personagens.
- **Drops de combate** (`scripts/util/loot.gd`): um pool único ponderado por
  profundidade da masmorra. Lutas comuns têm chance (`DROP_CHANCE`) de soltar 1
  item de tier apropriado; chefes soltam 1 garantido de um pool melhor. Itens
  caem no inventário compartilhado e aparecem no painel de recompensa.
- Fora de escopo por ora: tabelas de drop por inimigo, tiers na Loja, affixes.

## Fora de escopo da v2

Tile art das salas (usa chips/retângulos temáticos por enquanto),
som, loot affixes, hardcore.

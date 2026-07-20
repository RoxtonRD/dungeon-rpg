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
- Reusa 100% do existente: encounters e pools atuais, os 4 eventos
  (fonte, mercador, altar, baú), descanso, tesouro. A sala de combate
  abre a tela de combate atual sem mudanças.
- Scaling de dificuldade: manter a fórmula
  `1 + (andar−1)×0.15 + (dungeon_level−1)×0.20` — agora com 4 andares.

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

## Fora de escopo da v2

Tile art das salas (usa chips/retângulos temáticos por enquanto),
som, novas classes, loot affixes, hardcore.

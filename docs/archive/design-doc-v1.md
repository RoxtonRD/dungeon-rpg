# Design Doc — RPG Dungeon Crawler (estilo Monster's Den) — v1

> Documento de planejamento para um RPG dungeon-crawler por turnos, mobile,
> feito em Godot 4.6. Serve como ponto de partida para o desenvolvimento
> com o Claude Code. A v1 é deliberadamente enxuta: o objetivo é um jogo
> **funcional e divertido** com o mínimo de sistemas.

---

## 1. Visão geral

- **Gênero:** RPG dungeon-crawler tático por turnos.
- **Referência principal:** Monster's Den — combate por turnos, party fixa,
  dungeon como mapa de nós, loot e progressão entre dungeons.
- **Plataforma:** Android (mobile), orientação retrato.
- **Engine:** Godot 4.6, GDScript.
- **Arte:** retratos de personagens, itens e inimigos desenhados à mão pelo
  autor. Todo o resto da UI é construído com nós do Godot (sem texturas).
- **Idioma da UI:** português (pt-BR).

### Princípio de escopo

A v1 entrega o loop central e nada além dele:

> entrar na dungeon → lutar → ganhar loot → ficar mais forte → próxima dungeon

Qualquer sistema que não sirva diretamente a esse loop fica para depois da v1.

---

## 2. O que entra na v1

| Sistema | Descrição na v1 |
|---|---|
| Classes | 4 classes fixas de party: Guerreiro, Clérigo, Ladino, Mago. |
| Combate | Por turnos, ordem de iniciativa, fileiras frente/trás. |
| Formação | Grade simples 2×2 (frente/trás). Inimigos miram a frente primeiro. |
| Dungeon | Mapa de nós procedural, ramificado, com 3 andares. |
| Tipos de nó | Combate, tesouro, evento, descanso, chefe. |
| Skills | 4 skills por classe (16 no total), desbloqueio por nível. |
| Progressão | XP, níveis, 1 Ponto de Skill (SP) por nível. |
| Inventário | Slots de arma/armadura/acessório com modificadores de stat. |
| Loja | Loja única de tier fixo (sem tiers escaláveis). |
| Persistência | Save em arquivo. Em caso de TPK: revive a 25% HP, perde 20% do ouro. |

---

## 3. O que NÃO entra na v1 (backlog pós-v1)

Estes itens foram conscientemente cortados. Não são "esquecidos" — são
adiados. Cada um pode virar uma feature futura.

- **Grade tática 4×3 com acurácia por distância.** Monster's Den usa só
  frente/trás; a grade 2×2 já é fiel ao gênero. A grade rica incha o projeto.
- **Modo Hardcore.** Adiado.
- **Loja em tiers escaláveis.** v1 usa loja de tier único.
- **5 andares e 8 skills por classe.** v1 reduz para 3 andares e 4 skills.
- **Som, animações além de partículas de combate, afixos de loot.**

---

## 4. Estrutura técnica no Godot

### 4.1 Design data-driven com Resources

Todo conteúdo de jogo é definido como Resource (`.tres`), não hardcoded.
Isso permite criar/balancear conteúdo como assets, sem mexer em código.

- `ClassData` — stats base, crescimento por nível, papel (frente/trás), skills.
- `SkillData` — poder, custo de MP, efeitos, nível de desbloqueio.
- `EnemyData` — stats, skills, comportamento de IA.
- `ItemData` — tipo, slot, modificadores de stat, restrições de classe.

### 4.2 Uma cena por tela

Cada tela do jogo é uma cena Godot independente, usando nós `Control` e
sinais (signals) — substituindo o padrão de canvas imediato do protótipo.

Telas previstas: Menu principal, Criação/seleção de party, Formação,
Mapa da dungeon, Combate, Inventário, Loja, Tela de resultado.

### 4.3 Combate

Máquina de estados (state machine) para o fluxo de turnos. Estados típicos:
início do turno → seleção de ação → resolução → checagem de fim → próximo turno.

### 4.4 Persistência

Save em arquivo via `FileAccess` (JSON) ou `ConfigFile`. Manter desde já a
disciplina de versionar o formato do save para permitir migrações futuras.

### 4.5 Resolução e layout

Resolução base em retrato, escalada para o viewport. Definir nas Project
Settings (stretch mode/aspect) logo no início.

---

## 5. Fluxo de trabalho

### 5.1 Controle de versão (GitHub)

- Repositório Git no GitHub desde o primeiro dia.
- **Projeto fora do OneDrive** — o repositório Git é o backup. (No protótipo
  anterior o OneDrive piorava travamento de arquivos durante o build.)
- `.gitignore` apropriado para Godot logo no início — a pasta `.godot/` é
  cache e **não** deve ir para o repositório.
- Commits pequenos e frequentes, um por fatia de trabalho concluída. Isso
  cria um ponto de retorno seguro a cada passo.

### 5.2 Trabalhando com o Claude Code

- Criar um arquivo `CLAUDE.md` na raiz do projeto com: stack (Godot 4.x,
  GDScript, mobile retrato), convenções (Resources `.tres` para dados, uma
  cena por tela) e o escopo da v1. O Claude Code lê esse arquivo
  automaticamente, evitando repetir contexto a cada sessão.
- Trabalhar em **fatias pequenas e verificáveis** — ex.: "implemente a tela
  de combate com placeholders", não "faça o combate". Rodar no Godot e
  conferir antes de seguir.
- Pedir **placeholders explícitos para arte** — usar `ColorRect` ou ícones
  genéricos onde entrariam os retratos, para que código e arte avancem em
  trilhas separadas e independentes.

### 5.3 Asset "Godot AI" (opcional, recomendado)

O asset Godot AI conecta o Claude Code direto ao editor Godot via MCP,
permitindo que ele construa cenas/UI e veja o resultado por screenshots.
É útil, mas deve entrar **na ordem certa**:

1. Primeiro: repositório Git funcionando (rede de segurança para reverter).
2. Depois: projeto base no Godot rodando com placeholders.
3. Só então: instalar e ativar o Godot AI para acelerar a construção da UI.

Requer Godot 4.3+ e o utilitário `uv`. Como é uma ferramenta nova, manter os
commits frequentes para poder reverter qualquer mudança indesejada no editor.

---

## 6. Roteiro sugerido (ordem de implementação)

Cada etapa termina jogável/verificável e vira pelo menos um commit.

1. **Fundação** — repositório Git, `.gitignore`, projeto Godot, `CLAUDE.md`,
   Project Settings de resolução retrato.
2. **Dados** — definir os Resources (`ClassData`, `SkillData`, `EnemyData`,
   `ItemData`) e criar conteúdo inicial mínimo.
3. **Party** — criação/seleção das 4 classes; XP e leveling; SP.
4. **Combate** — máquina de estados de turnos, frente/trás, com placeholders.
5. **Dungeon** — geração do mapa de nós ramificado; tipos de nó.
6. **Inventário e equipamento** — slots e modificadores de stat.
7. **Loja** — loja de tier único; comprar/vender.
8. **Persistência** — save em arquivo; regra de TPK.
9. **Formação** — tela de grade 2×2 antes da dungeon.
10. **Polish de UI** — temas, layout, substituição de placeholders pelos
    retratos finais.

---

## 7. Lições do protótipo anterior

Pontos do protótipo Praesidium Dungeons que valem carregar como aprendizado:

- **O design de sistemas do protótipo era sólido** — fórmulas de SP, scaling
  de skills, geração de nós, regras de persistência no TPK. Reaproveitar como
  *design*, mesmo recomeçando o código do zero.
- **A dor estava no empacotamento, não no jogo** — a cadeia de build do
  Capacitor era o gargalo. Godot exporta APK direto; esse problema some.
- **Planejar antes de codar** — o protótipo sofreu por falta de planejamento
  inicial. Este documento existe para evitar repetir isso.

// Dungeon: a node-based map (3-4 columns of nodes that branch).
// Each node: combat | treasure | event | rest | boss

const Dungeon = {
  // Generate a dungeon run with N floors of nodes
  generate(level = 1, floors = 5) {
    const map = [];
    for (let f = 0; f < floors; f++) {
      const row = [];
      const isLast = f === floors - 1;
      const width = isLast ? 1 : (f === 0 ? 1 : 2 + (Math.random() < 0.5 ? 1 : 0));
      for (let i = 0; i < width; i++) {
        let kind;
        if (isLast) kind = 'boss';
        else if (f === 0) kind = 'combat';
        else {
          const r = Math.random();
          if (r < 0.55) kind = 'combat';
          else if (r < 0.78) kind = 'treasure';
          else if (r < 0.90) kind = 'event';
          else kind = 'rest';
        }
        row.push({ kind, visited: false, idx: i });
      }
      map.push(row);
    }
    return {
      level,
      floors,
      map,
      currentFloor: 0,
      currentNode: 0,
    };
  },

  rollEncounter(level) {
    const pools = [
      // lvl 1 — critters, weak humanoids
      ['goblin', 'goblin', 'bat', 'wolf', 'spider'],
      // lvl 2 — undead, bandits, fast enemies
      ['skeleton', 'slime', 'bandit', 'darkElf', 'gnoll', 'spider'],
      // lvl 3 — tougher humanoids, undead, aerial
      ['orc', 'ghoul', 'harpy', 'cultist', 'darkElf', 'gnoll'],
      // lvl 4 — heavies
      ['golem', 'ogre', 'stoneTroll', 'orc', 'cultist'],
      // lvl 5+ — elite mix
      ['golem', 'ogre', 'stoneTroll', 'ghoul', 'harpy', 'cultist'],
    ];
    const pool  = pools[Math.min(level - 1, pools.length - 1)];
    const count = irand(2, 4);
    const enc   = [];
    for (let i = 0; i < count; i++) enc.push({ id: choice(pool) });
    return enc;
  },

  rollBoss(level) {
    // Each dungeon level has a distinct boss encounter.
    if (level <= 1) return [{ id: 'necromancer'    }, { id: 'skeleton'  }];
    if (level <= 2) return [{ id: 'vampire'        }, { id: 'bat'       }, { id: 'bat'      }];
    if (level <= 3) return [{ id: 'werewolf'       }, { id: 'gnoll'     }, { id: 'wolf'     }];
    if (level <= 4) return [{ id: 'dragonHatchling'}, { id: 'orc'       }];
    if (level <= 5) return [{ id: 'wraith'         }, { id: 'skeleton'  }, { id: 'ghoul'    }];
    if (level <= 6) return [{ id: 'deathKnight'    }, { id: 'skeleton'  }, { id: 'skeleton' }];
    return             [{ id: 'lichKing'        }, { id: 'wraith'    }, { id: 'skeleton' }];
    // Level 8+ could use hydra — reserved for a secret/ultimate run
  },

  // Random events
  rollEvent() {
    const events = [
      {
        title: 'Fonte Antiga',
        desc: 'Uma fonte cristalina brilha com luz suave. Beber dela?',
        options: [
          { text: 'Beber', effect: () => { Party.fullHeal(Save.state.party); return 'O grupo é completamente curado!'; } },
          { text: 'Ignorar', effect: () => 'Vocês seguem em frente.' },
        ],
      },
      {
        title: 'Mercador Errante',
        desc: 'Um velho mercador oferece uma poção de cura por 30 ouro.',
        options: [
          { text: 'Comprar (30 ouro)', cond: () => Save.state.gold >= 30, effect: () => { Save.state.gold -= 30; Save.giveItem('potion_heal'); return 'Poção adquirida.'; } },
          { text: 'Recusar', effect: () => 'Vocês seguem em frente.' },
        ],
      },
      {
        title: 'Altar Sombrio',
        desc: 'Um altar sussurra promessas de poder em troca de sangue.',
        options: [
          { text: 'Sacrificar HP por XP', effect: () => {
            for (const c of Save.state.party) c.hp = Math.max(1, Math.floor(c.hp * 0.5));
            for (const c of Save.state.party) Party.awardXP(c, 12);
            return 'Cada herói perde metade do HP, mas ganha 12 XP.';
          } },
          { text: 'Recuar', effect: () => 'Vocês recuam, evitando o altar.' },
        ],
      },
      {
        title: 'Baú Suspeito',
        desc: 'Um baú trancado pulsa com energia.',
        options: [
          { text: 'Forçar (pode dar errado)', effect: () => {
            if (Math.random() < 0.6) { Save.giveItem(choice(['potion_heal','ring_might','ring_focus'])); return 'Sucesso! Item dentro.'; }
            for (const c of Save.state.party) c.hp = Math.max(1, c.hp - 8);
            return 'Armadilha! Cada herói perde 8 HP.';
          } },
          { text: 'Deixar', effect: () => 'Melhor não arriscar.' },
        ],
      },
    ];
    return choice(events);
  },

  resolveTreasure() {
    const loot = rollLoot(Save.state.runState ? Save.state.runState.level : 1);
    let gold = 0; const items = [];
    for (const l of loot) {
      if (l.kind === 'gold') gold += l.amount;
      else items.push(l.id);
    }
    Save.state.gold += gold;
    for (const id of items) Save.giveItem(id);
    return { gold, items };
  },

  resolveRest() {
    Party.fullHeal(Save.state.party);
    return 'O grupo descansa, recuperando HP e MP.';
  },

  enterRun(level = 1) {
    Save.state.runState = this.generate(level);
    Save.save();
  },

  exitRun(reason) {
    // reason: 'victory'|'defeat'|'flee'
    Save.state.runState = null;
    if (reason === 'defeat') {
      // NORMAL MODE: keep XP, items, equipment. Revive with 1 HP each.
      for (const c of Save.state.party) {
        c.hp = Math.max(1, Math.floor(Party.effectiveHPMax(c) * 0.25));
        c.mp = Math.max(0, Math.floor(Party.effectiveMPMax(c) * 0.25));
      }
      // Lose 20% gold as "rescue fee"
      const lost = Math.floor(Save.state.gold * 0.2);
      Save.state.gold -= lost;
      Save.state.stats.defeats++;
    } else if (reason === 'victory') {
      Party.fullHeal(Save.state.party);
      Save.state.stats.victories++;
      // Upgrade shop tier (capped at 5) and refresh stock
      Save.state.shopLevel = Math.min(5, (Save.state.shopLevel || 1) + 1);
      Save.state.shopStock = generateShopStock(Save.state.shopLevel);
    }
    Save.state.stats.runs++;
    Save.save();
  },
};

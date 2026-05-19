// Game data: classes, skills, enemies, items, dungeons.

const CLASSES = {
  warrior: {
    name: 'Guerreiro', sprite: 'warrior', role: 'front',
    baseHP: 38, baseMP: 8,
    hpPerLvl: 9, mpPerLvl: 1,
    atk: 7, def: 5, mag: 1, spd: 4,
    atkPerLvl: 2, defPerLvl: 2, magPerLvl: 0, spdPerLvl: 1,
    //         Lv1           Lv1        Lv2       Lv3          Lv4        Lv5        Lv6          Lv7
    skills: ['slash',      'guard',  'cleave', 'shieldBash', 'provoke', 'warCry', 'whirlwind', 'execute'],
  },
  cleric: {
    name: 'Clérigo', sprite: 'cleric', role: 'back',
    baseHP: 28, baseMP: 22,
    hpPerLvl: 6, mpPerLvl: 4,
    atk: 3, def: 3, mag: 6, spd: 4,
    atkPerLvl: 1, defPerLvl: 1, magPerLvl: 2, spdPerLvl: 1,
    //         Lv1        Lv1      Lv2       Lv3          Lv4         Lv5         Lv6          Lv7
    skills: ['smite',   'heal',  'bless', 'holyLight', 'barrier',  'healAll',  'holyNova',  'revive'],
  },
  rogue: {
    name: 'Ladino', sprite: 'rogue', role: 'front',
    baseHP: 30, baseMP: 12,
    hpPerLvl: 7, mpPerLvl: 2,
    atk: 6, def: 3, mag: 2, spd: 7,
    atkPerLvl: 2, defPerLvl: 1, magPerLvl: 0, spdPerLvl: 2,
    //         Lv1        Lv1          Lv2       Lv3            Lv4            Lv5            Lv6            Lv7
    skills: ['stab',  'backstab',  'poison', 'shadowStep', 'smokeScreen', 'venomBlade', 'relentless', 'assassinate'],
  },
  mage: {
    name: 'Mago', sprite: 'mage', role: 'back',
    baseHP: 24, baseMP: 28,
    hpPerLvl: 5, mpPerLvl: 5,
    atk: 2, def: 2, mag: 8, spd: 5,
    atkPerLvl: 1, defPerLvl: 1, magPerLvl: 3, spdPerLvl: 1,
    //           Lv1          Lv1        Lv2          Lv3            Lv4             Lv5            Lv6          Lv7
    skills: ['firebolt',   'frost',  'fireball',  'iceSpike',  'magicMissile', 'thunderbolt', 'blizzard', 'arcaneBlast'],
  },
};

// ── SKILLS ───────────────────────────────────────────────────────────────────
// unlockLvl : minimum hero level required
// type      : 'phys' | 'mag' | 'heal' | 'buff' | 'debuff' | 'multi' | 'revive'
// target    : 'one' | 'all' | 'self' | 'ally' | 'allies' | 'deadAlly' | 'random'
// multi     : add hitType:'phys'|'mag', hits:N
// buff      : { atk, def, mag, spd, dur }  — may also carry taunt:true or barrier:true
// debuff    : { atk, def, mag, spd, dur }
// dot       : { dmg, dur }
// finisher  : true → double power bonus when target HP < 25%
const SKILLS = {

  // ── WARRIOR ──────────────────────────────────────────────────────────────
  slash: {
    name: 'Cortar',           mp: 0,  unlockLvl: 1,
    type: 'phys', target: 'one', power: 1.0,
    desc: 'Ataque fisico basico. Sem custo de MP.',
  },
  guard: {
    name: 'Proteger',         mp: 4,  unlockLvl: 1,
    type: 'buff', target: 'self', buff: { def: 6, dur: 2 },
    desc: '+6 DEF por 2 turnos.',
  },
  cleave: {
    name: 'Talho',            mp: 6,  unlockLvl: 2,
    type: 'phys', target: 'all', power: 0.7,
    desc: 'Golpe amplo que atinge todos os inimigos.',
  },
  shieldBash: {
    name: 'Escudada',         mp: 5,  unlockLvl: 3,
    type: 'phys', target: 'one', power: 0.8,
    debuff: { spd: -4, dur: 2 },
    desc: 'Pancada com o escudo. -4 VEL no alvo.',
  },
  provoke: {
    name: 'Provocar',         mp: 6,  unlockLvl: 4,
    type: 'buff', target: 'self', buff: { def: 5, taunt: true, dur: 3 },
    desc: 'Forca inimigos a te atacar. +5 DEF por 3 turnos.',
  },
  warCry: {
    name: 'Grito de Guerra',  mp: 8,  unlockLvl: 5,
    type: 'buff', target: 'allies', buff: { atk: 4, dur: 3 },
    desc: '+4 ATK ao grupo inteiro por 3 turnos.',
  },
  whirlwind: {
    name: 'Redemoinho',       mp: 11, unlockLvl: 6,
    type: 'phys', target: 'all', power: 1.2,
    desc: 'Giro devastador: golpe fisico mais forte em todos.',
  },
  execute: {
    name: 'Executar',         mp: 10, unlockLvl: 7,
    type: 'phys', target: 'one', power: 2.5, crit: 0.5, finisher: true,
    desc: '50% critico. Dobra dano se alvo tiver HP baixo.',
  },

  // ── CLERIC ───────────────────────────────────────────────────────────────
  smite: {
    name: 'Punir',            mp: 4,  unlockLvl: 1,
    type: 'mag', target: 'one', power: 1.1,
    desc: 'Dano sagrado em 1 inimigo.',
  },
  heal: {
    name: 'Curar',            mp: 6,  unlockLvl: 1,
    type: 'heal', target: 'ally', power: 1.6,
    desc: 'Restaura HP de 1 aliado.',
  },
  bless: {
    name: 'Bencao',           mp: 8,  unlockLvl: 2,
    type: 'buff', target: 'allies', buff: { atk: 3, dur: 3 },
    desc: '+3 ATK ao grupo por 3 turnos.',
  },
  holyLight: {
    name: 'Luz Santa',        mp: 9,  unlockLvl: 3,
    type: 'mag', target: 'one', power: 1.8,
    desc: 'Raio sagrado intenso. Dano magico elevado.',
  },
  barrier: {
    name: 'Barreira',         mp: 10, unlockLvl: 4,
    type: 'buff', target: 'ally', buff: { barrier: true, dur: 99 },
    desc: 'Escudo magico que absorve 1 golpe em um aliado.',
  },
  healAll: {
    name: 'Cura em Massa',    mp: 16, unlockLvl: 5,
    type: 'heal', target: 'allies', power: 1.0,
    desc: 'Cura todos os aliados simultaneamente.',
  },
  holyNova: {
    name: 'Nova Sagrada',     mp: 14, unlockLvl: 6,
    type: 'mag', target: 'all', power: 0.9,
    desc: 'Explosao sagrada que atinge todos os inimigos.',
  },
  revive: {
    name: 'Reviver',          mp: 20, unlockLvl: 7,
    type: 'revive', target: 'deadAlly',
    desc: 'Ressuscita um aliado caido com 30% do HP maximo.',
  },

  // ── ROGUE ────────────────────────────────────────────────────────────────
  stab: {
    name: 'Estocar',          mp: 0,  unlockLvl: 1,
    type: 'phys', target: 'one', power: 1.0,
    desc: 'Golpe rapido e preciso. Sem custo de MP.',
  },
  backstab: {
    name: 'Apunhalar',        mp: 5,  unlockLvl: 1,
    type: 'phys', target: 'one', power: 1.8, crit: 0.4,
    desc: 'Ataque furtivo. 40% de chance de critico.',
  },
  poison: {
    name: 'Veneno',           mp: 6,  unlockLvl: 2,
    type: 'phys', target: 'one', power: 0.5,
    dot: { dmg: 5, dur: 3 },
    desc: 'Envenena o alvo. 5 dano por turno, 3 turnos.',
  },
  shadowStep: {
    name: 'Passo Sombrio',    mp: 7,  unlockLvl: 3,
    type: 'buff', target: 'self', buff: { spd: 5, def: 4, dur: 2 },
    desc: '+5 VEL e +4 DEF por 2 turnos.',
  },
  smokeScreen: {
    name: 'Cortina de Fumaca',mp: 8,  unlockLvl: 4,
    type: 'debuff', target: 'all',
    debuff: { atk: -3, spd: -4, dur: 2 },
    desc: 'Cega todos os inimigos. -3 ATK, -4 VEL por 2 turnos.',
  },
  venomBlade: {
    name: 'Lamina Venenosa',  mp: 10, unlockLvl: 5,
    type: 'phys', target: 'one', power: 1.2,
    dot: { dmg: 9, dur: 3 },
    desc: 'Corte com veneno intenso. 9 dano por turno.',
  },
  relentless: {
    name: 'Implacavel',       mp: 9,  unlockLvl: 6,
    type: 'multi', target: 'one', hitType: 'phys', hits: 3, power: 0.6,
    desc: 'Golpeia o mesmo alvo 3 vezes consecutivas.',
  },
  assassinate: {
    name: 'Assassinar',       mp: 14, unlockLvl: 7,
    type: 'phys', target: 'one', power: 2.8, crit: 0.6,
    desc: 'Golpe letal com 60% de chance de critico.',
  },

  // ── MAGE ─────────────────────────────────────────────────────────────────
  firebolt: {
    name: 'Dardo Igneo',      mp: 3,  unlockLvl: 1,
    type: 'mag', target: 'one', power: 1.2,
    desc: 'Projétil de fogo. Baixo custo de MP.',
  },
  frost: {
    name: 'Lamina Gelida',    mp: 7,  unlockLvl: 1,
    type: 'mag', target: 'one', power: 1.4,
    debuff: { spd: -3, dur: 2 },
    desc: 'Cristal de gelo. -3 VEL no alvo por 2 turnos.',
  },
  fireball: {
    name: 'Bola de Fogo',     mp: 10, unlockLvl: 2,
    type: 'mag', target: 'all', power: 1.0,
    desc: 'Explosao de fogo que atinge todos os inimigos.',
  },
  iceSpike: {
    name: 'Espigao de Gelo',  mp: 8,  unlockLvl: 3,
    type: 'mag', target: 'one', power: 1.6,
    debuff: { def: -4, dur: 2 },
    desc: 'Perfura a armadura do alvo. -4 DEF por 2 turnos.',
  },
  magicMissile: {
    name: 'Missil Arcano',    mp: 6,  unlockLvl: 4,
    type: 'multi', target: 'random', hitType: 'mag', hits: 3, power: 0.7,
    desc: 'Dispara 3 misseis em alvos aleatorios.',
  },
  thunderbolt: {
    name: 'Trovao',           mp: 12, unlockLvl: 5,
    type: 'mag', target: 'one', power: 1.5,
    debuff: { spd: -8, dur: 1 },
    desc: 'Raio que atordoa. -8 VEL por 1 turno.',
  },
  blizzard: {
    name: 'Nevasca',          mp: 14, unlockLvl: 6,
    type: 'mag', target: 'all', power: 0.8,
    debuff: { spd: -5, dur: 3 },
    desc: 'Tempestade de gelo. Dano em todos + -5 VEL.',
  },
  arcaneBlast: {
    name: 'Explosao Arcana',  mp: 15, unlockLvl: 7,
    type: 'mag', target: 'all', power: 1.4,
    desc: 'Explosao de magia pura. Dano maximo em todos.',
  },
};

// ── ENEMIES ──────────────────────────────────────────────────────────────────
const ENEMIES = {
  // ---- TIER 1 ----
  goblin: {
    name: 'Goblin', sprite: 'goblin', role: 'front',
    hp: 18, atk: 5, def: 2, mag: 0, spd: 5, xp: 8, gold: [3, 8],
    skills: ['eAttack'],
  },
  bat: {
    name: 'Morcego', sprite: 'bat', role: 'back',
    hp: 12, atk: 4, def: 1, mag: 0, spd: 8, xp: 7, gold: [2, 6],
    skills: ['eAttack'],
  },
  wolf: {
    name: 'Lobo', sprite: 'wolf', role: 'front',
    hp: 20, atk: 6, def: 2, mag: 0, spd: 8, xp: 10, gold: [3, 7],
    skills: ['eAttack', 'eBite'],
  },
  // ---- TIER 2 ----
  skeleton: {
    name: 'Esqueleto', sprite: 'skeleton', role: 'front',
    hp: 22, atk: 6, def: 3, mag: 0, spd: 3, xp: 10, gold: [4, 10],
    skills: ['eAttack'],
  },
  slime: {
    name: 'Slime', sprite: 'slime', role: 'front',
    hp: 28, atk: 4, def: 4, mag: 0, spd: 2, xp: 9, gold: [3, 7],
    skills: ['eAttack'],
  },
  bandit: {
    name: 'Bandido', sprite: 'bandit', role: 'front',
    hp: 28, atk: 7, def: 3, mag: 0, spd: 6, xp: 13, gold: [6, 12],
    skills: ['eAttack', 'eRage'],
  },
  darkElf: {
    name: 'Elfo Negro', sprite: 'darkElf', role: 'back',
    hp: 22, atk: 5, def: 3, mag: 4, spd: 7, xp: 12, gold: [5, 11],
    skills: ['eAttack', 'ePoison'],
  },
  // ---- TIER 3 ----
  orc: {
    name: 'Orc', sprite: 'orc', role: 'front',
    hp: 36, atk: 8, def: 4, mag: 0, spd: 4, xp: 14, gold: [6, 14],
    skills: ['eAttack', 'eRage'],
  },
  cultist: {
    name: 'Cultista', sprite: 'cultist', role: 'back',
    hp: 25, atk: 3, def: 2, mag: 7, spd: 5, xp: 14, gold: [6, 12],
    skills: ['eShadow', 'eCurse'],
  },
  // ---- TIER 4 ----
  stoneTroll: {
    name: 'Troll de Pedra', sprite: 'stoneTroll', role: 'front',
    hp: 55, atk: 9, def: 7, mag: 0, spd: 2, xp: 22, gold: [10, 20],
    skills: ['eCrush', 'eStoneSkin', 'eRegen'],
  },
  // ---- MINI-BOSS ----
  vampire: {
    name: 'Vampiro', sprite: 'vampire', role: 'back',
    hp: 48, atk: 7, def: 5, mag: 9, spd: 7, xp: 35, gold: [20, 38],
    skills: ['eBite', 'eLifeDrain'], boss: true,
  },
  // ---- BOSS TIER 1 ----
  necromancer: {
    name: 'Necromante', sprite: 'necromancer', role: 'back',
    hp: 60, atk: 4, def: 4, mag: 9, spd: 5, xp: 40, gold: [25, 40],
    skills: ['eShadow', 'eDrain'], boss: true,
  },
  // ---- BOSS TIER 2 ----
  dragonHatchling: {
    name: 'Dragao Filhote', sprite: 'dragonHatchling', role: 'front',
    hp: 90, atk: 12, def: 6, mag: 10, spd: 6, xp: 70, gold: [50, 80],
    skills: ['eAttack', 'eFireBreath', 'eRage'], boss: true,
  },
  // ---- BOSS TIER 3 ----
  lichKing: {
    name: 'Rei-Liche', sprite: 'lichKing', role: 'back',
    hp: 120, atk: 6, def: 8, mag: 16, spd: 5, xp: 130, gold: [100, 160],
    skills: ['eShadow', 'eCurse', 'eLifeDrain', 'eDrain'], boss: true,
  },

  // ════════════════════════════════════════════════════════════════════════════
  //  NEW ENEMIES
  // ════════════════════════════════════════════════════════════════════════════

  // ---- TIER 1 ----
  spider: {
    name: 'Aranha', sprite: 'spider', role: 'back',
    hp: 14, atk: 4, def: 1, mag: 0, spd: 9, xp: 8, gold: [2, 6],
    skills: ['eAttack', 'ePoison'],
  },

  // ---- TIER 2 ----
  gnoll: {
    name: 'Gnoll', sprite: 'gnoll', role: 'front',
    hp: 26, atk: 8, def: 3, mag: 0, spd: 6, xp: 12, gold: [4, 10],
    skills: ['eAttack', 'eRage'],
  },

  // ---- TIER 3 ----
  ghoul: {
    name: 'Ghoul', sprite: 'ghoul', role: 'front',
    hp: 30, atk: 5, def: 3, mag: 4, spd: 4, xp: 13, gold: [5, 11],
    skills: ['eAttack', 'eBite', 'eCurse'],
  },
  harpy: {
    name: 'Harpia', sprite: 'harpy', role: 'back',
    hp: 24, atk: 6, def: 2, mag: 5, spd: 8, xp: 14, gold: [5, 10],
    skills: ['eTalons', 'eScreech'],
  },

  // ---- TIER 4 ----
  golem: {
    name: 'Golem de Ferro', sprite: 'golem', role: 'front',
    hp: 60, atk: 10, def: 10, mag: 0, spd: 1, xp: 20, gold: [8, 16],
    skills: ['eCrush', 'eStoneSkin', 'eRegen'],
  },
  ogre: {
    name: 'Ogro', sprite: 'ogre', role: 'front',
    hp: 45, atk: 12, def: 5, mag: 0, spd: 3, xp: 18, gold: [8, 15],
    skills: ['eCrush', 'eRage'],
  },

  // ---- MINI-BOSS ----
  werewolf: {
    name: 'Lobisomem', sprite: 'werewolf', role: 'front',
    hp: 55, atk: 9, def: 4, mag: 0, spd: 8, xp: 38, gold: [22, 40],
    skills: ['eAttack', 'eBite', 'eRage', 'eEnrage'], boss: true,
  },
  wraith: {
    name: 'Espectro', sprite: 'wraith', role: 'back',
    hp: 50, atk: 3, def: 3, mag: 12, spd: 6, xp: 38, gold: [20, 36],
    skills: ['eShadow', 'eLifeDrain', 'eCurse'], boss: true,
  },

  // ---- BOSS TIER 4 ----
  deathKnight: {
    name: 'Cavaleiro da Morte', sprite: 'deathKnight', role: 'front',
    hp: 100, atk: 14, def: 10, mag: 6, spd: 5, xp: 100, gold: [80, 120],
    skills: ['eCrush', 'eDarkSlash', 'eShadow', 'eDrain'], boss: true,
  },

  // ---- BOSS TIER 5 (ultimate) ----
  hydra: {
    name: 'Hidra das Profundezas', sprite: 'hydra', role: 'front',
    hp: 160, atk: 13, def: 7, mag: 10, spd: 4, xp: 200, gold: [150, 220],
    skills: ['eBite', 'eFireBreath', 'eRage', 'eHeadRegen'], boss: true,
  },
};

const ENEMY_SKILLS = {
  // ── Basic ──────────────────────────────────────────────────────────────────
  eAttack:    { name: 'Atacar',              type: 'phys', target: 'one',  power: 1.0 },
  eRage:      { name: 'Furia',              type: 'phys', target: 'one',  power: 1.5 },
  eCrush:     { name: 'Esmagar',            type: 'phys', target: 'one',  power: 1.8 },
  eTalons:    { name: 'Garras',             type: 'phys', target: 'one',  power: 1.3 },
  eDarkSlash: { name: 'Corte Sombrio',      type: 'phys', target: 'one',  power: 1.6,
                debuff: { def: -3, dur: 2 } },
  // ── Caster ─────────────────────────────────────────────────────────────────
  eShadow:    { name: 'Sombra',             type: 'mag',  target: 'all',  power: 0.7 },
  eDrain:     { name: 'Drenar',             type: 'mag',  target: 'one',  power: 1.2, drain: true },
  eLifeDrain: { name: 'Drenar Vida',        type: 'mag',  target: 'one',  power: 1.4, drain: true },
  eFireBreath:{ name: 'Sopro Flamejante',   type: 'mag',  target: 'all',  power: 0.9 },
  eScreech:   { name: 'Grito Ensurdecedor', type: 'mag',  target: 'all',  power: 0.4,
                debuff: { spd: -4, dur: 2 } },
  // ── DoT / Debuff ───────────────────────────────────────────────────────────
  eBite:      { name: 'Mordida',            type: 'phys', target: 'one',  power: 1.1, drain: true },
  ePoison:    { name: 'Flecha Venenosa',    type: 'phys', target: 'one',  power: 0.6,
                dot: { dmg: 4, dur: 3 } },
  eCurse:     { name: 'Maldicao',           type: 'mag',  target: 'one',  power: 0.3,
                debuff: { atk: -3, def: -2, dur: 3 } },
  // ── Self-buff / Heal ───────────────────────────────────────────────────────
  eStoneSkin: { name: 'Pele de Pedra',      type: 'buff', target: 'self', buff: { def: 8, dur: 3 } },
  eRegen:     { name: 'Regenerar',          type: 'heal', target: 'self', power: 0.8 },
  eHeadRegen: { name: 'Regenerar Cabecas',  type: 'heal', target: 'self', power: 2.0 },
  // ── Conditional (only triggers at low HP) ─────────────────────────────────
  eEnrage:    { name: 'Furia Selvagem',     type: 'buff', target: 'self',
                buff: { atk: 5, spd: 3, dur: 3 }, condition: 'lowHp' },
};

// ── ITEMS ─────────────────────────────────────────────────────────────────────
const ITEMS = {
  sword_rusty:      { name: 'Espada Enferrujada',    slot: 'weapon',  sprite: 'sword',  mods: { atk: 2 },              value: 15,  classes: ['warrior','rogue'] },
  sword_iron:       { name: 'Espada de Ferro',        slot: 'weapon',  sprite: 'sword',  mods: { atk: 5 },              value: 60,  classes: ['warrior','rogue'] },
  sword_steel:      { name: 'Lamina de Aco',          slot: 'weapon',  sprite: 'sword',  mods: { atk: 9, spd: 1 },     value: 180, classes: ['warrior','rogue'] },
  dagger_shadow:    { name: 'Adaga das Sombras',      slot: 'weapon',  sprite: 'sword',  mods: { atk: 6, spd: 3 },     value: 140, classes: ['rogue'] },
  staff_apprentice: { name: 'Cajado de Aprendiz',     slot: 'weapon',  sprite: 'sword',  mods: { mag: 3 },              value: 25,  classes: ['cleric','mage'] },
  staff_runed:      { name: 'Cajado Runico',          slot: 'weapon',  sprite: 'sword',  mods: { mag: 7, mp: 4 },      value: 120, classes: ['cleric','mage'] },
  staff_arcane:     { name: 'Cajado Arcano',          slot: 'weapon',  sprite: 'sword',  mods: { mag: 12, mp: 8 },     value: 280, classes: ['cleric','mage'] },
  armor_cloth:      { name: 'Manto de Tecido',        slot: 'armor',   sprite: 'shield', mods: { def: 2, hp: 4 },      value: 20 },
  armor_leather:    { name: 'Armadura de Couro',      slot: 'armor',   sprite: 'shield', mods: { def: 4, hp: 8 },      value: 70 },
  armor_chain:      { name: 'Cota de Malha',          slot: 'armor',   sprite: 'shield', mods: { def: 7, hp: 14 },     value: 200 },
  armor_plate:      { name: 'Armadura de Placas',     slot: 'armor',   sprite: 'shield', mods: { def: 11, hp: 22 },    value: 400 },
  ring_focus:       { name: 'Anel de Foco',           slot: 'trinket', sprite: 'gold',   mods: { mp: 6, mag: 1 },      value: 80 },
  ring_might:       { name: 'Anel da Forca',          slot: 'trinket', sprite: 'gold',   mods: { atk: 2, hp: 6 },      value: 80 },
  ring_arcane:      { name: 'Anel Arcano',            slot: 'trinket', sprite: 'gold',   mods: { mag: 4, mp: 10 },     value: 160 },
  amulet_swift:     { name: 'Amuleto Veloz',          slot: 'trinket', sprite: 'gold',   mods: { spd: 3 },              value: 100 },
  amulet_ward:      { name: 'Amuleto de Guarda',      slot: 'trinket', sprite: 'gold',   mods: { def: 3, hp: 10 },     value: 130 },
  potion_heal:      { name: 'Pocao de Cura',          slot: 'consumable', sprite: 'potion', use: { heal: 30 },              value: 25  },
  potion_mana:      { name: 'Pocao de Mana',          slot: 'consumable', sprite: 'potion', use: { mp: 20 },                value: 30  },
  elixir_full:      { name: 'Elixir Pleno',           slot: 'consumable', sprite: 'potion', use: { heal: 80, mp: 40 },     value: 90  },
  tome_sp:          { name: 'Tomo de Maestria',       slot: 'consumable', sprite: 'potion', use: { sp_hero: 1 },            value: 200 },
  elixir_revival:   { name: 'Elixir de Reviver',      slot: 'consumable', sprite: 'potion', use: { reviveParty: 0.25 },    value: 100 },
};

// ── LOOT ─────────────────────────────────────────────────────────────────────
function rollLoot(level) {
  const out = [];
  out.push({ kind: 'gold', amount: irand(5 + level * 4, 12 + level * 8) });
  if (Math.random() < 0.55) {
    const pool = pickLootPool(level);
    out.push({ kind: 'item', id: pool[irand(0, pool.length - 1)] });
  }
  return out;
}

function pickLootPool(level) {
  if (level <= 1) return ['sword_rusty','staff_apprentice','armor_cloth','potion_heal','potion_heal','potion_mana'];
  if (level <= 2) return ['sword_iron','staff_apprentice','armor_leather','ring_might','ring_focus','potion_heal','potion_mana'];
  if (level <= 3) return ['sword_iron','dagger_shadow','staff_runed','armor_leather','ring_might','amulet_swift','potion_heal','potion_mana','elixir_full'];
  if (level <= 4) return ['sword_steel','dagger_shadow','staff_runed','armor_chain','ring_arcane','amulet_ward','potion_heal','potion_mana','elixir_full'];
  return ['sword_steel','staff_arcane','armor_chain','armor_plate','ring_arcane','amulet_ward','amulet_swift','elixir_full'];
}

// ── SHOP ─────────────────────────────────────────────────────────────────────
// Returns 6 item IDs for the shop stock, scaled to the current dungeon level.
// Equipment slots are limited supply (removed on purchase).
// Consumables are unlimited (never removed from stock).
function generateShopStock(dungeonLevel) {
  const lvl = Math.max(1, dungeonLevel || 1);
  const equipPools = [
    ['sword_rusty',  'staff_apprentice', 'armor_cloth',   'ring_might',  'ring_focus'             ],
    ['sword_iron',   'staff_apprentice', 'armor_leather',  'ring_might',  'ring_focus',  'amulet_swift'],
    ['sword_iron',   'dagger_shadow',    'staff_runed',    'armor_leather','ring_arcane', 'amulet_swift'],
    ['sword_steel',  'dagger_shadow',    'staff_runed',    'armor_chain',  'ring_arcane', 'amulet_ward' ],
    ['sword_steel',  'staff_arcane',     'armor_chain',    'armor_plate',  'ring_arcane', 'amulet_ward' ],
  ];
  const pool   = equipPools[Math.min(lvl - 1, equipPools.length - 1)];
  const equips = shuffle(pool).slice(0, 3);
  // Special slot: tome_sp gets more common at higher levels; elixir_revival fills mid-tier.
  const special = Math.random() < (0.08 + lvl * 0.04) ? 'tome_sp'
                : Math.random() < 0.35                 ? 'elixir_revival'
                :                                        'elixir_full';
  return [...equips, 'potion_heal', 'potion_mana', special];
}

// ── HELPERS ───────────────────────────────────────────────────────────────────
function irand(a, b) { return Math.floor(Math.random() * (b - a + 1)) + a; }
function choice(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// Party / character management.

const Party = {
  makeChar(classKey, name) {
    const cls = CLASSES[classKey];
    return {
      name, cls: classKey,
      lvl: 1, xp: 0,
      hp: cls.baseHP, hpMax: cls.baseHP,
      mp: cls.baseMP, mpMax: cls.baseMP,
      atk: cls.atk, def: cls.def, mag: cls.mag, spd: cls.spd,
      equip: { weapon: null, armor: null, trinket: null },
      skillLevels: {}, skillPoints: 1,
    };
  },

  xpForNext(lvl) {
    return Math.floor(20 * Math.pow(lvl, 1.5));
  },

  // Award XP; returns array of newly unlocked skill keys (across all level-ups).
  awardXP(c, amount) {
    c.xp += amount;
    const unlocked = [];
    while (c.xp >= this.xpForNext(c.lvl)) {
      c.xp -= this.xpForNext(c.lvl);
      unlocked.push(...this.levelUp(c));
    }
    return unlocked;
  },

  // Level up c; returns array of skill keys unlocked at the new level.
  levelUp(c) {
    const cls = CLASSES[c.cls];
    c.lvl++;
    c.hpMax += cls.hpPerLvl;
    c.mpMax += cls.mpPerLvl;
    c.atk   += cls.atkPerLvl;
    c.def   += cls.defPerLvl;
    c.mag   += cls.magPerLvl;
    c.spd   += cls.spdPerLvl;
    c.skillPoints = (c.skillPoints || 0) + 1;
    // Full restore on level-up (rewarding moment)
    c.hp = this.effectiveHPMax(c);
    c.mp = this.effectiveMPMax(c);
    // Collect skills newly unlocked at this exact level
    return cls.skills.filter(key => {
      const sk = SKILLS[key];
      return sk && sk.unlockLvl === c.lvl;
    });
  },

  // Skills the hero can currently use (unlocked by level).
  getAvailableSkills(c) {
    return CLASSES[c.cls].skills.filter(key => {
      const sk = SKILLS[key];
      return sk && c.lvl >= (sk.unlockLvl || 1);
    });
  },

  // Current upgrade level of a skill (base = 1).
  getSkillLvl(c, key) {
    return (c.skillLevels && c.skillLevels[key]) || 1;
  },

  // Max upgrade level: Lv7+ (ultimate) skills cap at 4, others at 3.
  skillMaxLvl(key) {
    const sk = SKILLS[key];
    if (!sk) return 1;
    return sk.maxLvl || (sk.unlockLvl >= 7 ? 4 : 3);
  },

  // Returns a copy of the skill definition with stats scaled by the hero's
  // current upgrade level in that skill.
  //   Lv2: +30% power, buff/debuff stats ×1.3, duration +1
  //   Lv3: +60% power, buff/debuff stats ×1.6, duration +2, MP -2, multi +1 hit
  //   Lv4: +100% power, buff/debuff stats ×2.0, duration +3, MP -3, multi +2 hits
  getUpgradedSkill(c, key) {
    const sk = SKILLS[key];
    if (!sk) return null;
    const lvl   = this.getSkillLvl(c, key);
    if (lvl <= 1) return sk;
    const bonus = lvl - 1;             // 1, 2 or 3
    const mult  = 1 + 0.3 * bonus;    // 1.3 / 1.6 / 2.0
    const s = { ...sk };
    if (s.power !== undefined) s.power = +( s.power * mult ).toFixed(2);
    if (s.buff) {
      s.buff = { ...s.buff };
      for (const k of ['atk','def','mag','spd'])
        if (s.buff[k]) s.buff[k] = Math.round(s.buff[k] * mult);
      if (s.buff.dur && s.buff.dur < 99)
        s.buff.dur = Math.min(6, s.buff.dur + bonus);
    }
    if (s.debuff) {
      s.debuff = { ...s.debuff };
      for (const k of ['atk','def','mag','spd'])
        if (s.debuff[k]) s.debuff[k] = Math.round(s.debuff[k] * mult);
      if (s.debuff.dur)
        s.debuff.dur = Math.min(6, s.debuff.dur + bonus);
    }
    if (s.dot) {
      s.dot = { ...s.dot };
      s.dot.dmg = Math.round(s.dot.dmg * mult);
      if (lvl >= 3) s.dot.dur = Math.min(5, s.dot.dur + 1);
    }
    if (s.type === 'multi') s.hits = s.hits + bonus;       // +1 per upgrade
    if (s.mp >= 3) s.mp = Math.max(1, s.mp - bonus * 2);  // -2 MP per upgrade
    return s;
  },

  // Returns true when the hero can spend 1 SP to upgrade this skill.
  canUpgradeSkill(c, key) {
    const sk = SKILLS[key];
    if (!sk) return false;
    if (c.lvl < (sk.unlockLvl || 1)) return false;
    if (this.getSkillLvl(c, key) >= this.skillMaxLvl(key)) return false;
    return (c.skillPoints || 0) >= 1;
  },

  // Spends 1 SP and increments the skill's upgrade level. Returns true on success.
  upgradeSkill(c, key) {
    if (!this.canUpgradeSkill(c, key)) return false;
    if (!c.skillLevels) c.skillLevels = {};
    c.skillLevels[key] = this.getSkillLvl(c, key) + 1;
    c.skillPoints = (c.skillPoints || 0) - 1;
    return true;
  },

  equip(c, charIdx, slot, itemId) {
    if (c.equip[slot]) Save.giveItem(c.equip[slot]);
    c.equip[slot] = itemId;
    const inv = Save.state.inventory;
    const idx = inv.findIndex(it => it.id === itemId);
    if (idx >= 0) inv.splice(idx, 1);
  },

  // Effective stats from base + equipment mods only (no combat statuses).
  stats(c) {
    let s = { atk: c.atk, def: c.def, mag: c.mag, spd: c.spd, hpBonus: 0, mpBonus: 0 };
    for (const slot of ['weapon', 'armor', 'trinket']) {
      const id = c.equip[slot];
      if (!id) continue;
      const it = ITEMS[id];
      if (!it || !it.mods) continue;
      if (it.mods.atk) s.atk += it.mods.atk;
      if (it.mods.def) s.def += it.mods.def;
      if (it.mods.mag) s.mag += it.mods.mag;
      if (it.mods.spd) s.spd += it.mods.spd;
      if (it.mods.hp)  s.hpBonus += it.mods.hp;
      if (it.mods.mp)  s.mpBonus += it.mods.mp;
    }
    return s;
  },

  effectiveHPMax(c) { return c.hpMax + this.stats(c).hpBonus; },
  effectiveMPMax(c) { return c.mpMax + this.stats(c).mpBonus; },

  isAlive(c) { return c.hp > 0; },
  partyAlive(party) { return party.some(c => this.isAlive(c)); },

  fullHeal(party) {
    for (const c of party) {
      c.hp = this.effectiveHPMax(c);
      c.mp = this.effectiveMPMax(c);
    }
  },

  useConsumable(c, itemId) {
    const it = ITEMS[itemId];
    if (!it || it.slot !== 'consumable') return false;
    if (it.use.heal)    c.hp          = Math.min(this.effectiveHPMax(c), c.hp + it.use.heal);
    if (it.use.mp)      c.mp          = Math.min(this.effectiveMPMax(c), c.mp + it.use.mp);
    if (it.use.sp_hero) c.skillPoints = (c.skillPoints || 0) + it.use.sp_hero;
    return true;
  },
};

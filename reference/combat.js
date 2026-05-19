// Turn-based combat. Monster's Den style: front/back rows.
// Combat state machine, action queue, log, animations.

const Combat = {
  state: null,

  start(party, enemies, onEnd) {
    // enemies is array of { id, ...overrides }
    const eList = enemies.map((e, i) => {
      const def = ENEMIES[e.id];
      return {
        id: e.id, name: def.name, role: def.role, sprite: def.sprite,
        hp: def.hp, hpMax: def.hp,
        atk: def.atk, def: def.def, mag: def.mag, spd: def.spd,
        xp: def.xp, gold: def.gold,
        skills: def.skills, boss: !!def.boss,
        idx: i, side: 'enemy',
        statuses: [],
      };
    });
    const pList = party.map((c, i) => ({
      ref: c, idx: i, side: 'party', statuses: [],
    }));

    this.state = {
      party: pList,
      enemies: eList,
      log: ['O combate começou!'],
      turn: 0,
      order: [],         // initiative queue for current round
      currentActor: null,
      pendingAction: null,
      animTimer: 0,
      pendingDamage: [], // floating numbers
      particles: [],     // visual hit effects
      shake: { t: 0, mag: 0 },  // screen shake
      onEnd, ended: false,
      result: null, // 'victory'|'defeat'|'flee'
      ui: { phase: 'idle', selectedSkill: null, validTargets: [] },
    };
    this.rollInitiative();
    this.nextActor();
  },

  // Compute effective combat stats for a wrapper, folding in active buff/debuff statuses.
  // wrapper: combat party wrapper {ref,statuses} or enemy object {atk,def,...,statuses}.
  // side: 'party' | 'enemy'
  effectiveStats(wrapper, side) {
    let base;
    if (side === 'party') {
      const eq = Party.stats(wrapper.ref);
      base = { atk: eq.atk, def: eq.def, mag: eq.mag, spd: eq.spd };
    } else {
      base = { atk: wrapper.atk, def: wrapper.def, mag: wrapper.mag || 0, spd: wrapper.spd };
    }
    for (const st of (wrapper.statuses || [])) {
      if (st.kind === 'buff' || st.kind === 'debuff') {
        if (st.atk !== undefined) base.atk = Math.max(0, base.atk + st.atk);
        if (st.def !== undefined) base.def = Math.max(0, base.def + st.def);
        if (st.mag !== undefined) base.mag = Math.max(0, base.mag + st.mag);
        if (st.spd !== undefined) base.spd = Math.max(0, base.spd + st.spd);
      }
    }
    return base;
  },

  rollInitiative() {
    const all = [];
    for (const p of this.state.party) if (Party.isAlive(p.ref)) {
      const s = Party.stats(p.ref);
      all.push({ side: 'party', ref: p, spd: s.spd + Math.random() * 2 });
    }
    for (const e of this.state.enemies) if (e.hp > 0) {
      all.push({ side: 'enemy', ref: e, spd: e.spd + Math.random() * 2 });
    }
    all.sort((a, b) => b.spd - a.spd);
    this.state.order = all;
  },

  nextActor() {
    const s = this.state;
    if (s.ended) return;
    // Check victory/defeat
    if (!s.enemies.some(e => e.hp > 0)) { this.endCombat('victory'); return; }
    if (!s.party.some(p => Party.isAlive(p.ref))) { this.endCombat('defeat'); return; }

    if (s.order.length === 0) {
      this.tickStatuses();
      if (s.ended) return;
      s.turn++;
      this.rollInitiative();
    }

    // Skip dead actors
    let next;
    while (s.order.length) {
      const candidate = s.order.shift();
      if (candidate.side === 'party' && Party.isAlive(candidate.ref.ref)) { next = candidate; break; }
      if (candidate.side === 'enemy' && candidate.ref.hp > 0) { next = candidate; break; }
    }
    if (!next) { this.nextActor(); return; }

    s.currentActor = next;
    s.ui.phase = 'idle';
    s.ui.selectedSkill = null;
    s.ui.validTargets = [];

    if (next.side === 'enemy') {
      // AI delay
      s.animTimer = 0.5;
    } else {
      // Player turn — wait for input
      this.openSkillMenu();
    }
  },

  tickStatuses() {
    const s = this.state;
    const all = [...s.party.map(p => ({ side: 'party', a: p })), ...s.enemies.map(e => ({ side: 'enemy', a: e }))];
    for (const x of all) {
      const target = x.side === 'party' ? x.a.ref : x.a;
      const statuses = x.a.statuses;
      for (let i = statuses.length - 1; i >= 0; i--) {
        const st = statuses[i];
        if (st.kind === 'dot') {
          const dmg = st.dmg;
          if (x.side === 'party') x.a.ref.hp = Math.max(0, x.a.ref.hp - dmg);
          else x.a.hp = Math.max(0, x.a.hp - dmg);
          this.log(`${this.actorName(x.a, x.side)} sofre ${dmg} de ${st.name}.`);
        }
        st.dur--;
        if (st.dur <= 0) statuses.splice(i, 1);
      }
    }
  },

  actorName(actor, side) {
    if (side === 'party') return actor.ref.name;
    return actor.name;
  },

  openSkillMenu() {
    this.state.ui.phase = 'choose_skill';
  },

  // Player chose a skill. If targeted, pick targets next.
  chooseSkill(skillKey) {
    const s = this.state;
    const actor = s.currentActor.ref.ref; // character
    const sk = Party.getUpgradedSkill(actor, skillKey);
    if (!sk) return;
    if (actor.mp < sk.mp) { this.log('MP insuficiente.'); return; }

    // Check deadAlly availability before accepting
    if (sk.target === 'deadAlly') {
      const dead = s.party.filter(p => !Party.isAlive(p.ref));
      if (!dead.length) { this.log('Nenhum aliado caido.'); return; }
    }

    s.ui.selectedSkill = skillKey;

    // Targets that resolve automatically (no player pick needed)
    if (sk.target === 'self' || sk.target === 'allies' || sk.target === 'all' || sk.target === 'random') {
      this.executePlayerAction(skillKey, null);
    } else {
      s.ui.phase = 'choose_target';
      s.ui.validTargets = this.computeValidTargets(sk);
    }
  },

  computeValidTargets(sk) {
    const s = this.state;
    if (sk.target === 'one' || sk.target === 'frontEnemy') {
      const alive = s.enemies.filter(e => e.hp > 0);
      const front = alive.filter(e => e.role === 'front');
      const pool  = front.length ? front : alive;
      return pool.map(e => ({ side: 'enemy', idx: e.idx }));
    }
    if (sk.target === 'ally') {
      return s.party.filter(p => Party.isAlive(p.ref)).map(p => ({ side: 'party', idx: p.idx }));
    }
    if (sk.target === 'deadAlly') {
      return s.party.filter(p => !Party.isAlive(p.ref)).map(p => ({ side: 'party', idx: p.idx }));
    }
    return [];
  },

  chooseTarget(side, idx) {
    const s = this.state;
    if (!s.ui.validTargets.some(t => t.side === side && t.idx === idx)) return;
    this.executePlayerAction(s.ui.selectedSkill, { side, idx });
  },

  executePlayerAction(skillKey, target) {
    const s = this.state;
    const actor = s.currentActor.ref.ref;
    const sk = Party.getUpgradedSkill(actor, skillKey);
    actor.mp -= sk.mp;

    s.ui.phase = 'animate';
    s.animTimer = 0.4;
    s.pendingAction = { kind: 'player', skillKey, target };
  },

  resolvePlayerAction(action) {
    const s = this.state;
    const { skillKey, target } = action;
    const casterWrapper = s.currentActor.ref;
    const actor = casterWrapper.ref;
    const sk = Party.getUpgradedSkill(actor, skillKey);
    const stats = this.effectiveStats(casterWrapper, 'party');

    // ── BUFF ─────────────────────────────────────────────────────────────────
    if (sk.type === 'buff') {
      let buffWrappers = [];
      if (sk.target === 'self')   buffWrappers = [casterWrapper];
      else if (sk.target === 'allies') buffWrappers = s.party.filter(p => Party.isAlive(p.ref));
      else if (sk.target === 'ally' && target) {
        const arr = target.side === 'party' ? s.party : s.enemies;
        buffWrappers = [arr[target.idx]];
      }
      for (const w of buffWrappers) {
        w.statuses.push({ kind: 'buff', name: sk.name, ...sk.buff, dur: sk.buff.dur });
        if (sk.buff.barrier) {
          // Make barrier stand out with dedicated kind
          w.statuses[w.statuses.length - 1].kind = 'barrier';
        }
      }
      this.log(`${actor.name} usa ${sk.name}.`);

    // ── DEBUFF ───────────────────────────────────────────────────────────────
    } else if (sk.type === 'debuff') {
      const targets = this.gatherTargets(sk, target, 'party');
      for (const t of targets) {
        t.a.statuses.push({ kind: 'debuff', name: sk.name, ...sk.debuff, dur: sk.debuff.dur });
      }
      this.spawnParticles({ side: 'enemy', a: s.enemies[0] || s.enemies[0] }, 'mag', 6);
      this.log(`${actor.name} usa ${sk.name}!`);

    // ── MULTI-HIT ────────────────────────────────────────────────────────────
    } else if (sk.type === 'multi') {
      const alive = s.enemies.filter(e => e.hp > 0);
      if (!alive.length) { s.pendingAction = null; s.animTimer = 0.2; return; }
      const fakeSk = { ...sk, type: sk.hitType || 'phys' };
      for (let h = 0; h < sk.hits; h++) {
        let hitTarget;
        if (sk.target === 'random') {
          const still = alive.filter(e => e.hp > 0);
          hitTarget = { side: 'enemy', a: still.length ? choice(still) : alive[0] };
        } else if (target) {
          const arr = target.side === 'party' ? s.party : s.enemies;
          hitTarget = { side: target.side, a: arr[target.idx] };
        }
        if (hitTarget && (hitTarget.side === 'party' ? Party.isAlive(hitTarget.a.ref) : hitTarget.a.hp > 0)) {
          this.applySkillEffect(fakeSk, actor, stats, hitTarget, 'party');
        }
      }

    // ── REVIVE ───────────────────────────────────────────────────────────────
    } else if (sk.type === 'revive') {
      if (target) {
        const arr = target.side === 'party' ? s.party : s.enemies;
        const tWrapper = arr[target.idx];
        const ref = tWrapper.ref;
        ref.hp = Math.max(1, Math.floor(Party.effectiveHPMax(ref) * 0.3));
        this.spawnParticles({ side: 'party', a: tWrapper }, 'heal', 14);
        this.spawnNumber({ side: 'party', a: tWrapper }, 'REVIVER!', '#e0d040', true);
        this.log(`${actor.name} revive ${ref.name}!`);
      }

    // ── HEAL ─────────────────────────────────────────────────────────────────
    } else {
      const targets = this.gatherTargets(sk, target, 'party');
      for (const t of targets) {
        this.applySkillEffect(sk, actor, stats, t, 'party');
      }
    }

    s.pendingAction = null;
    s.animTimer = 0.3;
  },

  gatherTargets(sk, chosen, mySide) {
    const s = this.state;
    if (sk.target === 'all') {
      return mySide === 'party'
        ? s.enemies.filter(e => e.hp > 0).map(e => ({ side: 'enemy', a: e }))
        : s.party.filter(p => Party.isAlive(p.ref)).map(p => ({ side: 'party', a: p }));
    }
    if (sk.target === 'allies') {
      return mySide === 'party'
        ? s.party.filter(p => Party.isAlive(p.ref)).map(p => ({ side: 'party', a: p }))
        : s.enemies.filter(e => e.hp > 0).map(e => ({ side: 'enemy', a: e }));
    }
    if (sk.target === 'self') {
      return [{ side: mySide, a: s.currentActor.ref }];
    }
    if (chosen) {
      const arr = chosen.side === 'party' ? s.party : s.enemies;
      return [{ side: chosen.side, a: arr[chosen.idx] }];
    }
    return [];
  },

  applySkillEffect(sk, actor, stats, target, casterSide) {
    const s = this.state;
    if (sk.type === 'buff' || sk.type === 'revive' || sk.type === 'debuff') return;

    // ── HEAL ─────────────────────────────────────────────────────────────────
    if (sk.type === 'heal') {
      const heal = Math.floor(stats.mag * sk.power + 5);
      const ref   = target.side === 'party' ? target.a.ref : target.a;
      const hpMax = target.side === 'party' ? Party.effectiveHPMax(ref) : ref.hpMax;
      ref.hp = Math.min(hpMax, ref.hp + heal);
      this.spawnNumber(target, '+' + heal, '#80ff80');
      this.spawnParticles(target, 'heal', 8);
      this.log(`${actor.name || actor.ref?.name || 'Aliado'} cura ${this.targetName(target)} em ${heal}.`);
      return;
    }

    // ── BARRIER ABSORPTION ───────────────────────────────────────────────────
    const barrierIdx = target.a.statuses.findIndex(st => st.kind === 'barrier');
    if (barrierIdx >= 0) {
      target.a.statuses.splice(barrierIdx, 1);
      this.spawnParticles(target, 'heal', 8);
      this.spawnNumber(target, 'BLOCK!', '#80d0ff', true);
      this.log(`A barreira de ${this.targetName(target)} absorveu o golpe!`);
      return;
    }

    // ── DAMAGE (phys / mag) ───────────────────────────────────────────────────
    const isMag = sk.type === 'mag';
    let raw  = (isMag ? stats.mag : stats.atk) * sk.power + irand(0, 3);

    // Finisher bonus: double power when target HP < 25%
    if (sk.finisher) {
      const tref0 = target.side === 'party' ? target.a.ref : target.a;
      if (tref0.hp <= tref0.hpMax * 0.25) raw *= 2;
    }

    let crit = false;
    if (sk.crit && Math.random() < sk.crit) { raw *= 1.8; crit = true; }

    const tref   = target.side === 'party' ? target.a.ref : target.a;
    const tstats = this.effectiveStats(target.a, target.side);
    const tDef   = isMag ? Math.floor(tstats.def * 0.4) : tstats.def;
    let dmg = Math.max(1, Math.floor(raw - tDef));

    tref.hp = Math.max(0, tref.hp - dmg);
    this.spawnNumber(target, String(dmg) + (crit ? '!' : ''), crit ? '#ffe040' : '#ff8080', crit);
    this.flashTarget(target, crit ? 1.0 : 0.7);

    const skName = sk.name || '';
    let pType = isMag ? 'mag' : 'phys';
    if (/fogo|igneo|fireball|firebolt|breath/i.test(skName)) pType = 'fire';
    this.spawnParticles(target, pType, crit ? 14 : 8);
    if (crit) this.shake(6, 0.22);
    else      this.shake(2, 0.10);

    this.log(`${actor.name || actor.ref?.name} usa ${sk.name} em ${this.targetName(target)} causando ${dmg}${crit ? ' CRITICO' : ''}.`);

    if (tref.hp === 0 && !target.a.deathTime) target.a.deathTime = 0.7;

    if (sk.dot)    target.a.statuses.push({ kind: 'dot',    name: sk.name, dmg: sk.dot.dmg, dur: sk.dot.dur });
    if (sk.debuff) target.a.statuses.push({ kind: 'debuff', name: sk.name, ...sk.debuff, dur: sk.debuff.dur });

    if (sk.drain) {
      const healed = Math.floor(dmg * 0.5);
      if (casterSide === 'enemy') {
        const caster = s.currentActor.ref;
        caster.hp = Math.min(caster.hpMax, caster.hp + healed);
      }
    }
  },

  targetName(t) { return t.side === 'party' ? t.a.ref.name : t.a.name; },

  spawnNumber(target, text, color, big = false) {
    this.state.pendingDamage.push({
      target, text, color, life: 1.4, age: 0, big,
    });
  },

  // Set a brief white flash on a combatant.
  flashTarget(target, amount = 0.7) {
    target.a.flashTime = 0.18;
    target.a.flashAmount = amount;
  },

  // Spawn N particles at target position. Type drives color/shape.
  spawnParticles(target, type, count = 8) {
    const s = this.state;
    const arr = target.side === 'party' ? s.party : s.enemies;
    const idx = arr.indexOf(target.a);
    const pos = UI.getCombatantPos(target.side, idx, arr);
    let palette;
    if (type === 'phys')      palette = ['#fff8d8', '#ffffff', '#e8c098'];
    else if (type === 'fire') palette = ['#ffe040', '#ff8020', '#e84020'];
    else if (type === 'mag')  palette = ['#a8c0ff', '#ffffff', '#5070c0'];
    else if (type === 'heal') palette = ['#80ff80', '#c0ffc0', '#40c060'];
    else                      palette = ['#ffffff'];
    for (let i = 0; i < count; i++) {
      const ang = Math.random() * Math.PI * 2;
      const speed = 40 + Math.random() * 80;
      s.particles.push({
        x: pos.x + (Math.random() - 0.5) * 12,
        y: pos.y - 6 + (Math.random() - 0.5) * 12,
        vx: Math.cos(ang) * speed,
        vy: Math.sin(ang) * speed - (type === 'heal' ? 30 : 10),
        life: 0.4 + Math.random() * 0.4,
        age: 0,
        color: palette[Math.floor(Math.random() * palette.length)],
        size: type === 'phys' ? 1 + Math.random() * 1.5 : 1.5 + Math.random() * 2,
        shape: type === 'phys' ? 'streak' : (type === 'heal' ? 'cross' : 'spark'),
        gravity: type === 'heal' ? -40 : 120,
      });
    }
  },

  // Trigger a screen-shake.
  shake(magnitude = 4, duration = 0.18) {
    const s = this.state;
    if (!s.shake || s.shake.t < duration) {
      s.shake = { t: duration, dur: duration, mag: magnitude };
    }
  },

  // Enemy AI turn
  enemyTurn() {
    const s = this.state;
    const e = s.currentActor.ref;
    // Filter skills by conditions (e.g. eEnrage only fires at low HP)
    const usable = e.skills.filter(key => {
      const def = ENEMY_SKILLS[key];
      if (!def) return false;
      if (def.condition === 'lowHp'    && e.hp > e.hpMax * 0.5) return false;
      if (def.condition === 'notLowHp' && e.hp <= e.hpMax * 0.5) return false;
      return true;
    });
    const skKey = choice(usable.length ? usable : e.skills);
    const sk = ENEMY_SKILLS[skKey];
    const eStats = this.effectiveStats(e, 'enemy');

    // ── Self-target skills ────────────────────────────────────────────────────
    if (sk.target === 'self') {
      if (sk.type === 'buff') {
        e.statuses.push({ kind: 'buff', name: sk.name, ...sk.buff, dur: sk.buff.dur });
        this.log(`${e.name} usa ${sk.name}.`);
      } else if (sk.type === 'heal') {
        const heal = Math.floor((e.mag || e.atk) * (sk.power || 0.8) + 5);
        e.hp = Math.min(e.hpMax, e.hp + heal);
        this.spawnNumber({ side: 'enemy', a: e }, '+' + heal, '#80ff80');
        this.spawnParticles({ side: 'enemy', a: e }, 'heal', 6);
        this.log(`${e.name} se regenera em ${heal}.`);
      }
      s.animTimer = 0.5;
      s.pendingAction = { kind: 'enemyDone' };
      return;
    }

    // ── Pick party target ─────────────────────────────────────────────────────
    let target = null;
    if (sk.target === 'one') {
      const aliveP = s.party.filter(p => Party.isAlive(p.ref));
      // Honour taunt: if any alive party member has taunt, force target to them
      const taunted = aliveP.filter(p => p.statuses.some(st => st.taunt));
      let frontPool;
      if (taunted.length) {
        frontPool = taunted;
      } else {
        // Use player's chosen formation (front row = slots 0 & 1) if available
        const formation = Save.state.runState && Save.state.runState.formation;
        if (formation) {
          const frontIdxs = new Set(formation.slice(0, 2));
          const frontAlive = aliveP.filter(p => frontIdxs.has(p.idx));
          frontPool = frontAlive.length ? frontAlive : aliveP;
        } else {
          const front = aliveP.filter(p => CLASSES[p.ref.cls].role === 'front');
          frontPool = front.length ? front : aliveP;
        }
      }
      target = { side: 'party', a: choice(frontPool) };
    }

    const targets = sk.target === 'all'
      ? s.party.filter(p => Party.isAlive(p.ref)).map(p => ({ side: 'party', a: p }))
      : [target];

    for (const t of targets) if (t) this.applySkillEffect(sk, e, eStats, t, 'enemy');
    s.animTimer = 0.5;
    s.pendingAction = { kind: 'enemyDone' };
  },

  log(msg) {
    this.state.log.push(msg);
    if (this.state.log.length > 30) this.state.log.shift();
  },

  // Use consumable from inventory mid-battle
  useItem(invIdx, targetIdx) {
    const s = this.state;
    const inv = Save.state.inventory[invIdx];
    if (!inv) return false;
    const it = ITEMS[inv.id];
    if (!it || it.slot !== 'consumable') return false;
    const target = s.party[targetIdx];
    if (!target || !Party.isAlive(target.ref)) return false;
    Party.useConsumable(target.ref, inv.id);
    Save.removeItem(invIdx);
    if (it.use.heal) this.spawnNumber({ side: 'party', a: target }, '+' + it.use.heal, '#80ff80');
    if (it.use.mp)   this.spawnNumber({ side: 'party', a: target }, '+' + it.use.mp + ' MP', '#80a0ff');
    this.log(`${target.ref.name} usa ${it.name}.`);
    s.animTimer = 0.3;
    s.pendingAction = { kind: 'itemDone' };
  },

  flee() {
    if (Math.random() < 0.6) {
      this.endCombat('flee');
    } else {
      this.log('A fuga falhou!');
      // Skip player turn
      this.state.animTimer = 0.4;
      this.state.pendingAction = { kind: 'fleeFail' };
    }
  },

  endCombat(result) {
    const s = this.state;
    s.ended = true;
    s.result = result;
    let xp = 0, gold = 0, drops = [];
    if (result === 'victory') {
      for (const e of this.state.enemies) {
        xp += e.xp;
        gold += irand(e.gold[0], e.gold[1]);
      }
      // Loot rolls
      const lootCount = 1 + (this.state.enemies.some(e => e.boss) ? 2 : 0);
      for (let i = 0; i < lootCount; i++) {
        const loot = rollLoot(Save.state.runState ? Save.state.runState.level : 1);
        for (const l of loot) {
          if (l.kind === 'gold') gold += l.amount;
          else drops.push(l.id);
        }
      }
    }
    setTimeout(() => s.onEnd({ result, xp, gold, drops }), 600);
  },

  // Called every frame
  update(dt) {
    const s = this.state;
    if (!s || s.ended) return;
    // Animate damage numbers
    for (const dn of s.pendingDamage) dn.age += dt;
    s.pendingDamage = s.pendingDamage.filter(d => d.age < d.life);

    // Update particles
    for (const p of s.particles) {
      p.age += dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += p.gravity * dt;
    }
    s.particles = s.particles.filter(p => p.age < p.life);

    // Decay flashes / death timers
    const all = s.party.concat(s.enemies);
    for (const a of all) {
      if (a.flashTime > 0) a.flashTime = Math.max(0, a.flashTime - dt);
      if (a.deathTime > 0) a.deathTime = Math.max(0, a.deathTime - dt);
    }

    // Decay shake
    if (s.shake && s.shake.t > 0) s.shake.t = Math.max(0, s.shake.t - dt);

    if (s.animTimer > 0) {
      s.animTimer -= dt;
      if (s.animTimer <= 0) {
        if (s.pendingAction) {
          const action = s.pendingAction;
          s.pendingAction = null;
          if (action.kind === 'player') { this.resolvePlayerAction(action); return; }
          if (action.kind === 'enemyDone' || action.kind === 'itemDone' || action.kind === 'fleeFail') { this.nextActor(); return; }
        }
        // Was an enemy waiting to act
        if (s.currentActor && s.currentActor.side === 'enemy' && !s.pendingAction && s.ui.phase === 'idle') {
          this.enemyTurn();
          return;
        }
        // After player resolved
        if (s.ui.phase === 'animate' && !s.pendingAction) {
          this.nextActor();
        }
      }
    }
  },
};

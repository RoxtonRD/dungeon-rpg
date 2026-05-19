// Persistent save state. Stored in localStorage.
// Key design: characters and items persist across TPK in normal mode.

const SAVE_KEY = 'praesidium_dungeons_save_v1';

const Save = {
  state: null,

  load() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (raw) {
        this.state = JSON.parse(raw);
        // Migrate old saves: ensure skill-upgrade fields exist on every hero
        if (this.state && this.state.party) {
          for (const c of this.state.party) {
            if (!c.skillLevels)        c.skillLevels  = {};
            if (c.skillPoints == null) c.skillPoints  = Math.max(1, c.lvl - 1);
          }
        }
        // Migrate: ensure shop fields exist
        if (this.state) {
          if (this.state.shopLevel == null) this.state.shopLevel = 1;
          if (!this.state.shopStock || !this.state.shopStock.length)
            this.state.shopStock = generateShopStock(this.state.shopLevel);
        }
        return true;
      }
    } catch (e) { console.warn('Save load failed', e); }
    return false;
  },

  save() {
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(this.state));
    } catch (e) { console.warn('Save failed', e); }
  },

  reset() {
    localStorage.removeItem(SAVE_KEY);
    this.state = null;
  },

  newGame() {
    this.state = {
      gold: 50,
      party: [
        Party.makeChar('warrior', 'Aldric'),
        Party.makeChar('cleric',  'Mira'),
        Party.makeChar('rogue',   'Vex'),
        Party.makeChar('mage',    'Selan'),
      ],
      inventory: [
        { id: 'potion_heal' }, { id: 'potion_heal' }, { id: 'potion_mana' },
      ],
      // Equip starter items
      runState: null,    // active dungeon run
      stats: { runs: 0, defeats: 0, victories: 0 },
      mode: 'normal',    // 'normal' = persistent | 'hardcore' = lose on TPK (future)
      shopLevel: 1,      // current shop quality tier
      shopStock: [],     // filled below after object creation
    };
    // Auto-equip starter gear by giving items
    this.giveItem('sword_rusty');     Party.equip(this.state.party[0], 0, 'weapon', 'sword_rusty');
    this.giveItem('staff_apprentice');Party.equip(this.state.party[1], 1, 'weapon', 'staff_apprentice');
    this.giveItem('sword_rusty');     Party.equip(this.state.party[2], 2, 'weapon', 'sword_rusty');
    this.giveItem('staff_apprentice');Party.equip(this.state.party[3], 3, 'weapon', 'staff_apprentice');
    this.giveItem('armor_cloth');     Party.equip(this.state.party[0], 0, 'armor',  'armor_cloth');
    this.giveItem('armor_cloth');     Party.equip(this.state.party[1], 1, 'armor',  'armor_cloth');
    this.giveItem('armor_cloth');     Party.equip(this.state.party[2], 2, 'armor',  'armor_cloth');
    this.giveItem('armor_cloth');     Party.equip(this.state.party[3], 3, 'armor',  'armor_cloth');
    this.state.shopStock = generateShopStock(1);
    this.save();
  },

  giveItem(id) {
    this.state.inventory.push({ id });
  },

  removeItem(invIdx) {
    this.state.inventory.splice(invIdx, 1);
  },
};

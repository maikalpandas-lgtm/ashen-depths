# Ashen Depths — Roadmap

Короткий чеклист. Детали лора, боя и **3 слоёв карт** → [DESIGN.md](./DESIGN.md) (§7).

## Фаза 0 — Репо и скелет ✅
- [x] Репо `ashen-depths` (GitHub)
- [x] Godot 4 project
- [x] FPS controller
- [x] Dungeon mesh / generator hook
- [x] `docs/DESIGN.md`

## Фаза 1 — Лабиринт MVP ✅
- [x] Rooms + corridors generator
- [x] Dead ends
- [x] Doors
- [x] Chest (1 type)
- [x] Torches + fog
- [x] Encounter pack spawn in rooms
- [ ] Minimap (optional polish)

## Фаза 2 — Партия + колоды
- [ ] 3 hero stubs (HP, portrait)
- [ ] **Deck per hero** (draw / hand / discard)
- [ ] Starter decks 8–10 cards
- [ ] Hub stub

## Фаза 3 — Бой + draft слой 1–2
- [ ] Combat state machine
- [ ] Hand / energy / end turn / intents
- [ ] **Layer 1:** post-combat 1 of 3 **or** skip→gold
- [ ] **Layer 2:** level-up → upgrade **or** rare
- [ ] Mini-boss + floor boss (simple rewards)

## Фаза 4 — Босс-слой + хаб + контент
- [ ] **Layer 3:** relic pick + shard + optional curse altar
- [ ] Camp: **remove / upgrade** for gold
- [ ] More heroes, biomes, loot, craft
- [ ] Trailer floor

## Фаза 5 — Полиш + demo
- [ ] Art pipeline, audio, balance, export

---

### Прогрессия (шпаргалка)

| Когда | Что выбираешь |
|-------|----------------|
| После пачки | 1 карта из 2–3 **или** skip (gold/minor) |
| Level-up | Upgrade своей **или** rare/uncommon |
| Босс | Relic 1-of-N + shard auto + optional cursed card |
| Хаб | Remove / upgrade за gold |

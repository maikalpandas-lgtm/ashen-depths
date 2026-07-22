# Ashen Depths — Roadmap

Короткий чеклист.  
Детали: [DESIGN.md](./DESIGN.md) — **§7** Inscryption-cards (**no board**), враги в коридоре · **§8** BB backpack.

## Фаза 0 — Репо и скелет ✅
- [x] Репо `ashen-depths` (GitHub)
- [x] Godot 4 project
- [x] FPS controller
- [x] Dungeon mesh / generator hook
- [x] `docs/DESIGN.md`

## Фаза 1 — Лабиринт MVP ✅ (закрыта 22.07.2026)
- [x] Corridor-first generator
- [x] Dead ends, doors, chest, encounters
- [x] Torches, cave props, fog, HUD
- [x] Minimap (parchment tiles)
- [x] Grid-move + fixed-forward camera (реф-feel) — W/S шаг, A/D 90°, hold-to-walk, качание рук
- [x] Art-first look — порода в шейдере (`cave_rock.gdshader`), 2D-пропсы, свет/туман под референс
- [x] F9 → `shots/` для ревью визуала

## Фаза 2 — Партия + колоды
- [x] 3 hero stubs (HP, portrait) — `scripts/party.gd`, Каэль/Лира/Сера, HP 34+30+24=88
- [x] **Deck** (draw / hand / discard / recycle / hand cap 10) — `scripts/cards/deck.gd`
- [x] Starter decks 8–10 карт — по 9 на героя, мерж в один combat deck с owner-тегом
- [x] Тесты логики — `godot --headless --script tests/run_tests.gd` (54 проверки)
- [ ] Арт: 3 портрета + 5 карт (промпты в `docs/ART_PROMPTS.md`, генерит Grok)
- [x] Тест-оверлей **C**: портреты + HP + рука из реальной колоды (`scripts/ui/card_test_overlay.gd`)
- [ ] Боевой UI руки (Фаза 3) — заменит тест-оверлей
- [ ] Hub stub

## Фаза 3 — Бой + draft слой 1–2
- [ ] Enemies in corridor (billboard) + combat overlay
- [ ] Hand / ⚡3 / END TURN / Block / intents (**no board**)
- [ ] Sigils + blood cost (Inscryption-flavor cards)
- [ ] **Layer 1:** post-combat 1 of 3 **or** skip→gold
- [ ] **Layer 2:** level-up → upgrade **or** rare
- [ ] Mini-boss + floor boss (simple rewards)

## Фаза 4 — Босс-слой + Backpack + Shop + хаб
- [ ] **Layer 3:** relic pick + shard + optional curse altar
- [ ] **4b:** backpack grid **5×4**, items **1×1 / 2×1**, adjacency
- [ ] Post-combat **item loot** (take / sell)
- [ ] **4c:** floor shop (buy / sell / reroll)
- [ ] **4d:** map **merchant** (0–1 / floor) + minimap icon
- [ ] Camp / shop: card **remove / upgrade** for gold
- [ ] Item catalog, more heroes, biomes
- [ ] Trailer floor

## Фаза 5 — Полиш + demo
- [ ] Art pipeline, audio, balance, export

---

## Долги (не блокируют фазы)

- Сундук / энкаунтеры / жаровни — до сих пор 3D-меши-заглушки (кубы и сферы).
  По концепту все объекты должны быть 2D-спрайтами — см. `AGENTS.md`.
- Спрайт в руке глушит `no_depth_test` через `material_override`; сейчас спасает
  ограничение выпирания скалы (`PUSH_LIMIT`). Правильное решение — вариант
  шейдера с `depth_test_disabled` через общий `.gdshaderinc`.

---

### Прогрессия (шпаргалка)

| Когда | Карты | Рюкзак / экономика |
|-------|--------|---------------------|
| После пачки | 1 of 2–3 **или** skip gold | item take **или** sell |
| Level-up | upgrade **или** rare card | — |
| Босс | relic pick + shard + curse? | rare/epic item pick |
| На этаже | — | **0–1 merchant** |
| После этажа | remove/upgrade (shop tab) | **full shop** |
| Хаб | remove/upgrade | edit backpack |

### Роли систем

| Система | Отвечает за |
|---------|-------------|
| Карты | Активный бой |
| Рюкзак | Пассивы / синергии предметов |
| Shop + merchant | Лут-ротация, gold sink |

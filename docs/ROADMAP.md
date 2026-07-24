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
- [x] Арт: 3 портрета + 10 карт + рамка + бейджи (батчи 1, 3, 4)
- [x] Тест-оверлей **C**: портреты + HP + рука из реальной колоды (`scripts/ui/card_test_overlay.gd`)
- [x] Боевой UI руки — `scripts/ui/combat_overlay.gd`
- [x] **Выбор героя** в стартовом меню — один герой на забег (`hero_select_overlay.gd`)
- [ ] Hub stub

## Фаза 3 — Бой + draft слой 1–2
- [x] Enemies in corridor (billboard) — `scripts/enemy_sprites.gd`, 7 типов, 22 стаи на этаж
- [x] Бой на месте: стая стоит в коридоре, шеренга поперёк подхода, боевая камера + свет
- [x] Hand / ⚡3 / END TURN / Block / intents (**no board**) — `combat_state.gd` + `combat_overlay.gd`
- [x] Прицеливание перетаскиванием, линия из шариков, аура выбранной карты
- [x] Фидбэк: подсветка цели, вспышка от удара, разрыв надвое при смерти, выпад + следы когтей + тряска
- [x] Sigils + blood cost — Sharp/Pierce/Cleave/Drain/Bone/Echo/Sanguine/Ward
- [x] Тесты боя — headless suite
- [x] **Layer 1:** post-combat 1 of 3 **or** skip→gold — `draft_overlay.gd`
- [x] **Layer 2:** level-up → upgrade **or** rare — `level_up_overlay.gd` + XP
- [x] Mini-boss + floor boss (simple rewards) — pack_kind, cave_warden / nav_host
- [x] Переход между этажами — EXIT → `GameState.advance_floor` + generate
- [x] Экран поражения — `defeat_overlay.gd` (встать 1 HP / новый забег)

## Фаза 4 — Босс-слой + Backpack + Shop + хаб
- [x] **Layer 3 light:** floor boss loot pick + seal_shard auto-offer
- [x] **4b:** backpack grid **5×4**, items **1×1 / 2×1**, adjacency + combat mods
- [x] Post-combat **item loot** (take / sell) — `loot_overlay.gd`
- [x] **4c:** floor shop (buy / sell / reroll) — EXIT → shop → next floor
- [x] **4d:** map **merchant** (0–1 / floor) + minimap icon
- [x] Camp / shop: card **remove / upgrade** for gold
- [x] Item catalog (12 items) — `item_db.gd`
- [ ] More heroes, biomes
- [ ] Trailer floor / curse altar full

## Фаза 5 — Полиш + demo
- [x] Audio MVP — Kenney CC0 SFX + `Sfx` autoload (бой, шаги, draft, chest)
- [x] Music bed — explore/combat loops + Kenney jingles (`Music` autoload)
- [x] Buses Master/Music/SFX + volume save (`user://audio_settings.cfg`)
- [x] Title splash + Esc pause/settings
- [x] Balance pass (enemy HP, slice 7, XP curve)
- [x] Export presets macOS / Windows / Web + `docs/EXPORT.md`
- [x] Chest + brazier 2D sprites (`prop_chest` / `prop_brazier`)
- [x] Full music beds (OGA CC0 Dark Ambience + Battle Theme A)
- [x] Export templates present + `tools/export_demo.sh` + codesign docs

---

## Долги (не блокируют фазы)

- [x] **Славянский арт (батч 5):** Витязь / Поляница / Волхв + анчутка, лихо,
  мавка, полудница — `assets/textures/hero_*` / `enemy_*`, §3.7.

- [x] Сундук и жаровни — 2D-спрайты (`prop_sprites.gd`).
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

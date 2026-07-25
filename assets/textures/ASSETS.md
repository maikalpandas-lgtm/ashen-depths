# Texture assets — catalog

**Правило:** эти ассеты **канонические**.  
Новые картинки рисуем **только когда явно попросишь**.  
Не перегенерировать «на всякий случай».

Cut tool: `tools/sprite_cutter.py` (chromakey / edge flood).  
Masters (исходники + готовые PNG): `assets/textures/masters/`.

---

## Как обрезать (рабочий рецепт — **без артефактов**)

Проверено на viewmodel/torch: чистый край, без белой/розовой каймы.

### 1) Gen (только если попросили)
В промпт: **`pure solid neon magenta background #FF00FF`** (или pure white), один объект, thick black outline в самом арте.

### 2) Cut — `tools/sprite_cutter.py --ffmpeg` (предпочтительно)

```bash
python3 tools/sprite_cutter.py src.jpg out.png --tolerance 60 --pad 4 --ffmpeg --erode-light 2
```

🚨 **`--color` НЕ указывать.** По умолчанию `auto` — ключ считывается с рамки
кадра. Генератор **никогда** не отдаёт ровно `#FF00FF`: в батче 1 фоны были
`#F31E9C`, `#F92E8A`, `#F81098`, `#F41290`, `#FA17AC`, `#EB1692`, `#F50D7A`,
`#F52190` — все разные. Если задать `--color FF00FF`, ffmpeg не поймает ничего
(расстояние ~116), резка молча свалится на flood, и **фон, окружённый артом**
(просвет между клинком и дугой, петля шнура) останется розовым пятном внутри
спрайта. Именно так и вышло в батче 1.

ffmpeg `colorkey` снимает альфу аккуратнее по сглаженному краю, чем flood.
Раньше его было нельзя (он keyит **весь кадр** и выедал светлое ядро пламени /
блики на стали), теперь дыры лечатся: `restore_interior()` заливает прозрачность
от рамки, и всё, что не связано с фоном, получает непрозрачность обратно.

Крутилки: `--ff-similarity` (по умолчанию 0.20, больше = агрессивнее),
`--ff-blend` (0.05). При 0.35 на белом фоне выедало ~7000 px пламени.

**Замер качества** (светлые пиксели по контуру — должно быть <2%):

```bash
python3 - <<'PY'
from PIL import Image
im=Image.open('assets/textures/torch.png').convert('RGBA'); w,h=im.size; px=im.load()
b=e=0
for y in range(h):
    for x in range(w):
        r,g,bl,a=px[x,y]
        if a==0: continue
        if any(not(0<=x+dx<w and 0<=y+dy<h) or px[x+dx,y+dy][3]==0
               for dx,dy in((1,0),(-1,0),(0,1),(0,-1))):
            e+=1
            if min(r,g,bl)>190: b+=1
print(f'{b}/{e} = {100*b/e:.1f}%')
PY
```

### 2b) Cut — flood без ffmpeg (запасной)
```bash
python3 tools/sprite_cutter.py path/to/raw.jpg assets/textures/out.png \
  --color FF00FF --tolerance 55 --pad 4
```
Что делает (и почему чисто):
1. **Flood-fill только с краёв** — вырезает key-цвет, **не** дырявит такой же цвет внутри силуэта  
2. **Despill** — убирает пурпурный/розовый fringe по контуру (JPEG/AI)  
3. **Binary alpha** (0 или 255) — нет полупрозрачной «молочной» каймы  
4. **Crop** по bbox + pad  

Для **white** фона: `--color FFFFFF --tolerance 40` (не жрать сталь/блики — при необходимости protect metal вручную).

### 3) Чего **не** делать (ломает край)
- **Не** раздувать outline (`MaxFilter` / «толстая чёрная обводка поверх») — жирный ореол  
- **Не** резать scissor > ~0.15 на стали (нож становится прозрачным)  
- **Не** ffmpeg `colorkey` на оранжевом огне / сером клинке, если key не чистый `#FF00FF` — съедает объект  
- **hand_torch / hand_knife / flame_only не перерезать из `masters/*_source.jpg`** — там фон не чистый белый (угол `(6,5,3)`), выйдет хуже. В игре они уже 0% каймы, резаны из магента-раёв.

### 4) В Godot
- `Sprite3D`: `transparent`, mild `alpha_scissor` ≤ 0.15 **или** disabled для ножа  
- `LINEAR_WITH_MIPMAPS` ок после hard alpha; не NEAREST если не нужен pixel look  

### 5) После cut
- Скопировать в `masters/` + строка в этой таблице  
- Игра грузит `assets/textures/<name>.png`  

---

## Viewmodel (рука игрока)

| ID | Файл в игре | Master PNG | Source (raw) | Назначение |
|----|-------------|------------|--------------|------------|
| **vm_hand_torch** | `hand_torch.png` | `masters/vm_hand_torch.png` | `masters/vm_hand_torch_source.jpg` | Левая рука + факел (FPS) |
| **vm_hand_knife** | `hand_knife.png` | `masters/vm_hand_knife.png` | `masters/vm_hand_knife_source.jpg` | Правая рука + нож (FPS) |

Код: `scripts/torch_sprites.gd` → `make_hand_torch()`.

---

## Heroes (портреты, батч 1)

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **hero_kael** | `hero_kael.png` | `masters/hero_kael.png` | `masters/hero_kael_source.jpg` | Каэль, паладин / танк |
| **hero_lyra** | `hero_lyra.png` | `masters/hero_lyra.png` | `masters/hero_lyra_source.jpg` | Лира, охотница / DPS |
| **hero_sera** | `hero_sera.png` | `masters/hero_sera.png` | `masters/hero_sera_source.jpg` | Сера, огненный маг / AoE |
| **hero_vityaz** | `hero_vityaz.png` | `masters/hero_vityaz.png` | `masters/hero_vityaz_source.jpg` | Витязь — богатырь / танк |
| **hero_polyanitsa** | `hero_polyanitsa.png` | `masters/hero_polyanitsa.png` | `masters/hero_polyanitsa_source.jpg` | Поляница — урон |
| **hero_volhv** | `hero_volhv.png` | `masters/hero_volhv.png` | `masters/hero_volhv_source.jpg` | Волхв — ведун / чары |

Фон gen: `#FF00FF`. Cut: `--color FF00FF --ffmpeg --erode-light 2`.  
Без рамок; круглый crop делает UI.  
Славянские портреты — батч 5 (`ART_PROMPTS.md` §3.7).

---

## Cards (иллюстрации, батч 1)

**Только art.** Рамку, название, ⚡ cost рисует движок — в PNG нет цифр/рамки.

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **card_slice** | `card_slice.png` | `masters/card_slice.png` | `masters/card_slice_source.jpg` | Slice — удар кинжалом |
| **card_block** | `card_block.png` | `masters/card_block.png` | `masters/card_block_source.jpg` | Block — щит + барьер |
| **card_firebolt** | `card_firebolt.png` | `masters/card_firebolt.png` | `masters/card_firebolt_source.jpg` | Firebolt — огненная стрела |
| **card_blood_lash** | `card_blood_lash.png` | `masters/card_blood_lash.png` | `masters/card_blood_lash_source.jpg` | Blood Lash — кровавый хлыст |
| **card_bone_rattle** | `card_bone_rattle.png` | `masters/card_bone_rattle.png` | `masters/card_bone_rattle_source.jpg` | Bone Rattle — кость на шнуре |
| **card_hack** | `card_hack.png` | `masters/card_hack.png` | `masters/card_hack_source.jpg` | Hack — cleaver vs shield |
| **card_cleave_cut** | `card_cleave_cut.png` | `masters/card_cleave_cut.png` | `masters/card_cleave_cut_source.jpg` | Cleave Cut — double slash |
| **card_echo_strike** | `card_echo_strike.png` | `masters/card_echo_strike.png` | `masters/card_echo_strike_source.jpg` | Echo Strike — ghost blade |
| **card_ward** | `card_ward.png` | `masters/card_ward.png` | `masters/card_ward_source.jpg` | Ward — spiked shield |
| **card_offering** | `card_offering.png` | `masters/card_offering.png` | `masters/card_offering_source.jpg` | Offering — burning card |
| **card_axe_swing** | `card_axe_swing.png` | `masters/card_axe_swing.png` | `masters/card_axe_swing_source.jpg` | Секира — тяжёлый удар |
| **card_spear_thrust** | `card_spear_thrust.png` | `masters/card_spear_thrust.png` | `masters/card_spear_thrust_source.jpg` | Копьё — пробой |
| **card_flail** | `card_flail.png` | `masters/card_flail.png` | `masters/card_flail_source.jpg` | Кистень — AoE |
| **card_dagger_pair** | `card_dagger_pair.png` | `masters/card_dagger_pair.png` | `masters/card_dagger_pair_source.jpg` | Двойной нож |
| **card_bear_claw** | `card_bear_claw.png` | `masters/card_bear_claw.png` | `masters/card_bear_claw_source.jpg` | Медвежья лапа |
| **card_tower_shield** | `card_tower_shield.png` | `masters/card_tower_shield.png` | `masters/card_tower_shield_source.jpg` | Червлёный щит |
| **card_chainmail** | `card_chainmail.png` | `masters/card_chainmail.png` | `masters/card_chainmail_source.jpg` | Кольчуга |
| **card_herbs** | `card_herbs.png` | `masters/card_herbs.png` | `masters/card_herbs_source.jpg` | Травы — heal |
| **card_kvass** | `card_kvass.png` | `masters/card_kvass.png` | `masters/card_kvass_source.jpg` | Ковш — energy |
| **card_frost** | `card_frost.png` | `masters/card_frost.png` | `masters/card_frost_source.jpg` | Стужа |
| **card_lightning** | `card_lightning.png` | `masters/card_lightning.png` | `masters/card_lightning_source.jpg` | Перун — молния |
| **card_curse_doll** | `card_curse_doll.png` | `masters/card_curse_doll.png` | `masters/card_curse_doll_source.jpg` | Куколка — порча |
| **card_raven** | `card_raven.png` | `masters/card_raven.png` | `masters/card_raven_source.jpg` | Ворон — вестник |
| **card_wolf_howl** | `card_wolf_howl.png` | `masters/card_wolf_howl.png` | `masters/card_wolf_howl_source.jpg` | Волчий вой |
| **card_blood_pact** | `card_blood_pact.png` | `masters/card_blood_pact.png` | `masters/card_blood_pact_source.jpg` | Уговор — blood cost |
| **card_bone_crown** | `card_bone_crown.png` | `masters/card_bone_crown.png` | `masters/card_bone_crown_source.jpg` | Костяной венец |

Промпты: `docs/ART_PROMPTS.md` §2 + §3.6 (батч 4) + §3.10 (батч 8, 16 карт).  
Качество cut (bright edge): batch1 ≤0.3%; batch4 ≤0.6%.

---

## Card UI (батч 3 — рамка / cost badge)

**Без букв, цифр, рун.** Текст и cost рисует движок (`card_test_overlay.gd`).

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **card_frame** | `card_frame.png` | `masters/card_frame.png` | `masters/card_frame_source.jpg` | Подложка карты ~5:7 (755×1052) |
| **card_cost_badge** | `card_cost_badge.png` | `masters/card_cost_badge.png` | `masters/card_cost_badge_source.jpg` | Кружок ⚡ (синяя эмаль) |
| **card_cost_badge_blood** | `card_cost_badge_blood.png` | `masters/card_cost_badge_blood.png` | `masters/card_cost_badge_blood_source.jpg` | Кружок 🩸 HP-cost (красная) |

Промпты: `docs/ART_PROMPTS.md` §3.5.  
Первая gen-рамка с черепами отброшена; в игре — чистая v2.

---

## Enemies (батч 2 — corridor billboards)

Фронтальный full-body, ноги на земле. Фон gen `#FF00FF`.

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **enemy_grub** | `enemy_grub.png` | `masters/enemy_grub.png` | `masters/enemy_grub_source.jpg` | Пещерный грызун (weak pack) |
| **enemy_brute** | `enemy_brute.png` | `masters/enemy_brute.png` | `masters/enemy_brute_source.jpg` | Каменный громила (tank) |
| **enemy_shade** | `enemy_shade.png` | `masters/enemy_shade.png` | `masters/enemy_shade_source.jpg` | Тень рудокопа (fast debuff) |
| **enemy_anchutka** | `enemy_anchutka.png` | `masters/enemy_anchutka.png` | `masters/enemy_anchutka_source.jpg` | Анчутка (Навь, pack) |
| **enemy_likho** | `enemy_likho.png` | `masters/enemy_likho.png` | `masters/enemy_likho_source.jpg` | Лихо Одноглазое (танк) |
| **enemy_mavka** | `enemy_mavka.png` | `masters/enemy_mavka.png` | `masters/enemy_mavka_source.jpg` | Мавка (быстрая) |
| **enemy_poludnitsa** | `enemy_poludnitsa.png` | `masters/enemy_poludnitsa.png` | `masters/enemy_poludnitsa_source.jpg` | Полудница (AoE) |
| **enemy_wolf** | `enemy_wolf.png` | `masters/enemy_wolf.png` | `masters/enemy_wolf_source.jpg` | Волк (лес, pack, 1.3 м, wide) |
| **enemy_kikimora** | `enemy_kikimora.png` | `masters/enemy_kikimora.png` | `masters/enemy_kikimora_source.jpg` | Кикимора (лес, 1.5 м) |
| **enemy_leshy** | `enemy_leshy.png` | `masters/enemy_leshy.png` | `masters/enemy_leshy_source.jpg` | Леший (лес, 2.3 м; босс = scale) |

Промпты: `docs/ART_PROMPTS.md` §3 + §3.7 (батч 5 Навь) + §3.9.5 (батч 7 лес).  
Cut quality (bright edge): wolf / kikimora / leshy = **0.0%**.  
`realm: "forest"` в `scripts/enemy_sprites.gd`. После арта волка — `tests/formation_test.gd`.

---

## Props (мир)

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **prop_wall_torch** | `torch.png` | `masters/prop_wall_torch.png` | `masters/prop_wall_torch_source.jpg` | Факел на стене + крепёж (**одно ухо справа**) |
| **fx_flame** | `flame_only.png` | `masters/fx_flame.png` | `masters/fx_flame_source.jpg` | Только пламя (анимация tip) |
| **fx_torch_glow** | `torch_glow.png` | `masters/fx_torch_glow.png` | procedural | Soft radial glow |
| **prop_chest** | `prop_chest.png` | `masters/prop_chest.png` | `masters/prop_chest_source.jpg` | Сундук (Sprite3D, billboard Y) |
| **prop_brazier** | `prop_brazier.png` | `masters/prop_brazier.png` | `masters/prop_brazier_source.jpg` | Настенная жаровня + cyan OmniLight |

Код: `scripts/torch_sprites.gd` → `make_wall_torch()`;  
`scripts/prop_sprites.gd` → `make_chest()` / `make_brazier()`.

⚠️ **prop_wall_torch:** в игре должен быть вариант с **одним** креплением справа
(режется из `masters/prop_wall_torch_source.jpg`, белый фон):

```bash
python3 tools/sprite_cutter.py assets/textures/masters/prop_wall_torch_source.jpg \
  assets/textures/torch.png --color FFFFFF --tolerance 55 --pad 4 --ffmpeg
```

Магента-вариант из `raw/torch_raw.jpg` — это симметричная «H»-скоба с **двумя**
ушами, на стене читается неправильно. Не возвращать.

---

## Как просить изменения

- «подкрути размер vm_hand_torch» → только код / scale, **без** gen  
- «перерисуй нож» → gen **только** `vm_hand_knife`  
- «новые мобы» → gen с chromakey + `tools/sprite_cutter.py`  

---

## Источник gen (сессия)

Хорошая пачка Imagine (бело/магента фон), от которой ведём:

| Session image | → asset ID |
|---------------|------------|
| `images/8.jpg` | vm_hand_torch |
| `images/9.jpg` | vm_hand_knife |
| `images/10.jpg` | prop_wall_torch |
| `images/7.jpg` | fx_flame |

Позже magenta-пачка (`12–15` / `raw/*_raw.jpg`) — запасные, не трогаем без запроса.

---

## Props (коридор, 2D)

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **prop_chest** | `prop_chest.png` | `masters/prop_chest.png` | `masters/prop_chest_source.jpg` | Сундук (Area3D + Sprite3D) |
| **prop_brazier** | `prop_brazier.png` | `masters/prop_brazier.png` | `masters/prop_brazier_source.jpg` | Настенная жаровня + cyan light |

Код: `scripts/prop_sprites.gd` · спавн: `dungeon_generator.gd` `_spawn_chest` / `_spawn_brazier`.

---

## Faces / avatars (батч 6) — только голова

Крупный план для круглой рамки HUD. Старые `hero_*` (бюст) остаются для справок.

| ID | Файл в игре | Master PNG | Source | Кто |
|----|-------------|------------|--------|-----|
| **face_vityaz** | `face_vityaz.png` | `masters/face_vityaz.png` | `masters/face_vityaz_source.jpg` | Витязь |
| **face_polyanitsa** | `face_polyanitsa.png` | `masters/face_polyanitsa.png` | `masters/face_polyanitsa_source.jpg` | Поляница |
| **face_volhv** | `face_volhv.png` | `masters/face_volhv.png` | `masters/face_volhv_source.jpg` | Волхв |

Код: `portrait` в `scripts/party.gd` → `left_panel.gd` / `card_test_overlay.gd`.
Промпты: `docs/ART_PROMPTS.md` §3.8.

---

## Forest biome (батч 7 — сказочный лес)

Открытая местность: 3D только земля, всё остальное 2D-спрайты.  
Опора по нижнему краю (кроме `forest_treeline`). Без baked ground shadow.  
Промпты: `docs/ART_PROMPTS.md` §3.9.

### Vegetation / props

| ID | Файл в игре | Master PNG | Source | Назначение |
|----|-------------|------------|--------|------------|
| **forest_pine** | `forest_pine.png` | `masters/forest_pine.png` | `masters/forest_pine_source.jpg` | Высокая ель |
| **forest_birch** | `forest_birch.png` | `masters/forest_birch.png` | `masters/forest_birch_source.jpg` | Берёза |
| **forest_oak_old** | `forest_oak_old.png` | `masters/forest_oak_old.png` | `masters/forest_oak_old_source.jpg` | Старый дуб-великан |
| **forest_bush** | `forest_bush.png` | `masters/forest_bush.png` | `masters/forest_bush_source.jpg` | Куст с ягодами |
| **forest_fern** | `forest_fern.png` | `masters/forest_fern.png` | `masters/forest_fern_source.jpg` | Папоротник |
| **forest_stump** | `forest_stump.png` | `masters/forest_stump.png` | `masters/forest_stump_source.jpg` | Пень + мухомор |
| **forest_log** | `forest_log.png` | `masters/forest_log.png` | `masters/forest_log_source.jpg` | Лежащее бревно |
| **forest_lantern** | `forest_lantern.png` | `masters/forest_lantern.png` | `masters/forest_lantern_source.jpg` | Фонарь на шесте |
| **forest_glowshroom** | `forest_glowshroom.png` | `masters/forest_glowshroom.png` | `masters/forest_glowshroom_source.jpg` | Светящиеся грибы |
| **forest_campfire** | `forest_campfire.png` | `masters/forest_campfire.png` | `masters/forest_campfire_source.jpg` | Костёр |
| **forest_treeline** | `forest_treeline.png` | `masters/forest_treeline.png` | `masters/forest_treeline_source.jpg` | Полоса леса на горизонте |

### Enemies (forest realm)

См. таблицу Enemies выше: `enemy_wolf`, `enemy_kikimora`, `enemy_leshy`.

---

## Backpack items (батч 10 — §3.12)

Иконки реликвий. В бою ~**30 px** — силуэт + 2–3 цвета, без мелочи.  
Id = `art` / filename stem в `scripts/items/item_db.gd`.

| ID | Файл в игре | Master PNG | Source | Предмет |
|----|-------------|------------|--------|---------|
| **item_rusty_blade** | `item_rusty_blade.png` | `masters/item_rusty_blade.png` | `masters/item_rusty_blade_source.jpg` | Ржавый клинок |
| **item_whetstone** | `item_whetstone.png` | `masters/item_whetstone.png` | `masters/item_whetstone_source.jpg` | Точило |
| **item_shield_shard** | `item_shield_shard.png` | `masters/item_shield_shard.png` | `masters/item_shield_shard_source.jpg` | Осколок щита |
| **item_poison_vial** | `item_poison_vial.png` | `masters/item_poison_vial.png` | `masters/item_poison_vial_source.jpg` | Фиал яда |
| **item_mana_rune** | `item_mana_rune.png` | `masters/item_mana_rune.png` | `masters/item_mana_rune_source.jpg` | Руна ⚡ |
| **item_coin_pouch** | `item_coin_pouch.png` | `masters/item_coin_pouch.png` | `masters/item_coin_pouch_source.jpg` | Мешок монет |
| **item_bone_charm** | `item_bone_charm.png` | `masters/item_bone_charm.png` | `masters/item_bone_charm_source.jpg` | Костяной оберег |
| **item_blood_charm** | `item_blood_charm.png` | `masters/item_blood_charm.png` | `masters/item_blood_charm_source.jpg` | Кровавый оберег |
| **item_iron_plating** | `item_iron_plating.png` | `masters/item_iron_plating.png` | `masters/item_iron_plating_source.jpg` | Железная обшивка |
| **item_hunter_fang** | `item_hunter_fang.png` | `masters/item_hunter_fang.png` | `masters/item_hunter_fang_source.jpg` | Клык охотника |
| **item_ember_core** | `item_ember_core.png` | `masters/item_ember_core.png` | `masters/item_ember_core_source.jpg` | Уголёк |
| **item_seal_shard** | `item_seal_shard.png` | `masters/item_seal_shard.png` | `masters/item_seal_shard_source.jpg` | Осколок Зарока |

Промпты: `docs/ART_PROMPTS.md` §3.12. Cut: `--ffmpeg --erode-light 2`.  
После drop: `godot --headless --import` + `tests/art_import_test.gd`.

---

## Status icons (батч 11 — §3.13)

Пилюли статусов в бою ~**26×17 px**. Один-два цвета, толстый outline.  
Id = `status_poison` / `status_frail` / `status_weak` / `status_rage`  
(см. `scripts/combat/statuses.gd`).

| ID | Файл в игре | Master PNG | Source | Статус |
|----|-------------|------------|--------|--------|
| **status_poison** | `status_poison.png` | `masters/status_poison.png` | `masters/status_poison_source.jpg` | Отрава — череп в капле |
| **status_frail** | `status_frail.png` | `masters/status_frail.png` | `masters/status_frail_source.jpg` | Порча — треснувший щит |
| **status_weak** | `status_weak.png` | `masters/status_weak.png` | `masters/status_weak_source.jpg` | Немощь — сломанная стрела вниз |
| **status_rage** | `status_rage.png` | `masters/status_rage.png` | `masters/status_rage_source.jpg` | Ярость — огненная стрела вверх |

Промпты: `docs/ART_PROMPTS.md` §3.13.

## Портреты по состоянию (батч 9, §3.11)

Подхватываются автоматически: `left_panel._portrait_for` ищет `<id>_hurt` ниже
половины HP и `<id>_low` ниже четверти. Файла нет → берётся базовый портрет с
красным подкрасом, так что набор можно доносить по одному.

| Файл | Кто | Состояние |
|---|---|---|
| `face_vityaz_hurt` | Витязь | ранен |
| `face_vityaz_low` | Витязь | при смерти |
| `face_polyanitsa_hurt` | Поляница | ранена |
| `face_polyanitsa_low` | Поляница | при смерти |
| `face_volhv_hurt` | Волхв | ранен |
| `face_volhv_low` | Волхв | при смерти |

## Фаза E — собираемое, расходники, трофеи (§3.14, 25.07.2026)

Собираемое = **спрайты в мире**, поэтому касаются нижнего края (проверено:
отступ снизу 0.4–0.7%) и без нарисованной тени. Расходники и трофеи = иконки.

| Файл | Что | Где видно |
|---|---|---|
| `forage_glow_moss` | Светящийся мох | коридор копей → Отвар |
| `forage_cave_mushroom` | Пещерный гриб | коридор копей → Противоядие |
| `forage_bone_pile` | Костяные обломки | коридор копей → +2 кости в бой |
| `forage_herbs` | Травы | лес → Отвар |
| `forage_berries` | Ягоды | лес → Ярый настой |
| `forage_amanita` | Мухомор | лес → Противоядие |
| `consum_broth` | Отвар | слот 1–3 в бою |
| `consum_rage_draught` | Ярый настой | слот 1–3 в бою |
| `consum_antidote` | Противоядие | слот 1–3 в бою |
| `trophy_fang` | Клык | с копей, продаётся |
| `trophy_hide` | Шкура | с леса, продаётся |
| `trophy_ichor` | Навья слизь | с Нави, продаётся |

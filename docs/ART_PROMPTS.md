# Art prompts — Ashen Depths

Промпты для генерации в Grok. Правила ассетов и резка — `assets/textures/ASSETS.md`.
Стиль обязан совпадать с уже готовыми `hand_torch.png` / `torch.png`.

---

## 0. Стилевой префикс (вставлять ПЕРЕД каждым промптом)

```
2D cartoon game art, hand-painted illustration, thick black ink outline around every
shape, bold cel shading with two or three tones, slightly desaturated fantasy palette,
dark teal-and-ember dungeon world, no gradients-heavy realism, no photorealism,
no text, no watermark, no border, no frame, single centred subject,
flat pure magenta background #FF00FF, full bleed background with no vignette
```

**Почему магента.** Резак вырезает фон заливкой от краёв. На чистой `#FF00FF` он
работает лучше всего — у белого фона проблемы со светлыми частями арта (мы это
уже ловили на факеле). Просить у Grok именно `#FF00FF`, не «transparent».

**Резка после генерации:**

```bash
python3 tools/sprite_cutter.py вход.jpg assets/textures/имя.png \
  --color FF00FF --tolerance 50 --pad 4 --ffmpeg --erode-light 2
```

Проверка качества (светлых пикселей по контуру должно быть <2%) — скрипт в
`ASSETS.md`, раздел «Замер качества».

---

## 1. Батч 1 — герои (3 портрета)

Бюст, три четверти, смотрит в кадр. Пойдёт в круглую рамку, поэтому **вся
важная часть — в центральном круге**, плечи можно обрезать.

Общий хвост для всех троих:

```
character bust portrait, head and shoulders only, three-quarter view facing the viewer,
centred composition that survives a circular crop, expressive readable silhouette
```

### 1.1 `hero_kael` — Каэль, паладин, танк

```
a stoic human paladin man in his forties, short greying dark hair, square jaw,
a pale scar across the left eyebrow, dented steel pauldrons with warm brass trim,
deep blue tabard, calm tired eyes, faint warm torchlight from below
```

### 1.2 `hero_lyra` — Лира, охотница, DPS

```
a sharp-eyed young huntress, dark braided hair with a green cloth band,
hooded leather cloak pushed back off the head, quiver strap across the chest,
alert half-smile, freckles, cool green-teal accents
```

### 1.3 `hero_sera` — Сера, огненный маг, AoE

```
a fire mage woman with cropped copper-red hair, soot smudge on one cheek,
charred leather mantle over a rust-orange robe, small embers floating near her shoulder,
intense focused eyes lit warm orange from her own magic
```

---

## 2. Батч 1 — карты (5 штук для теста)

**Только иллюстрация.** Рамку, название, стоимость и текст рисует движок — в
арте не должно быть ни рамки, ни подписей, ни цифр.

Общий хвост для всех карт:

```
square composition, single iconic object or effect centred in frame,
dynamic but readable at small size, no character faces, no text, no card frame
```

| Файл | Карта |
|---|---|
| `card_slice` | Slice — 6 урона |
| `card_block` | Block — +5 брони |
| `card_firebolt` | Firebolt — 5 урона, Pierce |
| `card_blood_lash` | Blood Lash — 4 HP → 12 урона, вампиризм |
| `card_bone_rattle` | Bone Rattle — 4 урона, при добивании +1 кость |

### 2.1 `card_slice`

```
a single curved steel dagger mid-swing, a clean white crescent slash arc trailing
behind the blade, a few sparks along the edge
```

### 2.2 `card_block`

```
a battered round wooden shield with an iron boss and rim, facing the viewer,
a soft pale blue hexagonal barrier shimmer flaring in front of it
```

### 2.3 `card_firebolt`

```
a compact spinning bolt of orange fire shaped like an arrowhead, streaking left to right,
a thin trail of embers and dark smoke behind it
```

### 2.4 `card_blood_lash`

```
a whip made of arcing crimson blood suspended in the air, droplets flung off the curve,
a faint dark red mist gathering at its base
```

### 2.5 `card_bone_rattle`

```
a cracked pale animal bone swinging on a leather cord, small teeth and bone shards
strung along it, a dull grey-green glow in the cracks
```

---

## 3. Батч 2 — враги (после карт)

Спрайты в коридоре, вид спереди, **в полный рост**, стоят на земле. Будут
билбордиться к игроку, поэтому строго фронтальный вид, без сильного ракурса.

Общий хвост:

```
full body standing character sprite, strictly front view, feet on the ground,
symmetrical readable silhouette, slight menace, scaled for a dungeon corridor
```

| Файл | Враг | Роль в бою |
|---|---|---|
| `enemy_grub` | Пещерный грызун | Слабый, много их |
| `enemy_brute` | Каменный громила | Танк, бьёт редко и сильно |
| `enemy_shade` | Тень рудокопа | Быстрый, вешает дебафф |

### 3.1 `enemy_grub`

```
a fat pale cave rodent the size of a dog, oversized front teeth, blind milky eyes,
patchy grey-green fur, twitching whiskers, hunched low on stubby legs
```

### 3.2 `enemy_brute`

```
a hulking humanoid made of moss-covered dungeon stone, boulder shoulders,
one arm far larger than the other, a dull ember glow in the seams between its rocks,
tiny head sunk between the shoulders
```

### 3.3 `enemy_shade`

```
the ghost of a miner, translucent teal, a battered helmet with a dead lamp,
a broken pickaxe in one hand, the lower body fading into wisps instead of legs,
hollow glowing eye sockets
```

---

## 3.5. Батч 3 — рамка карты (обложка)

Карта = **одна картинка-подложка** + иллюстрация скилла поверх + текст, который
рисует движок. Поэтому в рамке **не должно быть ни букв, ни цифр** — иначе они
разъедутся с реальными значениями при первой же правке баланса.

### Пропорции и зоны (обязательно соблюсти)

Соотношение **5:7** (например 512×716). Внутри рамки код ожидает такие зоны —
они заданы в `scripts/ui/card_test_overlay.gd` как `ART_RECT` / `NAME_RECT` /
`TEXT_RECT`:

| Зона | По ширине | По высоте | Что туда ляжет |
|---|---|---|---|
| Медальон стоимости | 12.6–36.4% | 8.1–25.1% | бейдж + цифра |
| Окно иллюстрации | 21–78% | 14.7–42.3% | арт скилла (`card_*.png`) |
| Лента названия | 26–74% | 48.7–55.6% | название карты |
| Поле текста | 16–84% | 60–88% | описание эффекта |

Числа **замерены по `card_frame.png`**, а не назначены заранее: первая рамка
приехала с окном и лентой заметно уже, чем я предполагал, и текст лёг бы на
голый пергамент. Если рамка перерисовывается — зоны надо перемерить и обновить
`scripts/ui/card_test_overlay.gd`.

⚠️ Медальон **перекрывает левый верхний угол окна арта**, поэтому бейдж
рисуется ПОВЕРХ иллюстрации. При перерисовке рамки либо сохранить это
перекрытие, либо развести их — иначе арт закроет медальон.

### 3.5.1 `card_frame` — базовая рамка

```
a blank fantasy card template, aged parchment face with a worn dark leather
border, an empty recessed rectangular window in the upper half where an
illustration will be placed, an empty horizontal ribbon banner below that window,
an empty round metal medallion socket in the top-left corner, lower half is clean
smooth parchment left completely empty for text, subtle paper grain, soft inner
shadow around the window, portrait orientation 5:7,
COMPLETELY EMPTY — no letters, no numbers, no runes, no symbols, no icons
```

⚠️ Модель любит дописывать «руны» и «символы» в пустые места. Если в отдаче есть
хоть что-то похожее на буквы — перегенерить, а не замазывать.

### 3.5.2 `card_cost_badge` — кружок стоимости (опционально)

```
a single round metal medallion badge, worn dark iron rim with a deep blue enamel
centre, empty middle with nothing written in it, slight bevel and highlight,
viewed straight on
```

Второй вариант с **красной** эмалью → `card_cost_badge_blood` (карты за HP).

### 3.5.3 Что дальше делает движок

Название, стоимость, текст и рамку по цвету владельца (золото Каэля / зелень
Лиры / оранжевый Серы) накладывает код. Одна рамка на все карты — тип и владелец
различаются подсветкой, а не отдельными картинками.

---

## 3.6. Батч 4 — недостающие иллюстрации карт

Пять карт из MVP-колоды пока с пустым окном. Тот же хвост, что в §2.

| Файл | Карта |
|---|---|
| `card_hack` | Hack — 10 урона, Sharp |
| `card_cleave_cut` | Cleave Cut — 5 + 50% соседу |
| `card_echo_strike` | Echo Strike — 7, повтор за 0 при кости |
| `card_ward` | Ward — +4 брони и 1 шип |
| `card_offering` | Offering — сброс карты, следующая дешевле |

### 3.6.1 `card_hack`
```
a heavy notched cleaver biting deep into a cracked iron shield boss, the shield
splitting apart, sparks and metal shards flying off the impact
```

### 3.6.2 `card_cleave_cut`
```
one wide horizontal axe sweep, two overlapping crescent slash arcs side by side,
the second arc fainter than the first, dust kicked up along the path
```

### 3.6.3 `card_echo_strike`
```
a straight sword thrust with a translucent ghost duplicate of the same blade
trailing half a step behind it, pale bone-white afterimage, small bone shard
glowing at the hilt
```

### 3.6.4 `card_ward`
```
a rune-etched kite shield standing upright, a ring of short iron spikes bristling
outward from its rim, a faint blue protective glow hugging the surface
```

### 3.6.5 `card_offering`
```
an open gauntleted palm holding a single burning playing card, the card curling
and dissolving into embers, thin gold sparks rising from it
```

---

## 3.7. Батч 5 — славянский набор (Навь)

Сеттинг сместился в славянскую мифологию. Старые герои и монстры **остаются**
(верхние этажи — копи), новые живут в **Нави** с 3-го этажа.

Стилевой префикс §0 — без изменений. Дополнительно ко всем промптам этого батча:

```
Slavic folklore aesthetic, birch-bark and rushnik red embroidery accents,
old-Russian ornament, bone charms and red thread, nothing generic-medieval,
no plate armour, no western knight iconography
```

### Герои (бюст, как в §1)

| Файл | Кто |
|---|---|
| `hero_vityaz` | Витязь — богатырь, танк |
| `hero_polyanitsa` | Поляница — женщина-богатырь, урон |
| `hero_volhv` | Волхв — ведун, чары |

**`hero_vityaz`**
```
a broad-shouldered Slavic bogatyr warrior, thick dark beard, conical nasal helm
over a chainmail coif, red kaftan under scale armour, calm heavy stare,
an embroidered red band at the collar
```

**`hero_polyanitsa`**
```
a Slavic warrior woman, one long dark braid over the shoulder, a red embroidered
sarafan under light lamellar armour, bow string across her chest, sharp confident
half-smile, small bone charms in her braid
```

**`hero_volhv`**
```
an old Slavic pagan sorcerer, long grey beard and unbound hair, wolf pelt over a
linen shirt with red hem embroidery, carved wooden staff top visible at the
shoulder, one milky blind eye, faint cold blue light on his face
```

### Враги Нави (фронтально, в полный рост, как в §3)

| Файл | Кто | Роль |
|---|---|---|
| `enemy_anchutka` | Анчутка | Мелочь, лезет толпой |
| `enemy_likho` | Лихо Одноглазое | Танк |
| `enemy_mavka` | Мавка | Быстрая, дебафф |
| `enemy_poludnitsa` | Полудница | Урон по площади |

**`enemy_anchutka`**
```
a small black bog imp the size of a child, no heels on its backwards feet,
duck-like bill, wet matted fur, tiny horns, mischievous grin, hunched and eager
```

**`enemy_likho`**
```
a gaunt towering hag-like figure of misfortune, ONE huge eye in the middle of the
forehead, tattered black shroud, impossibly long thin arms, dry white hair,
a heavy iron chain dragging from one wrist
```

**`enemy_mavka`**
```
the ghost of a drowned girl, pale green-tinged skin, long wet dark hair with
water weeds in it, a faded embroidered shift, no back visible only hollow ribs,
a wreath of dead flowers, bare feet not quite touching the ground
```

**`enemy_poludnitsa`**
```
the noon spirit, a tall pale woman in a bleached white sarafan, wheat stalks
braided into her hair, holding a large rusty sickle, blank white eyes,
harsh midday light on her despite the dark
```

---

## 3.8. Батч 6 — аватары героев (только лицо)

Текущие портреты — поясные: в круглой рамке HUD полкадра — плечи и доспех,
лицо мелкое. Нужен **крупный план лица** (как у конкурента): одна голова
во весь кадр, читается в круге ~100–120 px.

### Правила кадра (обязательно)

- **Только голова:** подбородок → макушка. **Без плеч, без торса, без доспеха
  на корпусе**, без рук.
- Лицо **во весь кадр** (extreme close-up / headshot fill).
- Глаза ≈ **45%** высоты кадра; макушка почти у верхнего края.
- Центр для **круглой обрезки** HUD.
- Фон: чистая **#FF00FF** (§0).
- Если модель вернула бюст — **перегенерить**, не «подрезать в Photoshop».

### Общий хвост (после §0; для славян ещё + хвост §3.7)

```
character FACE ONLY portrait, extreme close-up headshot, HEAD fills the entire
frame from chin to crown edge-to-edge, ZERO shoulders zero chest zero torso,
no armour plates no clothing collar no neck-guard, facing the viewer straight on,
big expressive eyes, bold thick black outline, flat cel shading two-three tones,
strong silhouette readable at 120px circular crop, nothing below the chin line
```

### Славянская тройка (основная партия)

| Файл | Кто | В коде `portrait` |
|---|---|---|
| `face_vityaz` | Витязь | → `party.gd` vityaz |
| `face_polyanitsa` | Поляница | → polyanitsa |
| `face_volhv` | Волхв | → volhv |

**`face_vityaz`**
```
a broad-faced Slavic bogatyr man, thick full dark brown beard filling the lower
third of the frame, heavy straight brows, calm stubborn dark eyes, weathered
skin, a thin red embroidered rushnik band across the forehead under a hint of
conical nasal-helm rim only at the very top edge of the frame, no shoulders
```

**`face_polyanitsa`**
```
a young Slavic warrior woman face filling the frame, one dark braid curved across
her cheek, sharp green-hazel eyes, a thin pale scar over one eyebrow, small red
embroidered ribbon in her hair near the temple, confident half-smile, freckles,
no shoulders no armor
```

**`face_volhv`**
```
an old Slavic pagan sorcerer face filling the frame, long grey beard filling the
lower frame, unbound grey hair, deep wrinkles, ONE milky white blind eye and one
clear pale blue eye, faint cold cyan light from below on the cheekbones, no
shoulders no staff
```

### Старая тройка (копи, опционально)

| Файл | Кто |
|---|---|
| `face_kael` | Каэль |
| `face_lyra` | Лира |
| `face_sera` | Сера |

**`face_kael`**
```
a stoic human paladin man in his forties, face only, short greying dark hair,
square jaw, a pale scar across the left eyebrow, calm tired brown eyes, warm
torch light from below on the face, no shoulders no pauldrons
```

**`face_lyra`**
```
a sharp-eyed young huntress face only, dark braided hair with a green cloth band
on the forehead, freckles, alert half-smile, cool green-teal eye accents, no
shoulders no cloak
```

**`face_sera`**
```
a fire mage woman face only, cropped copper-red hair, soot smudge on one cheek,
intense focused eyes lit warm orange from below by her own magic, no shoulders
no robe
```

---

## 3.9. Батч 7 — Сказочный лес (второй уровень)

Второй тип карты: **открытая местность**, не коридоры. Концепт тот же —
**3D только земля**, всё остальное 2D-спрайты (§ AGENTS.md).

### Стилевой хвост для леса

Вместо `dark teal-and-ember dungeon world` из §0 подставлять:

```
moonlit slavic fairy-tale forest at dusk, deep blue-green and violet shadows,
warm amber glow accents, birch and fir, folklore mood
```

### Правила кадра (обязательно)

- **Точка опоры — по нижнему краю.** Дерево / куст / камень должны касаться
  низа кадра стволом или основанием: движок ставит спрайт «ногами» на землю.
  Пустое поле под объектом = объект будет висеть в воздухе.
- **Не рисовать тень на земле** — контактную тень кладёт движок (иначе будет
  две, и вторая не совпадёт с рельефом).
- Фронтальный вид, без сильной перспективы сверху: спрайты билбордятся к
  камере, вид «сверху-вбок» на них ломается.
- Фон **строго `#FF00FF`**, как везде.

### 3.9.1 Деревья и растительность

| Файл | Что | Хвост промпта |
|---|---|---|
| `forest_pine` | Высокая ель | `a tall slender fir tree, dark blue-green needles, narrow silhouette, trunk visible at the bottom, full height of frame` |
| `forest_birch` | Берёза | `a white birch tree with black bark marks, sparse golden autumn leaves, slightly curved trunk, trunk base at the bottom edge` |
| `forest_oak_old` | Старый дуб-великан | `an ancient massive oak, gnarled twisted trunk, thick moss on the bark, broad heavy crown, roots spreading at the bottom edge` |
| `forest_bush` | Куст | `a low round bush with dense dark leaves and a few red berries, base at the bottom edge` |
| `forest_fern` | Папоротник | `a cluster of tall ferns, layered fronds, cool green, base at the bottom edge` |
| `forest_stump` | Пень | `an old mossy tree stump with a small toadstool growing on it, cut top, base at the bottom edge` |
| `forest_log` | Лежащее бревно | `a fallen mossy log lying horizontally, hollow dark end facing the viewer, wide not tall` |

### 3.9.2 Свет (замена настенным факелам)

В лесу нет стен, поэтому источники света — стоячие / висячие.

| Файл | Что | Хвост промпта |
|---|---|---|
| `forest_lantern` | Фонарь на шесте | `a lit iron lantern hanging from a wooden pole stuck in the ground, warm amber flame inside glass, pole base at the bottom edge` |
| `forest_glowshroom` | Светящиеся грибы | `a cluster of large glowing mushrooms, pale cyan bioluminescent caps casting light, base at the bottom edge` |
| `forest_campfire` | Костёр | `a small campfire of crossed logs with bright warm flames, ring of stones around it, wide not tall` |

### 3.9.3 Дальний план

| Файл | Что | Хвост промпта |
|---|---|---|
| `forest_treeline` | Полоса леса вдали | `a distant treeline silhouette, flat dark blue-violet shapes of fir tops, no detail, very wide horizontal strip, no ground` |

⚠️ `forest_treeline` — **широкая горизонтальная полоса** (примерно 4:1), она
идёт кольцом по горизонту и закрывает край карты. Единственный ассет батча,
который не «стоит на земле».

### 3.9.4 Земля (3D)

Земля — единственное, что 3D, и ей нужна **бесшовная** текстура; Grok бесшовность
не держит. Поэтому земля пока **процедурная**, как скала в копях
(`cave_rock.gdshader` → лесной вариант). Отдельного ассета не просить.

### 3.9.5 Обитатели леса (опционально, решает юзер)

Если лес получает свой бестиарий, а не мобов копей — фронтально, в полный рост,
по правилам §3 (`realm: "forest"` в `scripts/enemy_sprites.gd`):

| Файл | Кто | Хвост промпта |
|---|---|---|
| `enemy_leshy` | Леший | `a forest spirit made of bark and moss, long beard of hanging lichen, glowing green eyes, tall and stooped` |
| `enemy_kikimora` | Кикимора | `a small hunched swamp crone in ragged wet cloth, tangled hair with twigs, spindly limbs` |
| `enemy_wolf` | Волк | `a large shaggy grey wolf, bared fangs, hackles raised, standing on all fours` |

---

## 4. Куда класть готовое

1. Исходник (что отдал Grok) → `assets/textures/masters/<id>_source.jpg`
2. Резаный PNG → `assets/textures/masters/<id>.png` **и** `assets/textures/<id>.png`
3. Строка в таблицу `assets/textures/ASSETS.md`

Имена — ровно те, что в колонках «Файл» выше: код ищет арт по этим id
(`portrait` у героя в `scripts/party.gd`, `art` у карты в `scripts/cards/card_db.gd`).

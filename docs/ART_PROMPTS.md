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
| Кружок стоимости | 2–22% | 1–16% | цифра + ⚡/🩸 |
| Окно иллюстрации | 8–92% | 15–52% | арт скилла (`card_*.png`) |
| Лента названия | 6–94% | 54–63% | название карты |
| Поле текста | 10–90% | 66–93% | описание эффекта |

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

## 4. Куда класть готовое

1. Исходник (что отдал Grok) → `assets/textures/masters/<id>_source.jpg`
2. Резаный PNG → `assets/textures/masters/<id>.png` **и** `assets/textures/<id>.png`
3. Строка в таблицу `assets/textures/ASSETS.md`

Имена — ровно те, что в колонках «Файл» выше: код ищет арт по этим id
(`portrait` у героя в `scripts/party.gd`, `art` у карты в `scripts/cards/card_db.gd`).

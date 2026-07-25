# Готовый заказ артов — вставлять как есть

13 файлов. Префикс стиля **уже внутри** каждого промпта — собирать ничего не надо.

Класть готовое в `assets/textures/masters/<id>_source.jpg`, потом:

```bash
python3 tools/sprite_cutter.py assets/textures/masters/<id>_source.jpg \
  assets/textures/<id>.png --tolerance 60 --pad 4 --ffmpeg --erode-light 2
godot --headless --import
godot --headless --script tests/art_import_test.gd
```

⚠️ `--import` не пропускать: без него файл лежит на диске, но игра его не видит.
Ловили дважды — лес и карты батча 8 оба раза не появлялись именно из-за этого.

---

### `face_vityaz_low.png` — Витязь при смерти

```
extreme close-up headshot only, chin to crown, front view, a bearded slavic warrior man, conical iron helmet with a red embroidered band bearing white roosters and leaves, thick dark beard with small red embroidery marks, pale and haggard, eyes half closed and unfocused, heavy bleeding down one side of the face, jaw slack with exhaustion, greyed skin, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette
```

### `forage_glow_moss.png` — Светящийся мох (копи)

```
a patch of pale blue-green luminous moss growing over a small rounded rock, faint glow, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, dark teal-and-ember dungeon world, the object TOUCHES THE BOTTOM EDGE of the frame with its base or stem, no ground shadow painted under it, strictly front view
```

### `forage_cave_mushroom.png` — Пещерный гриб (копи)

```
a cluster of three pale bulbous cave mushrooms with thick short stems, no gills visible, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, dark teal-and-ember dungeon world, the object TOUCHES THE BOTTOM EDGE of the frame with its base or stem, no ground shadow painted under it, strictly front view
```

### `forage_bone_pile.png` — Костяные обломки (копи)

```
a small pile of cracked yellowed bones with one broken skull fragment on top, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, dark teal-and-ember dungeon world, the object TOUCHES THE BOTTOM EDGE of the frame with its base or stem, no ground shadow painted under it, strictly front view
```

### `forage_herbs.png` — Травы (лес)

```
a bundle of tall green medicinal herbs with narrow leaves and small white flowers, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, moonlit slavic fairy-tale forest at dusk, deep blue-green and violet shadows, warm amber glow accents, the object TOUCHES THE BOTTOM EDGE of the frame with its base or stem, no ground shadow painted under it, strictly front view
```

### `forage_berries.png` — Ягоды (лес)

```
a low bush branch heavy with clusters of dark red berries and green leaves, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, moonlit slavic fairy-tale forest at dusk, deep blue-green and violet shadows, warm amber glow accents, the object TOUCHES THE BOTTOM EDGE of the frame with its base or stem, no ground shadow painted under it, strictly front view
```

### `forage_amanita.png` — Мухомор (лес)

```
three red fly agaric mushrooms of different heights with white spots on the caps, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, moonlit slavic fairy-tale forest at dusk, deep blue-green and violet shadows, warm amber glow accents, the object TOUCHES THE BOTTOM EDGE of the frame with its base or stem, no ground shadow painted under it, strictly front view
```

### `consum_broth.png` — Отвар — лечит

```
a small wooden bowl of steaming brown broth with a single green herb sprig in it, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, dark teal-and-ember dungeon world, square composition, one single object centred, viewed straight on, must stay readable when shrunk to 30 pixels: bold silhouette, two or three colours only, no fine detail, no thin lines, the object does not touch the frame edges, about 10 percent empty margin all round, no shadow under the object
```

### `consum_rage_draught.png` — Ярый настой — Ярость

```
a squat clay flask of glowing orange liquid, cork removed, heat shimmer rising from the neck, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, dark teal-and-ember dungeon world, square composition, one single object centred, viewed straight on, must stay readable when shrunk to 30 pixels: bold silhouette, two or three colours only, no fine detail, no thin lines, the object does not touch the frame edges, about 10 percent empty margin all round, no shadow under the object
```

### `consum_antidote.png` — Противоядие — снимает хвори

```
a small glass bottle of clear pale blue liquid with a green leaf tied to its neck by cord, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, dark teal-and-ember dungeon world, square composition, one single object centred, viewed straight on, must stay readable when shrunk to 30 pixels: bold silhouette, two or three colours only, no fine detail, no thin lines, the object does not touch the frame edges, about 10 percent empty margin all round, no shadow under the object
```

### `trophy_fang.png` — Клык

```
a single long sharp tooth, ivory white with a dark bloodied root, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, dark teal-and-ember dungeon world, square composition, one single object centred, viewed straight on, must stay readable when shrunk to 30 pixels: bold silhouette, two or three colours only, no fine detail, no thin lines, the object does not touch the frame edges, about 10 percent empty margin all round, no shadow under the object
```

### `trophy_hide.png` — Шкура

```
a rolled scrap of coarse grey animal hide tied with a leather cord, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, dark teal-and-ember dungeon world, square composition, one single object centred, viewed straight on, must stay readable when shrunk to 30 pixels: bold silhouette, two or three colours only, no fine detail, no thin lines, the object does not touch the frame edges, about 10 percent empty margin all round, no shadow under the object
```

### `trophy_ichor.png` — Навья слизь

```
a sealed glass jar of murky violet spectral fluid with faint pale wisps drifting inside, 2D cartoon game art, hand-painted illustration, thick black ink outline around every shape, bold cel shading with two or three tones, slightly desaturated fantasy palette, no photorealism, no text, no watermark, no border, no frame, single centred subject, flat pure magenta background #FF00FF, full bleed background with no vignette, dark teal-and-ember dungeon world, square composition, one single object centred, viewed straight on, must stay readable when shrunk to 30 pixels: bold silhouette, two or three colours only, no fine detail, no thin lines, the object does not touch the frame edges, about 10 percent empty margin all round, no shadow under the object
```

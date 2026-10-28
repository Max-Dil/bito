# bito

A tiny software-rendered, 16-color indexed pixel graphics library for [LÖVE](https://love2d.org) (LuaJIT). It provides:

- **bito** – a palette-indexed framebuffer with a LÖVE-like drawing API (`bito.graphics`).
- **biteen** (`bito.screen`) – adaptive screen layout: resolution modes, orientation, safe areas, layout boxes, cameras and input coordinate conversion.
- **bisond** (`bito.sound`) – a tiny 4-channel tracker-style sound synthesizer driven by text streams.

Everything is drawn into a CPU-side `uint8` buffer of palette indices and uploaded to the GPU once per frame, where a small shader converts indices to RGB through a 16-entry palette texture.

## Table of contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Core concepts](#core-concepts)
- [Module `bito`](#module-bito)
- [Palette](#palette)
- [Module `bito.graphics`](#module-bitographics)
- [Type `Surface`](#type-surface)
- [Type `Font`](#type-font)
- [Module `bito.screen` (biteen)](#module-bitoscreen-biteen)
- [Type `Box`](#type-box)
- [Type `Camera`](#type-camera)
- [Module `bito.sound` (bisond)](#module-bitosound-bisond)
- [Complete example](#complete-example)
- [Notes and limitations](#notes-and-limitations)

---

## Requirements

- LÖVE 11.3 or newer (uses `ImageData:getFFIPointer`, `love.window.getSafeArea`, `Image:replacePixels`, `r8` image format when available).
- LuaJIT (the library uses `ffi` and `bit`).

Loading the module calls `love.graphics.setDefaultFilter('nearest', 'nearest', 1)`.

Save the library as `bito.lua` in your project and load it with:

```lua
local bito = require('bito')
```

---

## Quick start

```lua
local bito = require('bito')
local screen = bito.screen
local g = bito.graphics

local x = 0

function love.load()
    screen.init(bito, {
        width = 320,
        height = 180,
        mode = 'expand',
        integerScale = true,
        hook = true,
    })
end

function love.update(dt)
    x = (x + 40 * dt) % screen.getWidth()
    bito.sound.update()
end

function love.draw()
    g.clear('dark_blue')
    g.setColor('yellow')
    g.circle('fill', x, screen.getHeight() / 2, 8)
    g.setColor('white')
    g.print('HELLO BITO', 4, 4)
    bito.draw()
end
```

Rules of thumb:

1. Draw everything through `bito.graphics` (into the display or a canvas).
2. Call `bito.draw()` once per frame at the end of `love.draw` to present the display on the window.
3. Call `bito.screen.init` (or `bito.setResolution` + `bito.resize`) so the display is laid out correctly, and forward `love.resize` to it (done automatically with `hook = true`).

---

## Core concepts

### Colors

The palette has exactly 16 entries. A **Color** argument is accepted anywhere a color is expected and can be:

| Form | Meaning |
| --- | --- |
| `number` 1–16 | Palette index (1-based). Fractions are floored. Values outside 1–16 wrap around (`17` → `1`, `0` → `16`). |
| `string` | A color name from `bito.colors`. Unknown names resolve to `black`. |

`graphics.setColor` additionally accepts three RGB numbers (0–255), which are snapped to the nearest palette entry.

Functions that return a color (`getColor`, `getPixel`) return a 1-based palette index.

Default palette (PICO-8 style) and names:

| Index | Name | RGB |
| --- | --- | --- |
| 1 | `black` | 0, 0, 0 |
| 2 | `dark_blue` | 29, 43, 83 |
| 3 | `purple` | 126, 37, 83 |
| 4 | `dark_green` | 0, 135, 81 |
| 5 | `brown` | 171, 82, 54 |
| 6 | `gray` | 95, 87, 79 |
| 7 | `light_gray` | 194, 195, 199 |
| 8 | `white` | 255, 241, 232 |
| 9 | `red` | 255, 0, 77 |
| 10 | `orange` | 255, 163, 0 |
| 11 | `yellow` | 255, 236, 39 |
| 12 | `green` | 0, 228, 54 |
| 13 | `blue` | 41, 173, 255 |
| 14 | `lavender` | 131, 118, 156 |
| 15 | `pink` | 255, 119, 168 |
| 16 | `peach` | 255, 204, 170 |

The initial drawing color is `7` (`light_gray`).

### Render targets

There is always a current render target: either the **display** (the main framebuffer shown on screen) or a **canvas** created with `graphics.newCanvas`. Select it with `graphics.setCanvas`. All `graphics.*` drawing functions operate on the current target and use per-target state.

### Per-target state

Each target remembers its own translation, color, font and clip rectangle. These are saved when you switch away and restored when you switch back. `graphics.push` / `graphics.pop` save and restore this same state on a stack.

### Translation, clipping and the drawing functions

- `graphics.translation(x, y)` sets an absolute offset added to every coordinate of the drawing functions (it does not accumulate).
- All coordinates are floored to integers after translation.
- Clipping is a rectangle in target pixels. Drawing outside it is discarded.
- The `Surface` methods (`setPixel`, `getPixel`, `clear`) ignore translation and clipping.

### Transparency

Images created by `graphics.newImage` use palette index `255` internally as the transparent key (pixels with alpha below 128). Canvases have no key by default. `graphics.draw` lets you override the key per call.

### Virtual resolution

The display has a fixed pixel size (default `400x300`) that is scaled to fit the window with nearest-neighbor filtering and centered. `bito.screen` can automatically choose that pixel size from the window size.

---

## Module `bito`

`require('bito')` returns the main table:

| Field | Type | Description |
| --- | --- | --- |
| `graphics` | table | Drawing API, see [bito.graphics](#module-bitographics). |
| `colors` | table | Map of color name → 1-based palette index. |
| `draw` | function | Presents the display to the window. |
| `clear` | function | Clears the display. |
| `setPixel` | function | Writes a pixel to the display. |
| `getPixel` | function | Reads a pixel from the display. |
| `setResolution` | function | Changes the display size. |
| `getResolution` | function | Returns the display size. |
| `resize` | function | Recomputes scale and offset for a window size. |
| `setIntegerScale` | function | Toggles integer-only scaling. |
| `getScale` | function | Returns the current scale factor. |
| `getOffset` | function | Returns the display offset in the window. |
| `screenToPixel` | function | Converts window coordinates to display pixels. |
| `setPalette` | function | Replaces the palette. |
| `setPaletteColor` | function | Changes one palette entry. |
| `getPalette` | function | Returns a copy of the palette. |
| `screen` | table | The biteen module. |
| `sound` | table | The bisond module. |

### `bito.draw()`

Uploads the palette (if it changed) and the display buffer to the GPU, then draws the display scaled and centered in the window using the palette shader. Call it at the end of `love.draw`. It preserves the current LÖVE color and shader. It does not clear the window; the area outside the display (letterboxing) shows whatever LÖVE's background is.

```lua
function love.draw()
    bito.graphics.clear('black')
    bito.graphics.print('HI', 2, 2)
    bito.draw()
end
```

### `bito.clear([color])`

Fills the entire display with `color` (default `1`, black). Ignores clipping and ignores the current canvas; it always targets the display.

### `bito.setPixel(x, y, color)`

Sets one display pixel. Out-of-range coordinates are ignored. Ignores translation and clipping.

### `bito.getPixel(x, y) -> index | nil`

Returns the 1-based palette index of a display pixel, or `nil` if out of range.

### `bito.setResolution(width, height)`

Resizes the display buffer to `width` × `height` (values are floored and clamped to at least 1). The display contents are **cleared** and the layout is recomputed. If the display is the current target, its clip is updated automatically.

### `bito.getResolution() -> width, height`

Returns the display size in pixels.

### `bito.resize(windowWidth, windowHeight)`

Recomputes the display scale and offset for a window of the given size. If called with no arguments it queries `love.graphics.getDimensions()`. Call this from `love.resize` (done automatically by `screen.hook`).

### `bito.setIntegerScale(on)`

When `true`, the scale is rounded down to a whole number of physical pixels (taking the DPI scale into account), if the window is large enough. Re-lays out immediately.

### `bito.getScale() -> number`

Returns the current scale factor (window units per display pixel).

### `bito.getOffset() -> x, y`

Returns the top-left position of the display inside the window (in window units).

### `bito.screenToPixel(x, y) -> px, py`

Converts window coordinates to display pixel coordinates (floored). The result can be outside the display bounds.

### Palette functions

See [Palette](#palette).

---

## Palette

### `bito.setPalette(list)`

Replaces all 16 palette entries. `list` is an array of `{r, g, b}` triples in the 0–255 range. Missing entries fall back to the default palette.

```lua
bito.setPalette({
    {0, 0, 0},
    {255, 255, 255},
})
```

### `bito.setPaletteColor(color, r, g, b)`

Changes a single palette entry. `color` is an index or name; `r`, `g`, `b` are 0–255.

```lua
bito.setPaletteColor('red', 200, 20, 20)
```

### `bito.getPalette() -> table`

Returns a new array of 16 `{r, g, b}` triples.

### Behavior

- Changing the palette affects everything already drawn immediately, because the framebuffer stores indices and the palette is applied at presentation.
- `graphics.setColor(r, g, b)` and `graphics.newImage` quantize to the palette that is active **at the time of the call**.

---

## Module `bito.graphics`

Alias it for convenience:

```lua
local g = bito.graphics
```

### State

#### `g.push()`
Saves the current translation, color, font and clip on an internal stack.

#### `g.pop()`
Restores the most recently saved state. Does nothing if the stack is empty.

#### `g.setColor(color)` / `g.setColor(r, g, b)`
Sets the drawing color. With one argument it is an index or name. With three arguments (0–255) the nearest palette color is selected.

#### `g.getColor() -> index`
Returns the current drawing color as a 1-based index.

#### `g.translation(x, y)`
Sets the absolute translation applied to subsequent drawing calls.

#### `g.getTranslation() -> x, y`
Returns the current translation.

#### `g.setFont(font)`
Sets the font used by `g.print`.

#### `g.getFont() -> Font`
Returns the current font.

#### `g.getWidth()`, `g.getHeight()`, `g.getDimensions()`
Return the size of the **current render target**.

### Clipping

#### `g.setClip(x, y, w, h)`
Sets the clip rectangle (the translation is applied to `x`, `y`). Call with no arguments (or `nil`) to disable clipping.

#### `g.addClip(x, y, w, h)`
Intersects the current clip with the given rectangle (translation applied). If no clip is active, it becomes the clip.

#### `g.clearClip()`
Disables clipping.

#### `g.getClip() -> x, y, w, h | nil`
Returns the active clip rectangle relative to the current translation, or `nil` if clipping is off.

### Drawing

#### `g.clear([color])`
Fills the current target with `color` (default black). If a clip is active only the clipped area is filled.

#### `g.pixel(x, y)`
Draws one pixel in the current color.

#### `g.line(x1, y1, x2, y2)`
Draws a 1-pixel line using Bresenham's algorithm. Horizontal and vertical lines use fast paths.

#### `g.rectangle(mode, x, y, w, h)`
Draws a rectangle. `mode` is `'fill'` for a filled rectangle; any other value draws a 1-pixel outline. Width and height are floored; nothing is drawn if either is `<= 0`.

#### `g.circle(mode, cx, cy, r)`
Draws a circle with the midpoint algorithm. `mode` is `'fill'` or an outline for any other value. Nothing is drawn if `r < 0`.

#### `g.fill(x, y)`
Flood fill (scanline) starting at `(x, y)` with the current color. It replaces the connected region of pixels sharing the color of the start pixel and stays within the active clip. Does nothing if the start pixel already has the current color or is outside the clip.

```lua
g.setColor('red')
g.circle('line', 40, 40, 20)
g.setColor('yellow')
g.fill(40, 40)
```

#### `g.print(text, x, y)`
Draws text with the current font and color. `text` is converted with `tostring`; `nil` and empty strings draw nothing. Text is UTF-8; `\n` starts a new line at the original `x`. Glyphs missing from the font fall back to `?`.

```lua
g.setColor('white')
g.print('SCORE: ' .. 120, 4, 4)
```

### Fonts

#### `g.newFont([fontData,] size) -> Font`
Creates a font.

- `g.newFont(size)` uses the built-in font.
- `g.newFont(fontData, size)` uses custom glyph data.

`size` is an integer scale factor (default `1`, minimum `1`): glyph cells become `5*size` × `7*size` pixels, and spacing between characters is `size` pixels. See [Type Font](#type-font).

### Images and canvases

#### `g.newImage(source) -> Surface`
Creates an image surface from a file path, `FileData` or `ImageData`. Every pixel is quantized to the nearest palette color at load time. Pixels with alpha below 128 (below 0.5 for non-`rgba8` data) become transparent. The resulting surface has a transparent key set, so it is drawn with transparency by default.

#### `g.newCanvas(width, height) -> Surface`
Creates an empty offscreen surface filled with palette index 1 (black). Canvases have no transparent key unless you pass one to `g.draw`.

#### `g.setCanvas([canvas])`
Sets the current render target to `canvas`. Calling it with no argument (or `nil`) switches back to the display. State (translation, color, font, clip) is stored per target.

```lua
local sprite = g.newCanvas(16, 16)
g.setCanvas(sprite)
g.clear('black')
g.setColor('red')
g.circle('fill', 8, 8, 6)
g.setCanvas()
g.draw(sprite, 10, 10, 'black')
```

### Blitting

#### `g.draw(surface, [x, y, key, flipX, flipY])`
Copies a surface to the current target at `(x, y)` (default `0, 0`; translation applied).

- `key` – transparent color. A color value makes that color transparent; `false` disables transparency; `nil` uses the surface's own key (images: transparent pixels, canvases: none).
- `flipX`, `flipY` – mirror the surface horizontally/vertically.

Drawing a surface onto itself is ignored. If a color map is active, it is applied to copied pixels.

#### `g.drawRegion(surface, x, y, qx, qy, qw, qh, [key, flipX, flipY])`
Like `g.draw` but copies only the source rectangle `(qx, qy, qw, qh)`. Useful for sprite sheets and tiles. The region is clamped to the source bounds.

```lua
local sheet = g.newImage('sprites.png')
g.drawRegion(sheet, 50, 60, 16, 0, 16, 16)
g.drawRegion(sheet, 70, 60, 16, 0, 16, 16, nil, true)
```

### Color mapping

#### `g.mapColor(from, to)`
Remaps color `from` to `to` for all subsequent `g.draw` / `g.drawRegion` calls. Useful for palette swaps. Multiple mappings accumulate. The map is global (not part of `push`/`pop`) and affects only blitting, not shape drawing.

#### `g.resetColorMap()`
Removes all color mappings.

```lua
g.mapColor('red', 'blue')
g.draw(enemy, 20, 20)
g.resetColorMap()
```

---

## Type `Surface`

Represents the display, an image, or a canvas. Obtained from `g.newImage` and `g.newCanvas`.

| Field | Type | Description |
| --- | --- | --- |
| `width` | number | Width in pixels. |
| `height` | number | Height in pixels. |
| `key` | number or nil | Transparent index (`255` for images, `nil` for canvases). |

### Methods

#### `surface:clear([color])`
Fills the whole surface with `color` (default black). Ignores clipping.

#### `surface:setPixel(x, y, color)`
Sets a pixel. Out-of-bounds writes are ignored. Ignores translation and clipping.

#### `surface:getPixel(x, y) -> index | nil`
Returns the 1-based palette index at `(x, y)`, or `nil` if out of bounds or the pixel is transparent.

#### `surface:getResolution()`, `surface:getDimensions() -> width, height`
Return the surface size.

#### `surface:getWidth()`, `surface:getHeight()`
Return the width or height.

#### `surface:resize(width, height)`
Resizes the surface to the given size (floored, minimum 1), keeping the overlapping part of the old contents. New area is filled with index 0 (black). If the surface is the current target, its drawing bounds are updated. Resizing the display itself is equivalent to `bito.setResolution` (and clears it).

#### `surface:release()`
Frees the pixel buffer. The surface must not be used afterwards.

```lua
local canvas = g.newCanvas(32, 32)
canvas:clear('dark_blue')
canvas:setPixel(5, 5, 'white')
local w, h = canvas:getDimensions()
canvas:resize(64, 64)
canvas:release()
```

---

## Type `Font`

A fixed-size bitmap font.

| Field | Type | Description |
| --- | --- | --- |
| `data` | table | Glyph data (character → 7 row bytes). |
| `size` | number | Integer scale factor. |
| `charWidth` | number | Glyph width: `5 * size`. |
| `charHeight` | number | Glyph height: `7 * size`. |
| `spacing` | number | Pixels between glyphs and lines: `size`. |

### Glyph data format

A custom font is a table mapping a UTF-8 character (string) to an array of **7 integers**, one per row from top to bottom. Each integer uses its low **5 bits**; bit 4 (`0x10`) is the leftmost pixel and bit 0 (`0x01`) is the rightmost.

```lua
local myFont = {
    ['I'] = {0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E},
    ['?'] = {0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04},
}
local font = g.newFont(myFont, 2)
g.setFont(font)
```

If a character is missing from the data, the `?` glyph is used; if `?` is also missing, nothing is drawn.

### Built-in glyphs

Digits, Latin letters (upper and lower case), Cyrillic letters (upper and lower case), space, and the symbols
`. , : ! ? - _ + / \ ( ) [ ] { } < > = @ # $ % ^ & * " ' ~ \` |`, plus `°`, `↑`, `↓`, `←`, `→`.

### Methods

#### `font:getWidth(text) -> number`
Returns the width in pixels of the widest line of `text` (lines are separated by `\n`). Returns `0` for empty text.

#### `font:getHeight([text]) -> number`
Returns the height in pixels of `text` taking line breaks into account. Without text (or with empty text) returns one line height.

```lua
local font = g.getFont()
local w = font:getWidth('HELLO')
local h = font:getHeight('A\nB')
```

---

## Module `bito.screen` (biteen)

Handles virtual resolution, orientation, safe areas, layout helpers, cameras, and input conversion. Access it as `bito.screen`.

```lua
local screen = bito.screen
```

### Initialization

#### `screen.init(bito, [config]) -> screen`
Connects biteen to the bito instance and performs the first layout calculation. `config` fields:

| Field | Default | Description |
| --- | --- | --- |
| `baseWidth` / `width` | `320` | Base resolution width. |
| `baseHeight` / `height` | `180` | Base resolution height. |
| `portraitWidth` | `nil` | Base width used in portrait. Defaults to the smaller of base width/height. |
| `portraitHeight` | `nil` | Base height used in portrait. Defaults to the larger of base width/height. |
| `mode` | `'expand'` | Resolution mode, see below. |
| `orientation` | `'auto'` | `'auto'`, `'landscape'` or `'portrait'`. |
| `orientationThreshold` | `1.05` | Hysteresis for automatic orientation changes (≥ 1). |
| `maxAspect` | `nil` | Maximum virtual aspect ratio (width / height). |
| `minAspect` | `nil` | Minimum virtual aspect ratio (width / height). |
| `integerScale` | `false` | Use integer scaling. |
| `useOsSafeArea` | `true` | Take `love.window.getSafeArea` into account. |
| `compactDp` | `600` | Window size threshold for `sizeClass`. |
| `safePadding` | `nil` | Manual safe padding, see `setSafePadding`. |
| `onResize` | `nil` | `function(vw, vh, orientation, scale)` called when resolution, orientation or insets change. |
| `onOrientation` | `nil` | `function(orientation, vw, vh)` called when the orientation changes. |
| `hook` | `nil` | `true` or an options table, calls `screen.hook`. |

```lua
screen.init(bito, {
    width = 320,
    height = 180,
    portraitWidth = 180,
    portraitHeight = 320,
    mode = 'expand',
    integerScale = true,
    maxAspect = 21 / 9,
    safePadding = {top = 4, right = 4, bottom = 4, left = 4},
    onResize = function(vw, vh, orientation, scale)
    end,
    hook = true,
})
```

### Resolution modes

The base size depends on orientation: in landscape it is `max(baseW, baseH)` × `min(baseW, baseH)`; in portrait it is `portraitWidth × portraitHeight` (or the min/max defaults above).

| Mode | Behavior |
| --- | --- |
| `'fixed'` | The virtual resolution always equals the base size. |
| `'expand'` | The virtual resolution grows to fill the window while keeping the base scale; it is never smaller than the base size. |
| `'width'` | Width equals the base width; height follows the window aspect ratio. |
| `'height'` | Height equals the base height; width follows the window aspect ratio. |
| `'area'` | Keeps approximately the same pixel area as the base size, using the window aspect ratio. |

For all modes except `'fixed'`, `maxAspect` limits how wide and `minAspect` limits how tall the virtual resolution can be (they never constrain below the base aspect ratio).

### Configuration functions

| Function | Description |
| --- | --- |
| `screen.resize(w, h)` | Recalculates for a window size (called by the hook). |
| `screen.refresh()` | Recalculates using the current window size. |
| `screen.setMode(mode)` | Changes the resolution mode. |
| `screen.setOrientation(orientation)` | Sets `'auto'`, `'landscape'` or `'portrait'`. |
| `screen.setOrientationThreshold(t)` | Sets the auto-orientation hysteresis. |
| `screen.setAspectLimits(minAspect, maxAspect)` | Sets aspect ratio limits (`nil` removes a limit). |
| `screen.setBaseResolution(w, h, [portraitW, portraitH])` | Changes the base resolution. |
| `screen.setIntegerScale(on)` | Enables or disables integer scaling (also forwarded to bito). |
| `screen.setSafePadding(top, right, bottom, left)` | Sets manual safe padding. |
| `screen.setOsSafeArea(on)` | Enables or disables the OS safe area. |

#### `screen.setSafePadding(...)`
Accepts either up to four numbers (CSS-like: `top`, `right` defaults to `top`, `bottom` defaults to `top`, `left` defaults to `right`) or a table with fields `top`, `right`, `bottom`, `left` (or array positions 1–4). Values strictly between 0 and 1 are fractions of the virtual size; other values are pixels. The effective inset on each side is the larger of the manual padding and the OS safe-area inset.

```lua
screen.setSafePadding(8)
screen.setSafePadding(8, 4)
screen.setSafePadding({top = 12, bottom = 6})
screen.setSafePadding(0.05)
```

### Query functions

| Function | Returns |
| --- | --- |
| `screen.getDimensions()` | Virtual `width, height`. |
| `screen.getWidth()` | Virtual width. |
| `screen.getHeight()` | Virtual height. |
| `screen.getBaseDimensions()` | Current base `width, height` (depends on orientation). |
| `screen.getWindowSize()` | Window `width, height`. |
| `screen.getOrientation()` | `'landscape'` or `'portrait'`. |
| `screen.isLandscape()` | `true` in landscape. |
| `screen.isPortrait()` | `true` in portrait. |
| `screen.getScale()` | Display scale factor. |
| `screen.getOffset()` | Display `x, y` offset in the window. |
| `screen.getAspect()` | Virtual aspect ratio (width / height). |
| `screen.getDPIScale()` | LÖVE DPI scale (`1` if unavailable). |
| `screen.getSafeInsets()` | `top, right, bottom, left` insets in virtual pixels. |

### Responsive helpers

#### `screen.select(landscapeValue, portraitValue)`
Returns the first value in landscape and the second in portrait.

#### `screen.sizeClass() -> 'compact' | 'regular'`
Returns `'compact'` if the smaller window dimension is below `compactDp`, otherwise `'regular'`.

#### `screen.isMobile() -> boolean`
`true` on Android and iOS.

#### `screen.touchSize([minPx]) -> number`
Converts a minimum touch target size (default `44` window units) to virtual pixels, rounded up.

#### `screen.rel(rx, ry) -> x, y`
Converts fractions (0–1) of the virtual size to pixels.

#### `screen.vw(percent)`, `screen.vh(percent)`, `screen.vmin(percent)`, `screen.vmax(percent)`
CSS-like units. Return the given percentage of the virtual width, height, smaller side or larger side (floored).

```lua
local barHeight = screen.vh(10)
local margin = screen.vmin(2)
local x, y = screen.rel(0.5, 0.5)
local layout = screen.select('side panel', 'bottom panel')
local button = screen.touchSize(48)
```

### Layout boxes

#### `screen.box(x, y, w, h) -> Box`
Creates a [Box](#type-box).

#### `screen.screenBox() -> Box`
The full virtual screen.

#### `screen.safeBox() -> Box`
The virtual screen minus the safe insets.

#### `screen.baseBox() -> Box`
The base-resolution rectangle centered inside the virtual screen.

### Anchoring and aligned text

#### `screen.anchor(align, [ew, eh, ox, oy, rect]) -> x, y`
Computes the top-left position of an element of size `ew` × `eh` aligned inside `rect` (default: `safeBox()`) with an optional offset `(ox, oy)`.

Alignment codes:

| Code | Position |
| --- | --- |
| `tl`, `tc`, `tr` | Top left, center, right |
| `cl`, `cc` (or `c`), `cr` | Middle left, center, right |
| `bl`, `bc`, `br` | Bottom left, center, right |

#### `screen.printAligned(text, align, [ox, oy, rect]) -> x, y, w, h`
Prints text aligned inside `rect` (default `safeBox()`) with the current font and color, and returns the position and size used.

```lua
local x, y = screen.anchor('br', 16, 16, -2, -2)
screen.printAligned('PAUSED', 'cc')
screen.printAligned('v1.0', 'br', -2, -2)
```

### Input conversion

#### `screen.toPixel(screenX, screenY) -> px, py, inside`
Converts window coordinates to virtual pixel coordinates. `inside` is `true` if the point lies within the virtual screen.

#### `screen.getMouse() -> px, py, inside`
Current mouse position in virtual pixels.

#### `screen.getTouches() -> table`
Array of active touches, each `{id, x, y, inside}` with `x`, `y` in virtual pixels.

```lua
local mx, my, inside = screen.getMouse()
for _, t in ipairs(screen.getTouches()) do
    g.circle('line', t.x, t.y, 6)
end
```

### Camera access

#### `screen.newCamera() -> Camera`
Creates a new [Camera](#type-camera).

#### `screen.camera`
A default camera instance.

#### `screen.updateCameras(dt)`
Updates every camera (shake). Called automatically by the hook.

### Hooking LÖVE callbacks

#### `screen.hook([options])`
Wraps LÖVE callbacks (once only; further calls do nothing). Previously defined callbacks are still called.

| Option | Default | Effect |
| --- | --- | --- |
| `resize` | enabled (set `false` to disable) | Wraps `love.resize` and calls `screen.resize`. |
| `update` | enabled (set `false` to disable) | Wraps `love.update` and calls `screen.updateCameras`. |
| `input` | disabled (set `true` to enable) | Wraps `mousepressed`, `mousereleased`, `mousemoved`, `touchpressed`, `touchreleased`, `touchmoved` so that positions (and movement deltas) arrive in virtual pixels. Only callbacks that exist at hook time are wrapped. |

```lua
function love.mousepressed(x, y, button)
end

screen.hook({input = true})
```

### Debugging

#### `screen.debugDraw()`
Draws diagnostic overlays on the current target: the base box (pink outline), the safe box (green outline), a yellow center cross, and an info line with virtual size, orientation, scale, DPI scale and size class. Call it last in `love.draw` before `bito.draw()`.

---

## Type `Box`

A rectangle with integer `x`, `y`, `w`, `h`, used for layout. Created with `screen.box` or returned by other boxes. Dimensions are floored; width and height are never negative.

### Size values

Many methods accept a **size** value:

- A number strictly between 0 and 1 is a **fraction** of the relevant dimension.
- Any other number is a size in **pixels** (floored).

### Basic methods

| Method | Description |
| --- | --- |
| `box:clone()` | Returns a copy. |
| `box:unpack()` | Returns `x, y, w, h`. |
| `box:center()` | Returns the center `x, y`. |
| `box:right()` | Returns `x + w`. |
| `box:bottom()` | Returns `y + h`. |
| `box:contains(px, py)` | `true` if the point is inside the box. |
| `box:anchor(align, ew, eh, ox, oy)` | Like `screen.anchor`, using this box as the container. |

### `box:pad(top, [right, bottom, left]) -> Box`
Returns a new box shrunk by padding (CSS-like defaulting: `right` defaults to `top`, `bottom` defaults to `top`, `left` defaults to `right`). Size values are resolved against the box height (top/bottom) and width (left/right).

```lua
local inner = screen.safeBox():pad(4)
local asym = screen.safeBox():pad(8, 4)
```

### Cutting

The cut methods **modify the original box** (it shrinks) and **return the cut-off piece** as a new box. `gap` is an optional number of pixels removed between the cut piece and the remainder.

| Method | Description |
| --- | --- |
| `box:cutLeft(amount, [gap])` | Cuts from the left edge. |
| `box:cutRight(amount, [gap])` | Cuts from the right edge. |
| `box:cutTop(amount, [gap])` | Cuts from the top edge. |
| `box:cutBottom(amount, [gap])` | Cuts from the bottom edge. |
| `box:cut(side, amount, [gap])` | `side` is `'left'`, `'right'`, `'top'` or `'bottom'`. An unknown side returns a clone and leaves the box unchanged. |

#### `box:cutAuto(amountLandscape, [amountPortrait], [sideLandscape], [sidePortrait], [gap]) -> Box`
Cuts using different sides depending on orientation. Defaults: `sideLandscape = 'right'`, `sidePortrait = 'bottom'`, `amountPortrait = amountLandscape`.

A shorter form is also accepted when the second argument is a string: `box:cutAuto(amount, sideLandscape, sidePortrait, gap)`.

```lua
local area = screen.safeBox()
local header = area:cutTop(20, 2)
local sidebar = area:cutAuto(80, 40, 'left', 'bottom', 2)
local content = area
```

### Placing and fitting

#### `box:fit(aspectW, aspectH, [align]) -> Box`
Returns the largest box with the given aspect ratio that fits inside this box, aligned with `align` (default `'cc'`).

#### `box:place(w, h, [align, ox, oy]) -> Box`
Returns a box of size `w` × `h` aligned inside this box (default `'tl'`) with an optional offset.

```lua
local playfield = screen.safeBox():fit(4, 3)
local button = playfield:place(40, 12, 'bc', 0, -4)
```

### Splitting

#### `box:splitH(countOrWeights, [gap]) -> {Box}`
Splits into columns. Pass a number for equal columns or an array of weights for proportional columns. The last column absorbs rounding remainders.

#### `box:splitV(countOrWeights, [gap]) -> {Box}`
Splits into rows in the same way.

```lua
local cols = area:splitH(3, 2)
local rows = area:splitV({1, 2, 1})
```

### Stacking

#### `box:stackH(spec, [gap]) -> {Box}`
#### `box:stackV(spec, [gap]) -> {Box}`
Lays out items in a row (`stackH`) or column (`stackV`). `spec` is an array where each item is:

- a **number**: a fixed size (pixels, or a fraction when between 0 and 1);
- a **string** `'*'` or `'N*'` (for example `'2*'`): a flexible item that takes a share of the remaining space proportional to its weight.

Invalid items raise an error.

```lua
local cells = area:stackV({16, '*', '2*', 12}, 2)
```

### Grid

#### `box:gridCell(cols, rows, col, row, [gapX, gapY]) -> Box`
Returns the box of a single grid cell (1-based `col`, `row`). `gapY` defaults to `gapX`.

```lua
local cell = area:gridCell(4, 3, 2, 1, 2)
```

### Drawing helpers

#### `box:draw(fn, [clip])`
Runs `fn` with the origin translated to the box's top-left corner. If `clip` is truthy, drawing is also clipped to the box. State is saved and restored automatically. `fn` receives `(w, h, box, localBox)` where `localBox` is a box at `(0, 0)` with the same size.

#### `box:fill([color])`
Fills the box (optionally setting the color first).

#### `box:outline([color])`
Draws a 1-pixel outline (optionally setting the color first).

```lua
local panel = screen.safeBox():cutTop(40)
panel:fill('dark_blue')
panel:outline('white')
panel:draw(function(w, h)
    bito.graphics.setColor('white')
    bito.graphics.print('PANEL', 2, 2)
end, true)
```

---

## Type `Camera`

A 2D camera that translates world coordinates into the view. The camera position `(x, y)` is the world point displayed at the center of the viewport.

Many methods accept an optional `viewportBox`: a `Box` describing the part of the screen the camera renders into. Without it, the full virtual screen is used.

### Creation

```lua
local cam = screen.newCamera()
```

### Fields

| Field | Description |
| --- | --- |
| `x`, `y` | World position at the center of the view. |
| `bounds` | Optional table `{x, y, w, h}` limiting the camera. |

### Methods

#### `camera:lookAt(x, y, [viewportBox])`
Instantly centers the camera on a world position (coordinates are floored) and applies bounds.

#### `camera:follow(targetX, targetY, [speed, dt, viewportBox])`
Smoothly moves toward a target. `speed` defaults to `10`; `dt` defaults to `love.timer.getDelta()`. Movement is exponential smoothing with factor `min(1, speed * dt)`.

#### `camera:setBounds(x, y, w, h)`
Restricts the camera so the view stays inside the given world rectangle. If the world is smaller than the view on an axis, the camera is centered on it on that axis.

#### `camera:clearBounds()`
Removes the bounds.

#### `camera:shake([intensity, duration, decay])`
Starts a screen shake. Defaults: `intensity = 2` (pixels), `duration = 0.2` seconds, `decay = true` (the shake fades out; pass `false` for constant intensity).

#### `camera:stopShake()`
Stops the shake immediately.

#### `camera:update(dt)`
Advances the shake timer. Called automatically for all cameras by `screen.updateCameras` / the hook.

#### `camera:getOffset([viewportBox]) -> tx, ty`
Returns the translation that maps world to screen coordinates (including shake).

#### `camera:attach([viewportBox, noClip])`
Pushes the graphics state, optionally clips to the viewport, and applies the camera translation. Must be paired with `detach`.

#### `camera:detach()`
Restores the graphics state saved by `attach`.

#### `camera:draw(fn, [viewportBox, noClip])`
Convenience wrapper: attaches, calls `fn(x, y, w, h)` with the visible world bounds, and detaches.

#### `camera:toWorld(px, py, [viewportBox]) -> wx, wy`
Converts screen (virtual pixel) coordinates to world coordinates.

#### `camera:toScreen(wx, wy, [viewportBox]) -> px, py`
Converts world coordinates to screen coordinates.

#### `camera:getVisibleBounds([viewportBox]) -> x, y, w, h`
Returns the visible world rectangle.

```lua
local cam = screen.newCamera()
cam:setBounds(0, 0, 1024, 512)

function love.update(dt)
    cam:follow(player.x, player.y, 8, dt)
end

function love.keypressed(key)
    if key == 'space' then cam:shake(3, 0.3) end
end

function love.draw()
    bito.graphics.clear('black')
    cam:draw(function(vx, vy, vw, vh)
        drawWorld(vx, vy, vw, vh)
    end)
    bito.draw()
end
```

---

## Module `bito.sound` (bisond)

A small synthesizer that renders a text "pattern" into a sound and plays it. Output is 44100 Hz, 16-bit, mono.

```lua
local sound = bito.sound
```

### Stream format

A stream is a string of characters. Whitespace is ignored, so you can lay the pattern out freely. Characters are grouped into **steps** of **4 characters**, one per channel (channel 1–4). Characters at positions `step * 4 + channel` belong to the same channel. A trailing incomplete step is ignored.

The duration of one step is a sixteenth note: `60 / bpm / 4` seconds.

Each character is one of:

| Character | Meaning |
| --- | --- |
| Note character | Starts a note on that channel (see below). |
| `-` | Sustains the previous note on the same channel for one more step. |
| Anything else (for example `.`) | Rest (silence). |

Notes are mapped onto 12 semitones starting at C4 (261.63 Hz): C, C#, D, D#, E, F, F#, G, G#, A, A#, B.

| Characters | Waveform | Octave |
| --- | --- | --- |
| `A B C D E F G H I J K L` | Square | 4 |
| `M N O P Q R S T U V W X` | Sawtooth | 4 |
| `a b c d e f g h i j k l` | Triangle | 4 |
| `m n o p q r s t u v w x` | Noise (decaying; the character selects the pitch of the noise) | 4 |
| `0 1 2 3 4 5 6 7 8 9 ! @` | Triangle | 3 (one octave lower) |
| `# $ % ^ & * ( ) _ + = ~` | Sawtooth | 3 (one octave lower) |

Each note has a short fade-in/out to avoid clicks. Channels are mixed additively with clipping.

Example (a four-channel pattern, one step per group of four characters):

```lua
local stream = [[
A.0.
-.-.
C.0.
-.-.
E.2.
-.-.
G.0.
-.-.
]]
```

### Loading

#### `sound.loadFromStream(name, stream, [bpm]) -> true`
Renders a plain-text stream into a sound and stores it under `name`. `bpm` defaults to `120`.

#### `sound.load(name, path, [bpm]) -> true`
Loads a **compressed** stream from a file and stores the rendered sound under `name`. `path` may be:

- a `.png` file whose pixel bytes contain the data: the first three bytes are the little-endian length of the compressed data and the compressed data starts at byte 5 (offset 4);
- any other file in the LÖVE filesystem containing zlib-compressed data.

Raises an error if a non-PNG file cannot be read.

#### `sound.decode(pathOrData, [isRawCompressed]) -> string`
Returns the decompressed stream text. If `isRawCompressed` is `true`, `pathOrData` is treated as a zlib-compressed string. Otherwise it is a file path as described for `sound.load`.

```lua
sound.loadFromStream('jump', 'A...-...C...-...', 140)
sound.load('theme', 'theme.bin', 100)
```

### Playback

#### `sound.play(name, [loop, volume]) -> boolean`
Plays a loaded sound. Any instance of the same sound that is already playing is stopped first. `loop` is `true` to loop; `volume` is 0–1 (default `1`). Returns `false` if the sound is not loaded.

#### `sound.stop(name) -> boolean`
Stops a sound. Returns `true` if it was active.

#### `sound.pause(name) -> boolean`
Pauses an active sound. Returns `true` if it was active.

#### `sound.resume(name) -> boolean`
Resumes a paused sound. Returns `true` if it was active.

#### `sound.setVolume(name, volume) -> boolean`
Sets the volume (clamped to 0–1) of an active sound.

#### `sound.setLooping(name, loop) -> boolean`
Enables or disables looping of an active sound.

#### `sound.isPlaying(name) -> boolean`
`true` if the sound is currently playing.

#### `sound.stopAll()`
Stops all active sounds.

#### `sound.update()`
Releases references to sounds that have finished. Call it regularly, for example from `love.update`.

```lua
sound.loadFromStream('beep', 'A...-...', 160)
sound.play('beep', false, 0.8)

function love.update()
    sound.update()
end
```

---

## Complete example

```lua
local bito = require('bito')
local screen = bito.screen
local g = bito.graphics

local camera
local player = {x = 100, y = 60}
local hud
local sprite

function love.load()
    screen.init(bito, {
        width = 320,
        height = 180,
        mode = 'expand',
        integerScale = true,
        safePadding = 4,
        hook = {input = true},
    })

    bito.setPaletteColor('dark_blue', 20, 30, 70)

    sprite = g.newCanvas(8, 8)
    g.setCanvas(sprite)
    g.clear('black')
    g.setColor('red')
    g.circle('fill', 4, 4, 3)
    g.setCanvas()

    camera = screen.newCamera()
    camera:setBounds(0, 0, 640, 360)

    bito.sound.loadFromStream('step', 'm...-...', 180)
end

function love.update(dt)
    local dx, dy = 0, 0
    if love.keyboard.isDown('left') then dx = -1 end
    if love.keyboard.isDown('right') then dx = 1 end
    if love.keyboard.isDown('up') then dy = -1 end
    if love.keyboard.isDown('down') then dy = 1 end
    if dx ~= 0 or dy ~= 0 then
        player.x = player.x + dx * 60 * dt
        player.y = player.y + dy * 60 * dt
        if not bito.sound.isPlaying('step') then
            bito.sound.play('step', false, 0.5)
        end
    end
    camera:follow(player.x, player.y, 6, dt)
    bito.sound.update()
end

function love.draw()
    g.clear('dark_blue')

    camera:draw(function()
        g.setColor('dark_green')
        for gx = 0, 640, 32 do
            g.line(gx, 0, gx, 360)
        end
        for gy = 0, 360, 32 do
            g.line(0, gy, 640, gy)
        end
        g.draw(sprite, player.x - 4, player.y - 4, 'black')
    end)

    local bar = screen.safeBox():cutTop(12)
    bar:fill('black')
    bar:draw(function(w, h)
        g.setColor('white')
        g.print('X:' .. math.floor(player.x), 2, 2)
    end, true)

    bito.draw()
end
```

---

## Notes and limitations

- **Indexed color only.** Images are quantized to the 16-color palette when loaded; changing the palette later does not re-quantize them, but it does recolor everything on screen.
- **Display is cleared on resolution change.** `setResolution` (and `screen` recalculations that change the virtual size) reallocate and clear the display; redraw every frame.
- **`graphics.translation` is absolute**, not cumulative. Use `push`/`pop` and read the previous value with `getTranslation` when nesting.
- **`bito.clear`, `bito.setPixel`, `bito.getPixel`** always affect the display, regardless of the current canvas. Use the `Surface` methods or `graphics` functions for canvases.
- **`Surface` methods ignore clipping and translation**; `graphics` functions respect them.
- **Color map** (`mapColor`) is global and is not saved by `push`/`pop`.
- **Transparency**: images use index `255` internally and report `nil` from `getPixel` for transparent pixels.
- **Flood fill** stores spans in `int16` coordinates, so surfaces larger than 32767 pixels on a side are not supported.
- **Fonts** are monospaced 5×7 bitmaps; custom glyph rows use only the low 5 bits.
- **Sound** is rendered eagerly on load; long patterns take time to generate, so load sounds during startup.
- **Input hook** (`input = true`) only wraps callbacks that already exist when `screen.hook` is called.

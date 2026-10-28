local ffi = require('ffi')
local bit = require('bit')
local utf8 = require('utf8')

local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local sqrt, ceil, sin = math.sqrt, math.ceil, math.sin
local ffi_fill, ffi_copy = ffi.fill, ffi.copy
local band, lshift = bit.band, bit.lshift
local unpack = table.unpack or unpack
local random = math.random
local PI2 = math.pi * 2

love.graphics.setDefaultFilter('nearest', 'nearest', 1)

local DEFAULT_PALETTE = {
    {0, 0, 0}, {29, 43, 83}, {126, 37, 83}, {0, 135, 81},
    {171, 82, 54}, {95, 87, 79}, {194, 195, 199}, {255, 241, 232},
    {255, 0, 77}, {255, 163, 0}, {255, 236, 39}, {0, 228, 54},
    {41, 173, 255}, {131, 118, 156}, {255, 119, 168}, {255, 204, 170}
}

local colorNames = {
    black=1, dark_blue=2, purple=3, dark_green=4,
    brown=5, gray=6, light_gray=7, white=8,
    red=9, orange=10, yellow=11, green=12,
    blue=13, lavender=14, pink=15, peach=16
}

local palR, palG, palB = {}, {}, {}
local nearestCache = {}
local palDirty = true

local function nearestIndex(r, g, b)
    local key = r * 65536 + g * 256 + b
    local v = nearestCache[key]
    if v then return v end
    local best, bestD = 0, 1000000000
    for i = 1, 16 do
        local dr, dg, db = r - palR[i], g - palG[i], b - palB[i]
        local d = dr * dr + dg * dg + db * db
        if d < bestD then bestD, best = d, i - 1 end
    end
    nearestCache[key] = best
    return best
end

local function toIndex(c)
    if type(c) == 'string' then return (colorNames[c] or 1) - 1 end
    return (floor(c) - 1) % 16
end

local paletteData = love.image.newImageData(16, 1, 'rgba8')
local paletteImage = love.graphics.newImage(paletteData, {linear = true})
paletteImage:setFilter('nearest', 'nearest')
paletteImage:setWrap('clamp', 'clamp')

local function uploadPalette()
    for i = 1, 16 do
        paletteData:setPixel(i - 1, 0, palR[i] / 255, palG[i] / 255, palB[i] / 255, 1)
    end
    paletteImage:replacePixels(paletteData)
    palDirty = false
end

local function markPaletteDirty()
    palDirty = true
    nearestCache = {}
end

local function setPalette(list)
    for i = 1, 16 do
        local c = list[i] or DEFAULT_PALETTE[i]
        palR[i], palG[i], palB[i] = c[1], c[2], c[3]
    end
    markPaletteDirty()
end

local function setPaletteColor(i, r, g, b)
    i = toIndex(i) + 1
    palR[i], palG[i], palB[i] = r, g, b
    markPaletteDirty()
end

local function getPalette()
    local t = {}
    for i = 1, 16 do t[i] = {palR[i], palG[i], palB[i]} end
    return t
end

setPalette(DEFAULT_PALETTE)

local shader = love.graphics.newShader([=[
    uniform Image palette;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        float idx = floor(Texel(tex, uv).r * 255.0 + 0.5);
        return vec4(Texel(palette, vec2((idx + 0.5) * 0.0625, 0.5)).rgb, 1.0);
    }
]=])
shader:send('palette', paletteImage)

local defaultFont = {
    ['0'] = {0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E},
    ['1'] = {0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E},
    ['2'] = {0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F},
    ['3'] = {0x0E, 0x11, 0x01, 0x06, 0x01, 0x11, 0x0E},
    ['4'] = {0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02},
    ['5'] = {0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E},
    ['6'] = {0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E},
    ['7'] = {0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08},
    ['8'] = {0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E},
    ['9'] = {0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C},
    ['A'] = {0x04, 0x0A, 0x11, 0x11, 0x1F, 0x11, 0x11},
    ['B'] = {0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E},
    ['C'] = {0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E},
    ['D'] = {0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E},
    ['E'] = {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F},
    ['F'] = {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10},
    ['G'] = {0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F},
    ['H'] = {0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11},
    ['I'] = {0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E},
    ['J'] = {0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C},
    ['K'] = {0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11},
    ['L'] = {0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F},
    ['M'] = {0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11},
    ['N'] = {0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11},
    ['O'] = {0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E},
    ['P'] = {0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10},
    ['Q'] = {0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D},
    ['R'] = {0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11},
    ['S'] = {0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E},
    ['T'] = {0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04},
    ['U'] = {0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E},
    ['V'] = {0x11, 0x11, 0x11, 0x11, 0x0A, 0x0A, 0x04},
    ['W'] = {0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11},
    ['X'] = {0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11},
    ['Y'] = {0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04},
    ['Z'] = {0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F},
    ['a'] = {0x00, 0x00, 0x0E, 0x01, 0x0F, 0x11, 0x0F},
    ['b'] = {0x10, 0x10, 0x16, 0x19, 0x11, 0x11, 0x1E},
    ['c'] = {0x00, 0x00, 0x0E, 0x11, 0x10, 0x11, 0x0E},
    ['d'] = {0x01, 0x01, 0x0D, 0x13, 0x11, 0x11, 0x0F},
    ['e'] = {0x00, 0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E},
    ['f'] = {0x06, 0x09, 0x08, 0x1C, 0x08, 0x08, 0x08},
    ['g'] = {0x00, 0x0F, 0x11, 0x11, 0x0F, 0x01, 0x0E},
    ['h'] = {0x10, 0x10, 0x16, 0x19, 0x11, 0x11, 0x11},
    ['i'] = {0x04, 0x00, 0x0C, 0x04, 0x04, 0x04, 0x0E},
    ['j'] = {0x02, 0x00, 0x06, 0x02, 0x02, 0x12, 0x0C},
    ['k'] = {0x10, 0x10, 0x12, 0x14, 0x18, 0x14, 0x12},
    ['l'] = {0x0C, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E},
    ['m'] = {0x00, 0x00, 0x1A, 0x15, 0x15, 0x11, 0x11},
    ['n'] = {0x00, 0x00, 0x16, 0x19, 0x11, 0x11, 0x11},
    ['o'] = {0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E},
    ['p'] = {0x00, 0x00, 0x1E, 0x11, 0x1E, 0x10, 0x10},
    ['q'] = {0x00, 0x0D, 0x13, 0x11, 0x0F, 0x01, 0x01},
    ['r'] = {0x00, 0x00, 0x16, 0x19, 0x10, 0x10, 0x10},
    ['s'] = {0x00, 0x00, 0x0F, 0x10, 0x0E, 0x01, 0x1E},
    ['t'] = {0x08, 0x08, 0x1C, 0x08, 0x08, 0x09, 0x06},
    ['u'] = {0x00, 0x00, 0x11, 0x11, 0x11, 0x13, 0x0D},
    ['v'] = {0x00, 0x00, 0x11, 0x11, 0x11, 0x0A, 0x04},
    ['w'] = {0x00, 0x00, 0x11, 0x11, 0x15, 0x15, 0x0A},
    ['x'] = {0x00, 0x00, 0x11, 0x0A, 0x04, 0x0A, 0x11},
    ['y'] = {0x00, 0x11, 0x11, 0x0F, 0x01, 0x11, 0x0E},
    ['z'] = {0x00, 0x00, 0x1F, 0x02, 0x04, 0x08, 0x1F},
    [' '] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
    ['.'] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04},
    [','] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x04},
    [':'] = {0x00, 0x00, 0x04, 0x00, 0x04, 0x00, 0x00},
    ['!'] = {0x04, 0x04, 0x04, 0x04, 0x04, 0x00, 0x04},
    ['?'] = {0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04},
    ['-'] = {0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00},
    ['_'] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1F},
    ['+'] = {0x00, 0x04, 0x04, 0x1F, 0x04, 0x04, 0x00},
    ['/'] = {0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x00},
    ['\\']= {0x00, 0x10, 0x08, 0x04, 0x02, 0x01, 0x00},
    ['('] = {0x02, 0x04, 0x08, 0x08, 0x08, 0x04, 0x02},
    [')'] = {0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08},
    ['['] = {0x0E, 0x08, 0x08, 0x08, 0x08, 0x08, 0x0E},
    [']'] = {0x0E, 0x02, 0x02, 0x02, 0x02, 0x02, 0x0E},
    ['{'] = {0x06, 0x08, 0x08, 0x10, 0x08, 0x08, 0x06},
    ['}'] = {0x0C, 0x02, 0x02, 0x01, 0x02, 0x02, 0x0C},
    ['<'] = {0x02, 0x04, 0x08, 0x10, 0x08, 0x04, 0x02},
    ['>'] = {0x08, 0x04, 0x02, 0x01, 0x02, 0x04, 0x08},
    ['='] = {0x00, 0x00, 0x1F, 0x00, 0x1F, 0x00, 0x00},
    ['@'] = {0x0E, 0x11, 0x17, 0x15, 0x17, 0x10, 0x0E},
    ['#'] = {0x0A, 0x0A, 0x1F, 0x0A, 0x1F, 0x0A, 0x0A},
    ['$'] = {0x04, 0x0F, 0x14, 0x0E, 0x05, 0x1E, 0x04},
    ['%'] = {0x18, 0x19, 0x02, 0x04, 0x08, 0x13, 0x03},
    ['^'] = {0x04, 0x0A, 0x11, 0x00, 0x00, 0x00, 0x00},
    ['&'] = {0x0C, 0x12, 0x14, 0x08, 0x15, 0x12, 0x0D},
    ['*'] = {0x00, 0x04, 0x15, 0x0E, 0x15, 0x04, 0x00},
    ['"'] = {0x0A, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00},
    ['\'']= {0x04, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00},
    ['~'] = {0x00, 0x00, 0x0A, 0x15, 0x00, 0x00, 0x00},
    ['`'] = {0x08, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00},
    ['|'] = {0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04},
    ['°'] = {0x0E, 0x0A, 0x0E, 0x00, 0x00, 0x00, 0x00},
    ['↑'] = {0x04, 0x0E, 0x1F, 0x04, 0x04, 0x04, 0x04},
    ['↓'] = {0x04, 0x04, 0x04, 0x04, 0x1F, 0x0E, 0x04},
    ['←'] = {0x00, 0x04, 0x08, 0x1F, 0x08, 0x04, 0x00},
    ['→'] = {0x00, 0x04, 0x02, 0x1F, 0x02, 0x04, 0x00},
    ['А'] = {0x04, 0x0A, 0x11, 0x11, 0x1F, 0x11, 0x11},
    ['Б'] = {0x1F, 0x10, 0x10, 0x1E, 0x11, 0x11, 0x1E},
    ['В'] = {0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E},
    ['Г'] = {0x1F, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10},
    ['Д'] = {0x06, 0x0A, 0x0A, 0x0A, 0x12, 0x1F, 0x11},
    ['Е'] = {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F},
    ['Ж'] = {0x15, 0x15, 0x15, 0x0E, 0x15, 0x15, 0x15},
    ['З'] = {0x0E, 0x11, 0x01, 0x06, 0x01, 0x11, 0x0E},
    ['И'] = {0x11, 0x11, 0x13, 0x15, 0x19, 0x11, 0x11},
    ['Й'] = {0x15, 0x11, 0x13, 0x15, 0x19, 0x11, 0x11},
    ['К'] = {0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11},
    ['Л'] = {0x07, 0x09, 0x09, 0x09, 0x09, 0x11, 0x11},
    ['М'] = {0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11},
    ['Н'] = {0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11},
    ['О'] = {0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E},
    ['П'] = {0x1F, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11},
    ['Р'] = {0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10},
    ['С'] = {0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E},
    ['Т'] = {0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04},
    ['У'] = {0x11, 0x11, 0x11, 0x0F, 0x01, 0x11, 0x0E},
    ['Ф'] = {0x0E, 0x15, 0x15, 0x15, 0x0E, 0x04, 0x04},
    ['Х'] = {0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11},
    ['Ц'] = {0x11, 0x11, 0x11, 0x11, 0x11, 0x1F, 0x01},
    ['Ч'] = {0x11, 0x11, 0x11, 0x0F, 0x01, 0x01, 0x01},
    ['Ш'] = {0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x1F},
    ['Щ'] = {0x11, 0x11, 0x11, 0x15, 0x15, 0x1F, 0x01},
    ['Ъ'] = {0x18, 0x08, 0x08, 0x0E, 0x09, 0x09, 0x0E},
    ['Ы'] = {0x11, 0x11, 0x11, 0x1D, 0x13, 0x13, 0x1D},
    ['Ь'] = {0x10, 0x10, 0x10, 0x1E, 0x11, 0x11, 0x1E},
    ['Э'] = {0x0E, 0x11, 0x01, 0x07, 0x01, 0x11, 0x0E},
    ['Ю'] = {0x17, 0x19, 0x19, 0x1D, 0x19, 0x19, 0x17},
    ['Я'] = {0x0F, 0x11, 0x11, 0x0F, 0x05, 0x09, 0x11},
    ['а'] = {0x00, 0x00, 0x0E, 0x01, 0x0F, 0x11, 0x0F},
    ['б'] = {0x00, 0x0F, 0x10, 0x1E, 0x11, 0x11, 0x0E},
    ['в'] = {0x00, 0x1E, 0x11, 0x1E, 0x11, 0x11, 0x1E},
    ['г'] = {0x00, 0x1E, 0x10, 0x10, 0x10, 0x10, 0x10},
    ['д'] = {0x00, 0x06, 0x0A, 0x0A, 0x12, 0x1F, 0x11},
    ['е'] = {0x00, 0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E},
    ['ж'] = {0x00, 0x15, 0x15, 0x0E, 0x15, 0x15, 0x15},
    ['з'] = {0x00, 0x0E, 0x11, 0x02, 0x04, 0x11, 0x0E},
    ['и'] = {0x00, 0x11, 0x13, 0x15, 0x19, 0x11, 0x11},
    ['й'] = {0x0A, 0x11, 0x13, 0x15, 0x19, 0x11, 0x11},
    ['к'] = {0x00, 0x11, 0x12, 0x14, 0x18, 0x14, 0x12},
    ['л'] = {0x00, 0x07, 0x09, 0x09, 0x09, 0x11, 0x11},
    ['м'] = {0x00, 0x11, 0x1B, 0x15, 0x11, 0x11, 0x11},
    ['н'] = {0x00, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11},
    ['о'] = {0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E},
    ['п'] = {0x00, 0x1F, 0x11, 0x11, 0x11, 0x11, 0x11},
    ['р'] = {0x00, 0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10},
    ['с'] = {0x00, 0x00, 0x0E, 0x10, 0x10, 0x11, 0x0E},
    ['т'] = {0x00, 0x1F, 0x04, 0x04, 0x04, 0x04, 0x04},
    ['у'] = {0x00, 0x11, 0x11, 0x0F, 0x01, 0x11, 0x0E},
    ['ф'] = {0x00, 0x04, 0x0E, 0x15, 0x15, 0x0E, 0x04},
    ['х'] = {0x00, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11},
    ['ц'] = {0x00, 0x11, 0x11, 0x11, 0x11, 0x1F, 0x01},
    ['ч'] = {0x00, 0x11, 0x11, 0x0F, 0x01, 0x01, 0x01},
    ['ш'] = {0x00, 0x11, 0x11, 0x15, 0x15, 0x15, 0x1F},
    ['щ'] = {0x00, 0x11, 0x11, 0x15, 0x15, 0x1F, 0x01},
    ['ъ'] = {0x00, 0x18, 0x08, 0x0E, 0x09, 0x09, 0x0E},
    ['ы'] = {0x00, 0x11, 0x11, 0x1D, 0x13, 0x13, 0x1D},
    ['ь'] = {0x00, 0x10, 0x10, 0x1E, 0x11, 0x11, 0x1E},
    ['э'] = {0x00, 0x0E, 0x11, 0x03, 0x01, 0x11, 0x0E},
    ['ю'] = {0x00, 0x12, 0x15, 0x15, 0x1D, 0x15, 0x12},
    ['я'] = {0x00, 0x0F, 0x11, 0x0F, 0x05, 0x09, 0x11},
}

local Font = {}
Font.__index = Font

function Font:getGlyph(cp)
    local g = self.glyphs[cp]
    if g ~= nil then return g end
    local rows = self.data[utf8.char(cp)] or self.data['?']
    if not rows then
        self.glyphs[cp] = false
        return false
    end
    local runs, n = {}, 0
    for row = 1, 7 do
        local bits = rows[row]
        local c = 0
        while c < 5 do
            if band(bits, lshift(1, 4 - c)) ~= 0 then
                local start = c
                while c < 5 and band(bits, lshift(1, 4 - c)) ~= 0 do c = c + 1 end
                runs[n + 1], runs[n + 2], runs[n + 3] = start, row - 1, c - start
                n = n + 3
            else
                c = c + 1
            end
        end
    end
    g = {runs = runs, n = n}
    self.glyphs[cp] = g
    return g
end

function Font:getWidth(text)
    local maxChars, cur = 0, 0
    for _, cp in utf8.codes(tostring(text or "")) do
        if cp == 10 then
            cur = 0
        else
            cur = cur + 1
            if cur > maxChars then maxChars = cur end
        end
    end
    if maxChars == 0 then return 0 end
    return (maxChars - 1) * (self.charWidth + self.spacing) + self.charWidth
end

function Font:getHeight(text)
    if not text or text == "" then return self.charHeight end
    local lines = 1
    for _, cp in utf8.codes(tostring(text)) do
        if cp == 10 then lines = lines + 1 end
    end
    return (lines - 1) * (self.charHeight + self.spacing) + self.charHeight
end

local Surface = {}
Surface.__index = Surface

local display
local setResolution
local pix, W, H
local tx, ty = 0, 0
local col = 7
local font
local target
local clipOn = false
local kx1, ky1, kx2, ky2 = 0, 0, -1, -1
local minX, minY, maxX, maxY = 0, 0, -1, -1
local stack, sp = {}, 0
local graphics = {}

local function applyClip()
    if clipOn then
        minX = kx1 > 0 and kx1 or 0
        minY = ky1 > 0 and ky1 or 0
        maxX = kx2 < (W or 0) - 1 and kx2 or (W or 0) - 1
        maxY = ky2 < (H or 0) - 1 and ky2 or (H or 0) - 1
    else
        minX, minY, maxX, maxY = 0, 0, (W or 0) - 1, (H or 0) - 1
    end
end

local function initSurfaceState(s, f)
    s.tx, s.ty, s.col, s.font = 0, 0, 7, f
    s.clipOn = false
    s.kx1, s.ky1, s.kx2, s.ky2 = 0, 0, -1, -1
    return s
end

function Surface:clear(c)
    ffi_fill(self.pix, self.width * self.height, c and toIndex(c) or 0)
end

function Surface:setPixel(x, y, c)
    if x >= 0 and x < self.width and y >= 0 and y < self.height then
        self.pix[y * self.width + x] = toIndex(c)
    end
end

function Surface:getPixel(x, y)
    if x >= 0 and x < self.width and y >= 0 and y < self.height then
        local v = self.pix[y * self.width + x]
        if v < 16 then return v + 1 end
    end
    return nil
end

function Surface:getResolution() return self.width, self.height end
function Surface:getDimensions() return self.width, self.height end
function Surface:getWidth()      return self.width end
function Surface:getHeight()     return self.height end

function Surface:resize(w, h)
    w, h = max(1, floor(w)), max(1, floor(h))
    if self == display then return setResolution(w, h) end
    local old, ow, oh = self.pix, self.width, self.height
    local new = ffi.new('uint8_t[?]', w * h)
    if old then
        local cw, ch = min(ow, w), min(oh, h)
        for row = 0, ch - 1 do
            ffi_copy(new + row * w, old + row * ow, cw)
        end
    end
    self.pix, self.width, self.height = new, w, h
    if self == target then
        pix, W, H = new, w, h
        applyClip()
    end
end

function Surface:release()
    self.pix = nil
    if self.data then self.data:release() self.data = nil end
end

display = setmetatable({tx = 0, ty = 0, col = 7, clipOn = false, kx1 = 0, ky1 = 0, kx2 = -1, ky2 = -1}, Surface)

local function bind(s)
    if target then
        target.tx, target.ty, target.col, target.font = tx, ty, col, font
        target.clipOn, target.kx1, target.ky1, target.kx2, target.ky2 = clipOn, kx1, ky1, kx2, ky2
    end
    target = s
    pix, W, H = s.pix, s.width, s.height
    tx, ty, col, font = s.tx, s.ty, s.col, s.font
    clipOn, kx1, ky1, kx2, ky2 = s.clipOn, s.kx1, s.ky1, s.kx2, s.ky2
    applyClip()
end

local function hline(x1, x2, y, c)
    if y < minY or y > maxY then return end
    if x1 > x2 then x1, x2 = x2, x1 end
    if x2 < minX or x1 > maxX then return end
    if x1 < minX then x1 = minX end
    if x2 > maxX then x2 = maxX end
    local n = x2 - x1 + 1
    local i = y * W + x1
    if n <= 16 then
        for k = 0, n - 1 do pix[i + k] = c end
    else
        ffi_fill(pix + i, n, c)
    end
end

local function vline(x, y1, y2, c)
    if x < minX or x > maxX then return end
    if y1 > y2 then y1, y2 = y2, y1 end
    if y2 < minY or y1 > maxY then return end
    if y1 < minY then y1 = minY end
    if y2 > maxY then y2 = maxY end
    local i = y1 * W + x
    for _ = y1, y2 do
        pix[i] = c
        i = i + W
    end
end

local function fillRect(x, y, w, h, c)
    local x2, y2 = x + w - 1, y + h - 1
    if x < minX then x = minX end
    if y < minY then y = minY end
    if x2 > maxX then x2 = maxX end
    if y2 > maxY then y2 = maxY end
    if x > x2 or y > y2 then return end
    local n = x2 - x + 1
    local i = y * W + x
    if n <= 16 then
        for _ = y, y2 do
            for k = 0, n - 1 do pix[i + k] = c end
            i = i + W
        end
    else
        for _ = y, y2 do
            ffi_fill(pix + i, n, c)
            i = i + W
        end
    end
end

local function putPixel(px, py, c)
    if px >= minX and px <= maxX and py >= minY and py <= maxY then
        pix[py * W + px] = c
    end
end

function graphics.push()
    local i = sp
    stack[i + 1], stack[i + 2], stack[i + 3], stack[i + 4] = tx, ty, col, font
    stack[i + 5], stack[i + 6], stack[i + 7], stack[i + 8], stack[i + 9] = clipOn, kx1, ky1, kx2, ky2
    sp = i + 9
end

function graphics.pop()
    if sp == 0 then return end
    local i = sp
    tx, ty, col, font = stack[i - 8], stack[i - 7], stack[i - 6], stack[i - 5]
    clipOn, kx1, ky1, kx2, ky2 = stack[i - 4], stack[i - 3], stack[i - 2], stack[i - 1], stack[i]
    sp = i - 9
    applyClip()
end

function graphics.setColor(c, g, b)
    if g then
        col = nearestIndex(floor(c), floor(g), floor(b))
    else
        col = toIndex(c)
    end
end

function graphics.getColor()
    return col + 1
end

function graphics.translation(x, y)
    tx, ty = x, y
end

function graphics.getTranslation()
    return tx, ty
end

function graphics.setFont(f)
    font = f
end

function graphics.getFont()
    return font
end

function graphics.getWidth()      return W end
function graphics.getHeight()     return H end
function graphics.getDimensions() return W, H end

function graphics.setClip(x, y, w, h)
    if x == nil then
        clipOn = false
        applyClip()
        return
    end
    x, y = floor(x + tx), floor(y + ty)
    clipOn = true
    kx1, ky1, kx2, ky2 = x, y, x + floor(w) - 1, y + floor(h) - 1
    applyClip()
end

function graphics.addClip(x, y, w, h)
    x, y = floor(x + tx), floor(y + ty)
    local x2, y2 = x + floor(w) - 1, y + floor(h) - 1
    if clipOn then
        if x > kx1 then kx1 = x end
        if y > ky1 then ky1 = y end
        if x2 < kx2 then kx2 = x2 end
        if y2 < ky2 then ky2 = y2 end
    else
        kx1, ky1, kx2, ky2 = x, y, x2, y2
        clipOn = true
    end
    applyClip()
end

function graphics.clearClip()
    clipOn = false
    applyClip()
end

function graphics.getClip()
    if not clipOn then return nil end
    return kx1 - tx, ky1 - ty, kx2 - kx1 + 1, ky2 - ky1 + 1
end

function graphics.clear(c)
    local idx = c and toIndex(c) or 0
    if clipOn then
        fillRect(minX, minY, maxX - minX + 1, maxY - minY + 1, idx)
    else
        ffi_fill(pix, W * H, idx)
    end
end

function graphics.pixel(x, y)
    putPixel(floor(x + tx), floor(y + ty), col)
end

function graphics.line(x1, y1, x2, y2)
    x1, y1 = floor(x1 + tx), floor(y1 + ty)
    x2, y2 = floor(x2 + tx), floor(y2 + ty)
    if y1 == y2 then return hline(x1, x2, y1, col) end
    if x1 == x2 then return vline(x1, y1, y2, col) end
    if (x1 < minX and x2 < minX) or (x1 > maxX and x2 > maxX)
        or (y1 < minY and y2 < minY) or (y1 > maxY and y2 > maxY) then return end
    local dx, dy = abs(x2 - x1), abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy
    local c, w, p = col, W, pix
    local bx1, by1, bx2, by2 = minX, minY, maxX, maxY
    while true do
        if x1 >= bx1 and x1 <= bx2 and y1 >= by1 and y1 <= by2 then p[y1 * w + x1] = c end
        if x1 == x2 and y1 == y2 then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy x1 = x1 + sx end
        if e2 < dx then err = err + dx y1 = y1 + sy end
    end
end

function graphics.rectangle(mode, x, y, w, h)
    x, y, w, h = floor(x + tx), floor(y + ty), floor(w), floor(h)
    if w <= 0 or h <= 0 or x > maxX or y > maxY or x + w - 1 < minX or y + h - 1 < minY then return end
    if mode == 'fill' then
        fillRect(x, y, w, h, col)
    else
        fillRect(x, y, w, 1, col)
        if h > 1 then fillRect(x, y + h - 1, w, 1, col) end
        if h > 2 then
            fillRect(x, y + 1, 1, h - 2, col)
            if w > 1 then fillRect(x + w - 1, y + 1, 1, h - 2, col) end
        end
    end
end

function graphics.circle(mode, cx, cy, r)
    cx, cy, r = floor(cx + tx), floor(cy + ty), floor(r)
    if r < 0 or cx + r < minX or cx - r > maxX or cy + r < minY or cy - r > maxY then return end
    local c = col
    local filled = mode == 'fill'
    local x, y, d = 0, r, 3 - 2 * r
    while y >= x do
        if filled then
            hline(cx - y, cx + y, cy + x, c)
            hline(cx - y, cx + y, cy - x, c)
            hline(cx - x, cx + x, cy + y, c)
            hline(cx - x, cx + x, cy - y, c)
        else
            putPixel(cx + x, cy + y, c)
            putPixel(cx - x, cy + y, c)
            putPixel(cx + x, cy - y, c)
            putPixel(cx - x, cy - y, c)
            putPixel(cx + y, cy + x, c)
            putPixel(cx - y, cy + x, c)
            putPixel(cx + y, cy - x, c)
            putPixel(cx - y, cy - x, c)
        end
        x = x + 1
        if d > 0 then
            y = y - 1
            d = d + 4 * (x - y) + 10
        else
            d = d + 4 * x + 6
        end
    end
end

local fsCap = 65536
local fsx = ffi.new('int16_t[?]', fsCap)
local fsy = ffi.new('int16_t[?]', fsCap)

local function growFillStack()
    local newCap = fsCap * 2
    local nx = ffi.new('int16_t[?]', newCap)
    local ny = ffi.new('int16_t[?]', newCap)
    ffi_copy(nx, fsx, fsCap * 2)
    ffi_copy(ny, fsy, fsCap * 2)
    fsx, fsy, fsCap = nx, ny, newCap
end

function graphics.fill(x, y)
    x, y = floor(x + tx), floor(y + ty)
    if x < minX or x > maxX or y < minY or y > maxY then return end
    local from = pix[y * W + x]
    local c = col
    if from == c then return end
    local w, p = W, pix
    local bx1, by1, bx2, by2 = minX, minY, maxX, maxY
    local n = 1
    fsx[0], fsy[0] = x, y
    while n > 0 do
        n = n - 1
        local cx, cy = fsx[n], fsy[n]
        local row = cy * w
        if p[row + cx] == from then
            local l = cx
            while l > bx1 and p[row + l - 1] == from do l = l - 1 end
            local r = cx
            while r < bx2 and p[row + r + 1] == from do r = r + 1 end
            ffi_fill(p + (row + l), r - l + 1, c)
            for d = -1, 1, 2 do
                local ny = cy + d
                if ny >= by1 and ny <= by2 then
                    local nrow = ny * w
                    local inSpan = false
                    for px = l, r do
                        if p[nrow + px] == from then
                            if not inSpan then
                                if n >= fsCap then growFillStack() end
                                fsx[n], fsy[n] = px, ny
                                n = n + 1
                                inSpan = true
                            end
                        else
                            inSpan = false
                        end
                    end
                end
            end
        end
    end
end

function graphics.newFont(fontData, fontSize)
    if type(fontData) == 'number' then
        fontSize, fontData = fontData, defaultFont
    else
        fontData = fontData or defaultFont
    end
    fontSize = floor(fontSize or 1)
    if fontSize < 1 then fontSize = 1 end
    return setmetatable({
        data       = fontData,
        size       = fontSize,
        glyphs     = {},
        charWidth  = 5 * fontSize,
        charHeight = 7 * fontSize,
        spacing    = fontSize,
    }, Font)
end

local font1 = graphics.newFont(1)

function graphics.print(text, x, y)
    if text == nil then return end
    text = tostring(text)
    if text == "" then return end
    local f = font
    local s = f.size
    local cw, ch = f.charWidth, f.charHeight
    local adv, lh = cw + f.spacing, ch + f.spacing
    local glyphs = f.glyphs
    local c = col
    local x0 = floor(x + tx)
    local cx, cy = x0, floor(y + ty)
    local bx1, by1, bx2, by2 = minX, minY, maxX, maxY
    if s == 1 then
        for _, cp in utf8.codes(text) do
            if cp == 10 then
                cx = x0
                cy = cy + lh
            else
                if cx <= bx2 and cx + cw - 1 >= bx1 and cy <= by2 and cy + ch - 1 >= by1 then
                    local g = glyphs[cp]
                    if g == nil then g = f:getGlyph(cp) end
                    if g then
                        local runs = g.runs
                        for i = 1, g.n, 3 do
                            local rx, ry, rw = cx + runs[i], cy + runs[i + 1], runs[i + 2]
                            if ry >= by1 and ry <= by2 then
                                local lx = rx < bx1 and bx1 or rx
                                local r_x = rx + rw - 1
                                if r_x > bx2 then r_x = bx2 end
                                if lx <= r_x then
                                    local idx = ry * W + lx
                                    for k = 0, r_x - lx do pix[idx + k] = c end
                                end
                            end
                        end
                    end
                end
                cx = cx + adv
            end
        end
    else
        for _, cp in utf8.codes(text) do
            if cp == 10 then
                cx = x0
                cy = cy + lh
            else
                if cx <= bx2 and cx + cw - 1 >= bx1 and cy <= by2 and cy + ch - 1 >= by1 then
                    local g = glyphs[cp]
                    if g == nil then g = f:getGlyph(cp) end
                    if g then
                        local runs = g.runs
                        for i = 1, g.n, 3 do
                            fillRect(cx + runs[i] * s, cy + runs[i + 1] * s, runs[i + 2] * s, s, c)
                        end
                    end
                end
                cx = cx + adv
            end
        end
    end
end

function graphics.newImage(src)
    local isData = type(src) == 'userdata' and src.typeOf and src:typeOf('ImageData')
    local data = isData and src or love.image.newImageData(src)
    local w, h = data:getDimensions()
    local out = ffi.new('uint8_t[?]', w * h)
    if data:getFormat() == 'rgba8' then
        local p = ffi.cast('uint8_t*', data:getPointer())
        for i = 0, w * h - 1 do
            local o = i * 4
            if p[o + 3] < 128 then
                out[i] = 255
            else
                out[i] = nearestIndex(p[o], p[o + 1], p[o + 2])
            end
        end
    else
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local r, g, b, a = data:getPixel(x, y)
                out[y * w + x] = (a < 0.5) and 255 or nearestIndex(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
            end
        end
    end
    if not isData then data:release() end
    return initSurfaceState(setmetatable({pix = out, width = w, height = h, key = 255}, Surface), font1)
end

function graphics.newCanvas(width, height)
    width, height = max(1, floor(width)), max(1, floor(height))
    return initSurfaceState(setmetatable({
        pix    = ffi.new('uint8_t[?]', width * height),
        width  = width,
        height = height,
    }, Surface), font1)
end

function graphics.setCanvas(canvas)
    bind(canvas or display)
end

local cmap = nil

function graphics.mapColor(from, to)
    if not cmap then
        cmap = ffi.new('uint8_t[256]')
        for i = 0, 255 do cmap[i] = i end
    end
    cmap[toIndex(from)] = toIndex(to)
end

function graphics.resetColorMap()
    cmap = nil
end

local function blit(src, x, y, qx, qy, qw, qh, key, flipX, flipY)
    local sp_, sw, sh = src.pix, src.width, src.height
    if not sp_ then return end
    if qx < 0 then
        qw = qw + qx
        if not flipX then x = x - qx end
        qx = 0
    end
    if qx + qw > sw then
        local b = qx + qw - sw
        qw = qw - b
        if flipX then x = x + b end
    end
    if qy < 0 then
        qh = qh + qy
        if not flipY then y = y - qy end
        qy = 0
    end
    if qy + qh > sh then
        local b = qy + qh - sh
        qh = qh - b
        if flipY then y = y + b end
    end
    if qw <= 0 or qh <= 0 then return end
    local ol = x < minX and (minX - x) or 0
    local orr = (x + qw - 1 > maxX) and (x + qw - 1 - maxX) or 0
    local ot = y < minY and (minY - y) or 0
    local ob = (y + qh - 1 > maxY) and (y + qh - 1 - maxY) or 0
    local cw, ch = qw - ol - orr, qh - ot - ob
    if cw <= 0 or ch <= 0 then return end
    local dx, dy = x + ol, y + ot
    local sx = flipX and (qx + qw - 1 - ol) or (qx + ol)
    local sxStep = flipX and -1 or 1
    local sy = flipY and (qy + qh - 1 - ot) or (qy + ot)
    local syStep = flipY and -1 or 1
    local dst, dw = pix, W
    local map = cmap
    if not key and not flipX and not map then
        for row = 0, ch - 1 do
            ffi_copy(dst + ((dy + row) * dw + dx), sp_ + ((sy + row * syStep) * sw + sx), cw)
        end
        return
    end
    for row = 0, ch - 1 do
        local si = (sy + row * syStep) * sw + sx
        local di = (dy + row) * dw + dx
        for k = 0, cw - 1 do
            local v = sp_[si + k * sxStep]
            if v ~= key then
                if map then v = map[v] end
                dst[di + k] = v
            end
        end
    end
end

local function resolveKey(obj, key)
    if key == false then return nil end
    if key ~= nil then return toIndex(key) end
    return obj.key
end

function graphics.draw(obj, x, y, key, flipX, flipY)
    if obj == target then return end
    blit(obj, floor((x or 0) + tx), floor((y or 0) + ty), 0, 0, obj.width, obj.height, resolveKey(obj, key), flipX, flipY)
end

function graphics.drawRegion(obj, x, y, qx, qy, qw, qh, key, flipX, flipY)
    if obj == target then return end
    blit(obj, floor(x + tx), floor(y + ty), qx, qy, qw, qh, resolveKey(obj, key), flipX, flipY)
end

local ox, oy, scale = 0, 0, 1
local integerScale = false

local function getDpi()
    return love.graphics.getDPIScale and love.graphics.getDPIScale() or 1
end

local function layout(w, h)
    if not w then w, h = love.graphics.getDimensions() end
    local dpi = getDpi()
    local s = min(w / display.width, h / display.height)
    if integerScale then
        local phys = floor(s * dpi + 1e-6)
        if phys >= 1 then s = phys / dpi end
    end
    scale = s
    ox = floor((w - display.width * s) * 0.5 * dpi) / dpi
    oy = floor((h - display.height * s) * 0.5 * dpi) / dpi
end

local r8ok = true
if love.graphics.getImageFormats then
    local f = love.graphics.getImageFormats()
    if f and f['r8'] == false then r8ok = false end
end

local function createBuffers(width, height)
    if r8ok then
        local ok, data, image = pcall(function()
            local d = love.image.newImageData(width, height, 'r8')
            return d, love.graphics.newImage(d, {linear = true})
        end)
        if ok then
            return data, image, ffi.cast('uint8_t*', data:getPointer()), nil
        end
        r8ok = false
    end
    local data = love.image.newImageData(width, height, 'rgba8')
    local image = love.graphics.newImage(data, {linear = true})
    local rgba = ffi.cast('uint32_t*', data:getPointer())
    local buf = ffi.new('uint8_t[?]', width * height)
    return data, image, buf, rgba
end

function setResolution(width, height)
    width, height = max(1, floor(width)), max(1, floor(height))
    if display.image then display.image:release() end
    if display.data then display.data:release() end
    display.width, display.height = width, height
    local data, image, p, rgba = createBuffers(width, height)
    display.data, display.image, display.pix, display.rgba = data, image, p, rgba
    ffi_fill(display.pix, width * height, 0)
    if target == display then
        pix, W, H = display.pix, width, height
        applyClip()
    end
    layout()
end

local function draw()
    if palDirty then uploadPalette() end
    if display.rgba then
        local n = display.width * display.height
        local src, dst = display.pix, display.rgba
        for i = 0, n - 1 do dst[i] = src[i] end
    end
    display.image:replacePixels(display.data)
    local pr, pg, pb, pa = love.graphics.getColor()
    local prevShader = love.graphics.getShader()
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(display.image, ox, oy, 0, scale, scale)
    love.graphics.setShader(prevShader)
    love.graphics.setColor(pr, pg, pb, pa)
end

local function screenToPixel(x, y)
    return floor((x - ox) / scale), floor((y - oy) / scale)
end

display.font = font1
setResolution(400, 300)
bind(display)

local state = {
    mode                 = 'expand',
    orientationCfg       = 'auto',
    orientation          = 'landscape',
    orientationThreshold = 1.05,
    baseW                = 320,
    baseH                = 180,
    portraitW            = nil,
    portraitH            = nil,
    maxAspect            = nil,
    minAspect            = nil,
    vw                   = 320,
    vh                   = 180,
    curBaseW             = 320,
    curBaseH             = 180,
    winW                 = 320,
    winH                 = 180,
    scale                = 1,
    ox                   = 0,
    oy                   = 0,
    integerScale         = false,
    safe                 = { top = 0, right = 0, bottom = 0, left = 0 },
    os                   = { top = 0, right = 0, bottom = 0, left = 0 },
    useOsSafe            = true,
    insetsKey            = '',
    compactDp            = 600,
    ready                = false,
    hooked               = false,
    onResize             = nil,
    onOrientation        = nil,
}

local Box = {}
Box.__index = Box

local function newBox(x, y, w, h)
    return setmetatable({
        x = floor(x),
        y = floor(y),
        w = max(0, floor(w)),
        h = max(0, floor(h)),
    }, Box)
end

local biteen = {
    _bito = nil,
    box = newBox,
}

local function resolveSize(val, total)
    if val > 0 and val < 1 then
        return floor(total * val)
    end
    return floor(val)
end

function Box:clone()
    return newBox(self.x, self.y, self.w, self.h)
end

function Box:unpack()
    return self.x, self.y, self.w, self.h
end

function Box:center()
    return self.x + floor(self.w * 0.5), self.y + floor(self.h * 0.5)
end

function Box:right()  return self.x + self.w end
function Box:bottom() return self.y + self.h end

function Box:contains(px, py)
    return px >= self.x and px < self.x + self.w and py >= self.y and py < self.y + self.h
end

function Box:pad(top, right, bottom, left)
    top    = top or 0
    right  = right or top
    bottom = bottom or top
    left   = left or right
    local pt = resolveSize(top, self.h)
    local pb = resolveSize(bottom, self.h)
    local pl = resolveSize(left, self.w)
    local pr = resolveSize(right, self.w)
    return newBox(self.x + pl, self.y + pt, self.w - pl - pr, self.h - pt - pb)
end

function Box:cutLeft(amount, gap)
    local w = min(self.w, resolveSize(amount, self.w))
    local g = gap or 0
    local res = newBox(self.x, self.y, w, self.h)
    self.x = self.x + w + g
    self.w = max(0, self.w - w - g)
    return res
end

function Box:cutRight(amount, gap)
    local w = min(self.w, resolveSize(amount, self.w))
    local g = gap or 0
    local res = newBox(self.x + self.w - w, self.y, w, self.h)
    self.w = max(0, self.w - w - g)
    return res
end

function Box:cutTop(amount, gap)
    local h = min(self.h, resolveSize(amount, self.h))
    local g = gap or 0
    local res = newBox(self.x, self.y, self.w, h)
    self.y = self.y + h + g
    self.h = max(0, self.h - h - g)
    return res
end

function Box:cutBottom(amount, gap)
    local h = min(self.h, resolveSize(amount, self.h))
    local g = gap or 0
    local res = newBox(self.x, self.y + self.h - h, self.w, h)
    self.h = max(0, self.h - h - g)
    return res
end

function Box:cut(side, amount, gap)
    if side == 'left'   then return self:cutLeft(amount, gap) end
    if side == 'right'  then return self:cutRight(amount, gap) end
    if side == 'top'    then return self:cutTop(amount, gap) end
    if side == 'bottom' then return self:cutBottom(amount, gap) end
    return self:clone()
end

function Box:cutAuto(amountL, amountP, sideLandscape, sidePortrait, gap)
    if type(amountP) == 'string' then
        gap = sidePortrait
        sidePortrait = sideLandscape
        sideLandscape = amountP
        amountP = amountL
    end
    sideLandscape = sideLandscape or 'right'
    sidePortrait  = sidePortrait  or 'bottom'
    if state.orientation == 'landscape' then
        return self:cut(sideLandscape, amountL, gap)
    else
        return self:cut(sidePortrait, amountP or amountL, gap)
    end
end

function Box:fit(aspectW, aspectH, align)
    aspectW = aspectW or 1
    aspectH = aspectH or 1
    local s = min(self.w / aspectW, self.h / aspectH)
    local fw = floor(aspectW * s)
    local fh = floor(aspectH * s)
    local x, y = self:anchor(align or 'cc', fw, fh)
    return newBox(x, y, fw, fh)
end

function Box:place(w, h, align, ox, oy)
    local x, y = self:anchor(align or 'tl', w, h, ox, oy)
    return newBox(x, y, w, h)
end

function Box:splitH(countOrWeights, gap)
    gap = gap or 0
    local cells = {}
    if type(countOrWeights) == 'number' then
        local n = max(1, countOrWeights)
        local totalGap = gap * (n - 1)
        local cw = floor((self.w - totalGap) / n)
        for i = 1, n do
            local cx = self.x + (i - 1) * (cw + gap)
            local w = (i == n) and (self.x + self.w - cx) or cw
            cells[i] = newBox(cx, self.y, w, self.h)
        end
    elseif type(countOrWeights) == 'table' then
        local n = #countOrWeights
        local sum = 0
        for i = 1, n do sum = sum + countOrWeights[i] end
        local avail = self.w - gap * (n - 1)
        local cx = self.x
        for i = 1, n do
            local w = (i == n) and (self.x + self.w - cx) or floor(avail * (countOrWeights[i] / sum))
            cells[i] = newBox(cx, self.y, w, self.h)
            cx = cx + w + gap
        end
    end
    return cells
end

function Box:splitV(countOrWeights, gap)
    gap = gap or 0
    local cells = {}
    if type(countOrWeights) == 'number' then
        local n = max(1, countOrWeights)
        local totalGap = gap * (n - 1)
        local ch = floor((self.h - totalGap) / n)
        for i = 1, n do
            local cy = self.y + (i - 1) * (ch + gap)
            local h = (i == n) and (self.y + self.h - cy) or ch
            cells[i] = newBox(self.x, cy, self.w, h)
        end
    elseif type(countOrWeights) == 'table' then
        local n = #countOrWeights
        local sum = 0
        for i = 1, n do sum = sum + countOrWeights[i] end
        local avail = self.h - gap * (n - 1)
        local cy = self.y
        for i = 1, n do
            local h = (i == n) and (self.y + self.h - cy) or floor(avail * (countOrWeights[i] / sum))
            cells[i] = newBox(self.x, cy, self.w, h)
            cy = cy + h + gap
        end
    end
    return cells
end

local function parseSpec(spec, total, gap)
    local n = #spec
    local sizes, weights = {}, {}
    local fixedSum, weightSum = 0, 0
    for i = 1, n do
        local item = spec[i]
        if type(item) == 'number' then
            sizes[i] = resolveSize(item, total)
            fixedSum = fixedSum + sizes[i]
        elseif type(item) == 'string' then
            local num = item:match('^%s*([%d%.]*)%s*%*%s*$')
            if not num then
                error("biteen: invalid layout item '" .. item .. "' (expected number, '*' or '2*')", 3)
            end
            weights[i] = (num ~= '') and (tonumber(num) or 1) or 1
            weightSum = weightSum + weights[i]
        else
            error('biteen: layout item must be a number or string', 3)
        end
    end
    local flex = max(0, total - gap * (n - 1) - fixedSum)
    local lastFlex
    for i = n, 1, -1 do
        if weights[i] then lastFlex = i break end
    end
    local used = 0
    for i = 1, n do
        if weights[i] then
            if i == lastFlex then
                sizes[i] = max(0, flex - used)
            else
                sizes[i] = floor(flex * weights[i] / weightSum)
                used = used + sizes[i]
            end
        end
    end
    return sizes
end

local function stack(box, horizontal, spec, gap)
    gap = gap or 0
    local sizes = parseSpec(spec, horizontal and box.w or box.h, gap)
    local cells = {}
    local pos = horizontal and box.x or box.y
    for i = 1, #spec do
        if horizontal then
            cells[i] = newBox(pos, box.y, sizes[i], box.h)
        else
            cells[i] = newBox(box.x, pos, box.w, sizes[i])
        end
        pos = pos + sizes[i] + gap
    end
    return cells
end

function Box:stackH(spec, gap) return stack(self, true, spec, gap) end
function Box:stackV(spec, gap) return stack(self, false, spec, gap) end

function Box:gridCell(cols, rows, col, row, gapX, gapY)
    gapX = gapX or 0
    gapY = gapY or gapX
    local cw = floor((self.w - gapX * (cols - 1)) / cols)
    local ch = floor((self.h - gapY * (rows - 1)) / rows)
    local cx = self.x + (col - 1) * (cw + gapX)
    local cy = self.y + (row - 1) * (ch + gapY)
    return newBox(cx, cy, cw, ch)
end

function Box:anchor(align, ew, eh, ox, oy)
    return biteen.anchor(align, ew, eh, ox, oy, self)
end

function Box:draw(fn, clip)
    if not biteen._bito then return end
    local g = biteen._bito.graphics
    g.push()
    if clip then g.addClip(self.x, self.y, self.w, self.h) end
    local ctx, cty = g.getTranslation()
    g.translation(ctx + self.x, cty + self.y)
    fn(self.w, self.h, self, newBox(0, 0, self.w, self.h))
    g.pop()
end

function Box:fill(color)
    if not biteen._bito then return end
    if color then biteen._bito.graphics.setColor(color) end
    biteen._bito.graphics.rectangle('fill', self.x, self.y, self.w, self.h)
end

function Box:outline(color)
    if not biteen._bito then return end
    if color then biteen._bito.graphics.setColor(color) end
    biteen._bito.graphics.rectangle('line', self.x, self.y, self.w, self.h)
end

local function getDpi_()
    if love and love.graphics and love.graphics.getDPIScale then
        return love.graphics.getDPIScale()
    end
    return 1
end

local function snapScale(s)
    if state.integerScale then
        local dpi = getDpi_()
        local phys = floor(s * dpi + 1e-6)
        if phys >= 1 then return phys / dpi end
    end
    return s
end

local function resolveInsets()
    local s, o = state.safe, state.os
    local pt = max(resolveSize(s.top,    state.vh), o.top)
    local pb = max(resolveSize(s.bottom, state.vh), o.bottom)
    local pl = max(resolveSize(s.left,   state.vw), o.left)
    local pr = max(resolveSize(s.right,  state.vw), o.right)
    return pt, pr, pb, pl
end

local function updateOsSafe()
    local o = state.os
    o.top, o.right, o.bottom, o.left = 0, 0, 0, 0
    if not state.useOsSafe then return end
    if not (love and love.window and love.window.getSafeArea) then return end
    local ok, sx, sy, sw, sh = pcall(love.window.getSafeArea)
    if not ok or not sx or state.scale <= 0 then return end
    local s = state.scale
    local right  = state.ox + state.vw * s
    local bottom = state.oy + state.vh * s
    o.left   = max(0, ceil((sx - state.ox) / s - 1e-6))
    o.top    = max(0, ceil((sy - state.oy) / s - 1e-6))
    o.right  = max(0, ceil((right  - (sx + sw)) / s - 1e-6))
    o.bottom = max(0, ceil((bottom - (sy + sh)) / s - 1e-6))
end

local function recalculate(winW, winH)
    if not winW or not winH then
        winW, winH = love.graphics.getDimensions()
    end
    winW = max(1, winW)
    winH = max(1, winH)
    state.winW, state.winH = winW, winH
    local first = not state.ready
    local prevOrientation = state.orientation
    local cfg = state.orientationCfg
    if cfg == 'landscape' then
        state.orientation = 'landscape'
    elseif cfg == 'portrait' then
        state.orientation = 'portrait'
    else
        local a = winW / winH
        if first then
            state.orientation = (a >= 1) and 'landscape' or 'portrait'
        else
            local t = max(1, state.orientationThreshold or 1)
            if prevOrientation == 'landscape' then
                state.orientation = (a < 1 / t) and 'portrait' or 'landscape'
            else
                state.orientation = (a > t) and 'landscape' or 'portrait'
            end
        end
    end
    local bw, bh
    if state.orientation == 'landscape' then
        bw = max(state.baseW, state.baseH)
        bh = min(state.baseW, state.baseH)
    else
        bw = state.portraitW or min(state.baseW, state.baseH)
        bh = state.portraitH or max(state.baseW, state.baseH)
    end
    state.curBaseW, state.curBaseH = bw, bh
    local vw, vh = bw, bh
    local mode = state.mode
    if mode == 'fixed' then
        vw, vh = bw, bh
    elseif mode == 'expand' then
        local rawScale = min(winW / bw, winH / bh)
        if state.integerScale and rawScale >= 1 then
            rawScale = snapScale(rawScale)
        end
        if rawScale <= 0 then rawScale = 1 end
        if state.integerScale and rawScale >= 1 then
            vw = max(bw, floor(winW / rawScale))
            vh = max(bh, floor(winH / rawScale))
        else
            vw = max(bw, floor(winW / rawScale + 0.5))
            vh = max(bh, floor(winH / rawScale + 0.5))
        end
    elseif mode == 'width' then
        vw = bw
        vh = max(1, floor(bw * (winH / winW) + 0.5))
    elseif mode == 'height' then
        vh = bh
        vw = max(1, floor(bh * (winW / winH) + 0.5))
    elseif mode == 'area' then
        local area = bw * bh
        local aspect = winW / winH
        vw = max(1, floor(sqrt(area * aspect) + 0.5))
        vh = max(1, floor(sqrt(area / aspect) + 0.5))
    end
    if mode ~= 'fixed' then
        local baseAspect = bw / bh
        local a = vw / vh
        local hi = state.maxAspect and max(state.maxAspect, baseAspect)
        local lo = state.minAspect and min(state.minAspect, baseAspect)
        if hi and a > hi then
            vw = max(1, floor(vh * hi + 0.5))
        elseif lo and a < lo then
            vh = max(1, floor(vw / lo + 0.5))
        end
    end
    local resChanged = first or (vw ~= state.vw) or (vh ~= state.vh)
    local orientChanged = first or (state.orientation ~= prevOrientation)
    state.vw, state.vh = vw, vh
    if biteen._bito then
        local curW, curH = biteen._bito.getResolution()
        if curW ~= vw or curH ~= vh then
            biteen._bito.setResolution(vw, vh)
        end
        biteen._bito.resize(winW, winH)
    end
    if biteen._bito and biteen._bito.getScale then
        state.scale = biteen._bito.getScale()
        state.ox, state.oy = biteen._bito.getOffset()
    else
        local s = snapScale(min(winW / vw, winH / vh))
        state.scale = s
        state.ox = floor((winW - vw * s) * 0.5)
        state.oy = floor((winH - vh * s) * 0.5)
    end
    updateOsSafe()
    local pt, pr, pb, pl = resolveInsets()
    local key = pt .. ',' .. pr .. ',' .. pb .. ',' .. pl
    if key ~= state.insetsKey then
        state.insetsKey = key
        if not first then resChanged = true end
    end
    state.ready = true
    if orientChanged and state.onOrientation then
        state.onOrientation(state.orientation, vw, vh)
    end
    if (resChanged or orientChanged) and state.onResize then
        state.onResize(vw, vh, state.orientation, state.scale)
    end
end

function biteen.init(bitoInstance, config)
    biteen._bito = bitoInstance
    config = config or {}
    state.baseW                = config.baseWidth  or config.width  or 320
    state.baseH                = config.baseHeight or config.height or 180
    state.portraitW            = config.portraitWidth
    state.portraitH            = config.portraitHeight
    state.mode                 = config.mode or 'expand'
    state.orientationCfg       = config.orientation or 'auto'
    state.orientationThreshold = config.orientationThreshold or 1.05
    state.maxAspect            = config.maxAspect
    state.minAspect            = config.minAspect
    state.integerScale         = config.integerScale and true or false
    state.useOsSafe            = (config.useOsSafeArea ~= false)
    state.compactDp            = config.compactDp or 600
    state.onResize             = config.onResize
    state.onOrientation        = config.onOrientation
    state.safe.top, state.safe.right, state.safe.bottom, state.safe.left = 0, 0, 0, 0
    if config.safePadding then
        biteen.setSafePadding(config.safePadding)
    end
    if bitoInstance and bitoInstance.setIntegerScale then
        bitoInstance.setIntegerScale(state.integerScale)
    end
    state.ready = false
    state.insetsKey = ''
    recalculate()
    if config.hook then
        biteen.hook(type(config.hook) == 'table' and config.hook or nil)
    end
    return biteen
end

function biteen.resize(w, h)
    recalculate(w, h)
end

function biteen.refresh()
    recalculate()
end

function biteen.setMode(mode)
    state.mode = mode or 'expand'
    recalculate(state.winW, state.winH)
end

function biteen.setOrientation(orientation)
    state.orientationCfg = orientation or 'auto'
    recalculate(state.winW, state.winH)
end

function biteen.setOrientationThreshold(t)
    state.orientationThreshold = t or 1.05
    recalculate(state.winW, state.winH)
end

function biteen.setAspectLimits(minAspect, maxAspect)
    state.minAspect = minAspect
    state.maxAspect = maxAspect
    recalculate(state.winW, state.winH)
end

function biteen.setBaseResolution(w, h, portraitW, portraitH)
    state.baseW = w or state.baseW
    state.baseH = h or state.baseH
    if portraitW then state.portraitW = portraitW end
    if portraitH then state.portraitH = portraitH end
    recalculate(state.winW, state.winH)
end

function biteen.setIntegerScale(on)
    state.integerScale = on and true or false
    if biteen._bito and biteen._bito.setIntegerScale then
        biteen._bito.setIntegerScale(state.integerScale)
    end
    recalculate(state.winW, state.winH)
end

function biteen.setSafePadding(top, right, bottom, left)
    if type(top) == 'table' then
        state.safe.top    = top.top    or top[1] or 0
        state.safe.right  = top.right  or top[2] or state.safe.top
        state.safe.bottom = top.bottom or top[3] or state.safe.top
        state.safe.left   = top.left   or top[4] or state.safe.right
    else
        top    = top or 0
        right  = right or top
        bottom = bottom or top
        left   = left or right
        state.safe.top, state.safe.right, state.safe.bottom, state.safe.left = top, right, bottom, left
    end
    if state.ready then recalculate(state.winW, state.winH) end
end

function biteen.setOsSafeArea(on)
    state.useOsSafe = on and true or false
    recalculate(state.winW, state.winH)
end

function biteen.getDimensions()     return state.vw, state.vh end
function biteen.getWidth()          return state.vw end
function biteen.getHeight()         return state.vh end
function biteen.getBaseDimensions() return state.curBaseW, state.curBaseH end
function biteen.getWindowSize()     return state.winW, state.winH end
function biteen.getOrientation()    return state.orientation end
function biteen.isLandscape()       return state.orientation == 'landscape' end
function biteen.isPortrait()        return state.orientation == 'portrait' end
function biteen.getScale()          return state.scale end
function biteen.getOffset()         return state.ox, state.oy end
function biteen.getAspect()         return state.vw / state.vh end
function biteen.getDPIScale()       return getDpi_() end

function biteen.getSafeInsets()
    return resolveInsets()
end

function biteen.select(landscapeVal, portraitVal)
    if state.orientation == 'landscape' then
        return landscapeVal
    end
    return portraitVal
end

function biteen.sizeClass()
    return (min(state.winW, state.winH) < state.compactDp) and 'compact' or 'regular'
end

function biteen.isMobile()
    local os = love and love.system and love.system.getOS and love.system.getOS()
    return os == 'Android' or os == 'iOS'
end

function biteen.touchSize(minPx)
    local s = state.scale > 0 and state.scale or 1
    return ceil((minPx or 44) / s)
end

function biteen.rel(rx, ry)
    return floor((rx or 0) * state.vw), floor((ry or 0) * state.vh)
end

function biteen.vw(pct)   return floor((pct / 100) * state.vw) end
function biteen.vh(pct)   return floor((pct / 100) * state.vh) end
function biteen.vmin(pct) return floor((pct / 100) * min(state.vw, state.vh)) end
function biteen.vmax(pct) return floor((pct / 100) * max(state.vw, state.vh)) end

function biteen.box(x, y, w, h)
    return newBox(x, y, w, h)
end

function biteen.screenBox()
    return newBox(0, 0, state.vw, state.vh)
end

function biteen.safeBox()
    local pt, pr, pb, pl = resolveInsets()
    return newBox(pl, pt, state.vw - pl - pr, state.vh - pt - pb)
end

function biteen.baseBox()
    local x = floor((state.vw - state.curBaseW) * 0.5)
    local y = floor((state.vh - state.curBaseH) * 0.5)
    return newBox(x, y, state.curBaseW, state.curBaseH)
end

function biteen.anchor(align, ew, eh, ox, oy, rect)
    align  = align or 'tl'
    ew, eh = ew or 0, eh or 0
    ox, oy = ox or 0, oy or 0
    rect   = rect or biteen.safeBox()
    local x, y = rect.x, rect.y
    if align == 'tc' or align == 'cc' or align == 'c' or align == 'bc' then
        x = rect.x + floor((rect.w - ew) * 0.5)
    elseif align == 'tr' or align == 'cr' or align == 'br' then
        x = rect.x + rect.w - ew
    end
    if align == 'cl' or align == 'cc' or align == 'c' or align == 'cr' then
        y = rect.y + floor((rect.h - eh) * 0.5)
    elseif align == 'bl' or align == 'bc' or align == 'br' then
        y = rect.y + rect.h - eh
    end
    return floor(x + ox), floor(y + oy)
end

function biteen.printAligned(text, align, ox, oy, rect)
    if not biteen._bito then return end
    local f = biteen._bito.graphics.getFont()
    local tw = f:getWidth(text)
    local th = f:getHeight(text)
    local x, y = biteen.anchor(align, tw, th, ox, oy, rect)
    biteen._bito.graphics.print(text, x, y)
    return x, y, tw, th
end

function biteen.toPixel(screenX, screenY)
    local px, py
    if biteen._bito and biteen._bito.screenToPixel then
        px, py = biteen._bito.screenToPixel(screenX, screenY)
    else
        px = floor((screenX - state.ox) / state.scale)
        py = floor((screenY - state.oy) / state.scale)
    end
    local inside = (px >= 0 and px < state.vw and py >= 0 and py < state.vh)
    return px, py, inside
end

function biteen.getMouse()
    local mx, my = love.mouse.getPosition()
    return biteen.toPixel(mx, my)
end

function biteen.getTouches()
    local list = {}
    if love.touch then
        local touches = love.touch.getTouches()
        for i = 1, #touches do
            local id = touches[i]
            local tx_, ty_ = love.touch.getPosition(id)
            local px, py, inside = biteen.toPixel(tx_, ty_)
            list[i] = { id = id, x = px, y = py, inside = inside }
        end
    end
    return list
end

local Camera = {}
Camera.__index = Camera
local cameras = setmetatable({}, { __mode = 'k' })

function biteen.newCamera()
    local c = setmetatable({
        x          = 0,
        y          = 0,
        bounds     = nil,
        shakeTime  = 0,
        shakeDur   = 0,
        shakeMag   = 0,
        shakeDecay = true,
        shakeOX    = 0,
        shakeOY    = 0,
    }, Camera)
    cameras[c] = true
    return c
end

local function clampCamera(self, vw, vh)
    local b = self.bounds
    if not b then return end
    local halfW, halfH = floor(vw * 0.5), floor(vh * 0.5)
    if b.w <= vw then
        self.x = b.x + floor(b.w * 0.5)
    else
        self.x = max(b.x + halfW, min(b.x + b.w - (vw - halfW), self.x))
    end
    if b.h <= vh then
        self.y = b.y + floor(b.h * 0.5)
    else
        self.y = max(b.y + halfH, min(b.y + b.h - (vh - halfH), self.y))
    end
end

function Camera:lookAt(x, y, viewportBox)
    self.x = floor(x)
    self.y = floor(y)
    local vw = viewportBox and viewportBox.w or state.vw
    local vh = viewportBox and viewportBox.h or state.vh
    clampCamera(self, vw, vh)
end

function Camera:follow(tx_, ty_, speed, dt, viewportBox)
    speed = speed or 10
    dt = dt or (love.timer and love.timer.getDelta() or 0.016)
    local k = min(1, speed * dt)
    self.x = self.x + (tx_ - self.x) * k
    self.y = self.y + (ty_ - self.y) * k
    local vw = viewportBox and viewportBox.w or state.vw
    local vh = viewportBox and viewportBox.h or state.vh
    clampCamera(self, vw, vh)
end

function Camera:setBounds(x, y, w, h)
    self.bounds = { x = x, y = y, w = w, h = h }
end

function Camera:clearBounds()
    self.bounds = nil
end

function Camera:shake(intensity, duration, decay)
    self.shakeMag   = intensity or 2
    self.shakeTime  = duration  or 0.2
    self.shakeDur   = self.shakeTime
    self.shakeDecay = (decay ~= false)
end

function Camera:stopShake()
    self.shakeTime, self.shakeOX, self.shakeOY = 0, 0, 0
end

function Camera:update(dt)
    if self.shakeTime > 0 then
        self.shakeTime = max(0, self.shakeTime - dt)
        local m = self.shakeMag
        if self.shakeDecay and self.shakeDur > 0 then
            m = m * (self.shakeTime / self.shakeDur)
        end
        m = floor(m + 0.5)
        if self.shakeTime == 0 or m <= 0 then
            self.shakeOX, self.shakeOY = 0, 0
        else
            self.shakeOX = love.math.random(-m, m)
            self.shakeOY = love.math.random(-m, m)
        end
    end
end

function Camera:getOffset(viewportBox)
    local vx = viewportBox and viewportBox.x or 0
    local vy = viewportBox and viewportBox.y or 0
    local vw = viewportBox and viewportBox.w or state.vw
    local vh = viewportBox and viewportBox.h or state.vh
    clampCamera(self, vw, vh)
    local tx_ = vx + floor(vw * 0.5) - floor(self.x) + self.shakeOX
    local ty_ = vy + floor(vh * 0.5) - floor(self.y) + self.shakeOY
    return tx_, ty_
end

function Camera:attach(viewportBox, noClip)
    if not biteen._bito then return end
    local g = biteen._bito.graphics
    g.push()
    if viewportBox and not noClip then
        g.addClip(viewportBox.x, viewportBox.y, viewportBox.w, viewportBox.h)
    end
    local ctx, cty = g.getTranslation()
    local tx_, ty_ = self:getOffset(viewportBox)
    g.translation(ctx + tx_, cty + ty_)
end

function Camera:detach()
    if not biteen._bito then return end
    biteen._bito.graphics.pop()
end

function Camera:draw(fn, viewportBox, noClip)
    self:attach(viewportBox, noClip)
    local bx, by, bw, bh = self:getVisibleBounds(viewportBox)
    fn(bx, by, bw, bh)
    self:detach()
end

function Camera:toWorld(px, py, viewportBox)
    local tx_, ty_ = self:getOffset(viewportBox)
    return px - tx_, py - ty_
end

function Camera:toScreen(wx, wy, viewportBox)
    local tx_, ty_ = self:getOffset(viewportBox)
    return wx + tx_, wy + ty_
end

function Camera:getVisibleBounds(viewportBox)
    local vw = viewportBox and viewportBox.w or state.vw
    local vh = viewportBox and viewportBox.h or state.vh
    local wx, wy = self:toWorld(viewportBox and viewportBox.x or 0, viewportBox and viewportBox.y or 0, viewportBox)
    return wx, wy, vw, vh
end

biteen.camera = biteen.newCamera()

function biteen.updateCameras(dt)
    for c in pairs(cameras) do c:update(dt) end
end

function biteen.hook(opts)
    opts = opts or {}
    if state.hooked then return end
    state.hooked = true
    if opts.resize ~= false then
        local prev = love.resize
        love.resize = function(w, h)
            biteen.resize(w, h)
            if prev then return prev(w, h) end
        end
    end
    if opts.update ~= false then
        local prev = love.update
        love.update = function(dt)
            biteen.updateCameras(dt)
            if prev then return prev(dt) end
        end
    end
    if opts.input == true then
        local function wrapInput(name, posIdx, deltaIdx)
            local prev = love[name]
            if type(prev) ~= 'function' then return end
            love[name] = function(...)
                local n = select('#', ...)
                local a = { ... }
                local px, py = biteen.toPixel(a[posIdx], a[posIdx + 1])
                a[posIdx], a[posIdx + 1] = px, py
                if deltaIdx and a[deltaIdx] and a[deltaIdx + 1] then
                    local s = state.scale > 0 and state.scale or 1
                    a[deltaIdx], a[deltaIdx + 1] = a[deltaIdx] / s, a[deltaIdx + 1] / s
                end
                return prev(unpack(a, 1, n))
            end
        end
        wrapInput('mousepressed',  1)
        wrapInput('mousereleased', 1)
        wrapInput('mousemoved',    1, 3)
        wrapInput('touchpressed',  2, 4)
        wrapInput('touchreleased', 2, 4)
        wrapInput('touchmoved',    2, 4)
    end
end

function biteen.debugDraw()
    if not biteen._bito then return end
    local g = biteen._bito.graphics
    g.push()
    g.clearClip()
    g.translation(0, 0)
    biteen.baseBox():outline('pink')
    biteen.safeBox():outline('green')
    local cx, cy = floor(state.vw * 0.5), floor(state.vh * 0.5)
    g.setColor('yellow')
    g.line(cx - 4, cy, cx + 4, cy)
    g.line(cx, cy - 4, cx, cy + 4)
    local info = string.format("%dx%d %s x%.2f dpi%.1f %s",
        state.vw, state.vh, state.orientation == 'landscape' and 'LAND' or 'PORT',
        state.scale, getDpi_(), biteen.sizeClass())
    local f = g.getFont()
    local tw, th = f:getWidth(info), f:getHeight(info)
    g.setColor('black')
    g.rectangle('fill', 2, 2, tw + 4, th + 4)
    g.setColor('white')
    g.print(info, 4, 4)
    g.pop()
end

local SAMPLE_RATE = 44100
local CHANNELS = 4
local BASE_FREQS = {
    261.63, 277.18, 293.66, 311.13,
    329.63, 349.23, 369.99, 392.00,
    415.30, 440.00, 466.16, 493.88
}

local CHAR_WAVE = ffi.new("uint8_t[256]")
local CHAR_FREQ = ffi.new("double[256]")
local WAVE_NONE = 0
local WAVE_SQUARE = 1
local WAVE_SAWTOOTH = 2
local WAVE_TRIANGLE = 3
local WAVE_NOISE = 4

local function waveToInt(waveform)
    if waveform == "square" then return WAVE_SQUARE
    elseif waveform == "sawtooth" then return WAVE_SAWTOOTH
    elseif waveform == "triangle" then return WAVE_TRIANGLE
    elseif waveform == "noise" then return WAVE_NOISE
    end
    return WAVE_NONE
end

local function registerRange(chars, waveform, octaveShift)
    local mult = 2 ^ (octaveShift or 0)
    local waveId = waveToInt(waveform)
    for i = 1, #chars do
        local byte = chars:byte(i)
        CHAR_WAVE[byte] = waveId
        CHAR_FREQ[byte] = BASE_FREQS[i] * mult
    end
end

registerRange("ABCDEFGHIJKL", "square",   0)
registerRange("MNOPQRSTUVW",  "sawtooth", 0)
CHAR_WAVE[string.byte("X")] = WAVE_SAWTOOTH
CHAR_FREQ[string.byte("X")] = BASE_FREQS[12]
registerRange("abcdefghijkl", "triangle", 0)
registerRange("mnopqrstuvwx", "noise",    0)
registerRange("0123456789!@", "triangle", -1)
registerRange("#$%^&*()_+=~", "sawtooth", -1)

local SUSTAIN_BYTE = string.byte("-")
local loadedSounds = {}
local activeSources = {}

local function renderStreamToSoundData(stream, bpm)
    stream = stream:gsub("%s+", "")
    local totalChars = #stream
    local totalSteps = floor(totalChars / CHANNELS)
    if totalSteps == 0 then
        return love.sound.newSoundData(1, SAMPLE_RATE, 16, 1)
    end
    local stepDuration = 60 / (bpm or 120) / 4
    local stepSamples = floor(SAMPLE_RATE * stepDuration)
    local totalSamples = totalSteps * stepSamples
    local soundData = love.sound.newSoundData(totalSamples, SAMPLE_RATE, 16, 1)
    local dataPtr = ffi.cast("int16_t*", soundData:getFFIPointer())
    local streamBytes = ffi.cast("const uint8_t*", stream)
    local VOL_MULT = 7208.74
    for ch = 0, CHANNELS - 1 do
        local step = 0
        while step < totalSteps do
            local idx = step * CHANNELS + ch
            local symbol = streamBytes[idx]
            local waveType = CHAR_WAVE[symbol]
            if waveType > WAVE_NONE then
                local sustainSteps = 1
                while (step + sustainSteps) < totalSteps do
                    local nextIdx = (step + sustainSteps) * CHANNELS + ch
                    if streamBytes[nextIdx] == SUSTAIN_BYTE then
                        sustainSteps = sustainSteps + 1
                    else
                        break
                    end
                end
                local freq = CHAR_FREQ[symbol]
                local durSamples = sustainSteps * stepSamples
                local startSample = step * stepSamples
                local fadeSamples = min(floor(SAMPLE_RATE * 0.002), floor(durSamples * 0.2))
                local holdPeriod = max(1, floor(SAMPLE_RATE / (freq * 6)))
                local noiseVal = 0
                for i = 0, durSamples - 1 do
                    local t = i / SAMPLE_RATE
                    local val = 0
                    if waveType == WAVE_SQUARE then
                        val = sin(PI2 * freq * t) >= 0 and 0.6 or -0.6
                    elseif waveType == WAVE_SAWTOOTH then
                        val = (2 * ((t * freq) % 1) - 1) * 0.6
                    elseif waveType == WAVE_TRIANGLE then
                        val = (2 * abs(2 * ((t * freq) % 1) - 1) - 1) * 0.8
                    elseif waveType == WAVE_NOISE then
                        if i % holdPeriod == 0 then
                            noiseVal = (random() * 2 - 1) * 0.7
                        end
                        val = noiseVal * max(0, 1 - (i / durSamples))
                    end
                    local env = 1.0
                    if i < fadeSamples then
                        env = i / fadeSamples
                    elseif i > durSamples - fadeSamples then
                        env = (durSamples - i) / fadeSamples
                    end
                    local pos = startSample + i
                    if pos < totalSamples then
                        local sampleVal = val * env * VOL_MULT
                        local mixed = dataPtr[pos] + sampleVal
                        if mixed > 32767 then mixed = 32767
                        elseif mixed < -32768 then mixed = -32768 end
                        dataPtr[pos] = mixed
                    end
                end
                step = step + sustainSteps
            else
                step = step + 1
            end
        end
    end
    return soundData
end

local bisond = {}

function bisond.decode(pathOrData, isRawCompressed)
    local compressed = pathOrData
    if not isRawCompressed then
        if pathOrData:match("%.png$") then
            local imgData = love.image.newImageData(pathOrData)
            local ptr = ffi.cast("uint8_t*", imgData:getFFIPointer())
            local dataLen = ptr[0] + ptr[1] * 256 + ptr[2] * 65536
            compressed = ffi.string(ptr + 4, dataLen)
        else
            compressed = assert(love.filesystem.read(pathOrData), "Bisond: file not found: " .. tostring(pathOrData))
        end
    end
    return love.data.decompress("string", "zlib", compressed)
end

function bisond.load(name, path, bpm)
    local stream = bisond.decode(path, false)
    loadedSounds[name] = renderStreamToSoundData(stream, bpm or 120)
    return true
end

function bisond.loadFromStream(name, stream, bpm)
    loadedSounds[name] = renderStreamToSoundData(stream, bpm or 120)
    return true
end

function bisond.play(name, loop, volume)
    if not loadedSounds[name] then return false end
    bisond.stop(name)
    local source = love.audio.newSource(loadedSounds[name], "static")
    source:setLooping(loop == true)
    source:setVolume(max(0, min(1, volume or 1.0)))
    source:play()
    activeSources[name] = source
    return true
end

function bisond.stop(name)
    if activeSources[name] then
        activeSources[name]:stop()
        activeSources[name] = nil
        return true
    end
    return false
end

function bisond.pause(name)
    if activeSources[name] then
        activeSources[name]:pause()
        return true
    end
    return false
end

function bisond.resume(name)
    if activeSources[name] then
        activeSources[name]:play()
        return true
    end
    return false
end

function bisond.setVolume(name, volume)
    if activeSources[name] then
        activeSources[name]:setVolume(max(0, min(1, volume)))
        return true
    end
    return false
end

function bisond.setLooping(name, loop)
    if activeSources[name] then
        activeSources[name]:setLooping(loop)
        return true
    end
    return false
end

function bisond.isPlaying(name)
    return activeSources[name] ~= nil and activeSources[name]:isPlaying()
end

function bisond.stopAll()
    for _, src in pairs(activeSources) do
        src:stop()
    end
    activeSources = {}
end

function bisond.update()
    for name, src in pairs(activeSources) do
        if not src:isPlaying() and src:tell() > 0 then
            activeSources[name] = nil
        end
    end
end

local bito = {
    graphics        = graphics,
    colors          = colorNames,
    draw            = draw,
    clear           = function(c) display:clear(c) end,
    setPixel        = function(x, y, c) display:setPixel(x, y, c) end,
    getPixel        = function(x, y) return display:getPixel(x, y) end,
    setResolution   = setResolution,
    getResolution   = function() return display.width, display.height end,
    resize          = function(w, h) layout(w, h) end,
    setIntegerScale = function(on) integerScale = on and true or false layout() end,
    getScale        = function() return scale end,
    getOffset       = function() return ox, oy end,
    screenToPixel   = screenToPixel,
    setPalette      = setPalette,
    setPaletteColor = setPaletteColor,
    getPalette      = getPalette,
    screen          = biteen,
    sound           = bisond,
}

biteen._bito = bito

return bito
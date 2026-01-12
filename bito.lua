local utf8 = require('utf8')
local bit  = require('bit')

love.graphics.setDefaultFilter('nearest', 'nearest', 1)

local imageData
local ffiSuccess, ffi = pcall(require, "ffi")
-- ffiSuccess = false
if ffiSuccess then
    ffi.cdef[[
        #pragma pack(1)
        typedef struct {
            uint8_t r, g, b, a;
        } Pixel;
    ]]
    imageData = {}
        -- pixels = pointer image data,
        -- data = love image data
        -- size = width * height * 4,
        -- width = image width,
        -- height = image height

    function imageData:release()
        self.pixels = nil
        self.data:release()
    end
    function imageData:getWidth()
        return self.width
    end
    function imageData:getHeight()
        return self.height
    end
    function imageData:clear(r, g, b)
        if r and g and b then
            local w = self.width - 1
            local h = self.height - 1
            for x = 0, w do
                for y = 0, h, 1 do
                    local pixel = self.pixels[y * self.width + x]
                    pixel.r, pixel.g, pixel.b, pixel.a = r, g, b, 255
                end
            end
        else
            ffi.fill(self.pixels, self.size, 0)
        end
    end
    function imageData:setPixel(x, y, r, g, b)
        local pixel = self.pixels[y * self.width + x]
        pixel.r, pixel.g, pixel.b, pixel.a = r, g, b, 255
    end
    function imageData:getPixel(x, y)
        local pixel = self.pixels[y * self.width + x]
        return pixel.r, pixel.g, pixel.b, pixel.a
    end
    function imageData:mapPixel(callback)
        local w = self.width - 1
        local h = self.height - 1
        for x = 0, w do
            for y = 0, h, 1 do
                local pixel = self.pixels[y * self.width + x]
                pixel.r, pixel.g, pixel.b, pixel.a = callback(pixel.r, pixel.g, pixel.b)
            end
        end
    end
    function imageData:paste(source, dx, dy, sx, sy, sw, sh)
        sx = sx or 0
        sy = sy or 0
        sw = sw or source.width
        sh = sh or source.height

        for y = 0, sh-1 do
            local srcY = sy + y
            local dstY = dy + y

            if dstY >= 0 and dstY < self.height and srcY >= 0 and srcY < source.height then
                for x = 0, sw-1 do
                    local srcX = sx + x
                    local dstX = dx + x

                    if dstX >= 0 and dstX < self.width and srcX >= 0 and srcX < source.width then
                        local srcPixel = source.pixels[srcY * source.width + srcX]
                        local dstPixel = self.pixels[dstY * self.width + dstX]
                        dstPixel.r = srcPixel.r
                        dstPixel.g = srcPixel.g
                        dstPixel.b = srcPixel.b
                        dstPixel.a = srcPixel.a
                    end
                end
            end
        end
    end
else
    imageData = {}
        -- data = love imageData,
        -- width = image:getWidth(),
        -- height = image:getHeight()
    function imageData:release()
        self.data:release()
    end
    function imageData:clear(r, g, b)
        if r and g and b then
            self.data:mapPixel(function ()
                return r / 255, g / 255, b / 255, 1
            end)
        else
            if self.data then self.data:release() end
            self.data = love.image.newImageData(self.width, self.height)
        end
    end
    function imageData:getWidth()
        return self.width
    end
    function imageData:getHeight()
        return self.height
    end
    function imageData:setPixel(x, y, r, g, b)
        self.data:setPixel(x, y, r / 255, g / 255, b / 255, 1)
    end
    function imageData:getPixel(x, y)
        return self.data:getPixel(x, y)
    end
    function imageData:mapPixel(...)
        return self.data:mapPixel(...)
    end
    function imageData:paste(source, dx, dy, sx, sy, sw, sh)
        return self.data:paste(source.data, dx, dy, sx, sy, sw, sh)
    end
end

local newImageData
if ffiSuccess then
    newImageData = function (width, height, data)
        data = data or love.image.newImageData(width, height)
        local pixels = ffi.cast("Pixel*", data:getPointer())
        return setmetatable({
            data = data,
            width = width,
            height = height,
            size = width * height * 4,
            pixels = pixels
        }, {__index = imageData})
    end
else
    newImageData = function (width, height, data)
        data = data or love.image.newImageData(width, height)
        return setmetatable({data = data, width = width, height = height}, {__index = imageData})
    end
end

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

local display = {}

function display.setResolution(width, height)
    display.width, display.height = width, height
    display.scale = math.min(love.graphics.getWidth() / display.width, love.graphics.getHeight() / display.height)

    if display.imageData then display.imageData:release() end
    display.imageData = newImageData(display.width, display.height)
    if display.image then display.image:release() end
    display.image = love.graphics.newImage(display.imageData.data)

    display.width_1, display.height_1 = width - 1, height - 1
end

function display.getResolution()
    return display.width, display.height
end

function display.clear()
    display.imageData:clear()
end

display.setResolution(400, 300)

function display.setPixel(x, y, r, g, b)
    if x >= 0 and x <= display.width_1 and
       y >= 0 and y <= display.height_1 then
        display.imageData:setPixel(x, y, r, g, b)
    end
end

display.getPixel = function(x, y)
    if x >= 0 and x <= display.width_1 and
       y >= 0 and y <= display.height_1 then
        return display.imageData:getPixel(x, y)
    end
    return 0, 0, 0
end

function display.draw()
    display.image:replacePixels(display.imageData.data)
    love.graphics.draw(display.image, 0, 0, 0, display.scale, display.scale)
end

local graphics = {}
local floor = math.floor

graphics.drawState = {
    colorRed         = 255,
    colorGreen       = 255,
    colorBlue        = 255,
    stack            = {},
    translationX     = 0,
    translationY     = 0,
    font             = nil,
}
local drawState = graphics.drawState
local activeDisplay = display

graphics.push = function()
    table.insert(drawState.stack, {
        colorRed         = drawState.colorRed,
        colorGreen       = drawState.colorGreen,
        colorBlue        = drawState.colorBlue,
        translationX     = drawState.translationX,
        translationY     = drawState.translationY,
        font             = drawState.font
    })
end

graphics.pop = function()
    local state = table.remove(drawState.stack)
    if state then
        drawState.colorRed         = state.colorRed
        drawState.colorGreen       = state.colorGreen
        drawState.colorBlue        = state.colorBlue
        drawState.translationX     = state.translationX
        drawState.translationY     = state.translationY
        drawState.font             = state.font

        if ffiSuccess then
            drawState.ncolorRed   = drawState.colorRed / 255
            drawState.ncolorGreen = drawState.colorGreen / 255
            drawState.ncolorBlue  = drawState.colorBlue / 255
        else
            drawState.ncolorRed   = drawState.colorRed
            drawState.ncolorGreen = drawState.colorGreen
            drawState.ncolorBlue  = drawState.colorBlue
        end
    else
        print("Attempted to pop from an empty drawing state stack")
    end
end

graphics.setColor = function(r, g, b)
    drawState.colorRed = r
    drawState.colorGreen = g
    drawState.colorBlue = b

    if ffiSuccess then
        drawState.ncolorRed = r / 255
        drawState.ncolorGreen = g / 255
        drawState.ncolorBlue = b / 255
    else
        drawState.ncolorRed = r
        drawState.ncolorGreen = g
        drawState.ncolorBlue = b
    end
end

graphics.getColor = function()
    return drawState.colorRed, drawState.colorGreen, drawState.colorBlue
end

graphics.translation = function (x, y)
    drawState.translationX, drawState.translationY = x, y
end

graphics.getTranslation = function ()
    return drawState.translationX, drawState.translationY
end

graphics.setFont = function (font)
    drawState.font = font
end

graphics.getFont = function ()
    return drawState.font
end

graphics.pixel = function(x, y)
    x, y = floor(x + drawState.translationX), floor(y + drawState.translationY)
    activeDisplay.setPixel(x, y, drawState.colorRed, drawState.colorGreen, drawState.colorBlue)
end

graphics.clear = function (cr, cg, cb)
    activeDisplay.imageData:clear(cr, cg, cb)
end

graphics.line = function(x1, y1, x2, y2)
    x1, y1 = floor(x1 + drawState.translationX), floor(y1 + drawState.translationY)
    x2, y2 = floor(x2 + drawState.translationX), floor(y2 + drawState.translationY)

    local r, g, b = drawState.colorRed, drawState.colorGreen, drawState.colorBlue

    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy

    while true do
        activeDisplay.setPixel(x1, y1, r, g, b)

        if x1 == x2 and y1 == y2 then break end

        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x1 = x1 + sx
        end
        if e2 < dx then
            err = err + dx
            y1 = y1 + sy
        end
    end
end

graphics.circle = function(mode, x, y, radius)
    x, y, radius = floor(x + drawState.translationX), floor(y + drawState.translationY), floor(radius)

    local r, g, b = drawState.colorRed, drawState.colorGreen, drawState.colorBlue

    local function plotPoints(cx, cy, x_offset, y_offset)
        if mode == 'fill' then
            local start_x = cx - x_offset
            local end_x = cx + x_offset
            for px = start_x, end_x do
                activeDisplay.setPixel(px, cy + y_offset, r, g, b)
                activeDisplay.setPixel(px, cy - y_offset, r, g, b)
            end

            start_x = cx - y_offset
            end_x = cx + y_offset
            for px = start_x, end_x do
                activeDisplay.setPixel(px, cy + x_offset, r, g, b)
                activeDisplay.setPixel(px, cy - x_offset, r, g, b)
            end
        else
            activeDisplay.setPixel(cx + x_offset, cy + y_offset, r, g, b)
            activeDisplay.setPixel(cx - x_offset, cy + y_offset, r, g, b)
            activeDisplay.setPixel(cx + x_offset, cy - y_offset, r, g, b)
            activeDisplay.setPixel(cx - x_offset, cy - y_offset, r, g, b)
            activeDisplay.setPixel(cx + y_offset, cy + x_offset, r, g, b)
            activeDisplay.setPixel(cx - y_offset, cy + x_offset, r, g, b)
            activeDisplay.setPixel(cx + y_offset, cy - x_offset, r, g, b)
            activeDisplay.setPixel(cx - y_offset, cy - x_offset, r, g, b)
        end
    end

    local x_offset = 0
    local y_offset = radius
    local d = 3 - 2 * radius

    plotPoints(x, y, x_offset, y_offset)
    while y_offset >= x_offset do
        x_offset = x_offset + 1
        if d > 0 then
            y_offset = y_offset - 1
            d = d + 4 * (x_offset - y_offset) + 10
        else
            d = d + 4 * x_offset + 6
        end
        plotPoints(x, y, x_offset, y_offset)
    end
end

graphics.rectangle = function(mode, x, y, width, height)
    local px, py, pw, ph = floor(x + drawState.translationX), floor(y + drawState.translationY), floor(width), floor(height)

    if px > activeDisplay.width_1 or py > activeDisplay.height_1 or
       px + pw < 0 or py + ph < 0 then
        return
    end

    local x1, y1 = px, py
    local x2, y2 = math.min(activeDisplay.width, px + pw - 1), math.min(activeDisplay.height, py + ph - 1)
    local r, g, b = drawState.colorRed, drawState.colorGreen, drawState.colorBlue

    if mode == 'fill' then
        local pixel = activeDisplay.setPixel

        for current_y = y1, y2 do
            for current_x = x1, x2 do
                pixel(current_x, current_y, r, g, b)
            end
        end
    else
        local pixel = activeDisplay.setPixel

        if py >= 0 and py <= activeDisplay.height_1 then
            local start_x = math.max(x1, px)
            local end_x = math.min(x2, px + pw - 1)
            for current_x = start_x, end_x do
                pixel(current_x, py, r, g, b)
            end
        end

        local bottom_y = py + ph - 1
        if bottom_y >= 0 and bottom_y <= activeDisplay.height_1 then
            local start_x = math.max(x1, px)
            local end_x = math.min(x2, px + pw - 1)
            for current_x = start_x, end_x do
                pixel(current_x, bottom_y, r, g, b)
            end
        end

        if px >= 0 and px <= activeDisplay.width_1 then
            local start_y = math.max(y1, py + 1)
            local end_y = math.min(y2, py + ph - 2)
            for current_y = start_y, end_y do
                pixel(px, current_y, r, g, b)
            end
        end

        local right_x = px + pw - 1
        if right_x >= 0 and right_x <= activeDisplay.width_1 then
            local start_y = math.max(y1, py + 1)
            local end_y = math.min(y2, py + ph - 2)
            for current_y = start_y, end_y do
                pixel(right_x, current_y, r, g, b)
            end
        end
    end
end

graphics.fill = function (x, y)
    local tx, ty = floor(x + drawState.translationX), floor(y + drawState.translationY)

    if tx < 0 or tx > activeDisplay.width_1 or ty < 0 or ty > activeDisplay.height_1 then
        return
    end

    local startR, startG, startB = activeDisplay.getPixel(tx, ty)

    if startR == drawState.colorRed and
       startG == drawState.colorGreen and
       startB == drawState.colorBlue then
        return
    end

    local stack = {}
    table.insert(stack, {tx, ty})

    local width, height = activeDisplay.width_1, activeDisplay.height_1
    local r, g, b = drawState.colorRed, drawState.colorGreen, drawState.colorBlue
    local pixel = activeDisplay.setPixel

    while #stack > 0 do
        local current = table.remove(stack)
        local cx, cy = current[1], current[2]

        local left = cx
        while left >= 0 do
            local r, g, b = activeDisplay.getPixel(left, cy)
            if r ~= startR or g ~= startG or b ~= startB then
                break
            end
            left = left - 1
        end
        left = left + 1

        local right = cx
        while right <= width do
            local r, g, b = activeDisplay.getPixel(right, cy)
            if r ~= startR or g ~= startG or b ~= startB then
                break
            end
            right = right + 1
        end
        right = right - 1

        for px = left, right do
            pixel(px, cy, r, g, b)
        end

        for _, nextY in ipairs({cy - 1, cy + 1}) do
            if nextY >= 0 and nextY <= height then
                local px = left
                while px <= right do
                    local r, g, b = activeDisplay.getPixel(px, nextY)
                    if r == startR and g == startG and b == startB then
                        local segmentStart = px

                        while px <= right do
                            r, g, b = activeDisplay.getPixel(px, nextY)
                            if r ~= startR or g ~= startG or b ~= startB then
                                break
                            end
                            px = px + 1
                        end

                        table.insert(stack, {segmentStart, nextY})
                    else
                        px = px + 1
                    end
                end
            end
        end
    end
end

graphics.newImage = function (path)
    local data = love.image.newImageData(path)
    local width = data:getWidth()
    local height = data:getHeight()
    local image = newImageData(width, height, data)

    return {image = image, width = width, height = height, release = function(self)
        self.image:release()
    end, cache = nil, isCache = true}
end

graphics.draw = function (imageData, imageX, imageY)
    local f = floor
    if imageData.drawState then
        imageData.draw(imageX or 0, imageY or 0)
    else
        if imageData.isCache then
            if imageData.cache then
                local l = #imageData.cache
                for i = 1, l do
                    local x, y, r, g, b = unpack(imageData.cache[i])
                    local ox, oy = f(x + imageX + drawState.translationX), f(y + imageY + drawState.translationY)
                    activeDisplay.setPixel(ox, oy, r * drawState.ncolorRed, g * drawState.ncolorGreen, b * drawState.ncolorBlue)
                end
            else
                imageData.cache = {}
                local w, h = imageData.width - 1, imageData.height - 1
                for x = 0, w do
                    for y = 0, h do
                        local r, g, b, a = imageData.image:getPixel(x, y)
                        local ox, oy = f(x + imageX + drawState.translationX), f(y + imageY + drawState.translationY)
                        activeDisplay.setPixel(ox, oy, r * drawState.ncolorRed, g * drawState.ncolorGreen, b * drawState.ncolorBlue)
                        if a == 1 or a == 255 then
                            table.insert(imageData.cache, {x, y, r, g, b})
                        end
                    end
                end
            end
        else
            local w, h = imageData.width - 1, imageData.height - 1
            for x = 0, w do
                for y = 0, h do
                    local r, g, b = imageData.image:getPixel(x, y)
                    local ox, oy = f(x + imageX + drawState.translationX), f(y + imageY + drawState.translationY)
                    activeDisplay.setPixel(ox, oy, r * drawState.ncolorRed, g * drawState.ncolorGreen, b * drawState.ncolorBlue)
                end
            end
        end
    end
end

graphics.newFont = function(fontData, fontSize)
    if type(fontData) == 'number' then
        fontSize, fontData = fontData, defaultFont
    else
        fontData = fontData or defaultFont
    end

    fontSize = floor(fontSize or 1)
    if fontSize < 1 then fontSize = 1 end

    local font = {
        data = fontData,
        size = fontSize,
        charCache = {},
        charWidth = 5 * fontSize,
        charHeight = 7 * fontSize,
        spacing = fontSize
    }

    function font:getWidth(text)
        if not text or text == "" then return 0 end

        local maxWidth = 0
        local lines = {}
        for line in text:gmatch("[^\n]+") do
            table.insert(lines, line)
        end

        for _, line in ipairs(lines) do
            local width = 0
            local chars = {}
            for p, c in utf8.codes(line) do
                table.insert(chars, utf8.char(c))
            end

            width = (#chars - 1) * (self.charWidth + self.spacing) + self.charWidth
            if width > maxWidth then
                maxWidth = width
            end
        end

        return maxWidth
    end

    function font:getHeight(text)
        if not text or text == "" then return self.charHeight end

        local lines = {}
        for line in text:gmatch("[^\n]+") do
            table.insert(lines, line)
        end

        if not lines[1] then return self.charHeight end

        return (#lines - 1) * (self.charHeight + self.spacing) + self.charHeight
    end

    function font:getGlyph(char)
        if self.charCache[char] then
            return self.charCache[char]
        end

        local glyphData = self.data[char] or self.data['?']
        if not glyphData then
            return nil
        end

        local bitmap = {}
        local size = self.size

        for row = 1, 7 do
            local rowData = glyphData[row]
            local bitmapRow = {}

            for col = 0, 4 do
                local pixelOn = bit.band(rowData, bit.lshift(1, 4 - col)) ~= 0

                if size == 1 then
                    table.insert(bitmapRow, pixelOn)
                else
                    for _ = 1, size do
                        table.insert(bitmapRow, pixelOn)
                    end
                end
            end

            if size == 1 then
                table.insert(bitmap, bitmapRow)
            else
                for _ = 1, size do
                    table.insert(bitmap, bitmapRow)
                end
            end
        end

        self.charCache[char] = {
            bitmap = bitmap,
            width = #bitmap[1] or self.charWidth,
            height = #bitmap or self.charHeight
        }

        return self.charCache[char]
    end

    return font
end

graphics.print = function(text, x, y)
    if not text or text == "" then return end

    local font = drawState.font
    local tx, ty = floor(x + drawState.translationX), floor(y + drawState.translationY)
    local r, g, b = drawState.colorRed, drawState.colorGreen, drawState.colorBlue

    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local lineHeight = font.charHeight + font.spacing

    for lineIndex, line in ipairs(lines) do
        local lineY = ty + (lineIndex - 1) * lineHeight
        local charX = tx

        local chars = {}
        for _, c in utf8.codes(line) do
            table.insert(chars, utf8.char(c))
        end

        for _, char in ipairs(chars) do
            local glyph = font:getGlyph(char)
            if glyph then
                for row = 1, glyph.height do
                    local bitmapRow = glyph.bitmap[row]
                    if bitmapRow then
                        for col = 1, glyph.width do
                            if bitmapRow[col] then
                                activeDisplay.setPixel(charX + col - 1, lineY + row - 1, r, g, b)
                            end
                        end
                    end
                end
            end

            charX = charX + font.charWidth + font.spacing
        end
    end
end

graphics.newCanvas = function (width, height)
    local canvas = {
        drawState = {
            colorRed         = 255,
            colorGreen       = 255,
            colorBlue        = 255,
            stack            = {},
            translationX     = 0,
            translationY     = 0,
            font             = graphics.newFont(1),
        }
    }

    function canvas:release()
        if canvas.imageData then canvas.imageData:release() end
        canvas.imageData = nil
    end

    function canvas.setResolution(width, height)
        canvas.width, canvas.height = width, height

        if canvas.imageData then canvas.imageData:release() end
        canvas.imageData = newImageData(canvas.width, canvas.height)
        canvas.image = love.graphics.newImage(canvas.imageData.data)

        canvas.width_1, canvas.height_1 = width - 1, height - 1
    end

    function canvas.getResolution()
        return canvas.width, canvas.height
    end

    function canvas.clear()
        canvas.imageData:clear()
    end

    canvas.setResolution(width, height)

    function canvas.setPixel(x, y, r, g, b)
        if x >= 0 and x <= canvas.width_1 and
           y >= 0 and y <= canvas.height_1 then
            canvas.imageData:setPixel(x, y, r, g, b)
        end
    end

    canvas.getPixel = function(x, y)
        if x >= 0 and x <= canvas.width_1 and
           y >= 0 and y <= canvas.height_1 then
            return canvas.imageData:getPixel(x, y)
        end
        return 0, 0, 0
    end

    function canvas.draw(x, y)
        local pasteX, pasteY = floor(x + drawState.translationX), floor(y + drawState.translationY)
        local srcX, srcY = 0, 0
        local srcWidth, srcHeight = canvas.width, canvas.height
        if pasteX < 0 then
            srcX = -pasteX
            srcWidth = canvas.width - srcX
            pasteX = 0
        end
        if pasteY < 0 then
            srcY = -pasteY
            srcHeight = canvas.height - srcY
            pasteY = 0
        end
        if pasteX + srcWidth > display.width then
            srcWidth = display.width - pasteX
        end
        if pasteY + srcHeight > display.height then
            srcHeight = display.height - pasteY
        end
        if srcWidth <= 0 or srcHeight <= 0 then
            return
        end
        display.imageData:paste(canvas.imageData, pasteX, pasteY, srcX, srcY, srcWidth, srcHeight)
    end

    return canvas
end

graphics.setCanvas = function (canvas)
    canvas = canvas or display
    activeDisplay = canvas
    drawState = canvas == display and graphics.drawState or canvas.drawState
end

local bito         = {}

bito.draw          = display.draw
bito.clear         = display.clear
bito.getPixel      = display.getPixel
bito.setPixel      = display.setPixel
bito.setResolution = display.setResolution
bito.getResolution = display.getResolution

bito.graphics      = graphics

drawState.font = graphics.newFont(1)
graphics.setColor(255, 255, 255)

return bito
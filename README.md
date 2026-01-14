Bito - retro library 2d graphics

It works on ffi or on the functions built into love2d

The image automatically adjusts to different screens using letterbox

## API:
### bito:
local bito = require('bito')           | Load library

bito.draw()                            | Draw a virtual monitor
bito.clear()                           | It clears the virtual monitor very quickly by filling it with black
bito.resize(width, heght)              | Callback love.resize

local r, g, b, a = bito.getPixel(x, y) | Get the pixel color in the virtual monitor

bito.setPixel(x, y, r, g, b)           | Set the color of a pixel in the virtual monitor

bito.setResolution(width, height)      | Set the width and height of the virtual monitor

local w, h = bito.getResolution()      | Get the width and height of the virtual monitor


### bito.graphics:
bito.graphics.push() | Saves the current state of the chart in the stack

bito.graphics.pop()  | Loads the latest chart state from the stack


bito.graphics.setColor(r, g, b)             | Sets the drawing color

local r, g, b = bito.graphics.getColor()    | Gets the drawing color

bito.graphics.translation(x, y)             | Sets the drawing offset

local x, y = bito.graphics.getTranslation() | Gets the drawing offset

bito.graphics.setFont(font)                 | Sets the font for drawing text

local font = bito.graphics.getFont()        | Gets the text drawing font, default by default


bito.graphics.clear([r], [g], [b])                 | Clears the graphics and fills it with a specified color. If no color is provided, performs a fast fill with black

bito.graphics.pixel(x, y)                          | Draws a pixel

bito.graphics.fill(x, y)                           | Performs area fill (flood fill)

bito.graphics.line(x1, y1, x2, y2)                 | Draws a line

bito.graphics.circle(mode, x, y, radius)           | Draws a circle

bito.graphics.rectangle(mode, x, y, width, height) | Draws a rectangle

bito.graphics.draw(image or canvas, x, y)          | Draws a image or canvas

bito.graphics.print(text, x, y)                    | Draws text


local image = bito.graphics.newImage(path)               | Create new bitoImage

local font = bito.graphics.newFont([fontData], fontSize) | Create new bitoFont


local canvas = bito.graphics.newCanvas(width, height) | Creates a canvas on which you can draw

bito.graphics.setCanvas([canvas])                     | Sets the default drawing canvas to the virtual monitor


#### Image
local image = bito.graphics.newImage(path)


image.image     | Bito imageData

image.width     | Image width

image.height    | Image height

image:release() | Free up image resources

image.cache     | An array of cached pixels in an image

image.isCache   | The flag that controls whether caching is allowed, which is enabled by default


#### Font
local font = bito.graphics.newFont([fontData], fontSize)

Automatically caches character glyphs for optimization


font.data                         | fontdata

font.size                         | fontsize

font.charCache                    | Cached rendered characters

font.charWidth                    | Character width (5 * fontSize)

font.charHeight                   | Symbol height (7 * fontSize)

font.spacing                      | The size of the margins

local w = font:getWidth(text)     | Get the width occupied by the text

local h = font:getHeight(text)    | Get the height occupied by the text

local glyf = font:getGlyph(char)  | Get the glyph of a character


##### fontData:
Special font format
{
    ['0'] = {0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E},
    ['1'] = {0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E},
    ['2'] = {0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F},
    ['3'] = {0x0E, 0x11, 0x01, 0x06, 0x01, 0x11, 0x0E},
    ['4'] = {0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02},
    ['5'] = {0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E},
....


##### glyf:
glyf.bitmap | Symbol Card

glyf.width  | Glyph width

glyf.height | Glyph height


#### Canvas
local canvas = bito.graphics.newCanvas(width, height)


canvas.drawState                         | Drawing status

canvas.width                             | Canvas width

canvas.height                            | Canvas height

canvas.width_1                           | canvas.width - 1

canvas.height_1                          | canvas.height - 1

canvas.imageData                         | Bito imageData

canvas:release()                         | Free up canvas resources

canvas.setResolution(width, height)      | Set the width and height of the canvas

local w, h = canvas.getResolution()      | Get the width and height of the canvas

canvas.clear()                           | Very quickly fill the canvas with black color

canvas.setPixel(x, y, r, g, b)           | Install a pixel in the canvas

local r, g, b, a = canvas.getPixel(x, y) | Get a pixel from canvas

canvas.draw(x, y)                        | Draws canvas


#### Bito Image Data
It works on ffi rgba8. If there is no ffi, it adapts to the native functions of love2d


imageData:release()                             | Free up resources

local width = imageData:getWidth()              | Get the width

local height = imageData:getHeight()            | Get the height

imageData:clear(r, g, b)                        | Fill with the specified color, or if the color is not specified, fill with black very quickly

imageData:setPixel(x, y, r, g, b)               | Set a pixel in an image

local r, g, b, a = imageData:getPixel(x, y)     | Get a pixel in an image

imageData:mapPixel(callback)                    | Go through the pixels of the image and change the colors

imageData:paste(source, dx, dy, sx, sy, sw, sh) | love.imageData:paste works as expected


##### ffi imageData Properties
imageData.pixels | pointer imageData

imageData.data   | love imageData

imageData.size   | width * height * 4

imageData.width  | Image width

imageData.height | Image height


###### Pointer ImageData
#pragma pack(1)

typedef struct {

    uint8_t r, g, b, a;

} Pixel;


##### Properties of native functions
imageData.data   | love imageData

imageData.width  | Image width

imageData.height | Image height
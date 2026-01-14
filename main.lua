_G.love = love
local bito = require('bito')
local player = {x = 200, y = 150, image = bito.graphics.newImage('player.png')}
local font = bito.graphics.newFont(2)
function love.update(dt)
    if love.keyboard.isDown('right') then
        player.x = player.x + 60 * dt
    end
    if love.keyboard.isDown('left') then
        player.x = player.x - 60 * dt
    end
    if love.keyboard.isDown('up') then
        player.y = player.y - 60 * dt
    end
    if love.keyboard.isDown('down') then
        player.y = player.y + 60 * dt
    end
end
function love.resize(w, h)
    bito.resize(w, h)
end
function love.draw()
    local w, h = bito.getResolution()
    bito.clear()
    bito.graphics.draw(player.image, player.x, player.y)
    bito.graphics.setFont(font)
    local text = 'Bito - Топ!'
    bito.graphics.print(text, (w / 2) - font:getWidth(text) / 2, 0)
    bito.draw()
end

-- _G.love = love
-- local bito = require('bito')

-- local playerImage = bito.graphics.newImage('player.png')
-- local font2 = bito.graphics.newFont(2)
-- print('Bito 8')
-- -- playerImage.isCache = false

-- local x = 0
-- local y = 0
-- function love.update(dt)
--     if love.keyboard.isDown('right') then
--         x = x + 60 * dt
--     end
--     if love.keyboard.isDown('left') then
--         x = x - 60 * dt
--     end
--     if love.keyboard.isDown('up') then
--         y = y - 60 * dt
--     end
--     if love.keyboard.isDown('down') then
--         y = y + 60 * dt
--     end
-- end

-- local canvas = bito.graphics.newCanvas(40, 20)
-- bito.graphics.setCanvas(canvas)

-- bito.graphics.print('Тест', 0, 1)

-- bito.graphics.setCanvas()

-- function love.draw()
--     bito.graphics.translation(0, 0)

--     bito.clear()
--     -- bito.graphics.clear(50, 50, 50)

--     bito.graphics.setColor(255, 255, 255)
--     bito.graphics.translation(x, y)

--     bito.graphics.draw(playerImage, 0, 0)

--     bito.graphics.rectangle('line', 10, 10, 10, 10)

--     bito.graphics.setColor(255, 0, 0)
--     bito.graphics.fill(11, 11)

--     bito.graphics.setColor(255, 255, 255)
--     bito.graphics.circle('fill', 50, 50, 5)

--     bito.graphics.setColor(255, 255, 255)
--     bito.graphics.setFont(font2)
--     bito.graphics.print('Тест', 0, 0)

--     bito.graphics.draw(canvas, 200, 150)

--     bito.draw()

--     love.graphics.print(love.timer:getFPS())
-- end
_G.love = love
local bito = require('bito')
local g = bito.graphics

local floor, sin, cos, sqrt, abs = math.floor, math.sin, math.cos, math.sqrt, math.abs
local random, pi = math.random, math.pi
math.randomseed(7)

local W, H = 320, 180
bito.setResolution(W, H)

local BLACK, DBLUE, PURPLE, DGREEN, BROWN, GRAY, LGRAY, WHITE = 1, 2, 3, 4, 5, 6, 7, 8
local RED, ORANGE, YELLOW, GREEN, BLUE, LAV, PINK, PEACH     = 9, 10, 11, 12, 13, 14, 15, 16

local HORIZON, GROUND_Y, WATER_Y = 118, 132, 152
local MOON_X, MOON_Y, MOON_R = 70, 36, 14
local LIGHT_X, LIGHT_Y = 302, 84
local FIRE_X = 96
local FEET_Y = 141

local font1 = g.newFont(1)
local font2 = g.newFont(2)

local t = 0
local integerScale = false


local bayer = {
    {0, 8, 2, 10}, {12, 4, 14, 6}, {3, 11, 1, 9}, {15, 7, 13, 5},
}

local function bt(x, y)
    return (bayer[y % 4 + 1][x % 4 + 1] + 0.5) / 16
end

local function dither(x, y, f, c1, c2)
    g.setColor(f > bt(x, y) and c2 or c1)
    g.pixel(x, y)
end

local warm = {[1] = 2, [2] = 3, [6] = 5, [7] = 16, [5] = 10}
local function glow(cx, cy, r, strength)
    local r2 = r * r
    for y = cy - r, cy + r do
        local row = bayer[y % 4 + 1]
        for x = cx - r, cx + r do
            local dx, dy = x - cx, y - cy
            local d2 = dx * dx + dy * dy
            if d2 < r2 then
                local f = (1 - d2 / r2) * strength
                if f > (row[x % 4 + 1] + 0.5) / 16 then
                    local c = bito.getPixel(x, y)
                    local w = c and warm[c]
                    if w then bito.setPixel(x, y, w) end
                end
            end
        end
    end
end

local bg = g.newCanvas(W, H)
local blinkWindows, beacons, lamps = {}, {}, {}

local function ridge(base, amp, f1, f2, f3, ph, color, bottom)
    g.setColor(color)
    for x = 0, W - 1 do
        local h = amp * (0.55 + 0.3 * sin(x * f1 + ph) + 0.15 * sin(x * f2 + ph * 2) + 0.1 * sin(x * f3 + ph * 3))
        g.line(x, floor(base - h), x, bottom)
    end
end

local function buildBackground()
    g.setCanvas(bg)

    local stops = {BLACK, DBLUE, PURPLE, PINK}
    for y = 0, GROUND_Y do
        local f = math.min(y / HORIZON, 0.999) * 3
        local seg = floor(f)
        local c1, c2 = stops[seg + 1], stops[seg + 2]
        for x = 0, W - 1 do dither(x, y, f - seg, c1, c2) end
    end

    for y = MOON_Y - 34, MOON_Y + 34 do
        for x = MOON_X - 34, MOON_X + 34 do
            local dx, dy = x - MOON_X, y - MOON_Y
            local d = sqrt(dx * dx + dy * dy)
            if d > MOON_R and d < 34 and x >= 0 and x < W and y >= 0 and y < HORIZON then
                local base = bg:getPixel(x, y)
                dither(x, y, (1 - (d - MOON_R) / (34 - MOON_R)) * 0.45, base, LAV)
            end
        end
    end

    g.setColor(WHITE); g.circle('fill', MOON_X, MOON_Y, MOON_R)
    g.setColor(LGRAY)
    g.circle('fill', MOON_X - 5, MOON_Y - 4, 3)
    g.circle('fill', MOON_X + 5, MOON_Y + 3, 4)
    g.circle('fill', MOON_X - 2, MOON_Y + 8, 2)

    ridge(HORIZON, 30, 0.021, 0.07, 0.19, 1.0, LAV, GROUND_Y)
    ridge(HORIZON + 8, 20, 0.033, 0.09, 0.23, 4.0, DBLUE, GROUND_Y)

    local x = 0
    while x < LIGHT_X - 24 do
        local w = random(12, 26)
        local h = random(22, 56)
        local top = GROUND_Y - h
        g.setColor(BLACK); g.rectangle('fill', x, top, w, h)
        g.setColor(DBLUE); g.line(x, top, x, GROUND_Y - 1)

        if random() < 0.45 then
            local mx = x + floor(w / 2)
            g.setColor(GRAY); g.line(mx, top - 6, mx, top)
            beacons[#beacons + 1] = {mx, top - 7}
        end

        for wy = top + 4, GROUND_Y - 6, 6 do
            for wx = x + 3, x + w - 5, 5 do
                local r = random()
                if r < 0.38 then
                    g.setColor(r < 0.2 and YELLOW or (r < 0.3 and ORANGE or PEACH))
                    g.rectangle('fill', wx, wy, 2, 3)
                elseif r < 0.44 then
                    blinkWindows[#blinkWindows + 1] = {wx, wy, random() * 6.28, 0.5 + random() * 1.5}
                end
            end
        end
        x = x + w + random(0, 2)
    end

    g.setColor(DBLUE); g.rectangle('fill', LIGHT_X - 16, GROUND_Y - 8, 32, 8)
    g.setColor(GRAY);  g.rectangle('fill', LIGHT_X - 12, GROUND_Y - 8, 8, 2)
    local y0, y1 = LIGHT_Y + 6, GROUND_Y - 9
    for y = y0, y1 do
        local hw = floor(3 + 2 * (y - y0) / (y1 - y0) + 0.5)
        g.setColor(floor(y / 6) % 2 == 0 and RED or WHITE)
        g.line(LIGHT_X - hw, y, LIGHT_X + hw, y)
    end
    g.setColor(GRAY); g.rectangle('fill', LIGHT_X - 5, LIGHT_Y, 10, 6)
    g.setColor(RED)
    for i = 0, 4 do g.line(LIGHT_X - 5 + i, LIGHT_Y - i - 1, LIGHT_X + 5 - i, LIGHT_Y - i - 1) end

    g.setColor(LGRAY); g.rectangle('fill', 0, GROUND_Y, W, 2)
    g.setColor(GRAY);  g.rectangle('fill', 0, GROUND_Y + 2, W, WATER_Y - GROUND_Y - 2)
    g.setColor(DBLUE)
    g.line(0, GROUND_Y + 8, W - 1, GROUND_Y + 8)
    g.line(0, GROUND_Y + 14, W - 1, GROUND_Y + 14)
    for px = 0, W, 18 do g.line(px, GROUND_Y + 2, px - 8, GROUND_Y + 8) end
    for px = 0, W, 26 do g.line(px, GROUND_Y + 8, px - 10, GROUND_Y + 14) end

    g.setColor(GRAY)
    for px = 2, W, 10 do g.line(px, WATER_Y - 8, px, WATER_Y - 1) end
    g.setColor(LGRAY); g.line(0, WATER_Y - 8, W - 1, WATER_Y - 8)
    g.setColor(BLACK); g.rectangle('fill', 0, WATER_Y - 1, W, 1)

    for _, lx in ipairs({40, 120, 200, 264}) do
        g.setColor(GRAY); g.line(lx, GROUND_Y - 17, lx, GROUND_Y + 9)
        g.setColor(LGRAY); g.rectangle('fill', lx - 1, GROUND_Y + 9, 3, 2)
        g.setColor(BLACK); g.rectangle('fill', lx - 2, GROUND_Y - 21, 5, 2)
        lamps[#lamps + 1] = {lx, GROUND_Y - 19}
    end

    for y = WATER_Y, H - 1 do
        local f = (y - WATER_Y) / (H - WATER_Y)
        for x = 0, W - 1 do dither(x, y, f * 0.9, DBLUE, BLACK) end
    end
    g.setColor(BROWN)
    for y = WATER_Y, H - 1 do
        local src = GROUND_Y - 1 - (y - WATER_Y)
        for x = 0, W - 1 do
            local v = bg:getPixel(x, src)
            if (v == YELLOW or v == ORANGE or v == PEACH) and (x + y) % 2 == 0 then
                g.pixel(x, y)
            end
        end
    end

    g.setCanvas()
end

local KEY = GREEN

local function makeSprite(face, frame)
    local c = g.newCanvas(12, 16)
    c:clear(KEY)
    g.setCanvas(c)

    local lx = (frame == 0) and 0 or 1
    g.setColor(DBLUE)
    g.rectangle('fill', 3 + lx, 13, 2, 3)
    g.rectangle('fill', 7 - lx, 13, 2, 3)
    g.setColor(BLACK)
    g.rectangle('fill', 3 + lx, 15, 2, 1)
    g.rectangle('fill', 7 - lx, 15, 2, 1)

    g.setColor(BLUE);  g.rectangle('fill', 2, 6, 8, 7)
    g.setColor(DBLUE); g.rectangle('fill', 2, 11, 8, 2)

    g.setColor(PINK); g.rectangle('fill', 3, 5, 6, 2)
    if face > 0 then g.rectangle('fill', 1, 6, 2, 3) else g.rectangle('fill', 9, 6, 2, 3) end

    g.setColor(PEACH); g.rectangle('fill', 3, 1, 6, 5)
    g.setColor(RED)
    g.rectangle('fill', 3, 0, 6, 2)
    g.rectangle('fill', 2, 2, 8, 1)

    g.setColor(BLACK)
    if face > 0 then g.pixel(6, 3); g.pixel(8, 3) else g.pixel(3, 3); g.pixel(5, 3) end

    local fx = face > 0 and 10 or 0
    g.setColor(BLUE); g.rectangle('fill', face > 0 and 9 or 1, 8, 2, 2)
    g.setColor(GRAY); g.pixel(fx, 9)
    g.setColor(YELLOW); g.rectangle('fill', fx, 10, 2, 3)

    g.setCanvas()
    return c
end

local sprites = {
    [1]  = {[0] = makeSprite(1, 0),  [1] = makeSprite(1, 1)},
    [-1] = {[0] = makeSprite(-1, 0), [1] = makeSprite(-1, 1)},
}

local player = {x = 160, y = FEET_Y, vy = 0, face = 1, frame = 0, anim = 0, onGround = true}

local function updatePlayer(dt)
    local kd = love.keyboard.isDown
    local move = 0
    if kd('left', 'a') then move = -1 elseif kd('right', 'd') then move = 1 end

    if move ~= 0 then
        player.targetX = nil
    elseif player.targetX then
        local d = player.targetX - player.x
        if abs(d) < 2 then player.targetX = nil else move = d > 0 and 1 or -1 end
    end

    if move ~= 0 then player.face = move end
    player.x = math.max(6, math.min(W - 6, player.x + move * 70 * dt))

    if not player.onGround then
        player.vy = player.vy + 420 * dt
        player.y = player.y + player.vy * dt
        if player.y >= FEET_Y then
            player.y, player.vy, player.onGround = FEET_Y, 0, true
        end
    end

    if move ~= 0 and player.onGround then
        player.anim = player.anim + dt
        if player.anim > 0.12 then player.anim = 0; player.frame = 1 - player.frame end
    elseif move == 0 then
        player.frame = 0
    end
end

local fireRamp  = {WHITE, YELLOW, ORANGE, RED, BROWN, GRAY}
local trailRamp = {YELLOW, ORANGE, BROWN, GRAY}
local starRamp  = {WHITE, LGRAY, LAV, DBLUE}
local emberRamp = {YELLOW, ORANGE, RED, GRAY}
local burstRamps = {
    {WHITE, PEACH,  RED,    PURPLE, GRAY},
    {WHITE, BLUE,   BLUE,   DBLUE,  GRAY},
    {WHITE, GREEN,  GREEN,  DGREEN, GRAY},
    {WHITE, YELLOW, ORANGE, BROWN,  GRAY},
    {WHITE, PINK,   PINK,   PURPLE, GRAY},
}

local MAXP = 900
local parts, free, nfree = {}, {}, MAXP
for i = 1, MAXP do free[i] = {} end

local function emit(x, y, vx, vy, life, ramp, grav, drag)
    if nfree == 0 then return end
    local p = free[nfree]
    free[nfree] = nil
    nfree = nfree - 1
    p.x, p.y, p.vx, p.vy = x, y, vx, vy
    p.life, p.max, p.ramp, p.grav, p.drag = life, life, ramp, grav, drag
    parts[#parts + 1] = p
end

local function updateParticles(dt)
    local i = #parts
    while i >= 1 do
        local p = parts[i]
        p.life = p.life - dt
        if p.life <= 0 then
            parts[i] = parts[#parts]
            parts[#parts] = nil
            nfree = nfree + 1
            free[nfree] = p
        else
            local d = 1 - p.drag * dt
            if d < 0 then d = 0 end
            p.vx = p.vx * d
            p.vy = p.vy * d + p.grav * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
        i = i - 1
    end
end

local function drawParticles()
    for i = 1, #parts do
        local p = parts[i]
        local r = p.ramp
        local k = floor((1 - p.life / p.max) * #r) + 1
        if k > #r then k = #r end
        g.setColor(r[k])
        g.pixel(p.x, p.y)
    end
end

local rockets = {}

local function launch(x, targetY, ramp)
    rockets[#rockets + 1] = {x = x, y = GROUND_Y, vy = -95, ty = targetY, ramp = ramp or burstRamps[random(#burstRamps)]}
end

local function explode(r)
    local n = 70 + random(0, 40)
    for _ = 1, n do
        local a = random() * 2 * pi
        local sp = (0.35 + sqrt(random()) * 0.65) * 55
        emit(r.x, r.y, cos(a) * sp, sin(a) * sp, 0.9 + random() * 0.9, r.ramp, 38, 1.4)
    end
end

local function updateRockets(dt)
    for i = #rockets, 1, -1 do
        local r = rockets[i]
        r.y = r.y + r.vy * dt
        emit(r.x + (random() - 0.5) * 1.5, r.y, 0, random() * 10, 0.35, trailRamp, 0, 1)
        if r.y <= r.ty then
            explode(r)
            table.remove(rockets, i)
        end
    end
end

local fireAcc = 0
local function updateFire(dt)
    fireAcc = fireAcc + dt * 80
    while fireAcc >= 1 do
        fireAcc = fireAcc - 1
        emit(FIRE_X + (random() - 0.5) * 6, FEET_Y - 2, (random() - 0.5) * 14,
             -(16 + random() * 26), 0.45 + random() * 0.5, fireRamp, -20, 0.8)
    end
    if random() < dt * 6 then
        emit(FIRE_X + (random() - 0.5) * 4, FEET_Y - 4, (random() - 0.5) * 20,
             -(30 + random() * 20), 1.5, emberRamp, -4, 0.3)
    end
end

local shoot, shootT = nil, 3
local function updateShoot(dt)
    shootT = shootT - dt
    if not shoot and shootT <= 0 then
        shoot = {x = random(floor(W * 0.4), W), y = random(5, 40),
                 vx = -(110 + random() * 60), vy = 40 + random() * 30, life = 1.2}
        shootT = 4 + random() * 6
    end
    if shoot then
        shoot.x = shoot.x + shoot.vx * dt
        shoot.y = shoot.y + shoot.vy * dt
        shoot.life = shoot.life - dt
        emit(shoot.x, shoot.y, 0, 0, 0.6, starRamp, 0, 0)
        if shoot.life <= 0 then shoot = nil end
    end
end

local stars = {}
for _ = 1, 110 do
    local x, y = random(0, W - 1), random(0, 70)
    local dx, dy = x - MOON_X, y - MOON_Y
    if dx * dx + dy * dy > 36 * 36 then
        stars[#stars + 1] = {x, y, random() * 6.28, 1 + random() * 3}
    end
end

local function drawStars()
    for i = 1, #stars do
        local s = stars[i]
        local v = sin(t * s[4] + s[3])
        g.setColor(v > 0.5 and WHITE or (v > -0.3 and LGRAY or GRAY))
        g.pixel(s[1], s[2])
    end
end

local clouds = {}
for i = 1, 6 do
    clouds[i] = {x = random(0, W + 80), y = random(14, 58), speed = 3 + random() * 5, sc = 0.7 + random() * 0.8}
end
local puffs = {{0, 0, 7}, {9, 2, 6}, {-9, 3, 5}, {4, -4, 5}, {16, 4, 4}}

local function updateClouds(dt)
    for i = 1, #clouds do
        local c = clouds[i]
        c.x = c.x + c.speed * dt
        if c.x > W + 80 then c.x = 0 end
    end
end

local function drawClouds()
    for pass = 1, 2 do
        g.setColor(pass == 1 and LAV or DBLUE)
        local off = (pass == 1) and -1 or 0
        for i = 1, #clouds do
            local c = clouds[i]
            local cx = floor(c.x) - 40
            for j = 1, #puffs do
                local p = puffs[j]
                g.circle('fill', cx + p[1] * c.sc + off, c.y + p[2] * c.sc + off, p[3] * c.sc)
            end
        end
    end
end

local cubeV = {{-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},{-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}}
local cubeE = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
local cubeCol = {RED, ORANGE, YELLOW, GREEN, BLUE, PINK}
local cpx, cpy = {}, {}

local function drawCube(cx, cy, size)
    local ay, ax = t * 0.9, t * 0.6
    local cay, say, cax, sax = cos(ay), sin(ay), cos(ax), sin(ax)
    for i = 1, 8 do
        local v = cubeV[i]
        local x1 = v[1] * cay + v[3] * say
        local z1 = -v[1] * say + v[3] * cay
        local y1 = v[2] * cax - z1 * sax
        local z2 = v[2] * sax + z1 * cax
        local f = 3.5 / (3.5 + z2)
        cpx[i], cpy[i] = cx + x1 * size * f, cy + y1 * size * f
    end
    local shift = floor(t * 3)
    for i = 1, 12 do
        local e = cubeE[i]
        g.setColor(cubeCol[(i + shift) % #cubeCol + 1])
        g.line(cpx[e[1]], cpy[e[1]], cpx[e[2]], cpy[e[2]])
    end
    local sx, sy = cx + cos(t * 2) * 30, cy + sin(t * 2) * 10
    g.setColor(WHITE); g.circle('fill', sx, sy, 2)
    g.setColor(LAV);   g.circle('line', sx, sy, 3)
end

local function drawBeam()
    local th = pi + sin(t * 0.7) * 0.45 - 0.12
    local dx, dy = cos(th), sin(th)
    local nx, ny = -dy, dx
    g.setColor(YELLOW)
    for s = 4, 150 do
        local hw = s * 0.045 + 0.5
        local bx, by = LIGHT_X + dx * s, LIGHT_Y + 3 + dy * s
        local fade = (1 - s / 150) * 0.8
        local o = -hw
        while o <= hw do
            local px, py = floor(bx + nx * o), floor(by + ny * o)
            if fade > bt(px, py) then g.pixel(px, py) end
            o = o + 1
        end
    end
    g.setColor(YELLOW); g.rectangle('fill', LIGHT_X - 3, LIGHT_Y + 1, 6, 4)
    g.setColor(WHITE);  g.pixel(LIGHT_X, LIGHT_Y + 2)
end

local function drawCityLights()
    g.setColor(YELLOW)
    for i = 1, #blinkWindows do
        local w = blinkWindows[i]
        if sin(t * w[4] + w[3]) > -0.2 then g.rectangle('fill', w[1], w[2], 2, 3) end
    end
    g.setColor(RED)
    for i = 1, #beacons do
        local b = beacons[i]
        if sin(t * 3 + b[1]) > 0.4 then g.pixel(b[1], b[2]) end
    end
    for i = 1, #lamps do
        local l = lamps[i]
        glow(l[1], l[2] + 2, 13, 0.55 + 0.05 * sin(t * 9 + l[1]))
        g.setColor(YELLOW); g.rectangle('fill', l[1] - 1, l[2], 3, 2)
    end
end

local function drawWater()
    for y = WATER_Y, H - 1, 2 do
        local k = y - WATER_Y
        local off = floor(sin(t * 1.7 + k * 0.55) * 5)
        g.setColor(k % 4 == 0 and BLUE or LAV)
        local x = ((k * 7 + off) % 24) - 24
        while x < W do
            g.line(x, y, x + 3 + (k % 5), y)
            x = x + 24
        end
    end
    for y = WATER_Y, H - 1, 2 do
        local k = y - WATER_Y
        local cx = MOON_X + floor(sin(t * 2.2 + k * 0.5) * (2 + k * 0.25))
        local hw = math.max(1, floor(9 - k * 0.25 + sin(t * 3 + k) * 2))
        g.setColor(k < 8 and WHITE or LGRAY)
        g.line(cx - hw, y, cx + hw, y)
    end
end

local function drawCampfire()
    glow(FIRE_X, FEET_Y - 2, floor(30 + sin(t * 13) * 2 + random() * 2), 0.65)
    g.setColor(GRAY)
    g.rectangle('fill', FIRE_X - 9, FEET_Y + 1, 2, 1)
    g.rectangle('fill', FIRE_X + 8, FEET_Y + 1, 2, 1)
    g.setColor(BROWN)
    g.line(FIRE_X - 6, FEET_Y + 2, FIRE_X + 5, FEET_Y - 1)
    g.line(FIRE_X - 6, FEET_Y + 3, FIRE_X + 5, FEET_Y)
    g.line(FIRE_X + 6, FEET_Y + 2, FIRE_X - 5, FEET_Y - 1)
    g.line(FIRE_X + 6, FEET_Y + 3, FIRE_X - 5, FEET_Y)
end

local function drawPlayer()
    glow(floor(player.x + player.face * 5), floor(player.y - 7), 11, 0.5)
    g.setColor(BLACK)
    g.line(floor(player.x - 4), FEET_Y, floor(player.x + 4), FEET_Y)
    g.draw(sprites[player.face][player.frame], floor(player.x - 6), floor(player.y - 16), KEY)
end

local function drawHUD()
    g.setFont(font2)
    local title = "BITO - ночной город"
    local x = floor((W - font2:getWidth(title)) / 2)
    g.setColor(PURPLE); g.print(title, x + 1, 3)
    g.setColor(WHITE);  g.print(title, x, 2)

    g.setFont(font1)
    g.setColor(LGRAY)
    g.print("FPS " .. love.timer.getFPS() .. "  частиц " .. #parts, 3, H - 19)
    g.print("←→ ходьба  ↑ прыжок  клик: салют  I: масштаб", 3, H - 10)
end

buildBackground()

local autoT = 1

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end
    t = t + dt

    updatePlayer(dt)
    updateClouds(dt)
    updateShoot(dt)
    updateRockets(dt)
    updateFire(dt)
    updateParticles(dt)

    autoT = autoT - dt
    if autoT <= 0 then
        autoT = 1.5 + random() * 2.5
        launch(random(40, W - 40), random(22, 70))
    end

    bito.setPaletteColor(ORANGE, 255, 150 + floor(random() * 28), 0)
end

function love.draw()
    g.draw(bg, 0, 0)

    drawStars()
    drawClouds()
    drawCube(262, 40, 16)
    drawBeam()
    drawCityLights()
    drawWater()
    drawCampfire()
    drawPlayer()
    drawParticles()
    drawHUD()

    bito.draw()
end

function love.resize(w, h)
    bito.resize(w, h)
end

function love.keypressed(key)
    if (key == 'up' or key == 'w' or key == 'space') and player.onGround then
        player.vy, player.onGround = -150, false
    elseif key == 'f' then
        launch(random(40, W - 40), random(22, 70))
    elseif key == 'i' then
        integerScale = not integerScale
        bito.setIntegerScale(integerScale)
    elseif key == 'escape' then
        love.event.quit()
    end
end

function love.mousepressed(x, y)
    local px, py = bito.screenToPixel(x, y)
    if py < GROUND_Y - 4 then
        launch(math.max(10, math.min(W - 10, px)), math.max(12, py))
    else
        player.targetX = px
    end
end
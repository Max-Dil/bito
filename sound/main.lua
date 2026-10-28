local ffi = require('ffi')

local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local sin = math.sin
local random = math.random
local PI2 = math.pi * 2

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

local INPUT_FILE  = "notes.txt"
local OUTPUT_BSD  = "music.bsd"
local OUTPUT_PNG  = "music.png"
local DEFAULT_BPM = 130

local statusText = ""
local statsText  = ""

local function saveCompressedAsPng(compressedData, filename)
    local dataLen = #compressedData
    local totalPixels = 1 + math.ceil(dataLen / 4)
    local side = math.max(2, math.ceil(math.sqrt(totalPixels)))
    local imgData = love.image.newImageData(side, side)

    local b0 = dataLen % 256
    local b1 = math.floor(dataLen / 256) % 256
    local b2 = math.floor(dataLen / 65536) % 256
    imgData:setPixel(0, 0, love.math.colorFromBytes(b0, b1, b2, 255))

    local byteIdx = 1
    for y = 0, side - 1 do
        for x = 0, side - 1 do
            if not (x == 0 and y == 0) and byteIdx <= dataLen then
                local r = compressedData:byte(byteIdx)     or 0
                local g = compressedData:byte(byteIdx + 1) or 0
                local b = compressedData:byte(byteIdx + 2) or 0
                local a = compressedData:byte(byteIdx + 3) or 255
                imgData:setPixel(x, y, love.math.colorFromBytes(r, g, b, a))
                byteIdx = byteIdx + 4
            end
        end
    end

    imgData:encode("png", filename)
end

local function convertNotes()
    if not love.filesystem.getInfo(INPUT_FILE) then
        statusText = "ERROR: File " .. INPUT_FILE .. " not found in the project folder!"
        return
    end

    local rawStream = love.filesystem.read(INPUT_FILE)
    local cleanStream = rawStream:gsub("%s+", "")

    if #cleanStream == 0 then
        statusText = "ERROR: File " .. INPUT_FILE .. " is empty!"
        return
    end

    local compressed = love.data.compress("string", "zlib", cleanStream, 9)

    love.filesystem.write(OUTPUT_BSD, compressed)

    saveCompressedAsPng(compressed, OUTPUT_PNG)

    bisond.load("preview", OUTPUT_BSD, DEFAULT_BPM)

    local steps = math.floor(#cleanStream / 4)
    local ratio = math.floor((#compressed / #cleanStream) * 100)

    statusText = "SUCCESSFULLY CONVERTED!"
    statsText = string.format(
        "Source stream: %d chars (%d steps)\n" ..
        "%s size (zlib): %d bytes (%d%% of source)\n" ..
        "Saved to: %s\n\n" ..
        "[SPACE] - Play / Stop\n" ..
        "[R]     - Rebuild from %s\n" ..
        "[O]     - Open output folder",
        #cleanStream, steps,
        OUTPUT_BSD, #compressed, ratio,
        love.filesystem.getSaveDirectory(),
        INPUT_FILE
    )
end

function love.load()
    love.window.setTitle("bisond Converter (notes.txt -> .bsd / .png)")
    love.window.setMode(560, 260)
    convertNotes()
end

function love.update(dt)
    bisond.update()
end

function love.keypressed(key)
    if key == "space" then
        if bisond.isPlaying("preview") then
            bisond.stop("preview")
        else
            bisond.play("preview", true, 0.9)
        end
    elseif key == "r" then
        convertNotes()
    elseif key == "o" then
        love.system.openURL("file://" .. love.filesystem.getSaveDirectory())
    elseif key == "escape" then
        love.event.quit()
    end
end

function love.draw()
    love.graphics.clear(0.1, 0.11, 0.14)

    love.graphics.setColor(0.3, 0.9, 0.5)
    love.graphics.print(statusText, 20, 20)

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print(statsText, 20, 55)

    if bisond.isPlaying("preview") then
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.print("> PLAYING PREVIEW (LOOP)...", 20, 215)
    end
end
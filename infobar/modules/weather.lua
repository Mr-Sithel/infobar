-- weather.lua
-- HorizonXI-safe weather module for InfoBar (using meteorologist signature)
-- https://github.com/clanofartisans/meteorologist/blob/master/meteorologist.lua
-- Credit to Matix and Hugin for making the weather addon.

local weather = {}

weather.table = {
    [0]  = 'Clear',
    [1]  = 'Sunshine',
    [2]  = 'Clouds',
    [3]  = 'Fog',
    [4]  = 'Fire',
    [5]  = 'Fire •2',
    [6]  = 'Water',
    [7]  = 'Water •2',
    [8]  = 'Earth',
    [9]  = 'Earth •2',
    [10] = 'Wind',
    [11] = 'Wind •2',
    [12] = 'Ice',
    [13] = 'Ice •2',
    [14] = 'Thunder',
    [15] = 'Thunder •2',
    [16] = 'Light',
    [17] = 'Light •2',
    [18] = 'Dark',
    [19] = 'Dark •2',
}

weather.colors = {
    ["Clear"]       = {1.00, 0.90, 1.00, 1.0},
    ["Sunshine"]    = {1.00, 1.00, 0.60, 1.0},
    ["Clouds"]      = {0.80, 0.80, 0.80, 1.0},
    ["Fog"]         = {0.70, 0.70, 0.70, 1.0},

    ["Fire"]        = {1.00, 0.27, 0.00, 1.0},
    ["Fire •2"]     = {1.00, 0.10, 0.00, 1.0},

    ["Water"]       = {0.12, 0.56, 1.00, 1.0},
    ["Water •2"]    = {0.00, 0.40, 1.00, 1.0},

    ["Earth"]       = {1.00, 0.84, 0.00, 1.0},
    ["Earth •2"]    = {0.90, 0.70, 0.00, 1.0},

    ["Wind"]        = {0.20, 0.80, 0.20, 1.0},
    ["Wind •2"]     = {0.10, 0.60, 0.10, 1.0},

    ["Ice"]         = {0.53, 0.81, 0.98, 1.0},
    ["Ice •2"]      = {0.40, 0.70, 0.90, 1.0},

    ["Thunder"]     = {0.88, 0.60, 1.00, 1.0},
    ["Thunder •2"]  = {0.75, 0.40, 1.00, 1.0},

    ["Light"]       = {0.85, 0.90, 1.00, 1.0},
    ["Light •2"]    = {0.85, 0.90, 1.00, 1.0},

    ["Dark"]        = {0.52, 0.00, 0.75, 1.0},
    ["Dark •2"]     = {0.40, 0.00, 0.60, 1.0},
}

-- Cached pointer (set once)
local weather_ptr = nil

local function init_pointer()
    if weather_ptr ~= nil then return end

    local addr = ashita.memory.find('FFXiMain.dll', 0, '66A1????????663D????72', 0, 0)
    if addr ~= 0 then
        weather_ptr = ashita.memory.read_uint32(addr + 0x02)
    end
end

local function get_weather_id()
    init_pointer()

    if not weather_ptr or weather_ptr == 0 then
        return 0
    end

    return ashita.memory.read_uint8(weather_ptr)
end

function weather.get()
    return weather.table[get_weather_id()] or "Clear"
end

function weather.get_color()
    return weather.colors[weather.get()] or {1,1,1,1}
end

return weather

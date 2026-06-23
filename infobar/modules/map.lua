-- Credit to loonsies for creating the boussole addon.
-- Parts of Boussole was used to grab player position on grid. Example (I-5)
-- https://github.com/loonsies/boussole

local map = {}

local mem = ashita.memory
local ffi = require('ffi')

local MAP_TABLE_SIG = '8A0D????????5333C05684C95774??8A5424188B7424148B7C2410B9'
local ENTRY_SIZE = 0x0E

ffi.cdef [[
    typedef int32_t (__thiscall* CheckFloorNumber_f)(void* pThis, float X, float Y, float Z);
]]

map.table_ptr = 0
map.floor_func = nil
map.floor_this_ptr = nil
map.current_map_data = nil

---------------------------------------------------------
-- FIND MAP TABLE
---------------------------------------------------------
function map.find_map_table()
    local addr = mem.find('FFXiMain.dll', 0, MAP_TABLE_SIG, 0, 0)
    if addr == 0 then return nil end
    map.table_ptr = mem.read_uint32(addr + 0x1C)
    return map.table_ptr
end

---------------------------------------------------------
-- INIT FLOOR FUNCTION
---------------------------------------------------------
function map.init_floor_function()
    local func_addr = mem.find('FFXiMain.dll', 0, '8B542408568D4424108BF18B4C2410508B44240C', 0, 0)
    local this_addr = mem.find('FFXiMain.dll', 0, '8B7424148B4424108B7C240C8B0D', 0x0E, 0)

    if func_addr == 0 or this_addr == 0 then return false end

    map.floor_func = ffi.cast('CheckFloorNumber_f', func_addr)
    map.floor_this_ptr = this_addr
    return true
end

---------------------------------------------------------
-- READ MAP ENTRY
---------------------------------------------------------
function map.read_entry(index)
    if map.table_ptr == 0 then
        if not map.find_map_table() then return nil end
    end

    local base = map.table_ptr + (index * ENTRY_SIZE)

    local zone = mem.read_uint16(base + 0x00)
    local floorId = mem.read_uint8(base + 0x02)
    local flags = mem.read_uint8(base + 0x04)

    local scale_raw = mem.read_uint8(base + 0x05)
    local scale = (scale_raw >= 0x80) and (scale_raw - 0x100) or scale_raw

    local offsetX_raw = mem.read_uint16(base + 0x0A)
    local offsetX = (offsetX_raw >= 0x8000) and (offsetX_raw - 0x10000) or offsetX_raw

    local offsetY_raw = mem.read_uint16(base + 0x0C)
    local offsetY = (offsetY_raw >= 0x8000) and (offsetY_raw - 0x10000) or offsetY_raw

    return {
        ZoneId = zone,
        FloorId = floorId,
        Scale = scale,
        OffsetX = offsetX,
        OffsetY = offsetY,
        _index = index,
    }
end

---------------------------------------------------------
-- GET PLAYER ZONE
---------------------------------------------------------
function map.get_player_zone()
    local party = AshitaCore:GetMemoryManager():GetParty()
    if party then return party:GetMemberZone(0) end
    return nil
end

---------------------------------------------------------
-- GET PLAYER POSITION
---------------------------------------------------------
function map.get_player_position()
    local ent = GetPlayerEntity()
    if ent then
        return ent.Movement.LocalPosition.X,
               ent.Movement.LocalPosition.Y,
               ent.Movement.LocalPosition.Z
    end
    return nil, nil, nil
end

---------------------------------------------------------
-- GET FLOOR ID
---------------------------------------------------------
function map.get_floor_id(x, y, z)
    if not map.floor_func or not map.floor_this_ptr then
        if not map.init_floor_function() then return nil end
    end

    local this_ptr_val = mem.read_uint32(mem.read_uint32(map.floor_this_ptr))
    if this_ptr_val == 0 then return nil end

    local this_obj = ffi.cast('void*', this_ptr_val)
    return map.floor_func(this_obj, x, z, y)
end

---------------------------------------------------------
-- FIND ENTRY FOR ZONE + FLOOR
---------------------------------------------------------
function map.find_entry(zoneId, floorId)
    if map.table_ptr == 0 then
        if not map.find_map_table() then return nil end
    end

    -- brute force search (fast enough, table is tiny)
    for i = 0, 2048 do
        local entry = map.read_entry(i)
        if entry and entry.ZoneId == zoneId and entry.FloorId == floorId then
            return entry
        end
    end

    return nil
end

---------------------------------------------------------
-- GET CURRENT MAP ENTRY
---------------------------------------------------------
function map.get_current_map()
    local zone = map.get_player_zone()
    if not zone then return nil end

    local x, y, z = map.get_player_position()
    if not x then return nil end

    local floorId = map.get_floor_id(x, y, z)
    if not floorId then return nil end

    return map.find_entry(zone, floorId)
end

---------------------------------------------------------
-- WORLD → MAP PIXELS
---------------------------------------------------------
function map.world_to_map_coords(entry, x, y, z)
    local scale = math.abs(entry.Scale)
    if scale == 0 then return nil end

    local divisor = 2560.0 / scale
    local v = 1.0 / divisor

    local mapX = x * v * 512.0
    local mapY = -(y * v * 512.0)

    return mapX, mapY
end

---------------------------------------------------------
-- MAP PIXELS → GRID
---------------------------------------------------------
function map.map_to_grid_coords(entry, mapX, mapY)
    local gridDiv = 32
    local gridOff = 16

    local gx = math.floor((mapX - entry.OffsetX - gridOff) / gridDiv)
    local gy = math.floor((mapY - entry.OffsetY - gridOff) / gridDiv) + 1

    gx = math.max(0, math.min(25, gx))
    local letter = string.char(65 + gx)

    return letter, gy
end

---------------------------------------------------------
-- FINAL: GET PLAYER GRID POSITION
---------------------------------------------------------
function map.get_player_grid_position()
    local entry = map.get_current_map()
    if not entry then return nil end

    local x, y, z = map.get_player_position()
    local mapX, mapY = map.world_to_map_coords(entry, x, y, z)
    if not mapX then return nil end

    return map.map_to_grid_coords(entry, mapX, mapY)
end

return map

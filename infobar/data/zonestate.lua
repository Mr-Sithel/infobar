local ZoneState = {
    zoneId        = nil,
    zoneName      = '',
    regionName    = '',
    callbacks     = {},
    lastPlayerId  = 0,   -- NEW: track active character
}

local regions      = require('data/regions')
local regionZones  = require('data/regionZones')

---------------------------------------------------------
-- Helpers
---------------------------------------------------------

local function getRegionNameById(id)
    for _, region in pairs(regions) do
        if region.id == id then
            return region.en
        end
    end
    return nil
end

local function getRegionIDByZoneID(zoneID)
    for regionID, zoneIDs in pairs(regionZones.map) do
        for _, id in ipairs(zoneIDs) do
            if id == zoneID then
                return regionID
            end
        end
    end
    return nil
end

local function safePlayer()
    local ent = GetPlayerEntity()
    if ent == nil or ent.ServerId == nil or ent.ServerId == 0 then
        return nil
    end
    return ent
end

---------------------------------------------------------
-- Internal: Refresh zone + region
---------------------------------------------------------

function ZoneState.refresh()
    -------------------------------------------------
    -- 1) Detect character swap
    -------------------------------------------------
    local ent = safePlayer()
    if ent then
        if ZoneState.lastPlayerId ~= ent.ServerId then
            -- Character changed!
            ZoneState.lastPlayerId = ent.ServerId

            -- Force zone refresh
            ZoneState.zoneId = nil
        end
    end

    -------------------------------------------------
    -- 2) Read zone safely
    -------------------------------------------------
    local party = AshitaCore:GetMemoryManager():GetParty()
    if not party then return end

    local zid = party:GetMemberZone(0)
    if not zid or zid == 0 then return end

    local zname = AshitaCore:GetResourceManager():GetString('zones.names', zid)
    if not zname then return end

    local regionID = getRegionIDByZoneID(zid)
    local rname = regionID and getRegionNameById(regionID) or ''

    -------------------------------------------------
    -- 3) Only fire callbacks if zone changed
    -------------------------------------------------
    local changed = (zid ~= ZoneState.zoneId)

    ZoneState.zoneId     = zid
    ZoneState.zoneName   = zname
    ZoneState.regionName = rname

    if changed then
        for _, cb in ipairs(ZoneState.callbacks) do
            cb(zid, zname, rname)
        end
    end
end

---------------------------------------------------------
-- Public: Register callback
---------------------------------------------------------

function ZoneState.onChange(cb)
    table.insert(ZoneState.callbacks, cb)
end

---------------------------------------------------------
-- Public: Initialize event hooks
---------------------------------------------------------

function ZoneState.init()

    -------------------------------------------------
    -- 1) Normal zoning (0x0A)
    -------------------------------------------------
    ashita.events.register('packet_in', 'zonestate_zonepacket', function(e)
        if e.id == 0x0A then
            ashita.tasks.once(1, function()
                ZoneState.refresh()
            end)
        end
    end)

    -------------------------------------------------
    -- 2) Character login (memory not ready immediately)
    -------------------------------------------------
    ashita.events.register('login', 'zonestate_login', function()
        ashita.tasks.once(1, function() ZoneState.refresh() end)
        ashita.tasks.once(10, function() ZoneState.refresh() end)
    end)

    -------------------------------------------------
    -- 3) Addon load (initial)
    -------------------------------------------------
    ashita.events.register('load', 'zonestate_load', function()
        ashita.tasks.once(10, function() ZoneState.refresh() end)
    end)

    -------------------------------------------------
    -- 4) Heartbeat: detect character swap reliably
    -------------------------------------------------
    ashita.events.register('d3d_present', 'zonestate_heartbeat', function()
        ZoneState.refresh()
    end)
end

return ZoneState

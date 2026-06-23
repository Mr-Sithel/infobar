local direction = {}

-- Convert FFXI heading radians into compass direction
local function to_compass(heading)
    if not heading then return '--' end

    local degrees = math.deg(heading)
    local adjusted = (degrees + 90) % 360
    if adjusted < 0 then
        adjusted = adjusted + 360
    end

    if     adjusted >= 337.5 or adjusted < 22.5  then return 'N '
    elseif adjusted < 67.5   then return 'NE'
    elseif adjusted < 112.5  then return 'E '
    elseif adjusted < 157.5  then return 'SE'
    elseif adjusted < 202.5  then return 'S '
    elseif adjusted < 247.5  then return 'SW'
    elseif adjusted < 292.5  then return 'W '
    else                          return 'NW'
    end
end

-- Throttle state
local last_update = 0
local interval    = 1 / 8 
local cached      = '--'

function direction.get()
    local now = os.clock()
    if (now - last_update) < interval then
        return cached
    end
    last_update = now

    local mm = AshitaCore:GetMemoryManager()
    if not mm then
        cached = '--'
        return cached
    end

    local entity = mm:GetEntity()
    local party  = mm:GetParty()

    if not entity or not party then
        cached = '--'
        return cached
    end

    local idx = party:GetMemberTargetIndex(0)
    if not idx or idx == 0 then
        cached = '--'
        return cached
    end

    local heading = entity:GetHeading(idx)
    cached = to_compass(heading)
    return cached
end

function direction.color_for(dir)
    if dir == 'N ' then
        return { 0.75, 0.20, 0.20, 1.0 } -- red
    end
    return { 0.90, 0.75, 0.20, 1.0 }     -- yellow
end

return direction

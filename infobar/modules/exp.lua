local exp_module = {}

---------------------------------------------------------
-- EXP CHAIN CONFIGURATION & TABLES
---------------------------------------------------------
exp_module.Chains = {}

exp_module.Chains.MaxTimes = {
    { level = 10, maxtime = { 80,  80,  60,  40,  30,  15 } },
    { level = 20, maxtime = { 130, 130, 110, 80,  60,  25 } },
    { level = 30, maxtime = { 160, 150, 120, 90,  60,  30 } },
    { level = 40, maxtime = { 200, 200, 170, 130, 80,  40 } },
    { level = 50, maxtime = { 290, 290, 230, 170, 110, 50 } },
    { level = 99, maxtime = { 300, 300, 240, 180, 120, 60 } },
}

--[[
exp_module.Chains.MaxTimes = {
    { lvl = 10, maxtime={ 50,  40,  30,  20,  10,  6,  }, },
    { lvl = 20, maxtime={ 100, 80,  60,  40,  20,  8,  }, },
    { lvl = 30, maxtime={ 150, 120, 90,  60,  30,  10, }, },
    { lvl = 40, maxtime={ 200, 160, 120, 80,  40,  40, }, },
    { lvl = 50, maxtime={ 250, 200, 150, 100, 50,  50, }, },
    { lvl = 60, maxtime={ 300, 240, 180, 120, 90,  60, }, },
    { lvl = 99, maxtime={ 360, 300, 240, 165, 105, 60, }, },
}--]]

---------------------------------------------------------
-- TRACKED STATE
---------------------------------------------------------
local exp_data = {
    current_exp  = 0,
    max_exp      = 0,
    tnl          = 0,

    lp_current   = 0,
    lp_max       = 10000,
    merit_count  = 0,

    chain_count  = 0,
    chain_time   = 300,
    chain_start  = 0,

    session_exp  = 0,
    start_time   = os.time(),
    exp_per_hr   = 0,
    
    last_kill_time = 0,
    xp_kills       = {},
}

---------------------------------------------------------
-- HELPER: HANDLES LEVEL SYNC
---------------------------------------------------------
local function GetEffectiveLevel()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if not player then return 75 end

    local party = AshitaCore:GetMemoryManager():GetParty()
    if party and party:GetMemberIsActive(0) == 1 then
        local status, syncLevel = pcall(function() return party:GetMemberSyncLevel(0) end)
        if status and syncLevel and syncLevel > 0 then
            return syncLevel
        end
    end
    
    return player:GetMainJobLevel() or 75
end

---------------------------------------------------------
-- HELPER: CHECK IF PLAYER IS IN LP/MERIT MODE
---------------------------------------------------------
local function is_lp_mode()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if not player then return false end

    if GetEffectiveLevel() < 75 then
        return false
    end

    return player:GetIsLimitModeEnabled()
        or player:GetIsExperiencePointsLocked()
        or player:GetExpCurrent() == 55999
end

exp_module.format_comma = function(amount)
    if not amount then return "0" end
    local formatted = tostring(amount)
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

---------------------------------------------------------
-- CHAIN LOGIC
---------------------------------------------------------
exp_module.Chains.OnChain = function(chainNumber)
    chainNumber = chainNumber or 0

    exp_data.chain_count = chainNumber
    exp_data.chain_start = os.time()

    local playerLevel = GetEffectiveLevel()
    local nextChain   = math.min(chainNumber + 1, 6)

    for _, bucket in ipairs(exp_module.Chains.MaxTimes) do
        if playerLevel <= bucket.level then
            exp_data.chain_time = bucket.maxtime[nextChain] or exp_data.chain_time
            break
        end
    end
end

exp_module.Chains.End = function()
    exp_data.chain_count = 0
    exp_data.chain_time  = 0
    exp_data.chain_start = 0
end

---------------------------------------------------------
-- INITIALIZE
---------------------------------------------------------
exp_module.on_load = function()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if not player then return end

    exp_data.current_exp = player:GetExpCurrent()
    exp_data.max_exp     = player:GetExpNeeded()
    exp_data.tnl         = exp_data.max_exp - exp_data.current_exp

    if is_lp_mode() then
        local lp = player:GetLimitPoints()
        if lp and lp > 0 then
            exp_data.lp_current = lp
        else
            exp_data.lp_current = exp_data.current_exp % 10000
        end

        local merits = player:GetMeritPoints()
        if merits then
            exp_data.merit_count = merits
        end
    end
end

---------------------------------------------------------
-- RESET FOR ZONING
---------------------------------------------------------
exp_module.reset_all = function()
    exp_module.Chains.End()
    exp_data.last_kill_time = 0
    exp_data.xp_kills       = {}
end

---------------------------------------------------------
-- PACKET IN
---------------------------------------------------------
ashita.events.register('packet_in', 'exp_packet_in', function(e)
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if not player then return end

    local data = e.data_modified or e.data

    -- Packet 0x02D: EXP / LP / Chain Updates
    if e.id == 0x02D then
        local pId   = struct.unpack("I", data, 0x05)        -- EXP from your character
        local val   = struct.unpack("I", data, 0x11)        -- EXP gained
        local val2  = struct.unpack("I", data, 0x15)        -- EXP chain count
        local msgId = struct.unpack("H", data, 0x19) % 1024 -- Chat log message

        local playerEntity = GetPlayerEntity()
        if playerEntity and pId == playerEntity.ServerId then
            if msgId == 8 or msgId == 105 or msgId == 253 or msgId == 371 or msgId == 372 then
                local now = os.clock()

                -- Timeout idle check
                local TIMEOUT_SECONDS = 600
                if #exp_data.xp_kills > 0 then
                    local last_kill = exp_data.xp_kills[#exp_data.xp_kills].timestamp
                    if (now - last_kill) > TIMEOUT_SECONDS then
                        exp_data.xp_kills    = {}
                        exp_data.session_exp = 0
                        exp_data.start_time  = os.time()
                        exp_data.exp_per_hr  = 0
                    end
                end

                exp_data.session_exp = exp_data.session_exp + val

                if #exp_data.xp_kills > 0 and exp_data.xp_kills[1].timestamp == nil then
                    exp_data.xp_kills = {}
                end

                table.insert(exp_data.xp_kills, { timestamp = now, xp = val })

                if #exp_data.xp_kills > 20 then
                    table.remove(exp_data.xp_kills, 1)
                end

                -- XP/hr Calculation
                local MIN_KILLS = 2
                if #exp_data.xp_kills >= MIN_KILLS then
                    local oldest_kill = exp_data.xp_kills[1]
                    local window_time = now - oldest_kill.timestamp
                    
                    local window_xp = 0
                    for i = 2, #exp_data.xp_kills do
                        window_xp = window_xp + exp_data.xp_kills[i].xp
                    end

                    if window_time > 0 then
                        exp_data.exp_per_hr = math.floor((window_xp / window_time) * 3600)
                    end
                else
                    local elapsed = os.time() - exp_data.start_time
                    if elapsed > 0 then
                        exp_data.exp_per_hr = math.floor((exp_data.session_exp / elapsed) * 3600)
                    end
                end

                -- UPDATE CHAIN TIMER
                local is_em_or_higher = (val >= 100) or (val2 > 0)
                if is_em_or_higher then
                    exp_module.Chains.OnChain(val2)
                end

                -- Update LP / EXP Totals
                if is_lp_mode() then
                    exp_data.lp_current = exp_data.lp_current + val
                    if exp_data.lp_current >= 10000 then
                        exp_data.merit_count = exp_data.merit_count + math.floor(exp_data.lp_current / 10000)
                        exp_data.lp_current  = exp_data.lp_current % 10000
                    end
                else
                    exp_data.current_exp = exp_data.current_exp + val
                    if exp_data.current_exp > exp_data.max_exp then
                        exp_data.current_exp = exp_data.max_exp - 1
                    end
                end

            elseif msgId == 50 or msgId == 368 then
                exp_data.merit_count = val
            end
        end
    end

    -- Packet 0x061: General Stats & EXP update
    if e.id == 0x061 then
        exp_data.current_exp = struct.unpack("H", data, 0x11)
        exp_data.max_exp     = struct.unpack("H", data, 0x13)
        exp_data.tnl         = exp_data.max_exp - exp_data.current_exp
    end

    -- Packet 0x063: Merit & Limit Point update
    if e.id == 0x063 then
        if data:byte(5) == 2 then
            exp_data.lp_current  = struct.unpack("H", data, 9)
            exp_data.merit_count = data:byte(11) % 128
            exp_data.lp_max      = 10000
        end
    end

    -- Zone Change
    if e.id == 0x00A then
        exp_module.reset_all()
        exp_data.session_exp = 0
        exp_data.start_time  = os.time()
        exp_data.exp_per_hr  = 0
    end
end)

---------------------------------------------------------
-- HELPER: CALCULATE REMAINING CHAIN TIME
---------------------------------------------------------
exp_module.get_chain_time_remaining = function()
    if exp_data.chain_time == 0 or exp_data.chain_start == 0 then
        return 0
    end

    local elapsedTime   = os.time() - exp_data.chain_start
    local timeRemaining = exp_data.chain_time - elapsedTime

    if timeRemaining <= 0 then
        exp_module.Chains.End()
        return 0
    end

    return timeRemaining
end

---------------------------------------------------------
-- HELPER: CALCULATE Limit Points / EXP RATE
---------------------------------------------------------
exp_module.get_rate = function()
    if is_lp_mode() then
        return exp_data.exp_per_hr / 10000
    end
    return exp_data.exp_per_hr
end

---------------------------------------------------------
-- EXPORTS
---------------------------------------------------------
exp_module.exp_data = exp_data
exp_module.is_lp_mode = is_lp_mode

exp_module.on_load()

return exp_module
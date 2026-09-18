-- Credit to Original Author: Daniel_H and Artoo for the original addon.
-- This was used to port into a module to be used in InfoBar.
-- All values are for horizon and may need adjusting.
-- https://github.com/Appotemmis/Roll-Tracker

local roll_module = {
    active_rolls = {},
};

---------------------------------------------------------
-- DATA TABLES
---------------------------------------------------------
local corsair_roll_ids = {
    [98]  = "Fighter's Roll",   [99]  = "Monk's Roll",       [100] = "Healer's Roll",
    [101] = "Wizard's Roll",    [102] = "Warlock's Roll",    [103] = "Rogue's Roll",
    [104] = "Gallant's Roll",   [105] = "Chaos Roll",        [106] = "Beast Roll",
    [107] = "Choral Roll",      [108] = "Hunter's Roll",     [109] = "Samurai Roll",
    [110] = "Ninja Roll",       [111] = "Drachen Roll",      [112] = "Evoker's Roll",
    [113] = "Magus's Roll",     [114] = "Corsair's Roll",    [115] = "Puppet Roll",
    [116] = "Dancer's Roll",    [117] = "Scholar's Roll",    [118] = "Bolter's Roll",
    [119] = "Caster's Roll",    [120] = "Courser's Roll",    [121] = "Blitzer's Roll",
    [122] = "Tactician's Roll", [302] = "Allies' Roll",      [303] = "Miser's Roll",
    [304] = "Companion's Roll", [305] = "Avenger's Roll",    [390] = "Naturalist's Roll",
    [391] = "Runeist's Roll",
};

local roll_data = {
    ['Corsair\'s Roll'] = {
        desc='Experience Points',
        lucky=5,
        unlucky=9,
        bust=6,
        percent=true,
        values={
            [0]={10,11,11,12,20,13,15,16,8,17,24},
            [1]={10,11,11,12,20,13,15,16,8,17,24},
            [2]={10,11,11,12,20,13,15,16,8,17,24},
        },
    },
    
    ['Ninja Roll'] = {
        desc='Evasion',
        lucky=4,
        unlucky=8,
        bust=15,
        values={
            [0]={10,13,15,40,18,20,25,5,27,30,50},
            [1]={13,16,18,43,21,23,28,8,30,33,53},
            [2]={16,19,21,46,24,26,31,11,33,36,56},
        },
    },
    
    ['Hunter\'s Roll'] = {
        desc='Accuracy',
        lucky=4,
        unlucky=8,
        bust=15,
        values={
            [0]={10,13,15,40,18,20,25,5,27,30,50},
            [1]={13,16,18,43,21,23,28,8,30,33,53},
            [2]={16,19,21,46,24,26,31,11,33,36,56},
        },
    },
    
    ['Chaos Roll'] = {
        desc='Attack',
        lucky=4,
        unlucky=8,
        bust=15,
        values={
            [0]={29,36,39,92,45,54,61,21,64,71,111},
            [1]={31,39,42,100,49,59,66,22,69,77,121},
            [2]={33,42,45,109,53,64,72,24,75,84,132},
        },
    },
    
    ['Magus\'s Roll'] = {
        desc='Magic Defense Bonus',
        lucky=2,
        unlucky=6,
        bust=5,
        values={
            [0]={5,20,6,8,9,3,10,13,14,15,25},
            [1]={5,20,6,8,9,3,10,13,14,15,25},
            [2]={5,20,6,8,9,3,10,13,14,15,25},
        },
    },
    
    ['Healer\'s Roll'] = {
        desc='MP Recovered while healing',
        lucky=3,
        unlucky=7,
        bust=3,
        values={
            [0]={2,3,10,4,4,5,1,6,6,7,12,},
            [1]={3,4,11,5,5,6,2,7,7,8,13},
            [2]={4,5,12,6,6,7,3,8,8,9,14},
        },
    },
    
    ['Drachen Roll'] = {
        desc='Pet: ACC / Ranged ACC',
        lucky=4,
        unlucky=8,
        bust=0,
        values={
            [0]={10,13,15,40,18,20,25,5,28,30,50},
            [1]={10,13,15,40,18,20,25,5,28,30,50},
            [2]={10,13,15,40,18,20,25,5,28,30,50},
        },
    },
    
    ['Choral Roll'] = {
        desc='Spell Interruption Rate Down',
        lucky=2,
        unlucky=6,
        bust=25,
        percent=true,
        values={
            [0]={-13,-55,-17,-20,-25,-8,-30,-35,-40,-45,-65},
            [1]={-13,-55,-17,-20,-25,-8,-30,-35,-40,-45,-65},
            [2]={-13,-55,-17,-20,-25,-8,-30,-35,-40,-45,-65},
        },
    },
    
    ['Monk\'s Roll'] = {
        desc='Subtle Blow',
        lucky=3,
        unlucky=7,
        bust=11,
        values={
            [0]={8,10,32,12,14,16,4,20,22,24,40},
            [1]={8,10,32,12,14,16,4,20,22,24,40},
            [2]={8,10,32,12,14,16,4,20,22,24,40},
        },
    },
    
    ['Beast Roll'] = {
        desc='Pet: ATK / Ranged ATK',
        lucky=4,
        unlucky=8,
        bust=0,
        percent=true,
        values={
            [0]={16,20,24,64,28,32,40,8,44,48,80},
            [1]={16,20,24,64,28,32,40,8,44,48,80},
            [2]={16,20,24,64,28,32,40,8,44,48,80},
        },
    },
    
    ['Samurai Roll'] = {
        desc='Store TP',
        lucky=2,
        unlucky=6,
        bust=5,
        values={
            [0]={8,32,10,12,14,4,16,20,22,24,40},
            [1]={10,34,12,14,16,6,18,22,24,26,42},
            [2]={12,36,14,16,18,8,20,24,26,28,44},
        },
    },
    
    ['Evoker\'s Roll'] = {
        desc='Refresh',
        lucky=5,
        unlucky=9,
        bust=1,
        values={
            [0]={1,1,1,1,3,2,2,2,1,3,4},
            [1]={1,1,1,1,3,2,2,2,1,3,4},
            [2]={1,1,1,1,3,2,2,2,1,3,4},
        },
    },
    
    ['Rogue\'s Roll'] = {
        desc='Critical Hit Rate',
        lucky=5,
        unlucky=9,
        bust=6,
        percent=true,
        values={
            [0]={2,2,3,4,12,5,6,6,1,8,19},
            [1]={2,2,3,4,12,5,6,6,1,8,19},
            [2]={2,2,3,4,12,5,6,6,1,8,19},
        },
    },
    
    ['Warlock\'s Roll'] = {
        desc='Magic Accuracy',
        lucky=4,
        unlucky=8,
        bust=5,
        values={
            [0]={2,3,4,12,5,6,7,1,8,9,15},
            [1]={2,3,4,12,5,6,7,1,8,9,15},
            [2]={2,3,4,12,5,6,7,1,8,9,15},
        },
    },
    
    ['Fighter\'s Roll'] = {
        desc='Double Attack',
        lucky=5,
        unlucky=9,
        bust=6,
        percent=true,
        values={
            [0]={2,2,3,4,12,5,6,6,1,9,18},
            [1]={2,2,3,4,12,5,6,6,1,9,18},
            [2]={2,2,3,4,12,5,6,6,1,9,18},
        },
    },
    
    ['Puppet Roll'] = {
        desc='Pet: MACC / MAB',
        lucky=3,
        unlucky=7,
        bust=8,
        values={
            [0]={4,5,18,7,9,10,2,11,13,15,22},
            [1]={4,5,18,7,9,10,2,11,13,15,22},
            [2]={4,5,18,7,9,10,2,11,13,15,22},
        },
    },
    
    ['Gallant\'s Roll'] = {
        desc='Defense',
        lucky=3,
        unlucky=7,
        bust=120,
        values={
            [0]={48,60,200,72,88,104,32,120,140,160,240},
            [1]={52,64,204,76,92,108,36,124,144,164,244},
            [2]={56,68,208,80,96,112,40,128,148,168,248},
        },
    },
    
    ['Wizard\'s Roll'] = {
        desc='Magic Attack Bonus',
        lucky=5,
        unlucky=9,
        bust=4,
        values={
            [0]={2,3,4,4,10,5,6,7,1,7,12},
            [1]={2,3,4,4,10,5,6,7,1,7,12},
            [2]={2,3,4,4,10,5,6,7,1,7,12},
        },
    },
    
    ['Dancer\'s Roll'] = {
        desc='Regen',
        lucky=3,
        unlucky=7,
        bust=4,
        values={
            [0]={3,4,12,5,6,7,1,8,9,10,16},
            [1]={3,4,12,5,6,7,1,8,9,10,16},
            [2]={3,4,12,5,6,7,1,8,9,10,16},
        },
    },
    
    ['Scholar\'s Roll'] = {
        desc='Conserve MP',
        lucky=2,
        unlucky=6,
        bust=3,
        percent=true,
        values={
            [0]={2,10,3,4,4,1,5,6,7,7,12},
            [1]={2,10,3,4,4,1,5,6,7,7,12},
            [2]={2,10,3,4,4,1,5,6,7,7,12},
        },
    },
};

---------------------------------------------------------
-- INTERNAL HELPERS
---------------------------------------------------------
local function get_equipped_item_id(slot)
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    if not inventory then return 0 end
    local equipped = inventory:GetEquippedItem(slot);
    if not equipped or not equipped.Index then return 0 end

    local index = bit.band(equipped.Index, 0x00FF);
    if index == 0 then return 0 end

    local container = bit.rshift(bit.band(equipped.Index, 0xFF00), 8);
    local item = inventory:GetContainerItem(container, index);
    return (item and item.Id) and item.Id or 0;
end

local function get_roll_enhancement()
    local legs_id = get_equipped_item_id(7); -- Legs
    local right_ear_id = get_equipped_item_id(12); -- R.Ear

    local enhancement = 0;
    if legs_id == 15601 or legs_id == 16348 then enhancement = enhancement + 1 end
    if right_ear_id == 26114 or right_ear_id == 26115 then enhancement = enhancement + 1 end

    return math.min(enhancement, 2);
end

---------------------------------------------------------
-- PACKET HANDLERS
---------------------------------------------------------
local function parse_action_packet(e)
    local bit_data = e.data_raw;
    local bit_offset = 40;

    local function unpack_bits(length)
        local value = ashita.bits.unpack_be(bit_data, 0, bit_offset, length);
        bit_offset = bit_offset + length;
        return value;
    end

    local packet = {
        user_id = unpack_bits(32),
        target_count = unpack_bits(6),
    };
    bit_offset = bit_offset + 4;
    packet.type = unpack_bits(4);
    packet.id = unpack_bits(17);
    bit_offset = bit_offset + 15;
    packet.recast = unpack_bits(32);

    packet.targets = {};
    for i = 1, packet.target_count do
        local target = { id = unpack_bits(32), action_count = unpack_bits(4), actions = {} };
        for j = 1, target.action_count do
            local action = {
                reaction = unpack_bits(5),
                animation = unpack_bits(12),
                special_effect = unpack_bits(7),
                knockback = unpack_bits(3),
                param = unpack_bits(17),
                message = unpack_bits(10),
                flags = unpack_bits(31),
            };
            if unpack_bits(1) == 1 then bit_offset = bit_offset + 37 end
            if unpack_bits(1) == 1 then bit_offset = bit_offset + 34 end
            target.actions[j] = action;
        end
        packet.targets[i] = target;
    end
    return packet;
end

---------------------------------------------------------
-- PUBLIC MODULE INTERFACE
---------------------------------------------------------
function roll_module.initialize()
    roll_module.active_rolls = {};
end

function roll_module.reset()
    roll_module.active_rolls = {};
end

function roll_module.handle_packet(e)
    if e.id == 0x00B then
        roll_module.reset();
        return;
    end

    if e.id == 0x028 then
        local ok, packet = pcall(parse_action_packet, e);
        if not ok or packet.type ~= 6 or not corsair_roll_ids[packet.id] then return end

        local party = AshitaCore:GetMemoryManager():GetParty();
        if not party or party:GetMemberIsActive(0) ~= 1 then return end
        local local_player_id = party:GetMemberServerId(0);

        if packet.user_id == local_player_id then
            local roll_name = corsair_roll_ids[packet.id];
            local data = roll_data[roll_name];
            local total = packet.targets[1] and packet.targets[1].actions[1] and packet.targets[1].actions[1].param or nil;

            if data and total then
                local suffix = data.percent and "%" or "";

                if total > 11 then
                    -- Bust state
                    local bust_val = data.bust or 0
                    local bust_str = (bust_val == 0) and "No Effect" or string.format("-%s%s %s", tostring(bust_val), suffix, data.desc)
                
                    roll_module.active_rolls[roll_name] = {
                        name = roll_name,
                        total = total,
                        is_bust = true,
                        effect_text = bust_str,
                        expiration = os.clock() + 300, -- 5-minute Bust duration
                        lucky = data.lucky,
                        unlucky = data.unlucky,
                    };
                else
                    -- Normal roll state
                    local enhancement = get_roll_enhancement();
                    local tier_values = data.values[enhancement] or data.values[0];
                    local val = tier_values[total] or 0;
                    local prefix = (val > 0) and "+" or ""

                    roll_module.active_rolls[roll_name] = {
                        name = roll_name,
                        total = total,
                        is_bust = false,
                        effect_text = string.format("%s%s%s %s", prefix, tostring(val), suffix, data.desc),
                        expiration = os.clock() + 300,
                        lucky = data.lucky,
                        unlucky = data.unlucky,
                    };
                end
            end
        end
    end
end

return roll_module;
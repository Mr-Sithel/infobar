local hide_menu = {}

local game_menu_ptr = 0

-- Scan memory for FFXI Main Menu pointer during addon load
local function init_menu_pointer()
    game_menu_ptr = ashita.memory.find('FFXiMain.dll', 0, "8B480C85C974??8B510885D274??3B05", 16, 0)
end
init_menu_pointer()

-- Read current active game menu name
function hide_menu.get_active_menu_name()
    if game_menu_ptr == 0 or game_menu_ptr == nil then return nil end

    local ptr = ashita.memory.read_uint32(game_menu_ptr)
    if ptr == 0 then return nil end

    ptr = ashita.memory.read_uint32(ptr)
    if ptr == 0 then return nil end

    local menu_header = ashita.memory.read_uint32(ptr + 4)
    if menu_header == 0 then return nil end

    local menu_name_ptr = menu_header + 0x46
    local menu_name = ashita.memory.read_string(menu_name_ptr, 16)
    return string.gsub(menu_name or '', '\x00', '')
end

-- Helper check function: Returns true if map or full chat log is open
function hide_menu.is_map_or_chat_open()
    local name = hide_menu.get_active_menu_name()
    if not name or name == '' then return false end

    -- Check for Map ('menu    map') or Maximized Chat Log ('menu    fulllog')
    if string.match(name, 'menu    map') or string.match(name, 'menu    fulllog') then
        return true
    end

    return false
end

return hide_menu
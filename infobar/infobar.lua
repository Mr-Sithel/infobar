-----------------------------------------------------------------------------------------------------
-- Many creators involved that made the orignal code from the modules I put in the modules folder.
-- I then created and assembled InfoBar Overlay to display in game.
-- Credit goes out to Thorny, Atom0s, Loonsies, Xenonsmurf, Onimitch, Matix, Hugin, XIUI Team
-- Daniel_H, Shinzaku, Artoo and anyone else I may have missed.
-----------------------------------------------------------------------------------------------------

addon.name    = 'InfoBar'
addon.author  = 'Sithel'
addon.version = '0.6.0'
addon.desc    = 'Info Bar that shows (Job|Compass|pos|Zone Timer|Zone|Region|Day|Weather|Vana Time|Moon Phase|Assault|RollTracker).'
addon.link    = ''

local settings    = require('settings')
local imgui       = require('imgui')
local chat        = require('chat')
local vanatime    = require('modules/vanatime')
local ZoneState   = require('modules/zonestate')
local Weather     = require('modules/weather')
local Direction   = require('modules/direction')
local Map         = require('modules/map')
local Exp         = require('modules/exp');
local Assaults    = require('modules/assault');
local RollTracker = require('modules/rolltracker');

-- Settings
local default_settings = T{
    theme = 'gold',
    x_single = 878,
    y_single = 17,
    x_double_top    = 878,
    y_double_top    = 17,
    x_double_bottom = 878,
    y_double_bottom = 52,
    use_icons  = false,
    two_bars   = false,
    bg_opacity = 0.6,
    window_rounding = 6.0,
    show_weekday_horizontal = false,
    show_weekday_vertical   = false,
    show_exp_horizontal     = false,
    show_assault_bar        = false,
    show_roll_bar           = false,
    show_lucky_info         = true,
    show_roll_timer         = true,
    show_jobs       = true,
    show_playerdir  = true,
    show_playerpos  = true,
    show_zone_timer = true,
    show_zone       = true,
    show_region     = true,
    show_day        = true,
    show_weather    = true,
    show_time       = true,
    show_moon       = true,
}

local config = settings.load(default_settings)

-- Theme
local function loadTheme(name)
    return require('themes/theme_' .. name)
end

local current_loaded_theme_name = nil
local theme = nil
local function updateActiveTheme()
    local target_theme = config.theme or 'gold'
    if current_loaded_theme_name ~= target_theme then
        theme = loadTheme(target_theme)
        current_loaded_theme_name = target_theme
    end
end

-- Settings
local function update_settings(s)
    if s ~= nil then
        config = s
    end
    settings.save()
end

settings.register('settings', 'settings_update', update_settings)

-- State
local show_weather_test     = false
local show_settings_window  = false
local show_theme_window     = false
local currentZoneName       = ''
local currentRegionName     = ''
local zone_enter_time       = os.clock()
local top_initialized       = false
local bottom_initialized    = false
local active_assault        = nil
local assault_start_time    = 0

-- Helpers
local vana_days = {
    [0] = 'Fireday', [1] = 'Earthday', [2] = 'Waterday', [3] = 'Windsday',
    [4] = 'Iceday', [5] = 'Lightningday', [6] = 'Lightsday', [7] = 'Darksday',
}

local weekday_colors = {
    Fireday      = {1.00, 0.27, 0.00, 1.0},
    Earthday     = {1.00, 0.84, 0.00, 1.0},
    Waterday     = {0.12, 0.56, 1.00, 1.0},
    Windsday     = {0.20, 0.80, 0.20, 1.0},
    Iceday       = {0.53, 0.81, 0.98, 1.0},
    Lightningday = {0.88, 0.60, 1.00, 1.0},
    Lightsday    = {0.85, 0.90, 1.00, 1.0},
    Darksday     = {0.52, 0.00, 0.75, 1.0},
}

local function draw_colored_day(day)
    local col = weekday_colors[day]
    if col then
        imgui.TextColored({ col[1], col[2], col[3], col[4] }, day)
    else
        imgui.Text(day)
    end
end

local function get_job_text()
    if not config.show_jobs then
        return nil
    end

    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if not player then return nil end

    local mj = player:GetMainJob()
    local sj = player:GetSubJob()
    local ml = player:GetMainJobLevel()
    local sl = player:GetSubJobLevel()

    local mj_name = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", mj) or "???"
    local sj_name = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", sj) or "???"

    return string.format('%d %s/%s', ml, mj_name, sj_name)
end

local function get_zone_region()
    return currentZoneName ~= '' and currentZoneName or 'Unknown Zone',
           currentRegionName ~= '' and currentRegionName or 'Unknown Region'
end

local function get_vana_day_and_time()
    local date = vanatime.get_current_date()
    local time = vanatime.get_current_time()
    return vana_days[date.weekday], string.format('%02d:%02d', time.h, time.m)
end

local function get_zone_timer()
    local elapsed = math.floor(os.clock() - zone_enter_time)
    local mins    = math.floor(elapsed / 60)
    local secs    = elapsed % 60
    return string.format('%02d:%02d', mins, secs)
end

local function get_moon_phase()
    local date = vanatime.get_current_date()
    local moon_name = AshitaCore:GetResourceManager():GetString('moonphases', date.moon_phase)
    return string.format('%s %d%%', moon_name, date.moon_percent)
end

local function DrawCircledNumber(num, col)
    col = col or { 1.0, 1.0, 1.0, 1.0 }
    local u32_color = imgui.GetColorU32(col)
    local text = tostring(num)
    local padding = 4.0
    local pos = { imgui.GetCursorScreenPos() }
    local text_size = { imgui.CalcTextSize(text) }
    local radius = math.max(text_size[1], text_size[2]) / 2 + padding
    local center_x = pos[1] + radius
    local center_y = pos[2] + (text_size[2] / 2)

    local draw_list = imgui.GetWindowDrawList()

    -- Semi-transparent black background fill
    draw_list:AddCircleFilled({ center_x, center_y }, radius, 0xBB000000)

    -- Circle outline with dynamic U32 color
    draw_list:AddCircle({ center_x, center_y }, radius, u32_color, 12, 1.5)

    -- Render number text inside using dynamic color table
    imgui.SetCursorScreenPos({ center_x - (text_size[1] / 2), pos[2] })
    imgui.TextColored(col, text)

    imgui.SetCursorScreenPos({ pos[1] + (radius * 2) + 4, pos[2] })
end

-- Zone updates and chat parser
ZoneState.onChange(function(id, name, region)
    currentZoneName   = name or ''
    currentRegionName = region or ''
    zone_enter_time   = os.clock()

    -- Reset assault tracking on zone change
    active_assault     = nil
    assault_start_time = 0
end)

ashita.events.register('load', 'infobar_load', function()
    ZoneState.init()
    ashita.tasks.once(1, ZoneState.refresh)
end)

ashita.events.register('text_in', 'assault_text_in', function(e)
    if e.injected then return end

    local clean_msg = e.message:gsub('\x1e%p', ''):gsub('\x1f%p', '')

    -- Salvage check ("Commencing transport to Bhaflau Remnants!")
    local salvage_match = clean_msg:match("Commencing transport to%s+(.-)!")
    if salvage_match then
        for _, entry in ipairs(Assaults) do
            if entry.trigger and entry.trigger:lower() == salvage_match:lower() then
                active_assault = entry
                assault_start_time = os.clock()
                return
            end
        end
    end

    -- Standard Assault check ("Commencing Seagull Grounded!")
    local assault_match = clean_msg:match("Commencing%s+(.-)!")
    if assault_match then
        for _, entry in ipairs(Assaults) do
            if entry.name:lower() == assault_match:lower() then
                active_assault = entry
                assault_start_time = os.clock()
                return
            end
        end
    end
end)

ashita.events.register('packet_in', 'infobar_packet_in', function(e)
    RollTracker.handle_packet(e);
end)

-- Commands
local function split(str, sep)
    local t = {}
    for s in string.gmatch(str, "([^"..sep.."]+)") do
        t[#t+1] = s
    end
    return t
end

ashita.events.register('command', 'infobar_cmd', function(e)
    local args = split(e.command, ' ')
    local cmd = args[1] and args[1]:lower() or ''
    if cmd ~= '/infobar' and cmd ~= '/ibar' then
        return
    end
    e.blocked = true

    local sub = (args[2] or 'help'):lower()

    if sub == 'help' then
        print(chat.header(addon.name):append(chat.message('\31\207Commands:')));
        print('\31\207 /ibar                      \31\8 - This help menu.');
        print('\31\207 /ibar  c|config|settings   \31\8 - shows a settings window.');
        print('\31\207 /ibar  w|weekdays          \31\8 - shows days of the week order.');
        print('\31\207 /ibar  e|exp               \31\8 - shows an exp bar.');
        print('\31\207 /ibar  a|s|assault|salvage \31\8 - shows an assault/salvage bar.');
        print('\31\207 /ibar  rt|rolltracker      \31\8 - shows a COR roll tracker bar.');
        print('\31\207 /ibar  m|mode              \31\8 - Splits main bar into 2 smaller bars.');
        print('\31\207 /ibar  reset               \31\8 - reset positions.');
        print('\31\207 /ibar  save                \31\8 - save settings.');
    end
    if T{'settings', 'config', 'c'}:contains(sub) then
        show_settings_window = not show_settings_window
        return
    end

    if T{'weekdays', 'w'}:contains(sub) then
        config.show_weekday_horizontal = not config.show_weekday_horizontal
        settings.save()
        return
    end

    if T{'exp', 'e'}:contains(sub) then
        config.show_exp_horizontal = not config.show_exp_horizontal
        settings.save()
        return
    end

    if T{'assault', 'salvage', 'a', 's'}:contains(sub) then
        config.show_assault_bar = not config.show_assault_bar
        settings.save()
        return
    end

    if T{'rt', 'rolltracker'}:contains(sub) then
        config.show_roll_bar = not config.show_roll_bar
        settings.save()
        return
    end

    if T{'mode', 'm'}:contains(sub) then
        config.two_bars = not config.two_bars
        top_initialized    = false
        bottom_initialized = false
        settings.save()
        return
    end

    if T{'reset'}:contains(sub) then
        config.x_double_top    = default_settings.x_double_top
        config.y_double_top    = default_settings.y_double_top
        config.x_double_bottom = default_settings.x_double_bottom
        config.y_double_bottom = default_settings.y_double_bottom
        config.x_single        = default_settings.x_single
        config.y_single        = default_settings.y_single

        top_initialized    = false
        bottom_initialized = false
        settings.save()
        return
    end

    if sub == 'weathertest' then
        show_weather_test = not show_weather_test
        return
    end

    if sub == 'save' then
        settings.save()
        print(chat.header(addon.name):append(chat.message('\31\204Settings Saved!')));
        return
    end
end)

-- Draw themes
local function draw_theme_window()
    if not show_theme_window then return end

    theme.push()

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_AlwaysAutoResize
    )

    local is_open = { show_theme_window }
    if imgui.Begin('InfoBar - Themes', is_open, flags) then
        imgui.Text('Select Theme')
        imgui.SameLine()
        imgui.TextDisabled('(?)')
        if imgui.IsItemHovered() then
            imgui.SetTooltip('Choose a visual color theme for InfoBar.')
        end

        local themes = {
            'gold',
            'blue',
            'red',
            'green',
            'purple',
            'ice',
            'gray'
        }

        local current = config.theme or 'gold'

        imgui.PushItemWidth(140)
        if imgui.BeginCombo('##infobar_theme_select', current) then
            for _, t in ipairs(themes) do
                local selected = (t == current)
                if imgui.Selectable(t, selected) then
                    config.theme = t
                    settings.save()
                    updateActiveTheme()
                end

                if selected then
                    imgui.SetItemDefaultFocus()
                end
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()

        imgui.Separator()

        if imgui.Button('Close', { -1, 0 }) then
            show_theme_window = false
            is_open[1] = false
        end
    end

    imgui.End()
    theme.pop()
    show_theme_window = is_open[1]
end

---------------------------------------------------------
-- IMGUI WINDOWS
---------------------------------------------------------
local function draw_settings_window()
    if not show_settings_window then return end

    theme.push()

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_AlwaysAutoResize
    )

    local is_open = { show_settings_window }
    if imgui.Begin('InfoBar - Settings', is_open, flags) then
        local function toggle(label, key)
            local ref = { config[key] }
            if imgui.Checkbox(label, ref) then
                config[key] = ref[1]
                settings.save()
            end
        end

        -- Column 1
        imgui.BeginGroup()
        toggle("Show Job",        "show_jobs")
        toggle("Show Position",   "show_playerpos")
        toggle("Show Zone Timer", "show_zone_timer")
        toggle("Show Zone",       "show_zone")
        toggle("Show Region",     "show_region")
        imgui.EndGroup()

        imgui.SameLine(200)

        -- Column 2
        imgui.BeginGroup()
        toggle("Show Compass",    "show_playerdir")
        toggle("Show Day",        "show_day")
        toggle("Show Vana Time",  "show_time")
        toggle("Show Weather",    "show_weather")
        toggle("Show Moon Phase", "show_moon")
        imgui.EndGroup()

        imgui.Separator()

        -- Two Bar Mode
        local val = { config.two_bars }
        if imgui.Checkbox("Two Bars Mode", val) then
            config.two_bars = val[1]
            top_initialized    = false
            bottom_initialized = false
            settings.save()
        end

        imgui.SameLine()
        imgui.TextDisabled('(?)')
        if imgui.IsItemHovered() then
            imgui.SetTooltip(' Splits main bar into 2 smaller bars.')
        end

        -- Use Icons
        local ref = { config.use_icons }
        if imgui.Checkbox("Enable Icons", ref) then
            config.use_icons = ref[1]
            settings.save()
        end

        imgui.SameLine()
        imgui.TextDisabled('(?)')
        if imgui.IsItemHovered() then
            imgui.SetTooltip(' Shows icons for zone timer & vana clock.')
        end

        -- Opacity Slider
        imgui.Separator()
        imgui.Text("Background Options")
        local opacity_ref = { config.bg_opacity }
        if imgui.SliderFloat("Opacity", opacity_ref, 0.0, 1.0, "%.2f") then
            config.bg_opacity = opacity_ref[1]
            settings.save()
        end

        -- Background Rounding Slider (1–15)
        local rounding_ref = { config.window_rounding }
        if imgui.SliderFloat("Round Corners", rounding_ref, 1.0, 15.0, "%.0f") then
            config.window_rounding = rounding_ref[1]
            settings.save()
        end
        imgui.Separator()

        -- Added other bar toggles
        local vert_ref = { config.show_weekday_vertical }
        if imgui.Checkbox("Weekdays Vertical Bar", vert_ref) then
            config.show_weekday_vertical = vert_ref[1]
            settings.save()
        end

        local horiz_ref = { config.show_weekday_horizontal }
        if imgui.Checkbox("Weekdays Horizontal Bar", horiz_ref) then
            config.show_weekday_horizontal = horiz_ref[1]
            settings.save()
        end

        local exp_ref = { config.show_exp_horizontal }
        if imgui.Checkbox("EXP/LP Bar", exp_ref) then
            config.show_exp_horizontal = exp_ref[1]
            settings.save()
        end

        imgui.SameLine()
        imgui.TextDisabled('(?)')
        if imgui.IsItemHovered() then
            imgui.SetTooltip(' Displays XP/Merit per hour w/ chain.')
        end

        local assault_ref = { config.show_assault_bar }
        if imgui.Checkbox("Assault/Salvage Bar", assault_ref) then
            config.show_assault_bar = assault_ref[1]
            settings.save()
        end

        imgui.SameLine()
        imgui.TextDisabled('(?)')
        if imgui.IsItemHovered() then
            imgui.SetTooltip(' Displays time remaining in area.')
        end

        local roll_ref = { config.show_roll_bar }
        if imgui.Checkbox("RollTracker Bar", roll_ref) then
            config.show_roll_bar = roll_ref[1]
            settings.save()
        end

        imgui.SameLine()
        imgui.TextDisabled('(?)')
        if imgui.IsItemHovered() then
            imgui.SetTooltip(' Only for Corsair as main job.')
        end

        if config.show_roll_bar then
            imgui.Indent(16.0)

            local lucky_ref = { config.show_lucky_info }
            if imgui.Checkbox("Show Lucky/Unlucky Info", lucky_ref) then
                config.show_lucky_info = lucky_ref[1]
                settings.save()
            end

            local timer_ref = { config.show_roll_timer }
            if imgui.Checkbox("Show Roll Timers", timer_ref) then
                config.show_roll_timer = timer_ref[1]
                settings.save()
            end

            imgui.Unindent(16.0)
        end
        imgui.Separator()

        -- Reset + Save & Close Buttons
        if imgui.Button("Reset Positions", { 140, 0 }) then
            config.x_double_top    = default_settings.x_double_top
            config.y_double_top    = default_settings.y_double_top
            config.x_double_bottom = default_settings.x_double_bottom
            config.y_double_bottom = default_settings.y_double_bottom
            config.x_single        = default_settings.x_single
            config.y_single        = default_settings.y_single

            top_initialized    = false
            bottom_initialized = false
            settings.save()
        end

        imgui.SameLine()
        if imgui.Button("Themes", { 80, 0 }) then
            show_theme_window = not show_theme_window
        end

        imgui.SameLine()
        if imgui.Button("Save & Close", { 130, 0 }) then
            settings.save()
            show_settings_window = false
            is_open[1] = false
        end
    end

    imgui.End()
    theme.pop()
    show_settings_window = is_open[1]
end

local function draw_top_window()
    if not top_initialized then
        local target_x = config.two_bars and config.x_double_top or config.x_single
        local target_y = config.two_bars and config.y_double_top or config.y_single
        imgui.SetNextWindowPos({ target_x, target_y }, ImGuiCond_Always)
    end

    imgui.SetNextWindowBgAlpha(config.bg_opacity)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, config.window_rounding)
    imgui.PushStyleColor(ImGuiCol_WindowBg, {0.0, 0.0, 0.0, config.bg_opacity})

    local flags = bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoScrollWithMouse,
        ImGuiWindowFlags_AlwaysAutoResize
    )

    if imgui.Begin('InfoBar - Top', { true }, flags) then
        local pos = { imgui.GetWindowPos() }
        local cur_x, cur_y = pos[1], pos[2]

        if config.two_bars then
            if config.x_double_top ~= cur_x or config.y_double_top ~= cur_y then
                config.x_double_top = cur_x
                config.y_double_top = cur_y
                settings.save()
            end
        else
            if config.x_single ~= cur_x or config.y_single ~= cur_y then
                config.x_single = cur_x
                config.y_single = cur_y
                settings.save()
            end
        end
        top_initialized = true

        local zone, region = get_zone_region()
        local gx, gy = Map.get_player_grid_position()
        local playerpos = (gx and gy) and string.format("%s-%d", gx, gy) or "--/--"
        local facing = Direction.get()

        if config.two_bars then
            local day, time = get_vana_day_and_time()
            local weather_name  = Weather.get()
            local weather_color = Weather.get_color()

            local parts = {}

            if config.show_jobs       then table.insert(parts, { type="text",    value=get_job_text() }) end
            if config.show_playerdir  then table.insert(parts, { type="text",    value=facing }) end
            if config.show_playerpos  then table.insert(parts, { type="text",    value=playerpos }) end
            if config.show_zone_timer then table.insert(parts, { type="text",    value=get_zone_timer() }) end
            if config.show_zone       then table.insert(parts, { type="text",    value=zone }) end
            if config.show_region     then table.insert(parts, { type="text",    value=region }) end

            local first = true
            for _, item in ipairs(parts) do
                if not first then
                    imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|")
                    imgui.SameLine()
                end
                first = false

                if item.type == "day" then
                    draw_colored_day(item.value)
                elseif item.type == "weather" then
                    imgui.TextColored(item.color, item.value)
                elseif item.type == "text" then
                    if item.value == get_zone_timer() then
                        if config.use_icons then
                            imgui.TextColored({0.0, 1.0, 0.0, 1.0}, "\xef\x8b\xb2 " .. item.value)
                        else
                            imgui.TextColored({0.0, 1.0, 0.0, 1.0}, "Zone Timer " .. item.value)
                        end
                    elseif item.value == facing then
                        imgui.TextColored(Direction.color_for(facing), item.value)
                    else
                        imgui.Text(item.value)
                    end
                end
                imgui.SameLine()
            end
        else
            local day, time = get_vana_day_and_time()
            local weather_name  = Weather.get()
            local weather_color = Weather.get_color()
            local facing = Direction.get()

            local left = {}

            if config.show_jobs       then table.insert(left, get_job_text()) end
            if config.show_playerdir  then table.insert(left, facing) end
            if config.show_playerpos  then table.insert(left, playerpos) end
            if config.show_zone_timer then table.insert(left, get_zone_timer()) end
            if config.show_zone       then table.insert(left, zone) end
            if config.show_region     then table.insert(left, region) end

            if #left > 0 then
                for i, item in ipairs(left) do
                    if item == get_zone_timer() then
                        if config.use_icons then
                            imgui.TextColored({0.0, 1.0, 0.0, 1.0}, "\xef\x8b\xb2 " .. item)
                        else
                            imgui.TextColored({0.0, 1.0, 0.0, 1.0}, "Zone Timer " .. item)
                        end
                    elseif item == facing then
                        imgui.TextColored(Direction.color_for(facing), item)
                    else
                        imgui.Text(item)
                    end

                    imgui.SameLine()
                    imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|")
                    imgui.SameLine()
                end
            end

            if config.show_day then
                draw_colored_day(day)
                imgui.SameLine()
            end

            if config.show_time then
                imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|")
                imgui.SameLine()
                if config.use_icons then
                    imgui.TextColored({1.0, 0.80, 0.20, 1.0}, "\xef\x80\x97 " .. time)
                else
                    imgui.TextColored({1.0, 0.80, 0.20, 1.0}, time)
                end
                imgui.SameLine()
            end

            if config.show_weather then
                imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|")
                imgui.SameLine()
                imgui.TextColored(weather_color, weather_name)
                imgui.SameLine()
            end

            if config.show_moon then
                imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|")
                imgui.SameLine()
                imgui.Text(get_moon_phase())
            end
        end
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end

local function draw_bottom_window()
    if not config.two_bars then return end

    if not bottom_initialized then
        imgui.SetNextWindowPos({ config.x_double_bottom, config.y_double_bottom }, ImGuiCond_Always)
    end

    imgui.SetNextWindowBgAlpha(config.bg_opacity)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, config.window_rounding)
    imgui.PushStyleColor(ImGuiCol_WindowBg, {0.0, 0.0, 0.0, config.bg_opacity})

    local flags = bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoScrollWithMouse,
        ImGuiWindowFlags_AlwaysAutoResize
    )

    if imgui.Begin('InfoBar - Bottom', { true }, flags) then
        local pos = { imgui.GetWindowPos() }
        local cur_x, cur_y = pos[1], pos[2]

        if config.x_double_bottom ~= cur_x or config.y_double_bottom ~= cur_y then
            config.x_double_bottom = cur_x
            config.y_double_bottom = cur_y
            settings.save()
        end
        bottom_initialized = true

        local day, time = get_vana_day_and_time()
        local weather_name  = Weather.get()
        local weather_color = Weather.get_color()

        local parts = {}

        if config.show_day     then table.insert(parts, { type = "day",     value = day }) end
        if config.show_time    then table.insert(parts, { type = "text",    value = time }) end
        if config.show_weather then table.insert(parts, { type = "weather", value = weather_name, color = weather_color }) end
        if config.show_moon    then table.insert(parts, { type = "text",    value = get_moon_phase() }) end

        local first = true
        for _, item in ipairs(parts) do
            if not first then
                imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|")
                imgui.SameLine()
            end
            first = false

            if item.type == "day" then
                draw_colored_day(item.value)
            elseif item.type == "weather" then
                imgui.TextColored(item.color, item.value)
            elseif item.type == "text" then
                if item.value == time then
                    if config.use_icons then
                        imgui.TextColored({1.0, 0.80, 0.20, 1.0}, "\xef\x80\x97 " .. time)
                    else
                        imgui.TextColored({1.0, 0.80, 0.20, 1.0}, time)
                    end
                else
                    imgui.Text(item.value)
                end
            end
            imgui.SameLine()
        end
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end

local function draw_weekday_vertical()
    if not config.show_weekday_vertical then return end

    imgui.SetNextWindowBgAlpha(config.bg_opacity)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, config.window_rounding)
    imgui.PushStyleColor(ImGuiCol_WindowBg, {0.0, 0.0, 0.0, config.bg_opacity})

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoTitleBar
    )

    if imgui.Begin('InfoBar - Weekdays (Vertical)', { true }, flags) then
        draw_colored_day("Fireday")
        draw_colored_day("Earthday")
        draw_colored_day("Waterday")
        draw_colored_day("Windsday")
        draw_colored_day("Iceday")
        draw_colored_day("Lightningday")
        draw_colored_day("Lightsday")
        draw_colored_day("Darksday")
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end

local function draw_weekday_horizontal()
    if not config.show_weekday_horizontal then return end

    imgui.SetNextWindowBgAlpha(config.bg_opacity)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, config.window_rounding)
    imgui.PushStyleColor(ImGuiCol_WindowBg, {0.0, 0.0, 0.0, config.bg_opacity})

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoTitleBar
    )

    if imgui.Begin('InfoBar - Weekdays (Horizontal)', { true }, flags) then
        draw_colored_day("Fireday");      imgui.SameLine()
        draw_colored_day("Earthday");     imgui.SameLine()
        draw_colored_day("Waterday");     imgui.SameLine()
        draw_colored_day("Windsday");     imgui.SameLine()
        draw_colored_day("Iceday");       imgui.SameLine()
        draw_colored_day("Lightningday"); imgui.SameLine()
        draw_colored_day("Lightsday");    imgui.SameLine()
        draw_colored_day("Darksday")
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end

local function draw_exp_horizontal()
    if not config.show_exp_horizontal then return end

    -- Keep the XP/hr estimate updating once per second, similar to points addon.
    if Exp.update_rate then
        Exp.update_rate(false)
    end

    local data = Exp.exp_data
    local lp_mode = Exp.is_lp_mode and Exp.is_lp_mode() or false

    imgui.SetNextWindowBgAlpha(config.bg_opacity)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, config.window_rounding)
    imgui.PushStyleColor(ImGuiCol_WindowBg, {0,0,0,config.bg_opacity})

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoTitleBar
    )

    if imgui.Begin('InfoBar - EXP (Horizontal)', { true }, flags) then
        local curr = data.current_exp
        local max  = data.max_exp
        local tnl  = data.tnl
        local rate = data.exp_per_hr or 0
        local chain = data.chain_count or 0

        local tnl_label = "TNL:"
        if lp_mode then
            imgui.Text("LP:"); imgui.SameLine()
            curr = data.lp_current or 0
            max  = data.lp_max or 10000
            tnl  = max - curr
            tnl_label = "TNM:"

            local merit_str = string.format("%s/%s", Exp.format_comma(curr), Exp.format_comma(max))
            imgui.TextColored({0.23, 0.61, 0.91, 1.0}, merit_str); imgui.SameLine()
        else
            imgui.Text("EXP:"); imgui.SameLine()
            local exp_str = string.format("%s/%s", Exp.format_comma(curr), Exp.format_comma(max))
            imgui.TextColored({0.55, 0.90, 0.75, 1.0}, exp_str); imgui.SameLine()
        end

        imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|"); imgui.SameLine()

        imgui.Text(tnl_label); imgui.SameLine()
        if lp_mode then
            imgui.TextColored({0.23, 0.61, 0.91, 1.0}, Exp.format_comma(tnl)); imgui.SameLine()
            imgui.TextColored({0.2, 0.8, 0.2, 1.0}, string.format("(%d)", data.merit_count or 0)); imgui.SameLine()
        else
            imgui.TextColored({0.55, 0.90, 0.75, 1.0}, Exp.format_comma(tnl)); imgui.SameLine()
        end

        imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|"); imgui.SameLine()

        imgui.Text("Rate:"); imgui.SameLine()
        if lp_mode then
            local mp_rate = (data.exp_per_hr or 0) / 10000
            local rate_str = string.format("%.1f", mp_rate)
            imgui.TextColored({1.0, 0.80, 0.20, 1.0}, rate_str); imgui.SameLine()
            imgui.TextColored({1, 1, 1, 1}, " mp/hr"); imgui.SameLine()
        else
            local rate_str = Exp.format_comma(data.exp_per_hr or 0)
            imgui.TextColored({1.0, 0.80, 0.20, 1.0}, rate_str); imgui.SameLine()
            imgui.TextColored({1, 1, 1, 1}, " xp/hr"); imgui.SameLine()
        end

        imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|"); imgui.SameLine()

        imgui.Text("Chain:"); imgui.SameLine()
        local chain_rem = Exp.get_chain_time_remaining and Exp.get_chain_time_remaining() or 0
        if chain_rem > 0 then
            local mins = math.floor(chain_rem / 60)
            local secs = chain_rem % 60

            local chain_str = string.format("# %d (%dm %02ds)", chain, mins, secs)
            local timer_color = {1.0, 1.0, 0.67, 1.0}

            if chain_rem <= 10 then
                timer_color = {1.0, 0.2, 0.2, 1.0}
            elseif chain_rem <= 30 then
                timer_color = {1.0, 0.6, 0.0, 1.0}
            end
            imgui.TextColored(timer_color, chain_str)
        else
            imgui.TextColored({1.0, 0.80, 0.20, 1.0}, "0")
        end
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end

-- Assault / Salvage Bar (Shows time remaining inside)
local function draw_assault_horizontal()
    if not config.show_assault_bar then return end

    imgui.SetNextWindowBgAlpha(config.bg_opacity)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, config.window_rounding)
    imgui.PushStyleColor(ImGuiCol_WindowBg, {0, 0, 0, config.bg_opacity})

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoTitleBar
    )

    if imgui.Begin('InfoBar - Assault (Horizontal)', { true }, flags) then
        if active_assault and active_assault.zone == currentZoneName then
            local zone_display = currentZoneName ~= '' and currentZoneName or 'Unknown Zone'

            imgui.Text("Zone:"); imgui.SameLine()
            imgui.TextColored({0.55, 0.90, 0.75, 1.0}, zone_display); imgui.SameLine()

            imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|"); imgui.SameLine()

            imgui.Text("Assualt:"); imgui.SameLine()
            imgui.TextColored({1.0, 0.80, 0.20, 1.0}, active_assault.name); imgui.SameLine()

            if active_assault.portal then
                imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|"); imgui.SameLine()
                imgui.Text("Portal:"); imgui.SameLine()
                imgui.TextColored({0.23, 0.61, 0.91, 1.0}, active_assault.portal); imgui.SameLine()
            end

            imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|"); imgui.SameLine()

            local start_anchor = (assault_start_time > 0) and assault_start_time or zone_enter_time
            local limit_seconds = (active_assault.time_limit or 30) * 60
            local elapsed = math.floor(os.clock() - start_anchor)
            local remaining = limit_seconds - elapsed

            imgui.Text("Time Remaining:"); imgui.SameLine()

            if remaining > 0 then
                local mins = math.floor(remaining / 60)
                local secs = remaining % 60
                local time_str = string.format("%02d:%02d", mins, secs)

                local timer_color = {0.0, 1.0, 0.0, 1.0}
                if remaining <= 300 then
                    timer_color = {1.0, 0.2, 0.2, 1.0}
                elseif remaining <= 600 then
                    timer_color = {1.0, 0.6, 0.0, 1.0}
                end

                imgui.TextColored(timer_color, time_str)
            else
                imgui.TextColored({1.0, 0.2, 0.2, 1.0}, "00:00")
            end
        else
            imgui.TextColored({0.6, 0.6, 0.6, 1.0}, "Waiting to Enter Assault / Salvage...")
        end
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end

-- RollTracker Bar
local function draw_rolltracker_horizontal()
    if not config.show_roll_bar then return end

    local active_rolls = RollTracker.active_rolls
    local now = os.clock()

    -- Expire rolls past their 5-minute duration
    for k, v in pairs(active_rolls) do
        if v.expiration and (v.expiration - now) <= 0 then
            active_rolls[k] = nil
        end
    end

    -- Hide if no rolls active
    if next(active_rolls) == nil then return end

    imgui.SetNextWindowBgAlpha(config.bg_opacity)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, config.window_rounding)
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8, 12 })

    imgui.PushStyleColor(ImGuiCol_WindowBg, {0, 0, 0, config.bg_opacity})

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoTitleBar
    )

    if imgui.Begin('InfoBar - RollTracker', { true }, flags) then
        for rollName, data in pairs(active_rolls) do
            -- Roll name & circled total number with colors
            local circle_color = { 1.0, 0.8, 0.2, 1.0 }     -- Default Orange
            if data.is_bust then
                circle_color = { 1.0, 0.0, 0.0, 1.0 }       -- Red
            elseif data.total == 11 then
                circle_color = { 0.1, 1.0, 0.1, 1.0 }       -- Bright Green
            elseif data.total == data.lucky then
                circle_color = { 0.55, 0.90, 0.75, 1.0 }    -- Light Green
            elseif data.total == data.unlucky then
                circle_color = { 1.0, 0.45, 0.45, 1.0 }     -- Light Red
            end

            imgui.Text(rollName)
            imgui.SameLine()
            DrawCircledNumber(data.total, circle_color)
            imgui.SameLine()
            imgui.Dummy({ 2, 0 })
            imgui.SameLine()

            -- Lucky / Unlucky Display: [L:X/U:Y] (Toggleable)
            if config.show_lucky_info and data.lucky and data.unlucky then
                local c_1 = { 1.0, 1.0, 1.0, 1.0 }     -- Default White
                local c_2 = { 0.55, 0.90, 0.75, 1.0 }  -- Light Green
                local c_3 = { 0.6, 0.6, 0.6, 0.8 }     -- Gray
                local c_4 = { 1.0, 0.45, 0.45, 1.0 }   -- Light Red

                imgui.TextColored(c_1, "[L:")
                imgui.SameLine(0, 0)
                imgui.TextColored(c_2, tostring(data.lucky))
                imgui.SameLine(0, 0)
                imgui.TextColored(c_3, "/")
                imgui.SameLine(0, 0)
                imgui.TextColored(c_1, "U:")
                imgui.SameLine(0, 0)
                imgui.TextColored(c_4, tostring(data.unlucky))
                imgui.SameLine(0, 0)
                imgui.TextColored(c_1, "]")
                imgui.SameLine()
            end

            -- Status & Effect Text
            local effect_str = data.effect_text or "Value unknown"

            if data.is_bust then
                imgui.TextColored({ 1.0, 0.0, 0.0, 1.0 }, "(Bust! " .. effect_str .. ")")
            elseif data.total == 11 then
                imgui.TextColored({ 0.1, 1.0, 0.1, 1.0 }, "(\xef\x94\xa3\xef\x94\xa6 " .. effect_str .. ")")
            elseif data.total == data.lucky then
                imgui.TextColored({ 0.55, 0.90, 0.75, 1.0 }, "(Lucky! " .. effect_str .. ")")
            elseif data.total == data.unlucky then
                imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, "(Unlucky! " .. effect_str .. ")")
            else
                imgui.TextColored({ 1.0, 0.8, 0.2, 1.0 }, "(" .. effect_str .. ")")
            end

            -- Countdown Timer Next to Roll/Bust Status
            if config.show_roll_timer and data.expiration then
                local remaining = math.max(0, math.floor(data.expiration - now))
                local timer_str = string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
                imgui.SameLine()
                imgui.TextDisabled("[" .. timer_str .. "]")
            end
        end
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(3)
end

local function draw_weather_test_window()
    if not show_weather_test then return end

    imgui.SetNextWindowBgAlpha(config.bg_opacity)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, config.window_rounding)
    imgui.PushStyleColor(ImGuiCol_WindowBg, {0.0, 0.0, 0.0, config.bg_opacity})

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoTitleBar
    )

    if imgui.Begin('InfoBar - Weather Colors', { true }, flags) then
        for id, name in pairs(Weather.table) do
            local col = Weather.colors[name] or { 1, 1, 1, 1 }
            imgui.TextColored(col, name)
        end
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end

-- Preset
ashita.events.register('d3d_present', 'infobar_present', function()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local entity = GetPlayerEntity()

    if not player or not entity then return end

    if player.isZoning or player:GetMainJob() == 0 or entity.StatusServer == 4 then
        return
    end

    if currentZoneName == '' or currentRegionName == '' then
        ZoneState.refresh()
    end

    updateActiveTheme()
    draw_settings_window()
    draw_theme_window()
    draw_top_window()
    draw_bottom_window()
    draw_weekday_vertical()
    draw_weekday_horizontal()
    draw_exp_horizontal()
    draw_assault_horizontal()
    draw_rolltracker_horizontal()
    draw_weather_test_window()
end)
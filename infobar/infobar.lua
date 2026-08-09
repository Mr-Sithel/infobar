-----------------------------------------------------------------------------------------------------
-- Many creators involved that made the orignal code from the modules I put in the modules folder.
-- I then created and assembled InfoBar Overlay to display in game.
-- Credit goes out to Thorny, Atom0s, Loonsies, Xenonsmurf, Onimitch, Matix, Hugin, XIUI Team
-- and anyone else I may have missed.
-----------------------------------------------------------------------------------------------------

addon.name    = 'InfoBar'
addon.author  = 'Sithel'
addon.version = '0.4'
addon.desc    = 'Info Bar that shows (Job|Compass|pos|Zone Timer|Zone|Region|Day|Weather|Vana Time|Moon Phase).'
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
local theme       = require('modules/infobar_theme')

---------------------------------------------------------
-- SETTINGS
---------------------------------------------------------
local default_settings = T{
    x_single = 878,
    y_single = 17,

    x_double_top    = 878,
    y_double_top    = 17,
    x_double_bottom = 878,
    y_double_bottom = 52,

    use_icons = false,
    two_bars   = false,
    bg_opacity = 0.6,
    window_rounding = 6.0,

    show_weekday_horizontal = false,
    show_weekday_vertical   = false,
    show_exp_horizontal     = false,

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

---------------------------------------------------------
-- SETTINGS
---------------------------------------------------------
local function update_settings(s)
    if s ~= nil then
        config = s
    end
    settings.save()
end

settings.register('settings', 'settings_update', update_settings)

---------------------------------------------------------
-- STATE
---------------------------------------------------------
local show_weather_test       = false
local show_settings_window    = false

local currentZoneName   = ''
local currentRegionName = ''
local zone_enter_time   = os.clock()

local top_initialized    = false
local bottom_initialized = false

---------------------------------------------------------
-- HELPERS
---------------------------------------------------------
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

---------------------------------------------------------
-- ZONE UPDATES
---------------------------------------------------------
ZoneState.onChange(function(id, name, region)
    currentZoneName   = name or ''
    currentRegionName = region or ''
    zone_enter_time   = os.clock()
end)

ashita.events.register('load', 'infobar_load', function()
    ZoneState.init()
    ashita.tasks.once(1, ZoneState.refresh)
end)

---------------------------------------------------------
-- COMMANDS
---------------------------------------------------------
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
        print('\31\207 /ibar                    \31\8 - This help menu.');
        print('\31\207 /ibar  c|config|settings \31\8 - shows a settings window.');
        print('\31\207 /ibar  w|weekdays        \31\8 - shows days of the week order.');
        print('\31\207 /ibar  e|exp             \31\8 - shows an exp bar.');
        print('\31\207 /ibar  r|reset           \31\8 - reset positions.');
        print('\31\207 /ibar  save              \31\8 - save settings.');
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

    if T{'mode', 'm'}:contains(sub) then
        config.two_bars = not config.two_bars
        top_initialized    = false
        bottom_initialized = false
        settings.save()
        return
    end

    if T{'reset', 'r'}:contains(sub) then
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

---------------------------------------------------------
-- IMGUI WINDOWS
---------------------------------------------------------
local function draw_settings_window()
    if not show_settings_window then return end

    theme.push()

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoTitleBar
    )

    --if imgui.Begin("InfoBar - Settings", nil, flags) then     -- Ashita 4.30
    if imgui.Begin('InfoBar - Settings', { true }, flags) then  -- Ashita 4.16 or 4.30
        imgui.Text("InfoBar Settings")
        imgui.Separator()
        imgui.Text("Display Options")

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

        -- Column 2
        imgui.SameLine(200)

        imgui.BeginGroup()
        toggle("Show Compass",    "show_playerdir")
        toggle("Show Day",        "show_day")
        toggle("Show Vana Time",  "show_time")
        toggle("Show Weather",    "show_weather")
        toggle("Show Moon Phase", "show_moon")
        imgui.EndGroup()

        imgui.Separator()

        -------------------------------------------------
        -- TWO BAR MODE
        -------------------------------------------------
        local val = { config.two_bars }
        if imgui.Checkbox("Two Bars Mode", val) then
            config.two_bars = val[1]
            top_initialized    = false
            bottom_initialized = false
            settings.save()
        end

        -------------------------------------------------
        -- USE ICONS
        -------------------------------------------------
        local ref = { config.use_icons }
        if imgui.Checkbox("Enable Icons", ref) then
            config.use_icons = ref[1]
            settings.save()
        end

        -------------------------------------------------
        -- OPACITY SLIDER
        -------------------------------------------------
        imgui.Separator()
        imgui.Text("Background Options")
        local opacity_ref = { config.bg_opacity }
        if imgui.SliderFloat("Opacity", opacity_ref, 0.0, 1.0, "%.2f") then
            config.bg_opacity = opacity_ref[1]
            settings.save()
        end

        -------------------------------------------------
        -- Background Rounding Slider (1–15)
        -------------------------------------------------
        local rounding_ref = { config.window_rounding }
        if imgui.SliderFloat("Round Corners", rounding_ref, 1.0, 15.0, "%.0f") then
            config.window_rounding = rounding_ref[1]
            settings.save()
        end
        imgui.Separator()

        -------------------------------------------------
        -- WINDOW TOGGLES
        -------------------------------------------------
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
        imgui.Separator()

        -------------------------------------------------
        -- RESET + SAVE BUTTONS
        -------------------------------------------------
        if imgui.Button("Reset Positions") then
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
        if imgui.Button("Save Settings") then
            settings.save()
        end

        imgui.SameLine()
        if imgui.Button("Close") then
            show_settings_window = false
        end
    end

    imgui.End()
    theme.pop()
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

    --if imgui.Begin('InfoBar - Top', nil, flags) then    -- Ashita 4.30
    if imgui.Begin('InfoBar - Top', { true }, flags) then -- Ashita 4.16 or 4.30
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

        ---------------------------------------------------------
        -- TWO-BAR MODE 
        ---------------------------------------------------------
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
                    -- Zone timer (green)
                    if item.value == get_zone_timer() then
                        if config.use_icons then
                            imgui.TextColored({0.0, 1.0, 0.0, 1.0}, "\xef\x8b\xb2 " .. item.value)
                        else
                            imgui.TextColored({0.0, 1.0, 0.0, 1.0}, "Zone Timer " .. item.value)
                        end
                    -- Player direction 
                    elseif item.value == facing then
                        imgui.TextColored(Direction.color_for(facing), item.value)
                    else
                        imgui.Text(item.value)
                    end
                end
                imgui.SameLine()
            end

        ---------------------------------------------------------
        -- SINGLE-BAR MODE 
        ---------------------------------------------------------
        else
            local day, time = get_vana_day_and_time()
            local weather_name  = Weather.get()
            local weather_color = Weather.get_color()
            local facing = Direction.get()

            -- LEFT SIDE (job | compass | pos | timer | zone | region)
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

            -- DAY
            if config.show_day then
                draw_colored_day(day)
                imgui.SameLine()
            end

            -- TIME
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

            -- WEATHER
            if config.show_weather then
                imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|")
                imgui.SameLine()
                imgui.TextColored(weather_color, weather_name)
                imgui.SameLine()
            end

            -- MOON
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

    --if imgui.Begin('InfoBar - Bottom', nil, flags) then    -- Ashita 4.30
    if imgui.Begin('InfoBar - Bottom', { true }, flags) then -- Ashita 4.16 or 4.30
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

        -------------------------------------------------
        -- LIST OF ITEMS TO DISPLAY
        -------------------------------------------------
        local parts = {}

        if config.show_day     then table.insert(parts, { type = "day",     value = day }) end
        if config.show_time    then table.insert(parts, { type = "text",    value = time }) end
        if config.show_weather then table.insert(parts, { type = "weather", value = weather_name, color = weather_color }) end
        if config.show_moon    then table.insert(parts, { type = "text",    value = get_moon_phase() }) end

        -------------------------------------------------
        -- DRAW THE ROW
        -------------------------------------------------
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
                    -- Clock icon + yellow Vana time
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

    --if imgui.Begin("InfoBar - Weekdays (Vertical)", nil, flags) then    -- Ashita 4.30
    if imgui.Begin('InfoBar - Weekdays (Vertical)', { true }, flags) then -- Ashita 4.16 or 4.30
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

    --if imgui.Begin("InfoBar - Weekdays (Horizontal)", nil, flags) then    -- Ashita 4.30
    if imgui.Begin('InfoBar - Weekdays (Horizontal)', { true }, flags) then -- Ashita 4.16 or 4.30
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

    --if imgui.Begin("InfoBar - EXP (Horizontal)", nil, flags) then    -- Ashita 4.30
    if imgui.Begin('InfoBar - EXP (Horizontal)', { true }, flags) then -- Ashita 4.16 or 4.30
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
            imgui.TextColored({0.23, 0.61, 0.91, 1.0}, merit_str); imgui.SameLine() -- blue
        else
            imgui.Text("EXP:"); imgui.SameLine()
            local exp_str = string.format("%s/%s", Exp.format_comma(curr), Exp.format_comma(max))
            imgui.TextColored({0.55, 0.90, 0.75, 1.0}, exp_str); imgui.SameLine() -- light green
        end

        imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|"); imgui.SameLine()

        imgui.Text(tnl_label); imgui.SameLine()
        if lp_mode then
            imgui.TextColored({0.23, 0.61, 0.91, 1.0}, Exp.format_comma(tnl)); imgui.SameLine() -- blue
            imgui.TextColored({0.2, 0.8, 0.2, 1.0}, string.format("(%d)", data.merit_count or 0)); imgui.SameLine() -- green
        else
            imgui.TextColored({0.55, 0.90, 0.75, 1.0}, Exp.format_comma(tnl)); imgui.SameLine() -- light green
        end

        imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|"); imgui.SameLine()

        imgui.Text("Rate:"); imgui.SameLine()
        if lp_mode then
            local mp_rate = (data.exp_per_hr or 0) / 10000
            local rate_str = string.format("%.1f", mp_rate)
            imgui.TextColored({1.0, 0.80, 0.20, 1.0}, rate_str); imgui.SameLine() -- orange/yellow
            imgui.TextColored({1, 1, 1, 1}, " mp/hr"); imgui.SameLine()
        else
            local rate_str = Exp.format_comma(data.exp_per_hr or 0)
            imgui.TextColored({1.0, 0.80, 0.20, 1.0}, rate_str); imgui.SameLine() -- orange/yellow
            imgui.TextColored({1, 1, 1, 1}, " xp/hr"); imgui.SameLine()
        end

        imgui.TextColored({0.6, 0.6, 0.6, 0.4}, "|"); imgui.SameLine()

        --imgui.TextColored({1.0, 0.6, 0.0, 1.0}, " \xef\x83\x81\xef\x81\xa1"); imgui.SameLine()
        imgui.Text("Chain:"); imgui.SameLine()

        local chain_rem = Exp.get_chain_time_remaining and Exp.get_chain_time_remaining() or 0
        if chain_rem > 0 then
            local mins = math.floor(chain_rem / 60)
            local secs = chain_rem % 60
            
            -- Displays "#0 (4m 59s)"
            local chain_str = string.format("# %d (%dm %02ds)", chain, mins, secs)
            local timer_color = {1.0, 1.0, 0.67, 1.0}

            if chain_rem <= 10 then
                timer_color = {1.0, 0.2, 0.2, 1.0}  -- Red
            elseif chain_rem <= 30 then
                timer_color = {1.0, 0.6, 0.0, 1.0}  -- Orange
            end

            imgui.TextColored(timer_color, chain_str)
        else
            imgui.TextColored({1.0, 0.80, 0.20, 1.0}, "0")
            --imgui.Text("0")
        end
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
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

    --if imgui.Begin("InfoBar - Weather Colors", nil, flags) then    -- Ashita 4.30
    if imgui.Begin('InfoBar - Weather Colors', { true }, flags) then -- Ashita 4.16 or 4.30
        for id, name in pairs(Weather.table) do
            local col = Weather.colors[name] or { 1, 1, 1, 1 }
            imgui.TextColored(col, name)
        end
    end

    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar(2)
end

---------------------------------------------------------
-- PRESENT
---------------------------------------------------------
ashita.events.register('d3d_present', 'infobar_present', function()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local entity = GetPlayerEntity()

    -- hide UI if player/entity objects aren't initialized yet
    if not player or not entity then return end

    -- hide UI during zoning, uninitialized job state (0), or cutscenes/events (StatusServer == 4)
    if player.isZoning or player:GetMainJob() == 0 or entity.StatusServer == 4 then
        return
    end

    if currentZoneName == '' or currentRegionName == '' then
        ZoneState.refresh()
    end

    draw_settings_window()
    draw_top_window()
    draw_bottom_window()
    draw_weekday_vertical()
    draw_weekday_horizontal()
    draw_exp_horizontal()
    draw_weather_test_window()
end)
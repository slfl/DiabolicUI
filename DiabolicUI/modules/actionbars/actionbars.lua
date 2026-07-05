local _, Engine = ...
local L = Engine:GetLocale()

-- This module requires a "HIGH" priority, 
-- as other modules like the questtracker and the unitframes
-- hook themselves into its frames!
local Module = Engine:NewModule("ActionBars", "HIGH")
Module.Template = {} -- table to hold templates for buttons and bars

-- Lua API
local ipairs, select, unpack = ipairs, select, unpack
local tonumber = tonumber
local tinsert = table.insert

-- WoW API
local CreateFrame = CreateFrame
local GetAccountExpansionLevel = GetAccountExpansionLevel
local GetScreenWidth = GetScreenWidth
local GetTimeToWellRested = GetTimeToWellRested
local GetXPExhaustion = GetXPExhaustion
local IsXPUserDisabled = IsXPUserDisabled
local IsPossessBarVisible = IsPossessBarVisible
local UnitAffectingCombat = UnitAffectingCombat
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GameTooltip = GameTooltip
local MAX_PLAYER_LEVEL_TABLE = MAX_PLAYER_LEVEL_TABLE
local GetWatchedFactionInfo = GetWatchedFactionInfo

local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]]

-- whether or not the XP bar is enabled
Module.IsXPEnabled = function(self)
    if IsXPUserDisabled() 
    or UnitLevel("player") == (MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel() or #MAX_PLAYER_LEVEL_TABLE] or MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE]) then
        return
    end
    return true
end

Module.ApplySettings = Module:Wrap(function(self)
    local db = self.db
    local Main = self:GetWidget("Controller: Main"):GetFrame()
    local Side = self:GetWidget("Controller: Side"):GetFrame()
    
    -- Tell the secure environment about the number of visible bars
    -- This will also fire off an artwork update and sizing of bars and buttons!
    Main:SetAttribute("numbars", db.num_bars)
    Side:SetAttribute("numbars", db.num_side_bars)
end)

Module.LoadArtwork = function(self)
    local config = self.config.visuals.artwork
    local db = self.db
    
    local Main = self:GetWidget("Controller: Main"):GetFrame()
    
    self.artwork = {}
    self.artwork_modes = { "1", "2", "3", "vehicle" }
    
    -- holder for the artwork behind the buttons and globes
    local background = CreateFrame("Frame", nil, Main)
    background:SetFrameStrata("BACKGROUND")
    background:SetFrameLevel(10) -- room for the xp/rep bar
    background:SetAllPoints()
    
    -- artwork overlaying the globes (demon and angel)
    local overlay = CreateFrame("Frame", nil, Main)
    overlay:SetFrameStrata("MEDIUM")
    overlay:SetFrameLevel(10) -- room for the player unit frame and actionbuttons
    overlay:SetAllPoints()
    
    local new = function(parent, config)
        local artwork = parent:CreateTexture(nil, "ARTWORK")
        artwork:Hide()
        artwork:SetSize(unpack(config.size))
        artwork:SetTexture(config.texture)
        artwork:SetPoint(unpack(config.position))
        return artwork
    end

    for _,i in ipairs(self.artwork_modes) do
        self.artwork["bar"..i] = new(background, config[i].center)
        self.artwork["bar"..i.."left"] = new(overlay, config[i].left)
        self.artwork["bar"..i.."right"] = new(overlay, config[i].right)
        self.artwork["bar"..i.."skull"] = new(overlay, config[i].skull)

        -- doesn't exist for vehicles
        if config[i].centerxp then
            self.artwork["bar"..i.."xp"] = new(background, config[i].centerxp)
            self.artwork["bar"..i.."skullxp"] = new(overlay, config[i].skullxp)
        end
    end
end

Module.UpdateArtwork = function(self)
    local db = self.db
    
    -- we do a load on demand system here
    -- that creates the artwork upon the first bar update
    if not self.artwork then
        self:LoadArtwork() -- load the artwork
    end
    
    -- figure out which backdrop texture to show
    local Main = self:GetWidget("Controller: Main"):GetFrame()
    local state = tostring(Main:GetAttribute("state-page"))
    local num_bars = tonumber(Main:GetAttribute("numbars"))

    local artwork = self.artwork
    local artwork_modes = self.artwork_modes

    local has_xp_bar = self:IsXPEnabled()
    local xp_bar_widget = self:GetWidget("Bar: XP")
    local has_rep_bar = xp_bar_widget and xp_bar_widget.repData and xp_bar_widget.repData.isRep or false

    -- The XP-styled artwork (BarXP.tga) is used whenever the progress bar is
    -- visible for ANY reason: experience (1-79) OR a watched reputation (80).
    -- Otherwise the plain artwork (Bar.tga) is used.
    local show_xp_art = has_xp_bar or has_rep_bar

    local mode
    if state == "possess" or state == "vehicle" then
        mode = "vehicle"
    else
        mode = tostring(num_bars)
    end
    
    for _,i in ipairs(self.artwork_modes) do
        if i == mode then
            -- Show left and right (angel/demon) unless the user disabled artwork
            if Engine:GetConfig("UI", "character").show_artwork ~= false then
                self.artwork["bar"..i.."left"]:Show()
                self.artwork["bar"..i.."right"]:Show()
            else
                self.artwork["bar"..i.."left"]:Hide()
                self.artwork["bar"..i.."right"]:Hide()
            end

            if show_xp_art and self.artwork["bar"..i.."xp"] then
                -- progress bar visible -> XP-styled artwork
                self.artwork["bar"..i.."xp"]:Show()
                self.artwork["bar"..i.."skullxp"]:Show()
                self.artwork["bar"..i]:Hide()
                self.artwork["bar"..i.."skull"]:Hide()
            else
                -- no progress bar -> plain artwork
                self.artwork["bar"..i]:Show()
                self.artwork["bar"..i.."skull"]:Show()
                if self.artwork["bar"..i.."xp"] then
                    self.artwork["bar"..i.."xp"]:Hide()
                    self.artwork["bar"..i.."skullxp"]:Hide()
                end
            end
        else
            -- Hide all textures for non-active modes
            if self.artwork["bar"..i.."xp"] then
                self.artwork["bar"..i.."xp"]:Hide()
                self.artwork["bar"..i.."skullxp"]:Hide()
            end
            self.artwork["bar"..i]:Hide()
            self.artwork["bar"..i.."skull"]:Hide()
            self.artwork["bar"..i.."left"]:Hide()
            self.artwork["bar"..i.."right"]:Hide()
        end
    end
end

Module.GrabKeybinds = Module:Wrap(function(self)
    local bars = self.bars
    if not self.binding_table then
        self.binding_table = {
            "ACTIONBUTTON%d",                -- main action bar
            "MULTIACTIONBAR1BUTTON%d",       -- bottomleft bar
            "MULTIACTIONBAR2BUTTON%d",       -- bottomright bar
            "MULTIACTIONBAR3BUTTON%d",       -- right sidebar
            "MULTIACTIONBAR4BUTTON%d",       -- left sidebar
            "BONUSACTIONBUTTON%d",           -- pet bar
            "SHAPESHIFTBUTTON%d"             -- stance bar
        }
    end
    for bar_number,action_name in ipairs(self.binding_table) do
        local bar = bars[bar_number] -- upvalue the current bar
        if bar then
            ClearOverrideBindings(bar) -- clear current overridebindings
            for button_number, button in bar:GetAll() do -- only work with the buttons that have actually spawned
                local action = action_name:format(button_number) -- get the correct keybinding action name
                button:SetBindingAction(action) -- store the binding action name on the button
                for key_number = 1, select("#", GetBindingKey(action)) do -- iterate through the registered keys for the action
                    local key = select(key_number, GetBindingKey(action)) -- get a key for the action
                    if key and key ~= "" then
                        -- this is why we need named buttons
                        SetOverrideBindingClick(bars[bar_number], false, key, button:GetName()) -- assign the key to our own button
                    end    
                end
            end
        end
    end    
    
    -- update the vehicle bar keybind display
    local vehicle_bar = self:GetWidget("Bar: Vehicle"):GetFrame()
    for button_number, button in vehicle_bar:GetAll() do -- only work with the buttons that have actually spawned
        local action = "ACTIONBUTTON"..button_number -- get the correct keybinding action name
        button:SetBindingAction(action) -- store the binding action name on the button
    end

    -- TODO: add binds for our custom fishing/garrison bar
    
    if not self.vehicle_controller then
        -- We're using a custom vehicle bar, and in order for it to work properly, 
        -- we need to borrow the primary action bar's keybinds temporarily.
        -- This will override the temporary bindings normally assigned to our own main action bar. 
        local controller = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        controller:SetAttribute("_onstate-vehicle", [[
            if newstate == "vehicle" then
                for i = 1,6 do
                    local our_button, vehicle_button = ("ACTIONBUTTON%d"):format(i), ("CLICK EngineVehicleBarButton%d:LeftButton"):format(i)

                    -- Grab the keybinds from the default action bar,
                    -- and assign them to our custom vehicle bar. 

                    for k=1,select("#", GetBindingKey(our_button)) do
                        local key = select(k, GetBindingKey(our_button)) -- retrieve the binding key from our own primary bar
                        self:SetBinding(true, key, vehicle_button) -- assign that key to the vehicle bar
                    end
                end
            else
                -- Return the key bindings to whatever buttons they were
                -- assigned to before we so rudely grabbed them! :o
                self:ClearBindings()
            end
        ]])
        
        self.vehicle_controller = controller
    end

    UnregisterStateDriver(self.vehicle_controller, "vehicle")
    RegisterStateDriver(self.vehicle_controller, "vehicle", "[bonusbar:5][vehicleui]vehicle;novehicle")
end)

Module.OnInit = function(self, event, ...)
    self.config = self:GetStaticConfig("ActionBars") -- static config
    self.db = self:GetConfig("ActionBars", "character") -- per user settings for bars

    -- Enable controllers
    -- These mostly handle visibility, size and layout,
    -- so that other secure frames can anchor themselves to the bars.
    self:GetWidget("Controller: Main"):Enable()
    self:GetWidget("Controller: Side"):Enable()
    self:GetWidget("Controller: Stance"):Enable()
    self:GetWidget("Controller: Pet"):Enable()
    self:GetWidget("Controller: Menu"):Enable()
    self:GetWidget("Controller: Chat"):Enable()

    -- Enable bars
    -- Bars exist within their respective controllers, 
    -- but handles their own paging and visibilty.
    self:GetWidget("Bar: Vehicle"):Enable()
    self:GetWidget("Bar: 1"):Enable()
    self:GetWidget("Bar: 2"):Enable()
    self:GetWidget("Bar: 3"):Enable()
    self:GetWidget("Bar: 4"):Enable()
    self:GetWidget("Bar: 5"):Enable()
    self:GetWidget("Bar: Pet"):Enable()
    self:GetWidget("Bar: Stance"):Enable()
    self:GetWidget("Bar: XP"):Enable()
    
    -- enable menus
    self:GetWidget("Menu: Main"):Enable()
    self:GetWidget("Menu: Chat"):Enable()
    

    -- This is used to reassign the keybinds, 
    -- and the order of the bars determine what keybinds to grab. 
    self.bars = {} 
    tinsert(self.bars, self:GetWidget("Bar: 1"):GetFrame())    -- 1
    tinsert(self.bars, self:GetWidget("Bar: 2"):GetFrame())    -- 2
    tinsert(self.bars, self:GetWidget("Bar: 3"):GetFrame())    -- 3
    tinsert(self.bars, self:GetWidget("Bar: 4"):GetFrame())    -- 4
    tinsert(self.bars, self:GetWidget("Bar: 5"):GetFrame())    -- 5
    tinsert(self.bars, self:GetWidget("Bar: Pet"):GetFrame()) -- 7
    tinsert(self.bars, self:GetWidget("Bar: Stance"):GetFrame()) -- 6
        
    self:GrabKeybinds()
    self:RegisterEvent("UPDATE_BINDINGS", "GrabKeybinds")

    -- make sure the artwork module captures xp and reputation visibility updates
    self:RegisterEvent("PLAYER_ALIVE", "UpdateArtwork")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateArtwork")
    self:RegisterEvent("PLAYER_LEVEL_UP", "UpdateArtwork")
    self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateArtwork")
    self:RegisterEvent("PLAYER_LOGIN", "UpdateArtwork")
    self:RegisterEvent("PLAYER_FLAGS_CHANGED", "UpdateArtwork")
    self:RegisterEvent("DISABLE_XP_GAIN", "UpdateArtwork")
    self:RegisterEvent("ENABLE_XP_GAIN", "UpdateArtwork")
    self:RegisterEvent("PLAYER_UPDATE_RESTING", "UpdateArtwork")
    self:RegisterEvent("UPDATE_FACTION", "UpdateArtwork")
    
    -- faking a CVar here for WotLK clients
    local value, defaultValue, serverStoredAccountWide, serverStoredPerCharacter = GetCVarInfo("ActionButtonUseKeyDown")
    if value == nil and defaultValue == nil and serverStoredAccountWide == nil and serverStoredPerCharacter == nil then
        RegisterCVar("ActionButtonUseKeyDown", false)
        hooksecurefunc("SetCVar", function(name, value) 
            if name == "ActionButtonUseKeyDown" then
                self:GetWidget("Template: Button"):OnEvent("CVAR_UPDATE", "ACTION_BUTTON_USE_KEY_DOWN", value)
                self.db.cast_on_down = GetCVarBool("ActionButtonUseKeyDown") and 1 or 0 -- store the change 
            end
        end)
        
        -- set the newly created CVar to our stored setting
        SetCVar("ActionButtonUseKeyDown", self.db.cast_on_down == 1 and "1" or "0")
    end
    
    -- add the button to the same menu as it's found in from Cata and up
    local name = "InterfaceOptionsCombatPanelActionButtonUseKeyDown"
    if not _G[name] then
        -- We're mimicking what blizzard do to create the button in Cata and higher here
        -- We can't directly add it to their system, though, because the menu is secure and that would taint it 
        local button = CreateFrame("CheckButton", "$parentActionButtonUseKeyDown", InterfaceOptionsCombatPanel, "InterfaceOptionsCheckButtonTemplate")
        button:SetPoint("TOPLEFT", button:GetParent():GetName().."SelfCastKeyDropDown", "BOTTOMLEFT", 14, -24)
        button:SetChecked(GetCVarBool("ActionButtonUseKeyDown"))
        button:SetScript("OnClick", function() 
            if button:GetChecked() then
                SetCVar("ActionButtonUseKeyDown", "1")
            else
                SetCVar("ActionButtonUseKeyDown", "0")
            end
            self:GetWidget("Template: Button"):OnEvent("CVAR_UPDATE", "ACTION_BUTTON_USE_KEY_DOWN", GetCVar("ActionButtonUseKeyDown"))
        end)
        _G[button:GetName() .. "Text"]:SetText(L["Cast action keybinds on key down"])
    end
end

-- Shows or hides the menu/bags and chat/friends buttons based on the setting.
-- These are secure frames, so we can't Hide/Show them during combat -- if the
-- player is in combat we defer the change until they leave combat.
Module.UpdateArtworkVisibility = function(self)
    -- artwork show/hide is driven by UpdateArtwork reading the setting
    if self.artwork then
        self:UpdateArtwork()
    end
end

Module.UpdateButtonsVisibility = function(self)
    local show = Engine:GetConfig("UI", "character").show_buttons

    local menu = self:GetWidget("Controller: Menu"):GetFrame()
    local chat = self:GetWidget("Controller: Chat"):GetFrame()

    if InCombatLockdown() then
        -- can't touch secure frames in combat; retry once combat ends
        if not self._buttonsVisibilityDeferred then
            self._buttonsVisibilityDeferred = true
            local waiter = CreateFrame("Frame")
            waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
            waiter:SetScript("OnEvent", function(w)
                w:UnregisterEvent("PLAYER_REGEN_ENABLED")
                Module._buttonsVisibilityDeferred = nil
                Module:UpdateButtonsVisibility()
            end)
        end
        return
    end

    if show then
        menu:Show()
        chat:Show()
    else
        menu:Hide()
        chat:Hide()
    end
end

Module.OnEnable = function(self, event, ...)
    local BlizzardUI = self:GetHandler("BlizzardUI")
    BlizzardUI:GetElement("ActionBars"):Disable()
    
    BlizzardUI:GetElement("Menu_Panel"):Remove(6, "InterfaceOptionsActionBarsPanel")
    
    -- In theory this shouldn't have any effect, but by removing the menu panels above, 
    -- we're preventing the blizzard UI from calling it, and for some reason it is 
    -- required to be called at least once, or the game won't fire off the events 
    -- that tell the UI that the player has an active pet out. 
    -- In other words: without it both the pet bar and pet unitframe will fail after a /reload
    SetActionBarToggles(nil, nil, nil, nil, nil)

    -- enable templates (button events, etc)
    self:GetWidget("Template: Button"):Enable()

    -- apply all module settings
    -- this also fires off the enabling and positioning of the actionbars
    self:ApplySettings()

    -- apply the saved show/hide state for the menu & chat buttons
    self:UpdateButtonsVisibility()
end
local _, Engine = ...
local Module = Engine:GetModule("ActionBars")
local BarWidget = Module:SetWidget("Bar: XP")
local StatusBar = Engine:GetHandler("StatusBar")
local L = Engine:GetLocale()

-- Lua API
local unpack, select = unpack, select
local tonumber, tostring = tonumber, tostring
local floor, min = math.floor, math.min

-- WoW API
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local GetAccountExpansionLevel = GetAccountExpansionLevel
local GetTimeToWellRested = GetTimeToWellRested
local GetRestState = GetRestState
local GetXPExhaustion = GetXPExhaustion
local IsResting = IsResting
local IsXPUserDisabled = IsXPUserDisabled
local MAX_PLAYER_LEVEL_TABLE = MAX_PLAYER_LEVEL_TABLE
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitLevel = UnitLevel
local UnitRace = UnitRace
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GetWatchedFactionInfo = GetWatchedFactionInfo

-- time constants (used in the rested tooltip)
local hour, minute = 3600, 60

local maxRested = select(2, UnitRace("player")) == "Pandaren" and 3 or 1.5
local colors = {
    xp = { 251/255, 120/255, 29/255 }, 
    xp_rested = { 251/255, 120/255, 29/255 }, 
    xp_rested_bonus = { 251/255 * 1/3, 120/255 * 1/3, 29/255 * 1/3 }, 
    normal = { .9, .7, .15 },
    highlight = { 250/255, 250/255, 250/255 },
    green = { .15, .79, .15 },
    dimred = { .8, .1, .1 },
    offwhite = { .79, .79, .79 },
    offgreen = { .63, .83, .63 },
    reaction = {
        { 175/255, 76/255, 56/255 }, -- hated
        { 175/255, 76/255, 56/255 }, -- hostile
        { 192/255, 68/255, 0/255 }, -- unfriendly
        { 229/255, 210/255, 60/255 }, -- neutral
        { 64/255, 131/255, 38/255 }, -- friendly
        { 64/255, 131/255, 38/255 }, -- honored
        { 64/255, 131/255, 38/255 }, -- revered
        { 64/255, 131/255, 38/255 } -- exalted
    }
}

local shortString = "%s%%"
local longXPString = "%s / %s"
local fullXPString = "%s / %s - %s%%"
local restedString = " (%s%% %s)"
local shortLevelString = "%s %d"
local repString = "%s: %s / %s - %s%%"

local colorize = function(str, color)
    local r, g, b = unpack(colors[color] or colors.normal)
    return ("|cff%02X%02X%02X%s|r"):format(floor(r*255), floor(g*255), floor(b*255), str)
end

local short = function(value)
    value = tonumber(value)
    if not value then return "" end
    if value >= 1e6 then
        return ("%.1f"):format(value / 1e6):gsub("%.?0+([km])$", "%1") .. colorize("m", "offwhite")
    elseif value >= 1e3 or value <= -1e3 then
        return ("%.1f"):format(value / 1e3):gsub("%.?0+([km])$", "%1") .. colorize("k", "offwhite")
    else
        return tostring(value)
    end    
end

-- true when the player has reached the highest level for this client (WotLK: 80)
local IsMaxLevel = function()
    return UnitLevel("player") == (MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel() or #MAX_PLAYER_LEVEL_TABLE] or MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE])
end

-- The bar operates in one of two modes:
--   "xp"  : levels 1-79, experience gain (reputation is ignored here)
--   "rep" : level 80 (or xp disabled) AND a faction is being watched
-- If neither applies, the bar is hidden entirely.
BarWidget.GetMode = function(self)
    local xp_available = not IsXPUserDisabled() and not IsMaxLevel()
    if xp_available then
        return "xp"
    end
    if self.repData and self.repData.isRep then
        return "rep"
    end
    return nil
end

BarWidget.OnEnter = function(self)
    local mode = self:GetMode()
    if not mode then return end

    self.Controller.mouseIsOver = true

    if mode == "xp" then
        local data = self:UpdateXPData()
        if not data.xpMax then return end

        GameTooltip_SetDefaultAnchor(GameTooltip, self.Controller)
        local r2, g2, b2 = unpack(colors.offwhite)
        GameTooltip:AddLine(shortLevelString:format(LEVEL, UnitLevel("player")))
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["Current XP: "], longXPString:format(colorize(short(data.xp), "normal"), colorize(short(data.xpMax), "normal")), r2, g2, b2, r2, g2, b2)
        if data.restedLeft and data.restedLeft > 0 then
            GameTooltip:AddDoubleLine(L["Rested Bonus: "], longXPString:format(colorize(short(data.restedLeft), "normal"), colorize(short(data.xpMax * maxRested), "normal")), r2, g2, b2, r2, g2, b2)
        end
        if data.restState == 1 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Rested"], unpack(colors.highlight))
            GameTooltip:AddLine(L["%s of normal experience\ngained from monsters."]:format(shortString:format(data.mult)), unpack(colors.green))
            if data.resting and data.restedTimeLeft and data.restedTimeLeft > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["Resting"], unpack(colors.highlight))
                if data.restedTimeLeft > hour*2 then
                    GameTooltip:AddLine(L["You must rest for %s additional\nhours to become fully rested."]:format(colorize(floor(data.restedTimeLeft/hour), "offwhite")), unpack(colors.normal))
                else
                    GameTooltip:AddLine(L["You must rest for %s additional\nminutes to become fully rested."]:format(colorize(floor(data.restedTimeLeft/minute), "offwhite")), unpack(colors.normal))
                end
            end
        elseif data.restState >= 2 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Normal"], unpack(colors.highlight))
            GameTooltip:AddLine(L["%s of normal experience\ngained from monsters."]:format(shortString:format(data.mult)), unpack(colors.green))
            if not(data.restedTimeLeft and data.restedTimeLeft > 0) then 
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["You should rest at an Inn."], unpack(colors.dimred))
            end
        end
        GameTooltip:Show()

    elseif mode == "rep" then
        local data = self:UpdateRepData()
        if not data.repMax then return end

        GameTooltip_SetDefaultAnchor(GameTooltip, self.Controller)
        local r2, g2, b2 = unpack(colors.offwhite)
        local factionName = data.factionName or "Unknown"
        local standingText = _G["FACTION_STANDING_LABEL"..(data.standing or 4)] or "Unknown"
        GameTooltip:AddLine(shortLevelString:format(LEVEL, UnitLevel("player")))
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["Faction: "], colorize(factionName, "normal"), r2, g2, b2, r2, g2, b2)
        GameTooltip:AddDoubleLine(L["Standing: "], colorize(standingText, "normal"), r2, g2, b2, r2, g2, b2)
        GameTooltip:AddDoubleLine(L["Reputation: "], longXPString:format(colorize(short(data.rep), "normal"), colorize(short(data.repMax), "normal")), r2, g2, b2, r2, g2, b2)
        GameTooltip:Show()
    end

    self:UpdateBar()
end

BarWidget.OnLeave = function(self)
    GameTooltip:Hide()
    self.Controller.mouseIsOver = false
    self:UpdateBar()
end

BarWidget.Update = function(self)
    self:UpdateXPData()
    self:UpdateRepData()
    self:UpdateVisibility()
    self:UpdateBar()
    -- keep the surrounding artwork (Bar.tga vs BarXP.tga) in sync,
    -- AFTER our data is refreshed so it reads correct values.
    Module:UpdateArtwork()
end

BarWidget.UpdateBar = function(self)
    local mode = self:GetMode()
    if mode == "xp" then
        self:UpdateXPBar()
    elseif mode == "rep" then
        self:UpdateRepBar()
    end
end

BarWidget.UpdateXPBar = function(self)
    local data = self.xpData
    if not data or not data.xpMax or not data.color then return end

    local r, g, b = unpack(colors[data.color] or colors.normal)
    self.Bar:SetStatusBarColor(r, g, b)
    self.Bar:SetMinMaxValues(0, data.xpMax)
    self.Bar:SetValue(data.xp)
    self.Rested:SetMinMaxValues(0, data.xpMax)
    self.Rested:SetValue(min(data.xpMax, data.xp + (data.restedLeft or 0)))
    self.Rested:Show()
    self.Backdrop:SetVertexColor(r * 0.25, g * 0.25, b * 0.25)

    if self.Controller.mouseIsOver then
        if data.restedLeft then
            self.Value:SetFormattedText(fullXPString..colorize(restedString, "offgreen"), colorize(short(data.xp), "normal"), colorize(short(data.xpMax), "normal"), colorize(short(floor(data.xp/data.xpMax*100)), "normal"), short(floor(data.restedLeft/data.xpMax*100)), L["Rested"])
        else
            self.Value:SetFormattedText(fullXPString, colorize(short(data.xp), "normal"), colorize(short(data.xpMax), "normal"), colorize(short(floor(data.xp/data.xpMax*100)), "normal"))
        end
    else
        self.Value:SetFormattedText(shortString, colorize(short(floor(data.xp/data.xpMax*100)), "normal"))
    end
end

BarWidget.UpdateRepBar = function(self)
    local data = self.repData
    if not data or not data.repMax or data.repMax == 0 then return end

    local r, g, b = unpack(colors.reaction[data.standing] or colors.normal)
    self.Bar:SetStatusBarColor(r, g, b)
    self.Bar:SetMinMaxValues(0, data.repMax)
    self.Bar:SetValue(data.rep)
    self.Rested:SetMinMaxValues(0, data.repMax)
    self.Rested:SetValue(0)
    self.Rested:Hide()
    self.Backdrop:SetVertexColor(r * 0.25, g * 0.25, b * 0.25)

    if self.Controller.mouseIsOver then
        self.Value:SetFormattedText(repString, colorize(data.factionName or "Unknown", "normal"), colorize(short(data.rep), "normal"), colorize(short(data.repMax), "normal"), colorize(short(floor(data.rep/data.repMax*100)), "normal"))
    else
        self.Value:SetFormattedText(shortString, colorize(short(floor(data.rep/data.repMax*100)), "normal"))
    end
end

BarWidget.UpdateXPData = function(self)
    self.xpData = self.xpData or {}
    local data = self.xpData

    data.resting = IsResting()
    data.restState, data.restedName, data.mult = GetRestState()
    data.restedLeft, data.restedTimeLeft = GetXPExhaustion(), GetTimeToWellRested()
    data.xp, data.xpMax = UnitXP("player"), UnitXPMax("player")
    data.color = data.restedLeft and "xp_rested" or "xp"
    data.mult = (data.mult or 1) * 100

    if data.xpMax == 0 then
        data.xpMax = nil
        data.color = nil
    end

    return data
end

BarWidget.UpdateRepData = function(self)
    self.repData = self.repData or {}
    local data = self.repData

    local name, standing, minVal, maxVal, value = GetWatchedFactionInfo()
    if name then
        data.isRep = true
        data.factionName = name
        data.standing = standing
        data.rep = value - minVal
        data.repMin = 0
        data.repMax = maxVal - minVal
    else
        data.isRep = false
        data.factionName = nil
        data.standing = nil
        data.rep = nil
        data.repMin = nil
        data.repMax = nil
    end

    return data
end

BarWidget.UpdateSettings = function(self)
    local structure_config = Module.config.structure.controllers.xp
    local art_config = Module.config.visuals.xp
    local num_bars = tostring(self.Controller:GetParent():GetAttribute("numbars"))

    self.Controller:SetSize(unpack(structure_config.size[num_bars] or structure_config.size["1"]))
    self.Bar:SetSize(self.Controller:GetSize())
    self.Rested:SetSize(self.Controller:GetSize())
    self.Backdrop:SetTexture(art_config.backdrop.textures[num_bars])
end

BarWidget.UpdateVisibility = function(self)
    local in_vehicle = UnitHasVehicleUI("player")
    local mode = self:GetMode()

    if mode and not in_vehicle then
        self.Controller:Show()
    else
        self.Controller:Hide()
    end
end

BarWidget.OnEnable = function(self)
    self.xpData = {}
    self.repData = {}

    local structure_config = Module.config.structure.controllers.xp
    local art_config = Module.config.visuals.xp
    local num_bars = tostring(Module.db.num_bars)

    local Main = Module:GetWidget("Controller: Main"):GetFrame()

    -- Single controller used for both XP (1-79) and Reputation (80)
    local Controller = CreateFrame("Frame", nil, Main)
    Controller:SetFrameStrata("BACKGROUND")
    Controller:SetFrameLevel(0)
    Controller:SetSize(unpack(structure_config.size[num_bars] or structure_config.size["1"]))
    Controller:SetPoint(unpack(structure_config.position))
    Controller:EnableMouse(true)
    Controller:SetScript("OnEnter", function() self:OnEnter() end)
    Controller:SetScript("OnLeave", function() self:OnLeave() end)

    local Backdrop = Controller:CreateTexture(nil, "BACKGROUND")
    Backdrop:SetSize(unpack(art_config.backdrop.texture_size))
    Backdrop:SetPoint(unpack(art_config.backdrop.texture_position))
    Backdrop:SetTexture(art_config.backdrop.textures[num_bars])
    Backdrop:SetAlpha(.75)

    local Rested = StatusBar:New(Controller)
    Rested:SetSize(Controller:GetSize())
    Rested:SetAllPoints()
    Rested:SetFrameLevel(1)
    Rested:SetAlpha(art_config.rested.alpha)
    Rested:SetStatusBarTexture(art_config.rested.texture)
    Rested:SetStatusBarColor(unpack(colors.xp_rested_bonus))
    Rested:SetSparkTexture(art_config.rested.spark.texture)
    Rested:SetSparkSize(unpack(art_config.rested.spark.size))
    Rested:SetSparkFlash(2.75, 1.25, .175, .425)

    local Bar = StatusBar:New(Controller)
    Bar:SetSize(Controller:GetSize())
    Bar:SetAllPoints()
    Bar:SetFrameLevel(2)
    Bar:SetAlpha(art_config.bar.alpha)
    Bar:SetStatusBarTexture(art_config.bar.texture)
    Bar:SetSparkTexture(art_config.bar.spark.texture)
    Bar:SetSparkSize(unpack(art_config.bar.spark.size))
    Bar:SetSparkFlash(2.75, 1.25, .35, .85)

    local Overlay = CreateFrame("Frame", nil, Controller)
    Overlay:SetFrameStrata("MEDIUM")
    Overlay:SetFrameLevel(35)
    Overlay:SetAllPoints()

    local Value = Overlay:CreateFontString(nil, "OVERLAY")
    Value:SetPoint("CENTER")
    Value:SetFontObject(art_config.font_object)

    self.Controller = Controller
    self.Backdrop = Backdrop
    self.Rested = Rested
    self.Bar = Bar
    self.Value = Value

    -- Hook for bar number changes
    Main:HookScript("OnAttributeChanged", function(_, name, value) 
        if name == "numbars" then
            self:UpdateSettings()
        end
    end)

    -- Register events
    self:RegisterEvent("PLAYER_ALIVE", "Update")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
    self:RegisterEvent("PLAYER_LEVEL_UP", "Update")
    self:RegisterEvent("PLAYER_XP_UPDATE", "Update")
    self:RegisterEvent("PLAYER_LOGIN", "Update")
    self:RegisterEvent("PLAYER_FLAGS_CHANGED", "Update")
    self:RegisterEvent("DISABLE_XP_GAIN", "Update")
    self:RegisterEvent("ENABLE_XP_GAIN", "Update")
    self:RegisterEvent("PLAYER_UPDATE_RESTING", "Update")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE", "Update")
    self:RegisterEvent("UNIT_EXITED_VEHICLE", "Update")
    self:RegisterEvent("UPDATE_FACTION", "Update")

    -- Initial update to ensure data is set
    self:Update()
end

BarWidget.GetFrame = function(self)
    return self.Controller
end

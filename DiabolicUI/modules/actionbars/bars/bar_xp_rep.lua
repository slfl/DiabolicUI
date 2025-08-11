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
local GetAccountExpansionLevel = GetAccountExpansionLevel
local GetTimeToWellRested = GetTimeToWellRested
local GetXPExhaustion = GetXPExhaustion
local IsXPUserDisabled = IsXPUserDisabled
local MAX_PLAYER_LEVEL_TABLE = MAX_PLAYER_LEVEL_TABLE
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitLevel = UnitLevel
local UnitRace = UnitRace
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GetWatchedFactionInfo = GetWatchedFactionInfo

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
    -- faction reputation coloring
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

local shortXPString = "%s%%"
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

BarWidget.OnEnterXP = function(self)
    local data = self:UpdateXPData()
    if not data.xpMax then return end

    GameTooltip_SetDefaultAnchor(GameTooltip, self.XPController)
    local r, g, b = unpack(colors.highlight)
    local r2, g2, b2 = unpack(colors.offwhite)
    GameTooltip:AddLine(shortLevelString:format(LEVEL, UnitLevel("player")))
    GameTooltip:AddLine(" ")

    -- XP tooltip
    GameTooltip:AddDoubleLine(L["Current XP: "], longXPString:format(colorize(short(data.xp), "normal"), colorize(short(data.xpMax), "normal")), r2, g2, b2, r2, g2, b2)
    if data.restedLeft and data.restedLeft > 0 then
        GameTooltip:AddDoubleLine(L["Rested Bonus: "], longXPString:format(colorize(short(data.restedLeft), "normal"), colorize(short(data.xpMax * maxRested), "normal")), r2, g2, b2, r2, g2, b2)
    end
    if data.restState == 1 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Rested"], unpack(colors.highlight))
        GameTooltip:AddLine(L["%s of normal experience\ngained from monsters."]:format(shortXPString:format(data.mult)), unpack(colors.green))
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
        GameTooltip:AddLine(L["%s of normal experience\ngained from monsters."]:format(shortXPString:format(data.mult)), unpack(colors.green))
        if not(data.restedTimeLeft and data.restedTimeLeft > 0) then 
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["You should rest at an Inn."], unpack(colors.dimred))
        end
    end
    
    GameTooltip:Show()
    self.XPController.mouseIsOver = true
    self:UpdateXPBar()
end

BarWidget.OnEnterRep = function(self)
    local data = self:UpdateRepData()
    if not data.repMax then return end

    GameTooltip_SetDefaultAnchor(GameTooltip, self.RepController)
    local r, g, b = unpack(colors.highlight)
    local r2, g2, b2 = unpack(colors.offwhite)
    GameTooltip:AddLine(shortLevelString:format(LEVEL, UnitLevel("player")))
    GameTooltip:AddLine(" ")

    -- Reputation tooltip
    local factionName = data.factionName or "Unknown"
    local standingText = _G["FACTION_STANDING_LABEL"..data.standing] or "Unknown"
    GameTooltip:AddDoubleLine(L["Faction: "], colorize(factionName, "normal"), r2, g2, b2, r2, g2, b2)
    GameTooltip:AddDoubleLine(L["Standing: "], colorize(standingText, "normal"), r2, g2, b2, r2, g2, b2)
    GameTooltip:AddDoubleLine(L["Reputation: "], repString:format(standingText, colorize(short(data.rep), "normal"), colorize(short(data.repMax), "normal"), colorize(short(floor(data.rep/data.repMax*100)), "normal")), r2, g2, b2, r2, g2, b2)
    
    GameTooltip:Show()
    self.RepController.mouseIsOver = true
    self:UpdateRepBar()
end

BarWidget.OnLeaveXP = function(self)
    GameTooltip:Hide()
    self.XPController.mouseIsOver = false
    self:UpdateXPBar()
end

BarWidget.OnLeaveRep = function(self)
    GameTooltip:Hide()
    self.RepController.mouseIsOver = false
    self:UpdateRepBar()
end

BarWidget.Update = function(self)
    self:UpdateXPData()
    self:UpdateRepData()
    self:UpdateVisibility()
    self:UpdateXPBar()
    self:UpdateRepBar()
end

BarWidget.UpdateXPBar = function(self)
    local data = self.xpData
    if not data or not data.xpMax or not data.color then return end
    
    local r, g, b = unpack(colors[data.color] or colors.normal)
    self.XPBar:SetStatusBarColor(r, g, b)
    self.XPBar:SetMinMaxValues(0, data.xpMax)
    self.XPBar:SetValue(data.xp)
    self.Rested:SetMinMaxValues(0, data.xpMax)
    self.Rested:SetValue(min(data.xpMax, data.xp + (data.restedLeft or 0)))
    self.Rested:Show()
    if data.restedLeft then
        local r, g, b = unpack(colors.xp_rested_bonus)
        self.XPBackdrop:SetVertexColor(r * 0.25, g * 0.25, b * 0.25)
    else
        self.XPBackdrop:SetVertexColor(r * 0.25, g * 0.25, b * 0.25)
    end
    if self.XPController.mouseIsOver then
        if data.restedLeft then
            self.XPValue:SetFormattedText(fullXPString..colorize(restedString, "offgreen"), colorize(short(data.xp), "normal"), colorize(short(data.xpMax), "normal"), colorize(short(floor(data.xp/data.xpMax*100)), "normal"), short(floor(data.restedLeft/data.xpMax*100)), L["Rested"])
        else
            self.XPValue:SetFormattedText(fullXPString, colorize(short(data.xp), "normal"), colorize(short(data.xpMax), "normal"), colorize(short(floor(data.xp/data.xpMax*100)), "normal"))
        end
    else
        self.XPValue:SetFormattedText(shortXPString, colorize(short(floor(data.xp/data.xpMax*100)), "normal"))
    end
end

BarWidget.UpdateRepBar = function(self)
    local data = self.repData
    if not data or not data.repMax then return end
    
    local r, g, b = unpack(colors.reaction[data.standing] or colors.normal)
    self.RepBar:SetStatusBarColor(r, g, b)
    self.RepBar:SetMinMaxValues(data.repMin, data.repMax)
    self.RepBar:SetValue(data.rep)
    self.RepBackdrop:SetVertexColor(r * 0.25, g * 0.25, b * 0.25)
    if self.RepController.mouseIsOver then
        local standingText = _G["FACTION_STANDING_LABEL"..data.standing] or "Unknown"
        self.RepValue:SetFormattedText(repString, colorize(data.factionName or "Unknown", "normal"), colorize(short(data.rep), "normal"), colorize(short(data.repMax), "normal"), colorize(short(floor(data.rep/data.repMax*100)), "normal"))
    else
        self.RepValue:SetFormattedText(shortXPString, colorize(short(floor(data.rep/data.repMax*100)), "normal"))
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
    local prevFactionName = self.repData and self.repData.factionName
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
    
    if prevFactionName and prevFactionName ~= data.factionName then
        -- Handle faction change if needed
    end
    
    return data
end

BarWidget.CheckReputation = function(self)
    self:UpdateRepData()
    self:UpdateRepBar()
end

BarWidget.UpdateSettings = function(self)
    local structure_config = Module.config.structure.controllers.xp
    local rep_config = Module.config.structure.controllers.rep or Module.config.structure.controllers.xp -- Fallback to xp config if rep not defined
    local art_config = Module.config.visuals.xp
    local num_bars = tostring(self.XPController:GetParent():GetAttribute("numbars"))
    
    local player_is_max_level = UnitLevel("player") == (MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel() or #MAX_PLAYER_LEVEL_TABLE] or MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE])
    
    self.XPController:SetSize(unpack(structure_config.size[num_bars] or structure_config.size["1"]))
    self.XPBar:SetSize(self.XPController:GetSize())
    self.Rested:SetSize(self.XPController:GetSize())
    self.XPBackdrop:SetTexture(art_config.backdrop.textures[num_bars])
    
    self.RepController:SetSize(unpack(rep_config.size[num_bars] or rep_config.size["1"]))
    self.RepBar:SetSize(self.RepController:GetSize())
    self.RepBackdrop:SetTexture(art_config.backdrop.textures[num_bars])
    
    -- Adjust RepController position
    if not player_is_max_level then
        self.RepController:ClearAllPoints()
        self.RepController:SetPoint("BOTTOM", self.XPController, "TOP", 0, rep_config.offset or 10)
    else
        self.RepController:ClearAllPoints()
        self.RepController:SetPoint(unpack(structure_config.position))
    end
end

BarWidget.UpdateVisibility = function(self)
    local player_is_max_level = UnitLevel("player") == (MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel() or #MAX_PLAYER_LEVEL_TABLE] or MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE])
    local xp_is_disabled = IsXPUserDisabled() or player_is_max_level
    local isRep = self.repData and self.repData.isRep or false
    local in_vehicle = UnitHasVehicleUI("player")
    
    if xp_is_disabled or in_vehicle then
        self.XPController:Hide()
    else
        self.XPController:Show()
    end
    
    if not isRep or in_vehicle then
        self.RepController:Hide()
    else
        self.RepController:Show()
    end
end

BarWidget.OnEnable = function(self)
    self.xpData = {}
    self.repData = {}
    
    local structure_config = Module.config.structure.controllers.xp
    local rep_config = Module.config.structure.controllers.rep or Module.config.structure.controllers.xp -- Fallback to xp config
    local art_config = Module.config.visuals.xp
    local num_bars = tostring(Module.db.num_bars)
    
    local Main = Module:GetWidget("Controller: Main"):GetFrame()
    
    -- XP Controller
    local XPController = CreateFrame("Frame", nil, Main)
    XPController:SetFrameStrata("BACKGROUND")
    XPController:SetFrameLevel(0)
    XPController:SetSize(unpack(structure_config.size[num_bars] or structure_config.size["1"]))
    XPController:SetPoint(unpack(structure_config.position))
    XPController:EnableMouse(true)
    XPController:SetScript("OnEnter", function() self:OnEnterXP() end)
    XPController:SetScript("OnLeave", function() self:OnLeaveXP() end)
    
    local XPBackdrop = XPController:CreateTexture(nil, "BACKGROUND")
    XPBackdrop:SetSize(unpack(art_config.backdrop.texture_size))
    XPBackdrop:SetPoint(unpack(art_config.backdrop.texture_position))
    XPBackdrop:SetTexture(art_config.backdrop.textures[num_bars])
    XPBackdrop:SetAlpha(.75)
    
    local Rested = StatusBar:New(XPController)
    Rested:SetSize(XPController:GetSize())
    Rested:SetAllPoints()
    Rested:SetFrameLevel(1)
    Rested:SetAlpha(art_config.rested.alpha)
    Rested:SetStatusBarTexture(art_config.rested.texture)
    Rested:SetStatusBarColor(unpack(colors.xp_rested_bonus))
    Rested:SetSparkTexture(art_config.rested.spark.texture)
    Rested:SetSparkSize(unpack(art_config.rested.spark.size))
    Rested:SetSparkFlash(2.75, 1.25, .175, .425)
    
    local XPBar = StatusBar:New(XPController)
    XPBar:SetSize(XPController:GetSize())
    XPBar:SetAllPoints()
    XPBar:SetFrameLevel(2)
    XPBar:SetAlpha(art_config.bar.alpha)
    XPBar:SetStatusBarTexture(art_config.bar.texture)
    XPBar:SetSparkTexture(art_config.bar.spark.texture)
    XPBar:SetSparkSize(unpack(art_config.bar.spark.size))
    XPBar:SetSparkFlash(2.75, 1.25, .35, .85)
    
    local XPOverlay = CreateFrame("Frame", nil, XPController)
    XPOverlay:SetFrameStrata("MEDIUM")
    XPOverlay:SetFrameLevel(35)
    XPOverlay:SetAllPoints()
    
    local XPValue = XPOverlay:CreateFontString(nil, "OVERLAY")
    XPValue:SetPoint("CENTER")
    XPValue:SetFontObject(art_config.font_object)
    
    -- Reputation Controller
    local RepController = CreateFrame("Frame", nil, Main)
    RepController:SetFrameStrata("BACKGROUND")
    RepController:SetFrameLevel(0)
    RepController:SetSize(unpack(rep_config.size[num_bars] or rep_config.size["1"]))
    RepController:SetPoint("BOTTOM", XPController, "TOP", 0, rep_config.offset or 10)
    RepController:EnableMouse(true)
    RepController:SetScript("OnEnter", function() self:OnEnterRep() end)
    RepController:SetScript("OnLeave", function() self:OnLeaveRep() end)
    
    local RepBackdrop = RepController:CreateTexture(nil, "BACKGROUND")
    RepBackdrop:SetSize(unpack(art_config.backdrop.texture_size))
    RepBackdrop:SetPoint(unpack(art_config.backdrop.texture_position))
    RepBackdrop:SetTexture(art_config.backdrop.textures[num_bars])
    RepBackdrop:SetAlpha(.75)
    
    local RepBar = StatusBar:New(RepController)
    RepBar:SetSize(RepController:GetSize())
    RepBar:SetAllPoints()
    RepBar:SetFrameLevel(2)
    RepBar:SetAlpha(art_config.bar.alpha)
    RepBar:SetStatusBarTexture(art_config.bar.texture)
    RepBar:SetSparkTexture(art_config.bar.spark.texture)
    RepBar:SetSparkSize(unpack(art_config.bar.spark.size))
    RepBar:SetSparkFlash(2.75, 1.25, .35, .85)
    
    local RepOverlay = CreateFrame("Frame", nil, RepController)
    RepOverlay:SetFrameStrata("MEDIUM")
    RepOverlay:SetFrameLevel(35)
    RepOverlay:SetAllPoints()
    
    local RepValue = RepOverlay:CreateFontString(nil, "OVERLAY")
    RepValue:SetPoint("CENTER")
    RepValue:SetFontObject(art_config.font_object)
    
    self.XPController = XPController
    self.XPBackdrop = XPBackdrop
    self.Rested = Rested
    self.XPBar = XPBar
    self.XPValue = XPValue
    self.RepController = RepController
    self.RepBackdrop = RepBackdrop
    self.RepBar = RepBar
    self.RepValue = RepValue
    
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
    return self.XPController, self.RepController
end
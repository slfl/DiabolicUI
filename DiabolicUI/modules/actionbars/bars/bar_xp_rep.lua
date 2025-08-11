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
	local r, g, b = unpack(colors[color])
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

BarWidget.OnEnter = function(self)
	local data = self:UpdateData()
	if not (data.xpMax or data.repMax) then return end

	GameTooltip_SetDefaultAnchor(GameTooltip, self.Controller)
	local r, g, b = unpack(colors.highlight)
	local r2, g2, b2 = unpack(colors.offwhite)
	GameTooltip:AddLine(shortLevelString:format(LEVEL, UnitLevel("player")))
	GameTooltip:AddLine(" ")

	if data.isRep then
		-- Reputation tooltip
		local factionName = data.factionName or "Unknown"
		local standingText = _G["FACTION_STANDING_LABEL"..data.standing] or "Unknown"
		GameTooltip:AddDoubleLine(L["Faction: "], colorize(factionName, "normal"), r2, g2, b2, r2, g2, b2)
		GameTooltip:AddDoubleLine(L["Standing: "], colorize(standingText, "normal"), r2, g2, b2, r2, g2, b2)
		GameTooltip:AddDoubleLine(L["Reputation: "], repString:format(standingText, colorize(short(data.rep), "normal"), colorize(short(data.repMax), "normal"), colorize(short(floor(data.rep/data.repMax*100)), "normal")), r2, g2, b2, r2, g2, b2)
	else
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
	end
	
	GameTooltip:Show()
	self.Controller.mouseIsOver = true
	self:UpdateBar()
end

BarWidget.OnLeave = function(self)
	GameTooltip:Hide()
	self.Controller.mouseIsOver = false
	self:UpdateBar()
end

BarWidget.Update = function(self)
	self:UpdateData() -- Сначала обновляем данные, чтобы избежать устаревших значений в Visibility
	self:UpdateVisibility()
	self:UpdateBar()
end

BarWidget.UpdateBar = function(self)
	local data = self.data -- Уже обновлено в Update
	if not (data.xpMax or data.repMax) then return end
	
	if data.isRep then
		-- Reputation bar
		local r, g, b = unpack(colors.reaction[data.standing] or colors.normal)
		self.XP:SetStatusBarColor(r, g, b)
		self.XP:SetMinMaxValues(data.repMin, data.repMax)
		self.XP:SetValue(data.rep)
		self.Rested:Hide() -- Hide rested bar for reputation
		self.Backdrop:SetVertexColor(r * 0.25, g * 0.25, b * 0.25)
		if self.mouseIsOver then
			local standingText = _G["FACTION_STANDING_LABEL"..data.standing] or "Unknown"
			self.Value:SetFormattedText(repString, colorize(data.factionName or "Unknown", "normal"), colorize(short(data.rep), "normal"), colorize(short(data.repMax), "normal"), colorize(short(floor(data.rep/data.repMax*100)), "normal"))
		else
			self.Value:SetFormattedText(shortXPString, colorize(short(floor(data.rep/data.repMax*100)), "normal"))
		end
	else
		-- XP bar
		local r, g, b = unpack(colors[data.color])
		self.XP:SetStatusBarColor(r, g, b)
		self.XP:SetMinMaxValues(0, data.xpMax)
		self.XP:SetValue(data.xp)
		self.Rested:SetMinMaxValues(0, data.xpMax)
		self.Rested:SetValue(min(data.xpMax, data.xp + (data.restedLeft or 0)))
		self.Rested:Show()
		if data.restedLeft then
			local r, g, b = unpack(colors.xp_rested_bonus)
			self.Backdrop:SetVertexColor(r * 0.25, g * 0.25, b * 0.25)
		else
			self.Backdrop:SetVertexColor(r * 0.25, g * 0.25, b * 0.25)
		end
		if self.mouseIsOver then
			if data.restedLeft then
				self.Value:SetFormattedText(fullXPString..colorize(restedString, "offgreen"), colorize(short(data.xp), "normal"), colorize(short(data.xpMax), "normal"), colorize(short(floor(data.xp/data.xpMax*100)), "normal"), short(floor(data.restedLeft/data.xpMax*100)), L["Rested"])
			else
				self.Value:SetFormattedText(fullXPString, colorize(short(data.xp), "normal"), colorize(short(data.xpMax), "normal"), colorize(short(floor(data.xp/data.xpMax*100)), "normal"))
			end
		else
			self.Value:SetFormattedText(shortXPString, colorize(short(floor(data.xp/data.xpMax*100)), "normal"))
		end
	end
end

BarWidget.UpdateData = function(self)
	-- Сохраняем предыдущую фракцию для проверки изменений
	local prevFactionName = self.data.factionName

	self.data.resting = IsResting()
	self.data.restState, self.data.restedName, self.data.mult = GetRestState()
	self.data.restedLeft, self.data.restedTimeLeft = GetXPExhaustion(), GetTimeToWellRested()
	self.data.xp, self.data.xpMax = UnitXP("player"), UnitXPMax("player")
	self.data.color = self.data.restedLeft and "xp_rested" or "xp"
	self.data.mult = (self.data.mult or 1) * 100
	
	-- Reputation data
	local name, standing, minVal, maxVal, value = GetWatchedFactionInfo()
	if name then
		self.data.isRep = true
		self.data.factionName = name
		self.data.standing = standing
		self.data.rep = value - minVal
		self.data.repMin = 0
		self.data.repMax = maxVal - minVal
	else
		self.data.isRep = false
		self.data.factionName = nil
		self.data.standing = nil
		self.data.rep = nil
		self.data.repMin = nil
		self.data.repMax = nil
	end
	
	if self.data.xpMax == 0 then
		self.data.xpMax = nil
	end

	-- Проверка на смену репутации (если фракция изменилась, можно добавить логику, если нужно)
	if prevFactionName and prevFactionName ~= self.data.factionName then
		-- Здесь можно добавить кастомные действия при смене, но по умолчанию просто обновляем
	end

	return self.data
end

BarWidget.CheckReputation = function(self)
	-- Отдельная функция для принудительной проверки текущей репутации (вызывается при необходимости)
	self:UpdateData()
	self:UpdateBar()
end

BarWidget.UpdateSettings = function(self)
	local structure_config = Module.config.structure.controllers.xp
	local art_config = Module.config.visuals.xp
	local num_bars = tostring(self.Controller:GetParent():GetAttribute("numbars"))

	self.Controller:SetSize(unpack(structure_config.size[num_bars]))
	self.XP:SetSize(self.Controller:GetSize())
	self.Rested:SetSize(self.Controller:GetSize())
	self.Backdrop:SetTexture(art_config.backdrop.textures[num_bars])
end

BarWidget.UpdateVisibility = function(self)
	local player_is_max_level = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel() or #MAX_PLAYER_LEVEL_TABLE] or MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE]
	local xp_is_disabled = IsXPUserDisabled() or UnitLevel("player") == player_is_max_level
	local isRep = self.data.isRep or false -- Явная проверка на false для старта
	if (xp_is_disabled and not isRep) or UnitHasVehicleUI("player") then
		self.Controller:Hide()
	else
		self.Controller:Show()
	end
end

BarWidget.OnEnable = function(self)
	self.data = {}

	local structure_config = Module.config.structure.controllers.xp
	local art_config = Module.config.visuals.xp
	local num_bars = tostring(Module.db.num_bars)

	local Main = Module:GetWidget("Controller: Main"):GetFrame()
	
	local Controller = CreateFrame("Frame", nil, Main)
	Controller:SetFrameStrata("BACKGROUND")
	Controller:SetFrameLevel(0)
	Controller:SetSize(unpack(structure_config.size[num_bars]))
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
	
	local XP = StatusBar:New(Controller)
	XP:SetSize(Controller:GetSize())
	XP:SetAllPoints()
	XP:SetFrameLevel(2)
	XP:SetAlpha(art_config.bar.alpha)
	XP:SetStatusBarTexture(art_config.bar.texture)
	XP:SetSparkTexture(art_config.bar.spark.texture)
	XP:SetSparkSize(unpack(art_config.bar.spark.size))
	XP:SetSparkFlash(2.75, 1.25, .35, .85)
	
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
	self.XP = XP
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
end

BarWidget.GetFrame = function(self)
	return self.Controller
end

local Addon, Engine = ...
local Module = Engine:GetModule("UnitFrames")
local UnitFrameWidget = Module:SetWidget("Unit: Boss")

local UnitFrame = Engine:GetHandler("UnitFrame")
local StatusBar = Engine:GetHandler("StatusBar")

-- Lua API
local unpack = unpack
local path = ([[Interface\AddOns\%s\media\]]):format(Addon)

-- WoW API
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType

-- WotLK has 4 boss frames (confirmed against Blizzard's TargetFrame.lua)
local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 4

-- proportions mirror the target frame (scaled down to be narrower)
local scale = 0.62
local config = {
	frame   = { 346 * scale, 40 * scale },
	health_single = { 305 * scale, 15 * scale, y = -3 * scale },   -- HP when no power
	health_double = { 305 * scale, 15 * scale, y = -3 * scale },   -- HP when power present
	power   = { 274 * scale, 10 * scale, y = -(3 + 22) * scale },  -- power bar
	art     = { 512 * scale, 128 * scale, y_single = 53 * scale, y_double = 53 * scale },
	spacing = 24,
	first_offset = { -24, -20 },
	health_texture = path .. [[statusbars\DiabolicUI_StatusBar_512x64_Dark_Warcraft.tga]],
	power_texture  = path .. [[statusbars\DiabolicUI_StatusBar_512x64_Dark_Warcraft.tga]],
	border_single  = path .. [[textures\unitframes\DiabolicUI_Target_305x15_BorderBoss.tga]],
	border_double  = path .. [[textures\unitframes\DiabolicUI_Target_305x15_BorderBoss2Bars.tga]],
	name = {
		font_object = DiabolicUnitFrameNormal or GameFontNormal,
		color = { 0.95, 0.85, 0.45 },
	},
	value = {
		font_object = DiabolicUnitFrameNumberNormal or NumberFontNormal,
		color = { 0.94, 0.94, 0.94 },
	},
}

-- standard power colors
local PowerColors = {
	MANA        = { 0.20, 0.40, 1.00 },
	RAGE        = { 0.90, 0.20, 0.20 },
	FOCUS       = { 1.00, 0.50, 0.25 },
	ENERGY      = { 1.00, 0.85, 0.10 },
	RUNIC_POWER = { 0.00, 0.80, 1.00 },
}

-- Switches a boss frame between single (HP only) and double (HP + power) look.
local function UpdateLayout(self)
	local unit = self.unit
	if not unit then return end

	local hasPower = (UnitPowerMax(unit) or 0) > 0

	if hasPower then
		-- double: HP on top, power below, 2-bar border
		self.Border.tex:SetTexture(config.border_double)
		self.Border.tex:SetPoint("TOP", self, "TOP", 0, config.art.y_double)
		self.Health:SetSize(config.health_double[1], config.health_double[2])
		self.Health:ClearAllPoints()
		self.Health:SetPoint("TOP", self, "TOP", 0, config.health_double.y)
		self.Power:SetSize(config.power[1], config.power[2])
		self.Power:ClearAllPoints()
		self.Power:SetPoint("TOP", self, "TOP", 0, config.power.y)
		self.Power:GetScaffold():Show()

		-- color power by type
		local _, token = UnitPowerType(unit)
		local c = PowerColors[token] or { 0.4, 0.4, 0.9 }
		self.Power:SetStatusBarColor(c[1], c[2], c[3])
	else
		-- single: HP only, 1-bar border
		self.Border.tex:SetTexture(config.border_single)
		self.Border.tex:SetPoint("TOP", self, "TOP", 0, config.art.y_single)
		self.Health:SetSize(config.health_single[1], config.health_single[2])
		self.Health:ClearAllPoints()
		self.Health:SetPoint("TOP", self, "TOP", 0, config.health_single.y)
		self.Power:GetScaffold():Hide()
	end
end

-- Style function applied to each boss unit frame.
local Style = function(self, unit)
	self:Size(config.frame[1], config.frame[2])

	-- Health bar
	local Health = StatusBar:New(self)
	Health:SetSize(config.health_single[1], config.health_single[2])
	Health:SetPoint("TOP", self, "TOP", 0, config.health_single.y)
	Health:SetStatusBarTexture(config.health_texture)
	Health:SetStatusBarColor(0.35, 0.65, 0.20)
	Health.frequent = 1/60

	-- Power bar (hidden until needed)
	local Power = StatusBar:New(self)
	Power:SetSize(config.power[1], config.power[2])
	Power:SetPoint("TOP", self, "TOP", 0, config.power.y)
	Power:SetStatusBarTexture(config.power_texture)
	Power:GetScaffold():Hide()

	-- Border art on top (transparent centre reveals the bars)
	local Border = CreateFrame("Frame", nil, self)
	Border:SetFrameLevel(self:GetFrameLevel() + 3)
	Border:SetAllPoints(self)
	local BorderTex = Border:CreateTexture(nil, "BORDER")
	BorderTex:SetSize(config.art[1], config.art[2])
	BorderTex:SetPoint("TOP", self, "TOP", 0, config.art.y_single)
	BorderTex:SetTexture(config.border_single)
	Border.tex = BorderTex

	-- Health value (percent)
	Health.Value = Border:CreateFontString(nil, "OVERLAY")
	Health.Value:SetFontObject(config.value.font_object)
	Health.Value:SetPoint("RIGHT", Health:GetScaffold(), "RIGHT", -6, 0)
	Health.Value:SetTextColor(unpack(config.value.color))
	Health.Value.showPercent = true
	Health.Value.showDeficit = false
	Health.Value.showMaximum = false

	-- Boss name, above the bar
	local Name = Border:CreateFontString(nil, "OVERLAY")
	Name:SetFontObject(config.name.font_object)
	Name:SetPoint("BOTTOM", self, "TOP", 0, 2)
	Name:SetJustifyH("CENTER")
	Name:SetTextColor(unpack(config.name.color))
	Name:SetWordWrap(false)

	self.Health = Health
	self.Power = Power
	self.Border = Border
	self.Name = Name

	-- keep the single/double layout in sync with the boss's power
	self.Power.PostUpdate = function() UpdateLayout(self) end
	self.Health.PostUpdate = function() UpdateLayout(self) end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function() UpdateLayout(self) end)
	-- fired when bosses engage / change (the proper boss-frame trigger in WotLK)
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", function() UpdateLayout(self) end)
	self:RegisterEvent("UNIT_MAXPOWER", function(_, evtUnit)
		if evtUnit == self.unit then UpdateLayout(self) end
	end)
end

UnitFrameWidget.OnEnable = function(self)
	self.frames = {}

	-- Blizzard's boss frames are created lazily and re-shown when a boss appears,
	-- so hook each one to stay hidden.
	local hider = CreateFrame("Frame")
	hider:Hide()
	for i = 1, MAX_BOSS_FRAMES do
		local bf = _G["Boss"..i.."TargetFrame"]
		if bf and not bf._duiHidden then
			bf._duiHidden = true
			bf:UnregisterAllEvents()
			bf:Hide()
			bf:SetParent(hider)
			bf:HookScript("OnShow", function(f) f:Hide() end)
		end
	end

	-- Debug: /duiboss reports Blizzard + our boss frame state
	SLASH_DUIBOSS1 = "/duiboss"
	SlashCmdList["DUIBOSS"] = function()
		print("|cff4488ffBoss frame probe:|r")
		for i = 1, MAX_BOSS_FRAMES do
			local bf = _G["Boss"..i.."TargetFrame"]
			local exists = bf and "EXISTS" or "nil"
			local shown = (bf and bf:IsShown()) and "shown" or "hidden"
			local our = self.frames[i]
			local ourExists = our and "EXISTS" or "nil"
			local hasU = UnitExists("boss"..i)
			local pmax = hasU and (UnitPowerMax("boss"..i) or 0) or 0
			print(string.format("  boss%d: Blizz=%s(%s) | ours=%s | unit=%s pmax=%d",
				i, exists, shown, ourExists, tostring(hasU), pmax))
		end
	end

	local Minimap = _G.Minimap
	local anchorParent = Engine:GetFrame()

	for i = 1, MAX_BOSS_FRAMES do
		local frame = UnitFrame:New("boss"..i, anchorParent, Style)
		frame:ClearAllPoints()
		if i == 1 then
			if Minimap then
				frame:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", config.first_offset[1], config.first_offset[2])
			else
				frame:SetPoint("TOPRIGHT", anchorParent, "TOPRIGHT", -20, -200)
			end
		else
			frame:SetPoint("TOPRIGHT", self.frames[i-1], "BOTTOMRIGHT", 0, -config.spacing)
		end
		self.frames[i] = frame
	end
end

UnitFrameWidget.GetFrame = function(self)
	return self.frames
end

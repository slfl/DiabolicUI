local Addon, Engine = ...
local Module = Engine:GetModule("UnitFrames")
local UnitFrameWidget = Module:SetWidget("Unit: Boss")

local UnitFrame = Engine:GetHandler("UnitFrame")
local StatusBar = Engine:GetHandler("StatusBar")

-- Lua API
local unpack = unpack
local path = ([[Interface\AddOns\%s\media\]]):format(Addon)

local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 5

-- Step 1 config: single health bar + name + border art, left of the minimap.
-- Proportions mirror the target frame: frame 346x40 with a 305x15 health bar
-- and 512x128 border art. We scale everything by `scale` to narrow it.
local scale = 0.62
local config = {
	frame   = { 346 * scale, 40 * scale },
	health  = { 305 * scale, 15 * scale, offset_y = -3 * scale },
	art     = { 512 * scale, 128 * scale, offset_y = 53 * scale },
	spacing = 20,
	first_offset = { -24, -20 }, -- from minimap TOPLEFT: x left, y down
	health_texture = path .. [[statusbars\DiabolicUI_StatusBar_512x64_Dark_Warcraft.tga]],
	border_texture = path .. [[textures\unitframes\DiabolicUI_Target_305x15_BorderBoss.tga]],
	name = {
		font_object = DiabolicUnitFrameNormal or GameFontNormal,
		color = { 0.95, 0.85, 0.45 },
	},
	value = {
		font_object = DiabolicUnitFrameNumberNormal or NumberFontNormal,
		color = { 0.94, 0.94, 0.94 },
	},
}

-- Style function applied to each boss unit frame.
local Style = function(self, unit)
	self:Size(config.frame[1], config.frame[2])

	-- Health bar (sits in the transparent slot of the border art)
	local Health = StatusBar:New(self)
	Health:SetSize(config.health[1], config.health[2])
	Health:SetPoint("TOP", self, "TOP", 0, config.health.offset_y)
	Health:SetStatusBarTexture(config.health_texture)
	Health:SetStatusBarColor(0.65, 0.12, 0.12)
	Health.frequent = 1/60

	-- Border art on top (native-proportioned, transparent centre reveals the bar)
	local Border = CreateFrame("Frame", nil, self)
	Border:SetFrameLevel(self:GetFrameLevel() + 3)
	Border:SetAllPoints(self)
	local BorderTex = Border:CreateTexture(nil, "BORDER")
	BorderTex:SetSize(config.art[1], config.art[2])
	BorderTex:SetPoint("TOP", self, "TOP", 0, config.art.offset_y)
	BorderTex:SetTexture(config.border_texture)

	-- Health value (percent), on the border layer so it's above the bar
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
	self.Name = Name
end

UnitFrameWidget.OnEnable = function(self)
	self.frames = {}

	-- Blizzard's boss frames are created lazily and re-shown when a boss appears,
	-- so a one-time disable at load doesn't stick. Hook each one to stay hidden.
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
			local ourUnit = our and UnitExists("boss"..i) and "unit-present" or "no-unit"
			print(string.format("  boss%d: Blizz=%s(%s) | ours=%s(%s)", i, exists, shown, ourExists, ourUnit))
		end
	end

	local Minimap = _G.Minimap
	local anchorParent = Engine:GetFrame()

	for i = 1, MAX_BOSS_FRAMES do
		local frame = UnitFrame:New("boss"..i, anchorParent, Style)
		frame:ClearAllPoints()
		if i == 1 then
			-- anchor the first boss frame to the left of the minimap
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

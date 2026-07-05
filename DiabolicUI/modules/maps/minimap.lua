local Addon, Engine = ...
local Module = Engine:NewModule("Minimap", "HIGH")

-- Lua API
local unpack = unpack
local date = date
local format = string.format

-- WoW API
local CreateFrame = CreateFrame
local Minimap = Minimap
local GetMinimapZoneText = GetMinimapZoneText
local GetZonePVPInfo = GetZonePVPInfo
local UnitName = UnitName
local UnitLevel = UnitLevel
local IsResting = IsResting

-- Returns the color key for the current zone's pvp status
local GetZoneColorKey = function()
	local pvpType = GetZonePVPInfo()
	if pvpType == "sanctuary" then
		return "sanctuary"
	elseif pvpType == "arena" then
		return "hostile"
	elseif pvpType == "friendly" then
		return "friendly"
	elseif pvpType == "hostile" then
		return "hostile"
	elseif pvpType == "contested" then
		return "contested"
	elseif pvpType == "combat" then
		return "combat"
	end
	return "normal"
end

-- ======================================================================
-- Addon minimap-button collector
-- Adapted from the proven detection logic used by MinimapButtonButton:
-- scan Minimap's children and match frames whose name looks like an addon
-- minimap button, plus anything registered through LibDBIcon.
-- ======================================================================
local strmatch = string.match
local tinsert = table.insert
local ipairs = ipairs
local pairs = pairs

local collectedButtons = {}
local collectedMap = {}

local doNothing = function() end

local function isButtonCollected(button)
	return collectedMap[button] ~= nil
end

-- name patterns that identify third-party minimap buttons
local buttonPatterns = {
	"^LibDBIcon10_",
	"MinimapButton",
	"MinimapFrame",
	"MinimapIcon",
	"[-_]Minimap[-_]",
	"Minimap$",
}

local function nameMatchesButtonPattern(name)
	for _, pattern in ipairs(buttonPatterns) do
		if strmatch(name, pattern) then
			return true
		end
	end
	return false
end

-- Blizzard's own minimap frames we must NOT grab
local blizzardButtons = {
	MiniMapTracking = true,
	MiniMapTrackingButton = true,
	MiniMapMailFrame = true,
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	MiniMapWorldMapButton = true,
	MiniMapBattlefieldFrame = true,
	MiniMapLFGFrame = true,
	MiniMapVoiceChatFrame = true,
	GameTimeFrame = true,
	TimeManagerClockButton = true,
	QueueStatusMinimapButton = true,
	MinimapBackdrop = true,
	MinimapZoomBackdrop = true,
	MinimapNorthTag = true,
}

local function isMinimapButton(frame)
	local name = frame.GetName and frame:GetName()
	if not name then return false end
	if blizzardButtons[name] then return false end
	-- names ending in a digit are usually Blizzard sub-frames, not addon buttons
	if strmatch(name, "%d$") and not strmatch(name, "^LibDBIcon10_") then
		return false
	end
	return nameMatchesButtonPattern(name)
end


-- Mousewheel zoom (reuses Blizzard's zoom buttons under the hood)
local OnMouseWheel = function(self, delta)
	if delta > 0 then
		MinimapZoomIn:Click()
	elseif delta < 0 then
		MinimapZoomOut:Click()
	end
end

-- Left-click sets a minimap ping (visible to your group); right-click opens
-- the tracking menu (same behaviour as the default minimap).
local OnMouseUp = function(self, button)
	if button == "RightButton" then
		if MiniMapTrackingDropDown then
			ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, self, 0, 0)
		end
	elseif button == "LeftButton" then
		-- Minimap_OnClick handles the ping that group members can see
		if Minimap_OnClick then
			Minimap_OnClick(self)
		end
	end
end

Module.OnInit = function(self)
	self.db = self:GetConfig("Minimap", "character")
	self.config = self:GetStaticConfig("Minimap")

	-- master switch: if disabled, leave the Minimap alone so another addon can
	-- take it over. We restore the default round mask (in case we set the square
	-- one in a previous session) and then build nothing.
	if not self.db.enabled then
		self._disabled = true
		Minimap:SetMaskTexture([[Textures\MinimapMask]])
		return
	end

	local config = self.config

	-- Our own holder frame that everything attaches to
	local UICenter = Engine:GetFrame()
	self.frame = CreateFrame("Frame", nil, UICenter)
	self.frame:SetSize(unpack(config.size))
	self.frame:SetPoint(config.point[1], UICenter, config.point[1], config.point[2], config.point[3])

	-- A visibility child that mirrors the Minimap's shown state
	self.frame.visibility = CreateFrame("Frame", nil, self.frame)
	self.frame.visibility:SetAllPoints()

	-- Re-parent the real Minimap into our holder
	Minimap:SetParent(self.frame.visibility)
	Minimap:ClearAllPoints()
	Minimap:SetPoint(unpack(config.map.point))
	Minimap:SetSize(unpack(config.map.size))
	Minimap:SetFrameLevel(self.frame.visibility:GetFrameLevel() + 2)

	-- SQUARE shape: a plain white mask makes the map render as a square
	Minimap:SetMaskTexture(config.map.mask)

	-- Simple black border around the square
	self.frame.border = CreateFrame("Frame", nil, self.frame.visibility)
	self.frame.border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -config.border.size, config.border.size)
	self.frame.border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", config.border.size, -config.border.size)
	self.frame.border:SetBackdrop({
		edgeFile = [[Interface\Buttons\WHITE8X8]],
		edgeSize = config.border.size
	})
	self.frame.border:SetBackdropBorderColor(unpack(config.border.color))
	self.frame.border:SetFrameLevel(Minimap:GetFrameLevel() + 1)

	-- Dark vignette over the whole map (Diablo-style), controlled by settings
	-- Dark vignette over the whole map (Diablo-style), on its own frame ABOVE
	-- the Minimap so it actually renders on top of the map blips.
	local shadeFrame = CreateFrame("Frame", nil, self.frame.visibility)
	shadeFrame:SetAllPoints(Minimap)
	shadeFrame:SetFrameLevel(Minimap:GetFrameLevel() + 3)
	self.frame.shadeFrame = shadeFrame
	self.frame.shade = shadeFrame:CreateTexture(nil, "OVERLAY")
	self.frame.shade:SetAllPoints(shadeFrame)
	self.frame.shade:SetTexture(config.shade.texture)

	-- mousewheel zoom + right-click tracking
	Minimap:EnableMouseWheel(true)
	Minimap:SetScript("OnMouseWheel", OnMouseWheel)
	Minimap:SetScript("OnMouseUp", OnMouseUp)

	-- ------------------------------------------------------------------
	-- Texts above the map (Diablo 3 style), right-aligned
	-- ------------------------------------------------------------------
	local text_config = config.text

	-- Info line, split into two parts so only the time/date is clickable:
	--   [ Name (level) ]  [ HH:MM / DD.MM ]
	-- The time/date sits at the right edge; the name is to its left.

	-- Time/date (right side, clickable -> calendar)
	local Clock = self.frame.visibility:CreateFontString(nil, "OVERLAY")
	Clock:SetFont(text_config.info.font.path, text_config.info.font.size, text_config.info.font.style)
	Clock:SetShadowOffset(unpack(text_config.info.shadow.offset))
	Clock:SetShadowColor(unpack(text_config.info.shadow.color))
	Clock:SetJustifyH("RIGHT")
	Clock:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, 6)
	self.frame.clock = Clock

	-- Name (level) -- to the LEFT of the clock, not clickable
	local Info = self.frame.visibility:CreateFontString(nil, "OVERLAY")
	Info:SetFont(text_config.info.font.path, text_config.info.font.size, text_config.info.font.style)
	Info:SetShadowOffset(unpack(text_config.info.shadow.offset))
	Info:SetShadowColor(unpack(text_config.info.shadow.color))
	Info:SetJustifyH("RIGHT")
	Info:SetPoint("BOTTOMRIGHT", Clock, "BOTTOMLEFT", -4, 0)
	self.frame.info = Info

	-- Clickable overlay ONLY on the time/date -> opens the calendar.
	local infoButton = CreateFrame("Button", nil, self.frame.visibility)
	infoButton:SetAllPoints(Clock)
	infoButton:SetFrameLevel(self.frame.visibility:GetFrameLevel() + 5)
	infoButton:RegisterForClicks("LeftButtonUp")
	infoButton:SetScript("OnClick", function()
		if ToggleCalendar then
			ToggleCalendar()
		end
	end)
	infoButton:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
		GameTooltip:AddLine(date("%A, %d.%m.%Y"))
		GameTooltip:AddLine("|cff00ff00Click|r to open the calendar.", 1, 1, 1)
		GameTooltip:Show()
	end)
	infoButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.frame.infoButton = infoButton

	-- Zone name (top line) -- sits above the info line
	local Zone = self.frame.visibility:CreateFontString(nil, "OVERLAY")
	Zone:SetFont(text_config.zone.font.path, text_config.zone.font.size, text_config.zone.font.style)
	Zone:SetShadowOffset(unpack(text_config.zone.shadow.offset))
	Zone:SetShadowColor(unpack(text_config.zone.shadow.color))
	Zone:SetJustifyH("RIGHT")
	Zone:SetPoint("BOTTOMRIGHT", Clock, "TOPRIGHT", 0, 4)
	self.frame.zone = Zone

	-- ------------------------------------------------------------------
	-- Collapsible addon-button holder
	-- ------------------------------------------------------------------
	local btn_config = config.buttons

	-- toggle button, bottom-right under the map
	local toggle = CreateFrame("Button", nil, self.frame.visibility)
	toggle:SetSize(unpack(btn_config.toggle.size))
	toggle:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -9)
	toggle:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	self.buttonToggle = toggle

	-- single texture region we drive with atlas texcoords
	local tex = toggle:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(toggle)
	toggle.tex = tex

	-- updates the button texture based on state (disabled / expanded / hover)
	toggle.expanded = false
	toggle.hovered = false
	Module.UpdateToggleTexture = function(mod)
		local tc = btn_config.toggle
		-- no addon buttons collected -> disabled texture
		if #collectedButtons == 0 then
			tex:SetTexture(tc.texture_disabled)
			tex:SetTexCoord(unpack(tc.texcoord_disabled))
			return
		end
		tex:SetTexture(tc.texture)
		local key
		if toggle.expanded then
			key = toggle.hovered and "expanded_hover" or "expanded_normal"
		else
			key = toggle.hovered and "collapsed_hover" or "collapsed_normal"
		end
		tex:SetTexCoord(unpack(tc.texcoords[key]))
	end

	toggle:SetScript("OnEnter", function() toggle.hovered = true; Module:UpdateToggleTexture() end)
	toggle:SetScript("OnLeave", function() toggle.hovered = false; Module:UpdateToggleTexture() end)

	-- panel that holds the collected addon buttons (hidden by default)
	local panel = CreateFrame("Frame", nil, self.frame.visibility)
	panel:SetPoint("RIGHT", toggle, "LEFT", -btn_config.icon.padding, 0)
	panel:SetSize(1, btn_config.icon.slot)
	panel:SetFrameLevel(Minimap:GetFrameLevel() + 4)
	panel:Hide()
	self.buttonPanel = panel

	toggle:SetScript("OnClick", function() self:ToggleButtons() end)

	self:UpdateToggleTexture()
end

-- Updates the zone name and its color
Module.UpdateZone = function(self)
	local colors = self.config.text.colors
	local Zone = self.frame.zone
	Zone:SetText(GetMinimapZoneText() or "")
	local c = colors[GetZoneColorKey()] or colors.normal
	Zone:SetTextColor(c[1], c[2], c[3])
end

-- Updates the "Name (level)" part and the clock/date part per settings
Module.UpdateInfo = function(self)
	local colors = self.config.text.colors
	local c = colors.normal
	local db = self.db

	local name = UnitName("player") or ""
	local level = UnitLevel("player") or 0
	self.frame.info:SetFormattedText("%s (%d)", name, level)
	self.frame.info:SetTextColor(c[1], c[2], c[3])

	-- clock: 24h or 12h
	local clock
	if db.use24hrClock then
		clock = date("%H:%M")
	else
		clock = date("%I:%M %p")
	end

	-- date: day / day+month / day+month+year, with chosen separator
	local sep = db.date_separator or "."
	local dfmt
	if db.date_format == "d" then
		dfmt = "%d"
	elseif db.date_format == "dmy" then
		dfmt = "%d" .. sep .. "%m" .. sep .. "%y"
	else -- "dm"
		dfmt = "%d" .. sep .. "%m"
	end
	local day = date(dfmt)

	self.frame.clock:SetFormattedText("%s / %s", clock, day)
	self.frame.clock:SetTextColor(c[1], c[2], c[3])
end

Module.GetFrame = function(self)
	return self.frame
end

-- Applies the vignette (shade) on/off and its strength.
Module.UpdateShade = function(self)
	if not self.frame or not self.frame.shade then return end
	local db = self.db
	if db.show_shade then
		self.frame.shade:SetAlpha(db.shade_alpha or 0.5)
		self.frame.shade:Show()
	else
		self.frame.shade:Hide()
	end
end

-- Shows/hides the addon-button toggle under the map.
Module.UpdateButtonVisibility = function(self)
	if not self.buttonToggle then return end
	if self.db.show_buttons then
		self.buttonToggle:Show()
	else
		self.buttonToggle:Hide()
		if self.buttonPanel then self.buttonPanel:Hide() end
	end
end

-- Applies the overall minimap opacity.
-- At 0% we HIDE the visibility frame (which holds the map, blips and texts) --
-- setting alpha alone leaves the minimap blips (NPC dots, quest !/? icons)
-- visible, since they don't inherit the parent's alpha.
Module.UpdateMapAlpha = function(self)
	if not self.frame or not self.frame.visibility then return end
	local a = self.db.map_alpha or 1
	if a <= 0 then
		self.frame.visibility:Hide()
	else
		self.frame.visibility:Show()
		self.frame:SetAlpha(a)
	end
end

-- Applies all live-updatable settings at once.
Module.ApplySettings = function(self)
	if self._disabled then return end
	self:UpdateInfo()
	self:UpdateShade()
	self:UpdateButtonVisibility()
	self:UpdateMapAlpha()
end

-- Attempts to "square" a third-party minimap button: hide its round border /
-- background textures and clip its icon into a square. This is heuristic --
-- addons build these buttons differently -- but it covers the common cases.
local SquareButton = function(button, iconSize)
	-- resize the button itself to fill the icon area (inside our border)
	button:SetSize(iconSize, iconSize)

	-- walk the button's textures: hide round border/background overlays,
	-- square-clip whatever is left (the actual map icon).
	local regions = { button:GetRegions() }
	for _, region in ipairs(regions) do
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			local tex = region.GetTexture and region:GetTexture()
			local rname = (region.GetName and region:GetName()) or ""
			local texstr = tostring(tex or ""):lower()
			local rnamel = tostring(rname):lower()

			if texstr:find("minimap%-trackingborder")
			or texstr:find("ui%-minimap")
			or texstr:find("border")
			or texstr:find("background")
			or rnamel:find("border")
			or rnamel:find("background")
			or rnamel:find("overlay") then
				region:SetTexture(nil)
				region:Hide()
			else
				-- assume this is the icon: fill the button, trim round edges
				region:ClearAllPoints()
				region:SetPoint("CENTER", button, "CENTER", 0, 0)
				region:SetSize(iconSize, iconSize)
				if region.SetTexCoord then
					region:SetTexCoord(0.1, 0.9, 0.1, 0.9)
				end
			end
		end
	end
end

-- Wraps a collected addon button in our border and parents it to the panel.
Module.WrapButton = function(self, button)
	local cfg = self.config.buttons.icon
	local slot = cfg.slot          -- holder / visible slot size (borders touch here)
	local iconSize = cfg.icon      -- the addon icon inside the border
	local texSize = slot * cfg.texture_scale -- upscale border art so its frame fills the slot

	-- holder = our slot; holders touch edge-to-edge
	local holder = CreateFrame("Frame", nil, self.buttonPanel)
	holder:SetSize(slot, slot)
	holder:SetFrameLevel(self.buttonPanel:GetFrameLevel() + 1)

	-- parent the addon button INTO the holder so it moves with it (icon layer)
	button:SetParent(holder)
	button:ClearAllPoints()
	button:SetFrameStrata(holder:GetFrameStrata())
	button:SetFrameLevel(holder:GetFrameLevel() + 1)
	if button.SetIgnoreParentScale then button:SetIgnoreParentScale(false) end

	SquareButton(button, iconSize)
	button:SetPoint("CENTER", holder, "CENTER", 0, 0)

	-- border overlay ON TOP of the icon -- its own frame, above the button
	local borderFrame = CreateFrame("Frame", nil, holder)
	borderFrame:SetAllPoints(holder)
	borderFrame:SetFrameLevel(button:GetFrameLevel() + 1)
	local border = borderFrame:CreateTexture(nil, "OVERLAY")
	border:SetSize(texSize, texSize)          -- upscaled so the visible frame fills the slot
	border:SetPoint("CENTER", holder, "CENTER", 0, 0)
	border:SetTexture(cfg.border)

	-- freeze the button so its addon can't yank it back
	button.ClearAllPoints = doNothing
	button.SetPoint = doNothing
	button.SetParent = doNothing
	button.SetSize = doNothing

	button._holder = holder
	return holder
end

-- Lays out all collected button holders in a row to the LEFT of the toggle.
Module.LayoutButtons = function(self)
	local cfg = self.config.buttons.icon
	local prev
	for i, button in ipairs(collectedButtons) do
		local holder = button._holder
		if holder then
			holder:ClearAllPoints()
			if not prev then
				holder:SetPoint("RIGHT", self.buttonToggle, "LEFT", -cfg.padding, 0)
			else
				holder:SetPoint("RIGHT", prev, "LEFT", -cfg.padding, 0)
			end
			prev = holder
		end
	end
end

-- Scans the minimap for addon buttons and collects any new ones.
Module.CollectButtons = function(self)
	local before = #collectedButtons

	-- 1) LibDBIcon buttons (many addons register here)
	local LibStub = _G.LibStub
	if LibStub then
		local LibDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
		if LibDBIcon and LibDBIcon.objects then
			for _, button in pairs(LibDBIcon.objects) do
				if not isButtonCollected(button) then
					collectedMap[button] = true
					self:WrapButton(button)
					tinsert(collectedButtons, button)
				end
			end
		end
	end

	-- 2) direct children of the Minimap that look like addon buttons
	for _, child in ipairs({ Minimap:GetChildren() }) do
		if not isButtonCollected(child) and isMinimapButton(child) then
			collectedMap[child] = true
			self:WrapButton(child)
			tinsert(collectedButtons, child)
		end
	end

	-- 3) whitelisted frames (found by global name), wherever they live
	local whitelist = self.config.buttons.whitelist
	if whitelist then
		for _, name in ipairs(whitelist) do
			local frame = _G[name]
			if frame and frame.GetObjectType and not isButtonCollected(frame) then
				collectedMap[frame] = true
				self:WrapButton(frame)
				tinsert(collectedButtons, frame)
			end
		end
	end

	if #collectedButtons > before then
		self:LayoutButtons()
		if self.UpdateToggleTexture then self:UpdateToggleTexture() end
	end
end

-- Shows/hides the collected-button panel.
Module.ToggleButtons = function(self)
	if self.buttonPanel:IsShown() then
		self.buttonPanel:Hide()
		self.buttonToggle.expanded = false
	else
		self.buttonPanel:Show()
		self.buttonToggle.expanded = true
	end
	self:UpdateToggleTexture()
end


Module.OnEnable = function(self)
	-- master switch off: don't touch Blizzard's minimap at all
	if self._disabled then
		return
	end

	-- Hide Blizzard's default minimap chrome (border, buttons, cluster, etc.)
	self:GetHandler("BlizzardUI"):GetElement("Minimap"):Disable()

	-- Make sure the map is shown and positioned after Blizzard's UI is stripped
	Minimap:SetParent(self.frame.visibility)
	Minimap:ClearAllPoints()
	Minimap:SetPoint(unpack(self.config.map.point))
	Minimap:SetSize(unpack(self.config.map.size))
	Minimap:Show()

	-- Zone updates on zone-change events
	local zoneWatcher = CreateFrame("Frame")
	zoneWatcher:RegisterEvent("ZONE_CHANGED")
	zoneWatcher:RegisterEvent("ZONE_CHANGED_INDOORS")
	zoneWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	zoneWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	zoneWatcher:SetScript("OnEvent", function() self:UpdateZone() end)
	self:UpdateZone()

	-- Info line (name/level/clock) refreshes on a light timer for the clock
	local infoTimer = CreateFrame("Frame")
	infoTimer.elapsed = 0
	infoTimer:SetScript("OnUpdate", function(f, e)
		f.elapsed = f.elapsed + e
		if f.elapsed > 1 then
			f.elapsed = 0
			self:UpdateInfo()
		end
	end)
	self:UpdateInfo()

	-- apply the saved sub-option settings (shade, buttons, alpha)
	self:UpdateShade()
	self:UpdateButtonVisibility()
	self:UpdateMapAlpha()

	-- Collect addon minimap buttons. Many addons create their buttons AFTER we
	-- load, so we collect on entering world and then a few more times on a short
	-- timer to catch late arrivals.
	local collector = CreateFrame("Frame")
	collector:RegisterEvent("PLAYER_ENTERING_WORLD")
	collector:SetScript("OnEvent", function() self:CollectButtons() end)

	collector.elapsed = 0
	collector.tries = 0
	collector:SetScript("OnUpdate", function(f, e)
		f.elapsed = f.elapsed + e
		if f.elapsed > 2 then
			f.elapsed = 0
			f.tries = f.tries + 1
			self:CollectButtons()
			-- stop after ~10 attempts (20s); by then all addons have loaded
			if f.tries >= 10 then
				f:SetScript("OnUpdate", nil)
			end
		end
	end)
	self:CollectButtons()

	-- Debug helper: /duimap lists the names of all minimap child frames, so we
	-- can find the exact name of buttons our patterns miss (e.g. HealBot).
	SLASH_DIABOLICUIMAP1 = "/duimap"
	SlashCmdList["DIABOLICUIMAP"] = function()
		print("|cff4488ffDiabolicUI minimap children:|r")
		for _, child in ipairs({ Minimap:GetChildren() }) do
			local n = child.GetName and child:GetName()
			if n then
				print(" - " .. n)
			end
		end
		print("|cff4488ffUIParent children with 'heal' in name:|r")
		for _, child in ipairs({ UIParent:GetChildren() }) do
			local n = child.GetName and child:GetName()
			if n and n:lower():find("heal") then
				print(" - " .. n)
			end
		end
	end
end

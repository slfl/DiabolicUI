local _, Engine = ...
local Module = Engine:NewModule("DurabilityFrame")

-- Relocates the DurabilityFrame (the broken-armour indicator that Blizzard drops
-- in the centre of the screen) and lets the user unlock it, drag it anywhere,
-- then lock it. Position is saved per character. Same UX as the Vehicle mover.

local function db()
	return Engine:GetConfig("UI", "character")
end

-- Apply the saved (or default) position to the holder.
Module.Reposition = function(self)
	local holder = self.holder
	if not holder then return end
	holder:ClearAllPoints()
	local pos = db().durability_position
	if pos then
		holder:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
	else
		local d = self.default
		holder:SetPoint(d.point, d.anchor, d.rpoint, d.x, d.y)
	end
end

-- Save the holder's current position (relative to UIParent) into the config.
local function savePosition(self)
	local point, _, _, x, y = self.holder:GetPoint()
	db().durability_position = { point = point, x = x, y = y }
end

-- Movable overlay so the user can drag the frame while unlocked. We drag the
-- overlay and copy its position onto the holder (the durability icon is anchored
-- to the holder, so it follows).
Module.SetUnlocked = function(self, unlocked)
	local content = DurabilityFrame
	local holder = self.holder
	if not (content and holder) then return end

	if not self.overlay then
		local o = CreateFrame("Frame", nil, UIParent)
		o:SetAllPoints(holder)
		o:SetFrameStrata("DIALOG")
		o:EnableMouse(true)
		o:SetMovable(true)
		o:RegisterForDrag("LeftButton")

		local bg = o:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(o)
		bg:SetTexture(0, 0.6, 1, 0.35)
		o.bg = bg

		local label = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("CENTER", o, "CENTER", 0, 0)
		label:SetText("Прочность")
		o.label = label

		o:SetScript("OnDragStart", function(self2) self2:StartMoving() end)
		o:SetScript("OnDragStop", function(self2)
			self2:StopMovingOrSizing()
			local point, _, _, x, y = self2:GetPoint()
			holder:ClearAllPoints()
			holder:SetPoint(point, UIParent, point, x, y)
			savePosition(self)
			self2:ClearAllPoints()
			self2:SetAllPoints(holder)
		end)

		self.overlay = o
	end

	self.unlocked = unlocked
	if unlocked then
		self.overlay:ClearAllPoints()
		self.overlay:SetAllPoints(holder)
		self.overlay:Show()
		-- force the durability frame visible so there's something to position
		if not content:IsShown() then
			content:Show()
			self._forcedShown = true
		end
	else
		self.overlay:Hide()
		if self._forcedShown then
			content:Hide()
			self._forcedShown = false
		end
		self:Reposition()
	end
end

Module.IsUnlocked = function(self)
	return self.unlocked == true
end

Module.OnInit = function(self)
	local content = DurabilityFrame
	if not content then
		return
	end

	local config = self:GetStaticConfig("Blizzard").durability
	local point, anchor, rpoint, x, y = unpack(config.position)
	if anchor == "UICenter" then
		anchor = Engine:GetFrame()
	end
	-- default position = the module's configured spot
	self.default = { point = point, anchor = anchor, rpoint = rpoint, x = x, y = y }

	local holder = CreateFrame("Frame", nil, Engine:GetFrame())
	holder:SetWidth(content:GetWidth())
	holder:SetHeight(content:GetHeight())
	self.holder = holder

	content:ClearAllPoints()
	content:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0)

	-- keep our anchor when the game tries to re-anchor to the minimap cluster
	hooksecurefunc(content, "SetPoint", function(frame, _, a)
		if a == "MinimapCluster" or a == _G["MinimapCluster"] then
			frame:ClearAllPoints()
			frame:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0)
		end
	end)

	self:Reposition()
end

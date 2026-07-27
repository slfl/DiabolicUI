local ADDON, Engine = ...
local Module = Engine:NewModule("Vehicle")

-- Moves the VehicleSeatIndicator (passenger/seat frame for mounts like the
-- Traveler's Tundra Mammoth or the motorcycle) out of the screen centre.
-- The user can unlock it, drag it anywhere, then lock it; the position is saved
-- per character. The secure "Eject Passenger" menu is never touched.

local DEFAULT = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -20, 260 }

local function db()
	return Engine:GetConfig("UI", "character")
end

-- Apply the saved (or default) position to the frame.
Module.Reposition = function(self)
	local f = VehicleSeatIndicator
	if not f then return end
	local pos = db().vehicle_position
	f:ClearAllPoints()
	if pos then
		f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
	else
		f:SetPoint(DEFAULT[1], _G[DEFAULT[2]], DEFAULT[3], DEFAULT[4], DEFAULT[5])
	end
end

-- Save the frame's current position (relative to UIParent) into the config.
local function savePosition(f)
	local point, _, _, x, y = f:GetPoint()
	db().vehicle_position = { point = point, x = x, y = y }
end

-- A movable overlay so the user can drag the frame while unlocked. We drag an
-- overlay (not the secure frame directly) and copy its position back.
Module.SetUnlocked = function(self, unlocked)
	local f = VehicleSeatIndicator
	if not f then return end

	if not self.overlay then
		local o = CreateFrame("Frame", nil, UIParent)
		o:SetAllPoints(f)
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
		label:SetText("Транспорт")
		o.label = label

		o:SetScript("OnDragStart", function(self2)
			-- detach the vehicle frame and move it with the overlay
			f:ClearAllPoints()
			self2:StartMoving()
		end)
		o:SetScript("OnDragStop", function(self2)
			self2:StopMovingOrSizing()
			-- place the vehicle frame at the overlay's spot and save it
			local point, _, _, x, y = self2:GetPoint()
			f:ClearAllPoints()
			f:SetPoint(point, UIParent, point, x, y)
			savePosition(f)
		end)

		self.overlay = o
	end

	self.unlocked = unlocked
	if unlocked then
		self.overlay:ClearAllPoints()
		self.overlay:SetAllPoints(f)
		self.overlay:Show()
		-- make sure the frame is visible while positioning, even off a vehicle
		if not f:IsShown() then
			f:Show()
			self._forcedShown = true
		end
	else
		self.overlay:Hide()
		if self._forcedShown then
			f:Hide()
			self._forcedShown = false
		end
		self:Reposition()
	end
end

Module.IsUnlocked = function(self)
	return self.unlocked == true
end

Module.OnEnable = function(self)
	local f = VehicleSeatIndicator
	if not f then return end

	self:Reposition()

	-- keep our position when the game re-anchors the frame
	f:HookScript("OnShow", function()
		if not self:IsUnlocked() then self:Reposition() end
	end)
	if VehicleSeatIndicator_SetUpVehicle then
		hooksecurefunc("VehicleSeatIndicator_SetUpVehicle", function()
			if not self:IsUnlocked() then self:Reposition() end
		end)
	end
end

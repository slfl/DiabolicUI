local ADDON, Engine = ...
local Module = Engine:NewModule("NamePlates")

-- Lua API
local ipairs = ipairs
local path = ([[Interface\AddOns\%s\media\]]):format(ADDON)

-- WoW API
local WorldFrame = WorldFrame

-- === Single fixed style: the 195 border (512x64 sheet) ===
-- Measured from the red-frame marker file:
--   texture 512x64, red window 196x16 px, symmetric.
--   edge insets as fractions of the ART: left/right 0.30859, top/bottom 0.375.
local BORDER_TEX = path .. [[textures\unitframes\DiabolicUI_Target_195x13_Border.tga]]
local BAR_TEXTURE = path .. [[statusbars\DiabolicUI_StatusBar_512x64_Dark_Warcraft.tga]]
local ART_ASPECT = 512/64      -- = 8.0
local INSET_LR = 0.30859       -- left & right inset (fraction of art width)
local INSET_TB = 0.37500       -- top & bottom inset (fraction of art height)

-- On-screen plate height (the art width follows the aspect ratio).
local PLATE_HEIGHT = 34

-- A 3.3.5 nameplate is an anonymous WorldFrame child whose first two children
-- are both StatusBars (health + cast). Name/level/border are the plate's regions.
local function isNamePlate(frame)
	if frame:GetName() then return false end
	local c1, c2 = frame:GetChildren()
	if not (c1 and c2) then return false end
	if not (c1.GetStatusBarTexture and c2.GetStatusBarTexture) then return false end
	return true
end

local function parsePlate(frame)
	local healthBar, castBar = frame:GetChildren()
	local name, level
	for _, r in ipairs({ frame:GetRegions() }) do
		if r:GetObjectType() == "FontString" then
			if not name then name = r else level = r end
		end
	end
	return { healthBar = healthBar, castBar = castBar, name = name, level = level }
end

-- compute art size + bar insets in pixels for the current PLATE_HEIGHT
local function metrics()
	local artH = PLATE_HEIGHT
	local artW = artH * ART_ASPECT
	local insL = artW * INSET_LR
	local insR = artW * INSET_LR
	local insT = artH * INSET_TB
	local insB = artH * INSET_TB
	return artW, artH, insL, insR, insT, insB
end

local function pinBar(frame)
	local hb = frame._dui and frame._dui.healthBar
	local border = frame._duiBorder
	if not (hb and border) then return end
	local _, _, insL, insR, insT, insB = metrics()
	hb:ClearAllPoints()
	hb:SetPoint("TOPLEFT", border, "TOPLEFT", insL, -insT)
	hb:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -insR, insB)
end

-- Instantly hide a plate's default chrome (all textures except the raid icon).
-- Called the moment a plate is detected, BEFORE we build our own art, so the
-- original never gets a chance to flash on screen.
local function hideOriginal(frame)
	for _, r in ipairs({ frame:GetRegions() }) do
		if r:GetObjectType() == "Texture" and r ~= frame._duiBorder then
			local tex = tostring(r:GetTexture() or "")
			if not tex:find("RaidIcon") then r:SetTexture(nil) end
		end
	end
end

local function skinPlate(frame)
	if frame._duiPlate then return end
	frame._duiPlate = true

	local p = parsePlate(frame)
	frame._dui = p

	-- hide the original plate textures (border/glow/level ring)
	hideOriginal(frame)

	local artW, artH = metrics()

	-- our border art (transparent centre); OVERLAY so the frame sits above the bar
	local border = frame:CreateTexture(nil, "OVERLAY")
	border:SetPoint("CENTER", frame, "CENTER", 0, 0)
	border:SetSize(artW, artH)
	border:SetTexture(BORDER_TEX)
	frame._duiBorder = border

	-- health bar pinned inside the border window (both corners -> no drift)
	local hb = p.healthBar
	hb:SetStatusBarTexture(BAR_TEXTURE)
	pinBar(frame)

	-- name with our font, above the plate
	if p.name then
		p.name:SetFontObject(DiabolicUnitFrameNormal or GameFontNormal)
		p.name:ClearAllPoints()
		p.name:SetPoint("BOTTOM", border, "TOP", 0, 2)
		p.name:SetParent(frame)
	end

	-- level text at the right of the plate
	if p.level then
		p.level:SetFontObject(DiabolicUnitFrameNormal or GameFontNormalSmall)
		p.level:ClearAllPoints()
		p.level:SetPoint("LEFT", border, "RIGHT", -60, 0)
	end

	-- plates get recycled for new units and the game re-shows the default chrome;
	-- re-hide it and keep our art every time the plate is shown
	frame:HookScript("OnShow", function(f)
		hideOriginal(f)
		if f._duiBorder then f._duiBorder:Show() end
		pinBar(f)
	end)
end

local function updatePlate(frame)
	local p = frame._dui
	if not p then return end
	local hb = p.healthBar
	if hb and hb.GetStatusBarColor then
		local r, g, b = hb:GetStatusBarColor()
		hb:SetStatusBarColor(r, g, b, 1)
		hb:SetStatusBarTexture(BAR_TEXTURE)
	end
	pinBar(frame)
	if frame._duiBorder and not frame._duiBorder:IsShown() then
		frame._duiBorder:Show()
	end
end

Module.OnEnable = function(self)
	local scanner = CreateFrame("Frame")
	scanner.elapsed = 0
	scanner:SetScript("OnUpdate", function(f, e)
		f.elapsed = f.elapsed + e
		if f.elapsed < 0.05 then return end
		f.elapsed = 0

		-- Always scan the children. For any plate we haven't styled yet, hide the
		-- original chrome FIRST (pre-emptive) and then build our art. Doing the
		-- hide as the very first action keeps the default plate from flashing.
		for _, child in ipairs({ WorldFrame:GetChildren() }) do
			if not child._duiPlate and isNamePlate(child) then
				hideOriginal(child)   -- kill the default look instantly
				skinPlate(child)      -- then draw ours
			elseif child._duiPlate and child:IsShown() then
				updatePlate(child)
			end
		end
	end)
	self.scanner = scanner
end

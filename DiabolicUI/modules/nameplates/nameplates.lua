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

-- === Cast bar (integrated into the bottom of the health bar) =============
local CAST_HEIGHT_FRAC  = 1/3                     -- cast height = 1/3 of HP bar
local CAST_COLOR        = { 0.20, 0.80, 0.25 }    -- interruptible cast (green)
local CAST_COLOR_NOINT  = { 1.00, 0.50, 0.10 }    -- non-interruptible cast (orange)
local HL_PAD            = 3                        -- mouseover glow padding
local HL_COLOR          = { 1.00, 0.82, 0.20, 0.55 } -- glow tint (r,g,b,a)

-- A 3.3.5 nameplate is an anonymous WorldFrame child whose first two children
-- are both StatusBars (health + cast). Name/level/border are the plate's regions.
local function isNamePlate(frame)
	if frame:GetName() then return false end
	local c1, c2 = frame:GetChildren()
	if not (c1 and c2) then return false end
	if not (c1.GetStatusBarTexture and c2.GetStatusBarTexture) then return false end
	return true
end

-- Classify a plate's regions by their (original) texture path. This is far
-- more robust across builds than trusting region order. Must run on LIVE
-- textures (before hideOriginal nulls them); we fall back to the recorded
-- _duiOrigTex if the texture was already cleared.
local function parsePlate(frame)
	local healthBar, castBar = frame:GetChildren()
	local p = { healthBar = healthBar, castBar = castBar }
	for _, r in ipairs({ frame:GetRegions() }) do
		local ot = r:GetObjectType()
		if ot == "FontString" then
			if not p.name then p.name = r else p.level = r end
		elseif ot == "Texture" then
			local tex = tostring(r:GetTexture() or r._duiOrigTex or "")
			local dl  = select(1, r:GetDrawLayer())
			if tex:find("Nameplate%-Border") then
				if not p.healthBorder then p.healthBorder = r else p.castBorder = r end
			elseif tex:find("CastBar%-Shield") then p.shield = r
			elseif tex:find("Nameplate%-Glow") or dl == "HIGHLIGHT" then p.highlight = r
			elseif tex:find("UI%-TargetingFrame%-Skull") then p.skull = r
			elseif tex:find("RaidTargetingIcons") then p.raidIcon = r
			elseif tex:find("EliteNameplateIcon") then p.elite = r
			elseif tex:find("UI%-TargetingFrame%-Flash") then p.flash = r
			elseif dl == "OVERLAY" and r ~= frame._duiBorder and not p.castIcon then
				p.castIcon = r   -- leftover OVERLAY texture = cast spell icon (dynamic)
			end
		end
	end
	return p
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

-- Reveal-style fill: instead of letting the StatusBar squeeze the whole texture
-- into the filled width (default = stretch), we crop the fill texture's right
-- edge via TexCoord so it always renders 1:1 and just loses its tail as the
-- value drops. Driven by OnValueChanged (per-engine-frame, smooth) and re-run
-- after every SetStatusBarTexture (which resets TexCoord back to 0..1).
local function cropBar(bar)
	if not bar or not bar.GetStatusBarTexture then return end
	local tex = bar:GetStatusBarTexture()
	if not tex then return end
	local mn, mx = bar:GetMinMaxValues()
	local v = bar:GetValue() or 0
	local f = 0
	if mx and mn and mx > mn then f = (v - mn) / (mx - mn) end
	if f < 0 then f = 0 elseif f > 1 then f = 1 end
	tex:SetTexCoord(0, f, 0, 1)
end

-- Null ONLY the default chrome we replace: the aggro flash and the two
-- Nameplate-Border textures (health + cast frames). Everything else — cast
-- spell icon, non-interruptible shield, mouseover glow, raid/boss/elite
-- markers — is kept and restyled elsewhere. Requires frame._dui to be set.
local function hideOriginal(frame)
	local p = frame._dui
	if not p then return end
	for _, r in ipairs({ p.flash, p.healthBorder, p.castBorder }) do
		if r then
			if not r._duiRec then r._duiRec = true; r._duiOrigTex = tostring(r:GetTexture() or "") end
			r:SetTexture(nil)
		end
	end
end

-- Embed the cast bar (kid#2) into the BOTTOM of the health bar: pinned to both
-- bottom corners, height = 1/3 of the HP bar, drawn ABOVE the HP fill. So a
-- normal enemy just shows a shrinking red HP bar; when it casts, a thin yellow
-- (red if non-interruptible) sliver fills along the bottom third. No separate
-- frame, icon or shield — colour alone signals interruptibility.
-- Re-applied on skin, OnShow (recycle) and each tick while casting, because the
-- engine re-anchors/recolours kid#2 at cast start.
local function styleCast(frame)
	local p = frame._dui
	local cb = p and p.castBar
	local hb = p and p.healthBar
	if not (cb and hb) then return end
	local _, artH, _, _, insT, insB = metrics()
	local hbH = artH - insT - insB          -- on-screen HP bar height
	cb:SetStatusBarTexture(BAR_TEXTURE)
	cropBar(cb)                              -- reveal-style fill (SetStatusBarTexture reset the coords)
	cb:SetFrameLevel(hb:GetFrameLevel() + 1) -- above the HP fill
	cb:ClearAllPoints()
	cb:SetPoint("BOTTOMLEFT",  hb, "BOTTOMLEFT",  0, 0)
	cb:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 0, 0)
	cb:SetHeight(hbH * CAST_HEIGHT_FRAC)
	-- green = interruptible, orange = non-interruptible (shield region shown)
	local c = (p.shield and p.shield:IsShown()) and CAST_COLOR_NOINT or CAST_COLOR
	cb:SetStatusBarColor(c[1], c[2], c[3])
	-- keep the integrated look clean: no external spell icon, no shield graphic
	if p.castIcon then p.castIcon:Hide() end
	if p.shield then p.shield:SetTexture(nil) end
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
	cropBar(hb)
	pinBar(frame)

	-- reveal-style fill: crop the texture on every value change (both bars)
	hb:HookScript("OnValueChanged", function(self) cropBar(self) end)
	if p.castBar then
		p.castBar:HookScript("OnValueChanged", function(self) cropBar(self) end)
		-- style the cast bar the instant the client shows it (cast start), so it
		-- never waits for the 0.05s scanner tick — no delay, no default flash
		p.castBar:HookScript("OnShow", function() styleCast(frame) end)
	end

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

	-- cast bar (kid#2): our texture, sits just below the health bar
	styleCast(frame)

	-- mouseover glow: HIGHLIGHT layer, so the engine shows it on hover by
	-- itself. Re-anchor it to our health window and tint it.
	if p.highlight then
		p.highlight:SetTexture([[Interface\Tooltips\Nameplate-Glow]])
		p.highlight:ClearAllPoints()
		p.highlight:SetPoint("TOPLEFT", hb, "TOPLEFT", -HL_PAD, HL_PAD)
		p.highlight:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", HL_PAD, -HL_PAD)
		p.highlight:SetVertexColor(HL_COLOR[1], HL_COLOR[2], HL_COLOR[3], HL_COLOR[4])
	end

	-- plates get recycled for new units and the game re-shows the default chrome;
	-- re-hide it and keep our art every time the plate is shown
	frame:HookScript("OnShow", function(f)
		hideOriginal(f)
		if f._duiBorder then f._duiBorder:Show() end
		pinBar(f)
		styleCast(f)
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
		cropBar(hb)                 -- SetStatusBarTexture reset the coords -> re-apply
	end
	pinBar(frame)
	if frame._duiBorder and not frame._duiBorder:IsShown() then
		frame._duiBorder:Show()
	end
	-- cast bar upkeep: engine re-anchors/recolours kid#2 at cast start, so keep
	-- our embedded anchor + texture + colour while it is visible
	local cb = p.castBar
	if cb and cb:IsShown() then
		styleCast(frame)
	end
end

Module.OnEnable = function(self)
	local scanner = CreateFrame("Frame")
	scanner.elapsed = 0
	scanner:SetScript("OnUpdate", function(f, e)
		-- EVERY FRAME: catch new plates and keep the default chrome dead. This
		-- runs before the frame renders, so a plate shown this frame (e.g. on the
		-- V toggle) never gets to draw its default look — the 0.05s tick was too
		-- slow and left a visible flash. Skinning also nulls the chrome, and we
		-- re-null shown plates each frame in case the client re-applies it on show.
		local kids = { WorldFrame:GetChildren() }
		for _, child in ipairs(kids) do
			if child._duiPlate then
				if child:IsShown() then hideOriginal(child) end
			elseif isNamePlate(child) then
				skinPlate(child)
			end
		end

		-- THROTTLED (0.05s): heavier per-plate upkeep (reaction colour, texture,
		-- crop, border) — not latency-critical, so it needn't run every frame.
		f.elapsed = f.elapsed + e
		if f.elapsed < 0.05 then return end
		f.elapsed = 0
		for _, child in ipairs(kids) do
			if child._duiPlate and child:IsShown() then
				updatePlate(child)
			end
		end
	end)
	self.scanner = scanner

	-- === TEMP DEBUG: /duinp — dump full anatomy of visible nameplates =========
	-- Reports children (type + StatusBar flag), each child's regions, the plate's
	-- own regions with their ORIGINAL texture path (recorded in hideOriginal
	-- before we nuked them), draw layer and shown state. Remove before release.
	local function reg(r, tag)
		local rt = r:GetObjectType()
		local dl = (r.GetDrawLayer and select(1, r:GetDrawLayer())) or "-"
		local shown = r:IsShown() and "Y" or "n"
		local tex = r._duiOrigTex or (r.GetTexture and tostring(r:GetTexture() or "")) or ""
		if #tex > 60 then tex = "..."..tex:sub(-57) end
		local txt = (r.GetText and r:GetText()) or ""
		print(string.format("   %s %s [%s] shown=%s tex=%s %s", tag, rt, dl, shown, tex, txt ~= "" and ("txt="..txt) or ""))
	end
	local function dumpPlate(frame, idx)
		print("|cffffcc00== PLATE #"..idx.." ==|r shown="..tostring(frame:IsShown()))
		local kids = { frame:GetChildren() }
		print("  children: "..#kids)
		for i, c in ipairs(kids) do
			local sb = c.GetStatusBarTexture and " StatusBar" or ""
			print(string.format("  kid#%d %s%s", i, c:GetObjectType(), sb))
			for _, r in ipairs({ c:GetRegions() }) do reg(r, "     k"..i) end
		end
		print("  plate regions:")
		for _, r in ipairs({ frame:GetRegions() }) do reg(r, "    ") end
	end
	SLASH_DUINP1 = "/duinp"
	SlashCmdList["DUINP"] = function()
		local n = 0
		for _, child in ipairs({ WorldFrame:GetChildren() }) do
			if isNamePlate(child) and child:IsShown() then
				n = n + 1
				dumpPlate(child, n)
				if n >= 2 then break end
			end
		end
		if n == 0 then print("|cffff0000/duinp: нет видимых плашек на экране|r") end
	end
	-- === END TEMP DEBUG ======================================================
end

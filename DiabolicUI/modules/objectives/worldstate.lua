local Addon, Engine = ...
local Module = Engine:NewModule("WorldState")
local L = Engine:GetLocale()

-- Lua API
local gsub, format = string.gsub, string.format
local ipairs = ipairs

local path = ([[Interface\AddOns\%s\media\]]):format(Addon)

-- config (kept local; can be externalised to config/ later)
local config = {
	font = { path = path .. [[fonts\DejaVuSansCondensed.ttf]], size = 14, style = "" },
	row_height = 24,
	row_spacing = 2,
	point = { "TOPRIGHT", "TOPLEFT", -20, 0 }, -- our frame vs minimap
	colors = {
		alliance = { 0.30, 0.55, 1.00 }, -- blue
		horde    = { 0.90, 0.20, 0.20 }, -- red
		neutral  = { 1.00, 0.82, 0.20 }, -- gold
	},
	bar = {
		width = 200,
		height = 16,
		spacing = 8, -- gap below the text rows
		texture = [[Interface\TargetingFrame\UI-StatusBar]],
		border_color = { 0, 0, 0, 1 },
	},
}

-- Strips the trailing "(...)" chunk Blizzard appends to some rows, and trims.
local function CleanText(text)
	if not text then return "" end
	text = gsub(text, "%s*%b()", "")   -- remove any (...) groups
	text = gsub(text, "%s+$", "")       -- trailing spaces
	text = gsub(text, "^%s+", "")       -- leading spaces
	return text
end

-- Builds/refreshes our own world-state rows from the API.
Module.UpdateRows = function(self)
	local holder = self.holder
	if not holder then return end

	local rows = self.rows
	local num = GetNumWorldStateUI()
	local shown = 0

	for i = 1, num do
		-- NOTE: on this 3.3.5 build the return order is shifted vs retail docs.
		-- The phrase ("Базы: X ...") arrives in the 3rd value, and the icon PATH
		-- in the 4th. We use the path only to detect the faction for coloring.
		local uiType, barState, rowText, iconPath, _, _, _, _, extendedUI = GetWorldStateUIInfo(i)

		-- rows with an extended UI (capture bars) are handled elsewhere; skip here
		if (not extendedUI or extendedUI == 0) and rowText and rowText ~= "" then
			shown = shown + 1

			-- create the row on demand
			local row = rows[shown]
			if not row then
				row = CreateFrame("Frame", nil, holder)
				row:SetHeight(config.row_height)
				row:SetWidth(300)

				row.text = row:CreateFontString(nil, "OVERLAY")
				row.text:SetFont(config.font.path, config.font.size, config.font.style)
				row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
				row.text:SetJustifyH("RIGHT")
				row.text:SetJustifyV("MIDDLE")
				row.text:SetShadowOffset(1, -1)
				row.text:SetShadowColor(0, 0, 0, 1)

				rows[shown] = row
			end

			-- position rows top-down
			row:ClearAllPoints()
			if shown == 1 then
				row:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
			else
				row:SetPoint("TOPRIGHT", rows[shown-1], "BOTTOMRIGHT", 0, -config.row_spacing)
			end

			-- color the text by faction (detected from the icon path)
			local c = config.colors.neutral
			if iconPath then
				if iconPath:find("Alliance") then
					c = config.colors.alliance
				elseif iconPath:find("Horde") then
					c = config.colors.horde
				end
			end
			row.text:SetTextColor(c[1], c[2], c[3])
			row.text:SetText(CleanText(rowText))
			row:Show()
		end
	end

	-- hide any leftover rows from a previous larger set
	for i = shown + 1, #rows do
		rows[i]:Hide()
	end

	-- second pass: capture bars (extendedUI statuses)
	self:UpdateCaptureBars(shown)

	self.numShown = shown
	if shown > 0 or self.numBars > 0 then holder:Show() else holder:Hide() end
end

-- Builds/updates our own capture bars from the extendedUI world-state entries.
-- Layout: Alliance (blue) | neutral (grey) | Horde (red), with a sliding marker.
-- state1 = marker position 0..100, state2 = neutral-zone width in percent.
Module.UpdateCaptureBars = function(self, textRowsShown)
	local holder = self.holder
	local bars = self.bars
	local bcfg = config.bar
	local num = GetNumWorldStateUI()
	local shownBars = 0

	for i = 1, num do
		local uiType, state, rowText, iconPath, _, _, _, extendedUI, s1, s2 = GetWorldStateUIInfo(i)
		-- capture points come through as extendedUI == "CAPTUREPOINT"
		if extendedUI and extendedUI ~= 0 and extendedUI ~= "" and state and state > 0 then
			shownBars = shownBars + 1

			local bar = bars[shownBars]
			if not bar then
				bar = CreateFrame("Frame", nil, holder)
				bar:SetSize(bcfg.width, bcfg.height)

				-- Alliance zone (left, blue)
				bar.left = bar:CreateTexture(nil, "BACKGROUND")
				bar.left:SetTexture(bcfg.texture)
				bar.left:SetVertexColor(config.colors.alliance[1], config.colors.alliance[2], config.colors.alliance[3], 0.9)
				bar.left:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
				bar.left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)

				-- neutral zone (middle, grey)
				bar.mid = bar:CreateTexture(nil, "BACKGROUND")
				bar.mid:SetTexture(bcfg.texture)
				bar.mid:SetVertexColor(0.6, 0.6, 0.6, 0.8)

				-- Horde zone (right, red)
				bar.right = bar:CreateTexture(nil, "BACKGROUND")
				bar.right:SetTexture(bcfg.texture)
				bar.right:SetVertexColor(config.colors.horde[1], config.colors.horde[2], config.colors.horde[3], 0.9)
				bar.right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
				bar.right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)

				-- sliding marker
				bar.marker = bar:CreateTexture(nil, "OVERLAY")
				bar.marker:SetSize(3, bcfg.height - 2)
				bar.marker:SetTexture(1, 1, 1, 1)

				-- border
				bar:SetBackdrop({
					edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
					edgeSize = 8,
				})
				bar:SetBackdropBorderColor(unpack(bcfg.border_color))

				bars[shownBars] = bar
			end

			-- position: below the text rows (or the previous bar)
			bar:ClearAllPoints()
			if shownBars == 1 then
				local anchorY = -(textRowsShown * (config.row_height + config.row_spacing)) - bcfg.spacing
				bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, anchorY)
			else
				bar:SetPoint("TOPRIGHT", bars[shownBars-1], "BOTTOMRIGHT", 0, -bcfg.spacing)
			end

			-- read position + neutral width
			local pos = tonumber(s1) or 50
			if pos < 0 then pos = 0 elseif pos > 100 then pos = 100 end
			local neutral = tonumber(s2) or 0
			if neutral < 0 then neutral = 0 elseif neutral > 100 then neutral = 100 end

			local W = bcfg.width
			-- neutral zone centered; its half-width in fraction
			local halfN = (neutral / 100) / 2
			local leftEnd  = (0.5 - halfN)   -- fraction where blue ends
			local rightStart = (0.5 + halfN) -- fraction where red starts

			bar.left:SetWidth(W * leftEnd)

			bar.mid:ClearAllPoints()
			bar.mid:SetPoint("TOPLEFT", bar, "TOPLEFT", W * leftEnd, 0)
			bar.mid:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", W * rightStart, 0)

			bar.right:SetWidth(W * (1 - rightStart))

			-- marker position: state1 runs Horde(0)..Alliance(100) on this build,
			-- so invert it to match our Alliance(left)..Horde(right) layout
			bar.marker:ClearAllPoints()
			bar.marker:SetPoint("CENTER", bar, "LEFT", W * (1 - pos / 100), 0)

			bar:Show()
		end
	end

	for i = shownBars + 1, #bars do
		bars[i]:Hide()
	end
	self.numBars = shownBars
end

Module.OnEnable = function(self)
	self.rows = {}
	self.bars = {}
	self.numBars = 0

	-- Debug: /duiws dumps what the API returns, so we can see the real fields
	SLASH_DUIWS1 = "/duiws"
	SlashCmdList["DUIWS"] = function()
		local num = GetNumWorldStateUI()
		print("|cff4488ffWorldState count:|r "..num)
		for i = 1, num do
			local uiType, state, text, icon, dynIcon, tip, dynTip, extendedUI, s1, s2, s3 = GetWorldStateUIInfo(i)
			print(format("|cffffcc00#%d|r type=%s state=%s extUI=%s", i, tostring(uiType), tostring(state), tostring(extendedUI)))
			print("   text(3)="..tostring(text))
			print("   icon(4)="..tostring(icon))
			print(format("   state1=%s state2=%s state3=%s", tostring(s1), tostring(s2), tostring(s3)))
		end
	end

	-- Hide Blizzard's default always-up frame entirely
	Engine:GetHandler("BlizzardUI"):GetElement("WorldState"):Disable()

	-- Our holder, to the LEFT of the minimap, top-aligned
	local Minimap = _G.Minimap
	local holder = CreateFrame("Frame", "DiabolicUIWorldState", Engine:GetFrame())
	holder:SetSize(300, 200)
	local p = config.point
	holder:SetPoint(p[1], Minimap, p[2], p[3], p[4])
	holder:Hide()
	self.holder = holder

	-- refresh on the relevant events + a light timer for countdowns
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("UPDATE_WORLD_STATES")
	watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	watcher:RegisterEvent("WORLD_STATE_UI_TIMER_UPDATE")
	watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	watcher:SetScript("OnEvent", function() self:UpdateRows() end)

	self.timer = 0
	watcher:SetScript("OnUpdate", function(f, e)
		self.timer = self.timer + e
		if self.timer > 1 then
			self.timer = 0
			self:UpdateRows()
		end
	end)

	self:UpdateRows()
end

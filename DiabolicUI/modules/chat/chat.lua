local Addon, Engine = ...
local Module = Engine:NewModule("Chat", "LOW")
local L = Engine:GetLocale()

-- Lua API
local date = date
local format = string.format
local type = type

-- WoW API
local hooksecurefunc = hooksecurefunc

-- Builds the timestamp prefix per the current settings, or "" if disabled.
Module.GetTimestamp = function(self)
	local ts = self.db.timestamp
	if not ts.enabled then
		return ""
	end

	local timeStr
	if ts.format == "HH:MM:SS" then
		timeStr = date("%H:%M:%S")
	else
		timeStr = date("%H:%M")
	end

	if ts.brackets then
		timeStr = "[" .. timeStr .. "]"
	end

	local r, g, b
	if ts.use_custom_color then
		r, g, b = ts.color[1], ts.color[2], ts.color[3]
	else
		r, g, b = 0.5, 0.5, 0.5
	end
	local hex = format("%02x%02x%02x", r * 255, g * 255, b * 255)

	return "|cff" .. hex .. timeStr .. "|r "
end

-- Adds the AddMessage hook to a single chat frame (guards double-hooking).
-- Hooking AddMessage puts our timestamp at the very START of the final line
-- (after the sender/channel prefix has already been assembled by Blizzard).
Module.HookChatFrame = function(self, frame)
	if not frame or frame._duiTimestampHooked then return end
	frame._duiTimestampHooked = true

	local module = self
	local origAddMessage = frame.AddMessage
	frame.AddMessage = function(f, text, ...)
		if text and type(text) == "string" then
			local stamp = module:GetTimestamp()
			if stamp ~= "" then
				text = stamp .. text
			end
		end
		return origAddMessage(f, text, ...)
	end
end

-- ======================================================================
-- Dark Diablo styling: button textures, dark background, button visibility
-- ======================================================================

-- Applies our textures to one chat button (Normal/Highlight/Pushed/Disabled).
-- Works for existing Blizzard buttons AND freshly created ones (creates the
-- texture objects if they don't exist yet).
local function SkinButton(button, tex, size, texSize)
	if not button then return end
	button:SetSize(size[1], size[2])

	local function ensure(getterName, setterName, layer)
		local t = button[getterName] and button[getterName](button)
		if not t and button[setterName] then
			t = button:CreateTexture(nil, "ARTWORK")
			button[setterName](button, t)
		end
		return t
	end

	local function place(t, path, blend)
		if not t then return end
		t:SetTexture(path)
		t:ClearAllPoints()
		t:SetPoint("CENTER", button, "CENTER", 0, 0)
		t:SetSize(texSize[1], texSize[2])
		if blend then t:SetBlendMode(blend) end
	end

	place(ensure("GetNormalTexture", "SetNormalTexture"), tex.normal)
	place(ensure("GetHighlightTexture", "SetHighlightTexture"), tex.highlight, "BLEND")
	place(ensure("GetPushedTexture", "SetPushedTexture"), tex.highlight)
	place(ensure("GetDisabledTexture", "SetDisabledTexture"), tex.disabled)
end

-- Styles a single chat frame: dark background + skinned buttons.
Module.StyleChatFrame = function(self, frame, index)
	if not frame then return end
	local cfg = self.config
	local name = "ChatFrame" .. index

	-- dark background behind the text (extended slightly to cover the full block)
	if not frame._duiBG then
		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture(cfg.background.texture)
		bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
		bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -7)
		frame._duiBG = bg
	end

	-- skin the scroll buttons for this frame
	SkinButton(_G[name .. "ButtonFrameUpButton"],     cfg.buttons.up,     cfg.buttons.size, cfg.buttons.texture_size)
	SkinButton(_G[name .. "ButtonFrameDownButton"],   cfg.buttons.down,   cfg.buttons.size, cfg.buttons.texture_size)
	SkinButton(_G[name .. "ButtonFrameBottomButton"], cfg.buttons.bottom, cfg.buttons.size, cfg.buttons.texture_size)

	-- skin the shared chat menu button once (belongs to ChatFrame1)
	if index == 1 and ChatFrameMenuButton and not ChatFrameMenuButton._duiSkinned then
		SkinButton(ChatFrameMenuButton, cfg.buttons.menu, cfg.buttons.size, cfg.buttons.texture_size)
		ChatFrameMenuButton._duiSkinned = true
	end

	-- add our copy button (once, on ChatFrame1) beneath the bottom scroll button
	if index == 1 and not self.copyButton then
		local cb = CreateFrame("Button", "DiabolicUIChatCopyButton", UIParent)
		cb:SetSize(cfg.buttons.size[1], cfg.buttons.size[2])
		cb:SetFrameStrata("HIGH")
		cb:SetFrameLevel(50)
		-- place it at the TOP of the button stack, above the menu (gear) button
		local anchor = ChatFrameMenuButton or _G["ChatFrame1ButtonFrameUpButton"]
		if anchor then
			cb:SetPoint("BOTTOM", anchor, "TOP", 0, 2)
		else
			cb:SetPoint("TOPLEFT", _G.ChatFrame1, "TOPLEFT", -32, 0)
		end
		SkinButton(cb, cfg.buttons.copy, cfg.buttons.size, cfg.buttons.texture_size)
		cb:SetScript("OnClick", function()
			local frame = (SELECTED_DOCK_FRAME) or DEFAULT_CHAT_FRAME
			self:ShowCopyWindow(frame)
		end)
		cb:SetScript("OnEnter", function(b)
			GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
			GameTooltip:AddLine(L["Copy chat"])
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
		cb:Show()
		self.copyButton = cb
	end

	-- style the edit box: remove Blizzard's textured border, leave it transparent
	local editbox = _G[name .. "EditBox"]
	if editbox and not editbox._duiStyled then
		editbox._duiStyled = true
		-- hide the default left/right/mid border textures
		for _, part in ipairs({ "Left", "Right", "Mid" }) do
			local region = _G[name .. "EditBox" .. part]
			if region then region:SetTexture(nil) end
		end
		-- no backdrop at all -> fully transparent input line
		editbox:SetBackdrop(nil)
		-- position it as a tidy bar BELOW the chat frame, matching its width
		editbox:ClearAllPoints()
		editbox:SetHeight(26)
		editbox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -6)
		editbox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -6)
	end
end

-- Applies the dark background alpha to all chat frames.
Module.UpdateBackground = function(self)
	local a = self.db.style.bg_alpha or 0.5
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame" .. i]
		if frame and frame._duiBG then
			frame._duiBG:SetVertexColor(0, 0, 0, a)
		end
	end
end

-- Shows/hides the chat buttons (up/down/bottom + menu + friends).
Module.UpdateButtons = function(self)
	local show = self.db.style.show_buttons

	-- a parking frame for fully hiding the friends button
	if not self._hider then
		self._hider = CreateFrame("Frame")
		self._hider:Hide()
	end

	for i = 1, NUM_CHAT_WINDOWS do
		local name = "ChatFrame" .. i
		for _, suffix in ipairs({ "ButtonFrameUpButton", "ButtonFrameDownButton", "ButtonFrameBottomButton" }) do
			local b = _G[name .. suffix]
			if b then
				if show then b:Show() else b:Hide() end
			end
		end
	end

	if ChatFrameMenuButton then
		if show then ChatFrameMenuButton:Show() else ChatFrameMenuButton:Hide() end
	end

	if self.copyButton then
		if show then self.copyButton:Show() else self.copyButton:Hide() end
	end
end

-- Hides/shows the top FriendsMicroButton (the "Social" button).
-- We only toggle visibility -- its OnClick script is reused by the action bar's
-- own social button, so we must NOT remove or break it.
Module.UpdateFriendsButton = function(self)
	if not FriendsMicroButton then return end
	if not self._friendsHider then
		self._friendsHider = CreateFrame("Frame")
		self._friendsHider:Hide()
	end
	if self.db.style.hide_friends_button then
		FriendsMicroButton:Hide()
		FriendsMicroButton:SetAlpha(0)
		FriendsMicroButton:EnableMouse(false)
		FriendsMicroButton:SetParent(self._friendsHider)
	else
		FriendsMicroButton:SetParent(UIParent)
		FriendsMicroButton:SetAlpha(1)
		FriendsMicroButton:EnableMouse(true)
		FriendsMicroButton:Show()
	end
end

-- Re-applies all live style settings.
Module.ApplyStyle = function(self)
	if not self.db.style.enabled then return end
	self:UpdateBackground()
	self:UpdateButtons()
	self:UpdateFriendsButton()
end

-- ======================================================================
-- Copy window: shows the current chat frame's contents for copy/paste
-- ======================================================================

-- Builds (once) the centered copy window with a scrollable multiline editbox.
Module.CreateCopyWindow = function(self)
	if self.copyWindow then return self.copyWindow end

	local f = CreateFrame("Frame", "DiabolicUIChatCopyWindow", UIParent)
	f:SetSize(600, 400)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop({
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background-Dark]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 }
	})
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()

	-- title
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("DiabolicUI - " .. (COPY or "Copy"))

	-- close button
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	-- hint
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOM", 0, 14)

	-- scroll + multiline editbox
	local scroll = CreateFrame("ScrollFrame", "DiabolicUIChatCopyScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -40)
	scroll:SetPoint("BOTTOMRIGHT", -32, 36)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(540)
	edit:SetAutoFocus(false)
	edit:EnableMouse(true)
	edit:SetScript("OnEscapePressed", function() f:Hide() end)
	scroll:SetScrollChild(edit)

	f.editBox = edit
	f.hint = hint
	self.copyWindow = f
	return f
end

-- Collects the current chat frame's visible lines as a single string.
-- Colors are KEPT for on-screen readability; WoW strips the |cff..|r codes
-- automatically when the user copies text out of a multiline edit box.
Module.GetChatText = function(self, chatFrame)
	chatFrame = chatFrame or DEFAULT_CHAT_FRAME
	local lines = {}
	local num = chatFrame:GetNumMessages() or 0
	for i = 1, num do
		local msg = chatFrame:GetMessageInfo(i)
		if msg then
			lines[#lines + 1] = msg
		end
	end
	return table.concat(lines, "\n")
end

-- Opens the copy window filled with the given (or default) chat frame.
Module.ShowCopyWindow = function(self, chatFrame)
	local win = self:CreateCopyWindow()
	local text = self:GetChatText(chatFrame)
	win.editBox:SetText(text)
	win.hint:SetText((HIGHLIGHT_FONT_COLOR_CODE or "") .. "Ctrl+A, Ctrl+C" .. "|r")
	win:Show()
	win.editBox:SetCursorPosition(0)
	-- scroll to bottom so the latest messages are visible
	local sb = _G["DiabolicUIChatCopyScrollScrollBar"]
	if sb then sb:SetValue(sb:GetMinMaxValues() and select(2, sb:GetMinMaxValues()) or 0) end
end

Module.OnInit = function(self)
	self.db = self:GetConfig("Chat", "character")
	self.config = self:GetStaticConfig("Chat")
end

Module.OnEnable = function(self)
	-- hook all existing chat windows for timestamps
	for i = 1, NUM_CHAT_WINDOWS do
		self:HookChatFrame(_G["ChatFrame" .. i])
	end

	-- hook temporary windows (whispers, etc.) as they're created
	if FCF_OpenTemporaryWindow then
		hooksecurefunc("FCF_OpenTemporaryWindow", function()
			for i = 1, NUM_CHAT_WINDOWS do
				self:HookChatFrame(_G["ChatFrame" .. i])
			end
		end)
	end

	-- apply dark Diablo styling
	if self.db.style.enabled then
		for i = 1, NUM_CHAT_WINDOWS do
			self:StyleChatFrame(_G["ChatFrame" .. i], i)
		end
		self:ApplyStyle()
	end
end

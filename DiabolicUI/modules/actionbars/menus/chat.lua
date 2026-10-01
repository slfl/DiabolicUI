local _, Engine = ...
local Module = Engine:GetModule("ActionBars")
local MenuWidget = Module:SetWidget("Menu: Chat")
local L = Engine:GetLocale()


-- Lua API
local setmetatable = setmetatable

-- WoW API
local CreateFrame = CreateFrame
local GetTime = GetTime
local sin, pi = math.sin, math.pi

-- "smouldering" new-message glow on the Chat button (tune to taste)
local GLOW_COLOR  = { 1, .45, .1 }   -- ember tint, additive over the button art
local GLOW_MIN    = .15              -- alpha at the dim end of the pulse
local GLOW_MAX    = .85              -- alpha at the bright end
local GLOW_PERIOD = 1.4              -- seconds per full pulse
local ICON_WARM   = { 1, .78, .45 }  -- icon tint at the bright end
local CONTOUR_PAD = 6                -- how far the glowing outline sits outside the button
local COUNT_SIZE  = 20               -- unread counter font size
local COUNT_COLOR = { 1, .82, .2 }   -- unread counter color (Diablo gold)


MenuWidget.Skin = function(self, button, config, icon)
	local icon_config = Module.config.visuals.menus.icons

	button.Normal = button:CreateTexture(nil, "BORDER")
	button.Normal:ClearAllPoints()
	button.Normal:SetPoint(unpack(config.button.texture_position))
	button.Normal:SetSize(unpack(config.button.texture_size))
	button.Normal:SetTexture(config.button.textures.normal)
	
	button.Pushed = button:CreateTexture(nil, "BORDER")
	button.Pushed:Hide()
	button.Pushed:ClearAllPoints()
	button.Pushed:SetPoint(unpack(config.button.texture_position))
	button.Pushed:SetSize(unpack(config.button.texture_size))
	button.Pushed:SetTexture(config.button.textures.pushed)

	button.Icon = button:CreateTexture(nil, "OVERLAY")
	button.Icon:SetSize(unpack(icon_config.size))
	button.Icon:SetPoint(unpack(icon_config.position))
	button.Icon:SetAlpha(icon_config.alpha)
	button.Icon:SetTexture(icon_config.texture)
	button.Icon:SetTexCoord(unpack(icon_config.texcoords[icon]))
	
	local position = icon_config.position
	local position_pushed = icon_config.pushed.position
	local alpha = icon_config.alpha
	local alpha_pushed = icon_config.pushed.alpha

	button.OnButtonState = function(self, state, lock)
		if state == "PUSHED" then
			self.Pushed:Show()
			self.Normal:Hide()
			self.Icon:ClearAllPoints()
			self.Icon:SetPoint(unpack(position_pushed))
			self.Icon:SetAlpha(alpha_pushed)
		else
			self.Normal:Show()
			self.Pushed:Hide()
			self.Icon:ClearAllPoints()
			self.Icon:SetPoint(unpack(position))
			self.Icon:SetAlpha(alpha)
		end
	end
	hooksecurefunc(button, "SetButtonState", button.OnButtonState)

	button:SetHitRectInsets(0, 0, 0, 0)
	button:OnButtonState(button:GetButtonState())
end

MenuWidget.OnEnable = function(self)
	local config = Module.config
	local db = Module.db

	local Menu = Module:GetWidget("Controller: Chat"):GetFrame()
	local MenuButton = Module:GetWidget("Template: MenuButton")
	local FlyoutBar = Module:GetWidget("Template: FlyoutBar")
	local InputBox = ChatFrame1EditBox
	local FriendsButton = FriendsMicroButton
	local FriendsWindow = FriendsFrame

	-- config table shortcuts
	local chat_menu_config = config.structure.controllers.chatmenu
	local input_config = config.visuals.menus.chat.input
	local menu_config = config.visuals.menus.chat.menu

	-- Main Buttons
	---------------------------------------------
	local ChatButton = MenuButton:New(Menu)
	ChatButton:SetPoint("BOTTOMLEFT")
	ChatButton:SetFrameStrata("MEDIUM")
	ChatButton:SetFrameLevel(50) -- get it above the actionbars
	ChatButton:SetSize(unpack(input_config.button.size))

	self:Skin(ChatButton, input_config, "chat")

	-- New-message glow: a copy of the button's own art in additive blend, so the
	-- glow follows the stone frame exactly; pulsed by a sine while active.
	local glow = ChatButton:CreateTexture(nil, "ARTWORK")
	glow:SetPoint(unpack(input_config.button.texture_position))
	glow:SetSize(unpack(input_config.button.texture_size))
	glow:SetTexture(input_config.button.textures.normal)
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3])
	glow:SetAlpha(0)
	ChatButton.Glow = glow

	-- Glowing outline: the addon's shared UI glow backdrop (same art as the
	-- tooltip / aura highlights), tinted ember, around the button.
	local contour = CreateFrame("Frame", nil, ChatButton)
	contour:SetPoint("TOPLEFT", ChatButton, "TOPLEFT", -CONTOUR_PAD, CONTOUR_PAD)
	contour:SetPoint("BOTTOMRIGHT", ChatButton, "BOTTOMRIGHT", CONTOUR_PAD, -CONTOUR_PAD)
	contour:SetFrameLevel(ChatButton:GetFrameLevel() + 2)
	local ui = Engine:GetStaticConfig("UI")
	local glowBackdrop = ui and ui.backdrops and ui.backdrops.glow and ui.backdrops.glow.backdrop
	if glowBackdrop then
		contour:SetBackdrop(glowBackdrop)
		contour:SetBackdropBorderColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3])
	end
	contour:SetAlpha(0)
	ChatButton.Contour = contour

	-- Unread counter in the middle of the button, above the icon.
	local badge = CreateFrame("Frame", nil, ChatButton)
	badge:SetAllPoints(ChatButton)
	badge:SetFrameLevel(ChatButton:GetFrameLevel() + 3)
	local count = badge:CreateFontString(nil, "OVERLAY")
	local Fonts = Engine:GetModule("Fonts", true)
	local countFont = Fonts and Fonts.fonts and Fonts.fonts.header_normal
	if countFont then count:SetFont(countFont, COUNT_SIZE, "OUTLINE") end
	if not count:GetFont() then   -- font missing / failed to load: use a stock object
		count:SetFontObject(NumberFontNormalLarge or GameFontNormalLarge)
	end
	count:SetPoint("CENTER", ChatButton.Icon, "CENTER", 0, 0)
	count:SetTextColor(COUNT_COLOR[1], COUNT_COLOR[2], COUNT_COLOR[3])
	count:Hide()
	ChatButton.Count = count

	-- one sine drives every enabled layer, so they pulse in sync
	local pulse = CreateFrame("Frame", nil, ChatButton)
	pulse:Hide()
	pulse.style = "art"
	pulse:SetScript("OnUpdate", function(f)
		local k = .5 + .5 * sin(GetTime() * 2 * pi / GLOW_PERIOD)   -- 0..1
		local a = GLOW_MIN + (GLOW_MAX - GLOW_MIN) * k
		local art = (f.style == "art" or f.style == "both")
		local border = (f.style == "border" or f.style == "both")
		glow:SetAlpha(art and a or 0)
		contour:SetAlpha(border and a or 0)
		if art then
			ChatButton.Icon:SetVertexColor(1 + (ICON_WARM[1] - 1) * k, 1 + (ICON_WARM[2] - 1) * k, 1 + (ICON_WARM[3] - 1) * k)
		else
			ChatButton.Icon:SetVertexColor(1, 1, 1)
		end
	end)
	pulse:SetScript("OnHide", function()
		glow:SetAlpha(0)
		contour:SetAlpha(0)
		ChatButton.Icon:SetVertexColor(1, 1, 1)
	end)
	ChatButton.Pulse = pulse
	
	-- Button state follows the input line's FOCUS, not its visibility: with the
	-- "IM" chat style the line stays shown after a message is sent. An unfocused
	-- line is hidden one frame later (classic-style behaviour), so it can't pop up
	-- when the chat is shown again. The delay lets Show() -> SetFocus() finish.
	local unfocusedCheck = CreateFrame("Frame")
	unfocusedCheck:Hide()
	unfocusedCheck:SetScript("OnUpdate", function(f)
		f:Hide()
		if InputBox:IsShown() and not InputBox:HasFocus() then
			InputBox:Hide()
		end
	end)
	InputBox:HookScript("OnEditFocusGained", function() ChatButton:SetButtonState("PUSHED", 1) end)
	InputBox:HookScript("OnEditFocusLost", function()
		ChatButton:SetButtonState("NORMAL")
		unfocusedCheck:Show()
	end)
	InputBox:HookScript("OnShow", function() unfocusedCheck:Show() end)
	InputBox:HookScript("OnHide", function() ChatButton:SetButtonState("NORMAL") end)



	local SocialButton = MenuButton:New(Menu)
	SocialButton:SetPoint("BOTTOMLEFT", ChatButton, "BOTTOMRIGHT", chat_menu_config.padding, 0 )
	SocialButton:SetFrameStrata("MEDIUM")
	SocialButton:SetFrameLevel(50) -- get it above the actionbars
	SocialButton:SetSize(unpack(input_config.button.size))
	self:Skin(SocialButton, input_config, "group")

	
	FriendsWindow:HookScript("OnShow", function() SocialButton:SetButtonState("PUSHED", 1) end)
	FriendsWindow:HookScript("OnHide", function() SocialButton:SetButtonState("NORMAL") end)

	ChatButton.OnEnter = function(self) 
		if ChatButton:GetButtonState() == "PUSHED"
		or SocialButton:GetButtonState() == "PUSHED" then
			GameTooltip:Hide()
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 6, 16)
		GameTooltip:AddLine(L["Chat"])
		local Chat = Engine:GetModule("Chat", true)
		if Chat and Chat.HasNotification and Chat:HasNotification() then
			GameTooltip:AddLine(L["New messages:"] .. " " .. table.concat(Chat:GetNotifySenders(), ", "), 1, .82, 0, true)
		end
		if Chat and Chat.IsAutoHideActive and Chat:IsAutoHideActive() then
			GameTooltip:AddLine(L["<Left-click> to show or hide the chat."], 0, .7, 0)
			GameTooltip:AddLine(L["<Right-click> to write a message."], 0, .7, 0)
		else
			GameTooltip:AddLine(L["<Left-click> or <Enter> to chat."], 0, .7, 0)
		end
		GameTooltip:Show()
	end
	ChatButton:SetScript("OnEnter", ChatButton.OnEnter)
	ChatButton:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
	
	ChatButton.OnClick = function(self, button)
		-- with chat auto-hide on, left-click toggles the chat itself;
		-- right-click (or auto-hide off) keeps the classic "open input line"
		if button == "LeftButton" then
			local Chat = Engine:GetModule("Chat", true)
			if Chat and Chat.ToggleChatVisibility and Chat:ToggleChatVisibility() then
				self:OnEnter()
				return
			end
		end
		if InputBox:IsShown() and InputBox:HasFocus() then
			if ChatEdit_OnEscapePressed then
				ChatEdit_OnEscapePressed(InputBox)
			else
				InputBox:ClearFocus()
			end
			InputBox:Hide()
		elseif ChatFrame_OpenChat then
			ChatFrame_OpenChat("")
		else
			InputBox:Show()
			InputBox:SetFocus()
		end
		if button == "LeftButton" then
			self:OnEnter() -- update tooltips
		end
	end
	ChatButton:SetAttribute("_onclick", [[ control:CallMethod("OnClick", button); ]])

	
	
	
	SocialButton.OnEnter = function(self) 
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 6, 16)
		GameTooltip:AddLine(L["Friends & Guild"])
		GameTooltip:AddLine(L["<Left-click> to toggle social frames."], 0, .7, 0)
		GameTooltip:Show()
	end
	SocialButton:SetScript("OnEnter", SocialButton.OnEnter)
	SocialButton:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
	
	SocialButton.OnClick = FriendsMicroButton:GetScript("OnClick")
	SocialButton:SetAttribute("_onclick", [[ control:CallMethod("OnClick", button); ]])

	-- exposed so the "show menu buttons" option can keep the Chat button alone
	self.ChatButton = ChatButton
	self.SocialButton = SocialButton

	local Chat = Engine:GetModule("Chat", true)
	if Chat then
		local wasActive = false
		Chat.onNotifyChanged = function(active, n)
			local style, showCount = Chat:GetNotifyStyle()
			pulse.style = style
			if active then pulse:Show() else pulse:Hide() end
			if active and showCount and (n or 0) > 0 then
				count:SetText((n > 99) and "99+" or tostring(n))
				count:Show()
			else
				count:Hide()
			end
			-- a hidden Chat button pops up while it has news (deferred in combat)
			if active ~= wasActive then
				wasActive = active
				if Module.UpdateButtonsVisibility then Module:UpdateButtonsVisibility() end
			end
			if GameTooltip:IsOwned(ChatButton) then ChatButton:OnEnter() end
		end
	end

end

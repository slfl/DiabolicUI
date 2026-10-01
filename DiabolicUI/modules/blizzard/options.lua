local _, Engine = ...
local Module = Engine:NewModule("Options", "LOW")
local L = Engine:GetLocale()

-- WoW API
local CreateFrame = CreateFrame
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory

-- Lua API
local floor = math.floor

-- Creates a single labelled checkbox tied to a boolean setting.
--   parent   : the options panel frame
--   name     : unique global-ish frame name suffix
--   label    : text shown next to the box
--   tooltip  : hover description (optional)
--   get      : function() -> boolean   (reads current value)
--   set      : function(checked)        (writes new value + applies live)
--   anchorTo : frame to anchor below (or nil for first item)
local function CreateCheckbox(parent, name, label, tooltip, get, set, anchorTo)
	local check = CreateFrame("CheckButton", "DiabolicUIOptions"..name, parent, "InterfaceOptionsCheckButtonTemplate")

	if anchorTo then
		check:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -8)
	else
		check:SetPoint("TOPLEFT", 16, -8)
	end

	local text = _G[check:GetName().."Text"]
	text:SetText(label)

	check.tooltipText = tooltip

	check:SetScript("OnShow", function(self)
		self:SetChecked(get() and true or false)
	end)

	check:SetScript("OnClick", function(self)
		local checked = self:GetChecked() and true or false
		set(checked)
	end)

	return check
end

-- Creates a labelled slider tied to a numeric setting.
--   parent    : the options panel
--   name      : unique frame name suffix
--   label     : text above the slider
--   tooltip   : hover description
--   minV,maxV : value range
--   step      : step increment
--   get       : function() -> number
--   set       : function(value) -> applies live
--   fmt       : function(value) -> string (shown under the slider)
--   anchorTo  : frame to anchor below
local function CreateSlider(parent, name, label, tooltip, minV, maxV, step, get, set, fmt, anchorTo)
	local slider = CreateFrame("Slider", "DiabolicUIOptions"..name, parent, "OptionsSliderTemplate")
	slider:SetWidth(200)

	if anchorTo then
		slider:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 4, -24)
	else
		slider:SetPoint("TOPLEFT", 20, -80)
	end

	_G[slider:GetName().."Text"]:SetText(label)
	_G[slider:GetName().."Low"]:SetText(tostring(minV))
	_G[slider:GetName().."High"]:SetText(tostring(maxV))
	slider.tooltipText = tooltip

	slider:SetMinMaxValues(minV, maxV)
	slider:SetValueStep(step)
	slider:SetValue(get())

	-- current value text under the slider
	local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	valueText:SetPoint("TOP", slider, "BOTTOM", 0, 2)
	valueText:SetText(fmt(get()))

	slider:SetScript("OnValueChanged", function(self, value)
		-- snap to step
		value = floor((value / step) + 0.5) * step
		valueText:SetText(fmt(value))
		set(value)
	end)

	slider:SetScript("OnShow", function(self)
		self:SetValue(get())
		valueText:SetText(fmt(get()))
	end)

	return slider
end

-- Creates a labelled dropdown tied to a value setting.
--   parent   : content frame
--   name     : unique suffix
--   label    : text above the dropdown
--   options  : ordered list of { value = ..., text = ... }
--   get      : function() -> current value
--   set      : function(value) -> applies live
--   anchorTo : frame to anchor below
local function CreateDropdown(parent, name, label, options, get, set, anchorTo, rightOf)
	local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	if rightOf then
		-- place this dropdown's label to the right of another dropdown's label
		labelText:SetPoint("TOPLEFT", rightOf.labelText, "TOPLEFT", 180, 0)
	elseif anchorTo then
		-- align with the checkbox labels above (their text starts ~+4 from frame)
		labelText:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 4, -14)
	else
		labelText:SetPoint("TOPLEFT", 20, -14)
	end
	labelText:SetText(label)

	local dd = CreateFrame("Frame", "DiabolicUIOptions"..name, parent, "UIDropDownMenuTemplate")
	-- UIDropDownMenuTemplate has ~16px of built-in left padding, so pull it left
	-- by that amount to line the visible box up with the label.
	dd:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", -16, -2)

	local function refreshText()
		local cur = get()
		for _, opt in ipairs(options) do
			if opt.value == cur then
				UIDropDownMenu_SetText(dd, opt.text)
				return
			end
		end
	end

	UIDropDownMenu_Initialize(dd, function(self, level)
		for _, opt in ipairs(options) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = opt.text
			info.value = opt.value
			info.func = function()
				set(opt.value)
				UIDropDownMenu_SetText(dd, opt.text)
			end
			info.checked = (opt.value == get())
			UIDropDownMenu_AddButton(info, level)
		end
	end)
	UIDropDownMenu_SetWidth(dd, 120)
	refreshText()

	dd.labelText = labelText
	return dd, labelText
end

-- Creates a child options panel registered under the main DiabolicUI category.
local function CreateSubPanel(nameKey, title)
	local p = CreateFrame("Frame", "DiabolicUIOptions"..nameKey, UIParent)
	p.name = title
	p.parent = "DiabolicUI"

	local heading = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", 16, -16)
	heading:SetText(title)
	p.heading = heading

	return p
end

-- Wraps a panel in a scroll frame and returns the scroll content frame.
local function MakeScrollable(panel, topAnchor)
	local scroll = CreateFrame("ScrollFrame", panel:GetName().."Scroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, -12)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 16)

	local content = CreateFrame("Frame", panel:GetName().."Content", scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)
	scroll:SetScript("OnSizeChanged", function(f, w, h) content:SetWidth(w) end)
	return content
end

Module.OnEnable = function(self)
	-- ==============================================================
	-- MAIN PANEL: just the DiabolicUI logo
	-- ==============================================================
	local panel = CreateFrame("Frame", "DiabolicUIOptionsPanel", UIParent)
	panel.name = "DiabolicUI"

	local logo = panel:CreateTexture(nil, "ARTWORK")
	logo:SetTexture([[Interface\AddOns\DiabolicUI\media\textures\ui\DiabolicUI_Logo.tga]])
	-- logo art is 1024x512 (2:1); show it at a tidy size, centered near the top
	logo:SetSize(384, 192)
	logo:SetPoint("TOP", panel, "TOP", 0, -40)

	local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	ver:SetPoint("TOP", logo, "BOTTOM", 0, -8)
	ver:SetText("v2.0")

	InterfaceOptions_AddCategory(panel)
	self.panel = panel

	-- ==============================================================
	-- SUB-PANEL: Command Bar (FPS, coords, buttons, class orb)
	-- ==============================================================
	local cmd = CreateSubPanel("CommandBar", L["Command bar"])
	local cmdContent = MakeScrollable(cmd, cmd.heading)

	local perf = CreateCheckbox(cmdContent, "Performance",
		L["Show FPS and latency"],
		L["Toggles the performance readout (frames per second and latency) on the micro menu."],
		function() return Engine:GetConfig("UI", "character").show_performance end,
		function(checked)
			Engine:GetConfig("UI", "character").show_performance = checked
			local ActionBars = Engine:GetModule("ActionBars", true)
			if ActionBars and ActionBars.UpdatePerformanceVisibility then ActionBars:UpdatePerformanceVisibility() end
		end, nil)

	local coords = CreateCheckbox(cmdContent, "Coordinates",
		L["Show player coordinates"],
		L["Shows your map coordinates in the lower-left corner."],
		function() return Engine:GetConfig("UI", "character").show_coordinates end,
		function(checked)
			Engine:GetConfig("UI", "character").show_coordinates = checked
			local ActionBars = Engine:GetModule("ActionBars", true)
			if ActionBars and ActionBars.UpdateCoordinatesVisibility then ActionBars:UpdateCoordinatesVisibility() end
		end, perf)

	local buttons = CreateCheckbox(cmdContent, "ShowButtons",
		L["Show menu buttons"],
		L["Shows the menu, bags, chat and friends buttons. Turn off for a cleaner interface."],
		function() return Engine:GetConfig("UI", "character").show_buttons end,
		function(checked)
			Engine:GetConfig("UI", "character").show_buttons = checked
			local ActionBars = Engine:GetModule("ActionBars", true)
			if ActionBars and ActionBars.UpdateButtonsVisibility then ActionBars:UpdateButtonsVisibility() end
		end, coords)

	local chatbtn = CreateCheckbox(cmdContent, "HideChatButton",
		L["Hide chat button"],
		L["Hide chat button tip"],
		function() return Engine:GetConfig("UI", "character").hide_chat_button ~= false end,
		function(checked)
			Engine:GetConfig("UI", "character").hide_chat_button = checked
			local ActionBars = Engine:GetModule("ActionBars", true)
			if ActionBars and ActionBars.UpdateButtonsVisibility then ActionBars:UpdateButtonsVisibility() end
		end, buttons)

	local classcolor = CreateCheckbox(cmdContent, "ClassHealthColor",
		L["Class colored health orb"],
		L["Colors the player health orb using your class color instead of the default red."],
		function() return Engine:GetConfig("UI", "character").class_health_color end,
		function(checked)
			Engine:GetConfig("UI", "character").class_health_color = checked
			local UnitFrames = Engine:GetModule("UnitFrames", true)
			if UnitFrames and UnitFrames.RefreshHealthColor then UnitFrames:RefreshHealthColor() end
		end, chatbtn)

	local classcolorpet = CreateCheckbox(cmdContent, "ClassHealthColorPet",
		L["Also color the pet health orb"],
		L["Also colors the pet health orb using your class color."],
		function() return Engine:GetConfig("UI", "character").class_health_color_pet end,
		function(checked)
			Engine:GetConfig("UI", "character").class_health_color_pet = checked
			local UnitFrames = Engine:GetModule("UnitFrames", true)
			if UnitFrames and UnitFrames.RefreshHealthColor then UnitFrames:RefreshHealthColor() end
		end, classcolor)
	classcolorpet:SetPoint("TOPLEFT", classcolor, "BOTTOMLEFT", 16, -8)

	-- decorative angel/demon side artwork
	local artwork = CreateCheckbox(cmdContent, "ShowArtwork",
		L["Show artwork"],
		L["Shows the decorative angel and demon artwork on the sides of the command bar."],
		function() return Engine:GetConfig("UI", "character").show_artwork end,
		function(checked)
			Engine:GetConfig("UI", "character").show_artwork = checked
			local ActionBars = Engine:GetModule("ActionBars", true)
			if ActionBars and ActionBars.UpdateArtworkVisibility then ActionBars:UpdateArtworkVisibility() end
		end, classcolorpet)
	artwork:SetPoint("TOPLEFT", classcolorpet, "BOTTOMLEFT", -16, -8)

	-- orb value display mode
	local resources = CreateDropdown(cmdContent, "ResourceDisplay",
		L["Show resources"],
		{
			{ value = "always", text = L["Always"] },
			{ value = "combat", text = L["In combat only"] },
			{ value = "never",  text = L["Never"] },
		},
		function() return Engine:GetConfig("UI", "character").resource_display end,
		function(v)
			Engine:GetConfig("UI", "character").resource_display = v
			local UnitFrames = Engine:GetModule("UnitFrames", true)
			if UnitFrames and UnitFrames.RefreshResourceDisplay then UnitFrames:RefreshResourceDisplay() end
		end,
		artwork)

	-- vehicle seat frame: label + a lock/unlock button to drag it into place
	local vehLabel = cmdContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	vehLabel:SetPoint("TOPLEFT", resources, "BOTTOMLEFT", 0, -24)
	vehLabel:SetText(L["Vehicle frame"])

	local vehButton = CreateFrame("Button", "DiabolicUIVehicleMoveButton", cmdContent, "UIPanelButtonTemplate")
	vehButton:SetSize(160, 24)
	vehButton:SetPoint("LEFT", vehLabel, "RIGHT", 12, 0)
	local function refreshVehButton()
		local V = Engine:GetModule("Vehicle", true)
		if V and V:IsUnlocked() then
			vehButton:SetText(L["Lock"])
		else
			vehButton:SetText(L["Unlock"])
		end
	end
	vehButton:SetScript("OnClick", function()
		local V = Engine:GetModule("Vehicle", true)
		if not V then return end
		V:SetUnlocked(not V:IsUnlocked())
		refreshVehButton()
	end)
	refreshVehButton()

	-- durability frame: label + a lock/unlock button to drag it into place
	local durabLabel = cmdContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	durabLabel:SetPoint("TOPLEFT", vehLabel, "BOTTOMLEFT", 0, -24)
	durabLabel:SetText(L["Durability frame"])

	local durabButton = CreateFrame("Button", "DiabolicUIDurabilityMoveButton", cmdContent, "UIPanelButtonTemplate")
	durabButton:SetSize(160, 24)
	durabButton:SetPoint("LEFT", durabLabel, "RIGHT", 12, 0)
	local function refreshDurabButton()
		local D = Engine:GetModule("DurabilityFrame", true)
		if D and D:IsUnlocked() then
			durabButton:SetText(L["Lock"])
		else
			durabButton:SetText(L["Unlock"])
		end
	end
	durabButton:SetScript("OnClick", function()
		local D = Engine:GetModule("DurabilityFrame", true)
		if not D then return end
		D:SetUnlocked(not D:IsUnlocked())
		refreshDurabButton()
	end)
	refreshDurabButton()

	-- objectives tracker: label + a lock/unlock button to drag it into place
	local trackLabel = cmdContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	trackLabel:SetPoint("TOPLEFT", durabLabel, "BOTTOMLEFT", 0, -24)
	trackLabel:SetText(L["Objectives tracker"])

	local trackButton = CreateFrame("Button", "DiabolicUITrackerMoveButton", cmdContent, "UIPanelButtonTemplate")
	trackButton:SetSize(160, 24)
	trackButton:SetPoint("LEFT", trackLabel, "RIGHT", 12, 0)
	local function refreshTrackButton()
		local T = Engine:GetModule("ObjectivesTracker", true)
		if T and T:IsTrackerUnlocked() then
			trackButton:SetText(L["Lock"])
		else
			trackButton:SetText(L["Unlock"])
		end
	end
	trackButton:SetScript("OnClick", function()
		local T = Engine:GetModule("ObjectivesTracker", true)
		if not T then return end
		T:SetTrackerUnlocked(not T:IsTrackerUnlocked())
		refreshTrackButton()
	end)
	refreshTrackButton()

	-- XP/rep bar: what text to show on the bar when not hovered
	local xpText = CreateDropdown(cmdContent, "XPBarText",
		L["XP bar text"],
		{
			{ value = "off",     text = L["Hidden"] },
			{ value = "percent", text = L["Percent"] },
			{ value = "text",    text = L["Numbers"] },
			{ value = "both",    text = L["Numbers and percent"] },
		},
		function()
			return Engine:GetConfig("UI", "character").xp_text_mode or "percent"
		end,
		function(v)
			Engine:GetConfig("UI", "character").xp_text_mode = v
			local AB = Engine:GetModule("ActionBars", true)
			local w = AB and AB.GetWidget and AB:GetWidget("Bar: XP")
			if w and w.UpdateBar then w:UpdateBar() end
		end,
		trackLabel)

	-- full vs abbreviated numbers on the XP/rep bar and its tooltip
	local xpFull = CreateCheckbox(cmdContent, "XPBarFullNumbers",
		L["Full numbers"], L["Full numbers tip"],
		function() return Engine:GetConfig("UI", "character").xp_full_numbers ~= false end,
		function(c)
			Engine:GetConfig("UI", "character").xp_full_numbers = c
			local AB = Engine:GetModule("ActionBars", true)
			local w = AB and AB.GetWidget and AB:GetWidget("Bar: XP")
			if w and w.UpdateBar then w:UpdateBar() end
		end,
		xpText)

	cmdContent:SetHeight(680)
	InterfaceOptions_AddCategory(cmd)

	-- ==============================================================
	-- SUB-PANEL: Minimap
	-- ==============================================================
	local mm = CreateSubPanel("MinimapPanel", L["Minimap"])
	local mmContent = MakeScrollable(mm, mm.heading)

	local function mmdb() return Engine:GetConfig("Minimap", "character") end
	local function applyMinimap()
		local Minimap = Engine:GetModule("Minimap", true)
		if Minimap and Minimap.ApplySettings then Minimap:ApplySettings() end
	end

	local minimap = CreateCheckbox(mmContent, "CustomMinimap",
		L["Custom minimap"],
		L["Shows the custom square minimap. Turn off to use another minimap addon. Requires a relog to take effect."],
		function() return mmdb().enabled end,
		function(checked)
			mmdb().enabled = checked
			print("|cff4488ffDiabolicUI:|r "..L["The minimap change will take effect after your next relog."])
		end, nil)

	local clock24 = CreateCheckbox(mmContent, "Clock24",
		L["24-hour clock"],
		L["Use a 24-hour clock (15:55) instead of 12-hour (3:55 PM)."],
		function() return mmdb().use24hrClock end,
		function(checked) mmdb().use24hrClock = checked; applyMinimap() end,
		minimap)
	clock24:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 16, -8)

	local localTime = CreateCheckbox(mmContent, "LocalTime",
		L["Use local time"],
		L["Show your computer's local time instead of the server time."],
		function() return mmdb().use_local_time end,
		function(checked) mmdb().use_local_time = checked; applyMinimap() end,
		clock24)

	local dateFormat = CreateDropdown(mmContent, "DateFormat",
		L["Date format"],
		{
			{ value = "d",   text = L["Day only"] },
			{ value = "dm",  text = L["Day and month"] },
			{ value = "dmy", text = L["Day, month and year"] },
		},
		function() return mmdb().date_format end,
		function(v) mmdb().date_format = v; applyMinimap() end,
		localTime)

	local dateSep = CreateDropdown(mmContent, "DateSeparator",
		L["Date separator"],
		{
			{ value = ".", text = L["Dot (.)"] },
			{ value = ":", text = L["Colon (:)"] },
			{ value = "/", text = L["Slash (/)"] },
		},
		function() return mmdb().date_separator end,
		function(v) mmdb().date_separator = v; applyMinimap() end,
		clock24, dateFormat)

	local mmButtons = CreateCheckbox(mmContent, "MinimapButtons",
		L["Show addon buttons"],
		L["Show the collapsible addon-button holder under the minimap."],
		function() return mmdb().show_buttons end,
		function(checked) mmdb().show_buttons = checked; applyMinimap() end,
		dateFormat)
	mmButtons:SetPoint("TOPLEFT", dateFormat, "BOTTOMLEFT", 12, -10)

	local shade = CreateCheckbox(mmContent, "MinimapShade",
		L["Show vignette"],
		L["Show a dark vignette overlay on the minimap."],
		function() return mmdb().show_shade end,
		function(checked) mmdb().show_shade = checked; applyMinimap() end,
		mmButtons)
	shade:SetPoint("TOPLEFT", mmButtons, "BOTTOMLEFT", 0, -8)

	local shadeSlider = CreateSlider(mmContent, "MinimapShadeAlpha",
		L["Vignette strength"],
		L["Adjust the vignette opacity."],
		0, 1, 0.05,
		function() return mmdb().shade_alpha end,
		function(v) mmdb().shade_alpha = v; applyMinimap() end,
		function(v) return ("%d%%"):format(v * 100) end,
		shade)

	local alphaSlider = CreateSlider(mmContent, "MinimapAlpha",
		L["Minimap opacity"],
		L["Adjust the overall minimap opacity."],
		0, 1, 0.25,
		function() return mmdb().map_alpha end,
		function(v) mmdb().map_alpha = v; applyMinimap() end,
		function(v) return ("%d%%"):format(v * 100) end,
		shadeSlider)

	mmContent:SetHeight(520)
	InterfaceOptions_AddCategory(mm)

	-- ==============================================================
	-- SUB-PANEL: Chat (timestamp settings)
	-- ==============================================================
	local chat = CreateSubPanel("ChatPanel", L["Chat"])
	local chatContent = MakeScrollable(chat, chat.heading)

	local function chdb() return Engine:GetConfig("Chat", "character").timestamp end
	local function chstyle2() return Engine:GetConfig("Chat", "character").style end

	-- Master switch: enhanced chat styling (applies on relog)
	local enhanced = CreateCheckbox(chatContent, "EnhancedChat",
		L["Enhanced chat"],
		L["Applies the dark Diablo chat styling, buttons and copy window. Requires a relog to take effect."],
		function() return chstyle2().enabled end,
		function(checked)
			chstyle2().enabled = checked
			print("|cff4488ffDiabolicUI:|r "..L["The chat change will take effect after your next relog."])
		end,
		nil)

	local ts_enabled = CreateCheckbox(chatContent, "ChatTimestamp",
		L["Show message timestamp"],
		L["Shows the time before each chat message."],
		function() return chdb().enabled end,
		function(checked) chdb().enabled = checked end,
		enhanced)

	local ts_format = CreateDropdown(chatContent, "ChatTimestampFormat",
		L["Timestamp format"],
		{
			{ value = "HH:MM",    text = "15:55" },
			{ value = "HH:MM:SS", text = "15:55:30" },
		},
		function() return chdb().format end,
		function(v) chdb().format = v end,
		ts_enabled)

	local ts_brackets = CreateCheckbox(chatContent, "ChatTimestampBrackets",
		L["Wrap time in brackets"],
		L["Wraps the timestamp in square brackets, e.g. [15:55]."],
		function() return chdb().brackets end,
		function(checked) chdb().brackets = checked end,
		ts_format)
	ts_brackets:SetPoint("TOPLEFT", ts_format, "BOTTOMLEFT", 16, -12)

	local ts_note = chatContent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	ts_note:SetPoint("TOPLEFT", ts_brackets, "BOTTOMLEFT", 0, -14)
	ts_note:SetText(L["Timestamp changes apply to new messages."])

	-- style helpers
	local function chstyle() return Engine:GetConfig("Chat", "character").style end
	local function applyChatStyle()
		local Chat = Engine:GetModule("Chat", true)
		if Chat and Chat.ApplyStyle then Chat:ApplyStyle() end
	end

	-- show/hide chat buttons
	local ch_buttons = CreateCheckbox(chatContent, "ChatShowButtons",
		L["Show chat buttons"],
		L["Shows the up / down / bottom scroll buttons on the chat window."],
		function() return chstyle().show_buttons end,
		function(checked) chstyle().show_buttons = checked; applyChatStyle() end,
		nil)
	ch_buttons:SetPoint("TOPLEFT", ts_note, "BOTTOMLEFT", 0, -20)

	-- hide the top friends ("Social") button
	local ch_friends = CreateCheckbox(chatContent, "ChatHideFriends",
		L["Hide friends button"],
		L["Hides the friends (Social) button above the chat. The one by the input line stays."],
		function() return chstyle().hide_friends_button end,
		function(checked) chstyle().hide_friends_button = checked; applyChatStyle() end,
		ch_buttons)

	-- dark background strength slider
	local ch_bg = CreateSlider(chatContent, "ChatBgAlpha",
		L["Background darkness"],
		L["Adjust the darkness of the chat background."],
		0, 1, 0.05,
		function() return chstyle().bg_alpha end,
		function(v) chstyle().bg_alpha = v; applyChatStyle() end,
		function(v) return ("%d%%"):format(v * 100) end,
		ch_friends)

	-- inactivity auto-hide / auto-fade
	local function chah() return Engine:GetConfig("Chat", "character").autohide end
	local function applyAutoHide()
		local Chat = Engine:GetModule("Chat", true)
		if Chat and Chat.RefreshAutoHide then Chat:RefreshAutoHide() end
	end

	local ah_enabled = CreateCheckbox(chatContent, "ChatAutoHide",
		L["Auto-hide chat"], L["Auto-hide chat tip"],
		function() return chah().enabled end,
		function(c) chah().enabled = c; applyAutoHide() end,
		nil)
	ah_enabled:SetPoint("TOPLEFT", ch_bg, "BOTTOMLEFT", 0, -28)

	local ah_mode = CreateDropdown(chatContent, "ChatAutoHideMode",
		L["Auto-hide mode"],
		{
			{ value = "fade", text = L["Make transparent"] },
			{ value = "hide", text = L["Hide completely"] },
		},
		function() return chah().mode end,
		function(v) chah().mode = v; applyAutoHide() end,
		ah_enabled)
	UIDropDownMenu_SetWidth(ah_mode, 180)

	local ah_delay = CreateSlider(chatContent, "ChatAutoHideDelay",
		L["Inactivity delay"], L["Inactivity delay tip"],
		5, 120, 5,
		function() return chah().delay end,
		function(v) chah().delay = v; applyAutoHide() end,
		function(v) return ("%d"):format(v) end,
		ah_mode)

	local ah_alpha = CreateSlider(chatContent, "ChatAutoHideAlpha",
		L["Faded opacity"], L["Faded opacity tip"],
		0.05, 0.9, 0.05,
		function() return chah().alpha end,
		function(v) chah().alpha = v; applyAutoHide() end,
		function(v) return ("%d%%"):format(v * 100) end,
		ah_delay)

	-- glowing Chat button on new messages while the chat is hidden/faded
	local function chnotify()
		local a = chah()
		if type(a.notify) ~= "table" then a.notify = {} end
		local n = a.notify
		if n.enabled == nil then n.enabled = true end
		if n.style == nil then n.style = "art" end
		return n
	end
	-- re-paint the button right away (style / counter changes)
	local function applyNotify()
		local Chat = Engine:GetModule("Chat", true)
		if Chat and Chat.FireNotifyChanged then Chat:FireNotifyChanged() end
	end

	local nt_enabled = CreateCheckbox(chatContent, "ChatNotify",
		L["Notify on new messages"], L["Notify on new messages tip"],
		function() return chnotify().enabled ~= false end,
		function(c) chnotify().enabled = c; applyNotify() end,
		nil)
	nt_enabled:SetPoint("TOPLEFT", ah_alpha, "BOTTOMLEFT", -4, -28)

	local nt_style = CreateDropdown(chatContent, "ChatNotifyStyle",
		L["Glow style"],
		{
			{ value = "art",    text = L["Smouldering button"] },
			{ value = "border", text = L["Glowing outline"] },
			{ value = "both",   text = L["Button and outline"] },
		},
		function() return chnotify().style end,
		function(v) chnotify().style = v; applyNotify() end,
		nt_enabled)
	UIDropDownMenu_SetWidth(nt_style, 180)

	local nt_count = CreateCheckbox(chatContent, "ChatNotifyCount",
		L["Show message count"], L["Show message count tip"],
		function() return chnotify().count end,
		function(c) chnotify().count = c; applyNotify() end,
		nt_style)

	local nt_guild = CreateCheckbox(chatContent, "ChatNotifyGuild",
		L["Also guild messages"], L["Also guild messages tip"],
		function() return chnotify().guild end,
		function(c) chnotify().guild = c end,
		nt_count)

	local nt_group = CreateCheckbox(chatContent, "ChatNotifyGroup",
		L["Also party and raid messages"], L["Also party and raid messages tip"],
		function() return chnotify().group end,
		function(c) chnotify().group = c end,
		nt_guild)

	local nt_channel = CreateCheckbox(chatContent, "ChatNotifyChannel",
		L["Also public channels"], L["Also public channels tip"],
		function() return chnotify().channel end,
		function(c) chnotify().channel = c end,
		nt_group)

	chatContent:SetHeight(980)
	InterfaceOptions_AddCategory(chat)

	-- ==============================================================
	-- SUB-PANEL: Battlefield (world state / capture bar)
	-- ==============================================================
	local bf = CreateSubPanel("BattlefieldPanel", L["Battlefield"])
	local bfContent = MakeScrollable(bf, bf.heading)

	local function bfdb() return Engine:GetConfig("UI", "character") end
	local function applyBf()
		local WS = Engine:GetModule("WorldState", true)
		if WS and WS.RefreshWorldState then WS:RefreshWorldState() end
	end

	local bf_enabled = CreateCheckbox(bfContent, "WorldStateEnabled",
		L["Show battlefield status"],
		L["Shows the battlefield status text (bases, victory points) to the left of the minimap."],
		function() return bfdb().worldstate_enabled end,
		function(checked) bfdb().worldstate_enabled = checked; applyBf() end,
		nil)

	local bf_bar = CreateCheckbox(bfContent, "WorldStateCaptureBar",
		L["Show capture bar"],
		L["Shows the capture-point bar with the sliding Alliance / Horde indicator."],
		function() return bfdb().worldstate_capturebar end,
		function(checked) bfdb().worldstate_capturebar = checked; applyBf() end,
		bf_enabled)

	local bf_color = CreateCheckbox(bfContent, "WorldStateFactionColor",
		L["Color text by faction"],
		L["Colors the status text blue for Alliance and red for Horde."],
		function() return bfdb().worldstate_faction_color end,
		function(checked) bfdb().worldstate_faction_color = checked; applyBf() end,
		bf_bar)

	bfContent:SetHeight(260)
	InterfaceOptions_AddCategory(bf)

	-- ==============================================================
	-- SUB-PANEL: Fonts (combat text font)
	-- ==============================================================
	StaticPopupDialogs["DIABOLICUI_COMBATFONT_RELOG"] = {
		text = L["Combat font relog notice"],
		button1 = L["Log out now"],
		button2 = L["Later"],
		OnAccept = function() Logout() end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		preferredIndex = 3,
	}

	local fontp = CreateSubPanel("FontsPanel", L["Fonts"])
	local fontContent = MakeScrollable(fontp, fontp.heading)

	local function fontsModule() return Engine:GetModule("Fonts", true) end
	local function fontCfg()
		local F = fontsModule()
		return F and F:GetCombatFontSettings() or {}
	end
	-- apply live (scrolling combat text) and tell the user a relog is needed
	local function fontChanged()
		local F = fontsModule()
		if F then F:ApplyCombatFont() end
		StaticPopup_Show("DIABOLICUI_COMBATFONT_RELOG")
	end

	local f_enabled = CreateCheckbox(fontContent, "CombatFontEnabled",
		L["Custom combat text font"], L["Custom combat text font tip"],
		function() return fontCfg().enabled end,
		function(c)
			if fontCfg().enabled == c then return end
			fontCfg().enabled = c
			fontChanged()
		end, nil)

	local fontOptions = {}
	do
		local F = fontsModule()
		if F then
			for _, f in ipairs(F:GetCombatFontList()) do
				fontOptions[#fontOptions + 1] = { value = f.value, text = f.text }
			end
		end
	end
	local f_font = CreateDropdown(fontContent, "CombatFontFace",
		L["Combat text font"], fontOptions,
		function() return fontCfg().font end,
		function(v)
			if fontCfg().font == v then return end
			fontCfg().font = v
			fontChanged()
		end,
		f_enabled)
	UIDropDownMenu_SetWidth(f_font, 180)

	fontContent:SetHeight(200)
	InterfaceOptions_AddCategory(fontp)

	-- ==============================================================
	-- SUB-PANEL: Away mode (AFK)
	-- ==============================================================
	local afkp = CreateSubPanel("AwayMode", L["Away mode"])
	local afkContent = MakeScrollable(afkp, afkp.heading)

	local function afkCfg()
		local M = Engine:GetModule("AFK", true)
		return M and M:GetSettings() or {}
	end
	local function afkApply()
		local M = Engine:GetModule("AFK", true)
		if M and M.Refresh then M:Refresh() end
	end

	local a_enabled = CreateCheckbox(afkContent, "AFKEnabled",
		L["Enable away screen"], L["Enable away screen tip"],
		function() return afkCfg().enabled end,
		function(c) afkCfg().enabled = c; afkApply() end, nil)

	local a_orbit = CreateCheckbox(afkContent, "AFKOrbit",
		L["Orbit the camera"], L["Orbit the camera tip"],
		function() return afkCfg().orbit end,
		function(c) afkCfg().orbit = c; afkApply() end, a_enabled)

	local a_camspeed = CreateSlider(afkContent, "AFKCamSpeed",
		L["Camera orbit speed"], L["Camera orbit speed tip"],
		0.01, 0.15, 0.005,
		function() return afkCfg().cam_speed end,
		function(v) afkCfg().cam_speed = v; afkApply() end,
		function(v) return string.format("%.3f", v) end, a_orbit)

	local a_model = CreateCheckbox(afkContent, "AFKShowModel",
		L["Show player model"], L["Show player model tip"],
		function() return afkCfg().show_model end,
		function(c) afkCfg().show_model = c; afkApply() end, a_camspeed)

	local a_rotate = CreateCheckbox(afkContent, "AFKRotateModel",
		L["Rotate the model"], L["Rotate the model tip"],
		function() return afkCfg().rotate_model end,
		function(c) afkCfg().rotate_model = c; afkApply() end, a_model)

	local a_mspeed = CreateSlider(afkContent, "AFKModelSpeed",
		L["Model rotation speed"], L["Model rotation speed tip"],
		0.1, 3.0, 0.1,
		function() return afkCfg().model_speed end,
		function(v) afkCfg().model_speed = v; afkApply() end,
		function(v) return string.format("%.1f", v) end, a_rotate)

	local a_msize = CreateSlider(afkContent, "AFKModelSize",
		L["Model size"], L["Model size tip"],
		120, 600, 10,
		function() return afkCfg().model_size end,
		function(v) afkCfg().model_size = v; afkApply() end,
		function(v) return tostring(floor(v)) end, a_mspeed)

	local a_mangle = CreateSlider(afkContent, "AFKModelAngle",
		L["Model angle"], L["Model angle tip"],
		0, 6.2, 0.1,
		function() return afkCfg().model_facing end,
		function(v) afkCfg().model_facing = v; afkApply() end,
		function(v) return string.format("%.1f", v) end, a_msize)

	local a_name = CreateCheckbox(afkContent, "AFKShowName",
		L["Show name"], L["Show name tip"],
		function() return afkCfg().show_name end,
		function(c) afkCfg().show_name = c; afkApply() end, a_mangle)

	local a_level = CreateCheckbox(afkContent, "AFKShowLevel",
		L["Show level"], L["Show level tip"],
		function() return afkCfg().show_level end,
		function(c) afkCfg().show_level = c; afkApply() end, a_name)

	local a_guild = CreateCheckbox(afkContent, "AFKShowGuild",
		L["Show guild"], L["Show guild tip"],
		function() return afkCfg().show_guild end,
		function(c) afkCfg().show_guild = c; afkApply() end, a_level)

	local a_hint = CreateCheckbox(afkContent, "AFKShowHint",
		L["Show hint"], L["Show hint tip"],
		function() return afkCfg().show_hint end,
		function(c) afkCfg().show_hint = c; afkApply() end, a_guild)

	local a_whisper = CreateCheckbox(afkContent, "AFKShowWhispers",
		L["Show whispers"], L["Show whispers tip"],
		function() return afkCfg().show_whispers end,
		function(c) afkCfg().show_whispers = c; afkApply() end, a_hint)

	afkContent:SetHeight(680)
	InterfaceOptions_AddCategory(afkp)

	-- ==============================================================
	-- SUB-PANEL: About
	-- ==============================================================
	local about = CreateSubPanel("About", L["About"])
	local ay = -60
	local function AboutLine(labelKey, value, color)
		local row = about:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row:SetPoint("TOPLEFT", 32, ay)
		row:SetText(labelKey)
		local val = about:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		val:SetPoint("LEFT", row, "LEFT", 110, 0)
		val:SetText(value)
		if color then val:SetTextColor(color[1], color[2], color[3]) end
		ay = ay - 26
	end

	local aboutTitle = about:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	aboutTitle:SetPoint("TOPLEFT", 16, -44)
	aboutTitle:SetText(L["A Diablo-style UI modification."])

	AboutLine(L["Version"], "v2.0")
	AboutLine(L["Author"], "Mansi")
	AboutLine(L["Original"], "Lars Norberg")
	AboutLine(L["Category"], L["Interface"])
	AboutLine(L["License"], L["Free / open"])
	AboutLine(L["Email"], "slfl@mail.ru", { .3, .6, 1 })
	AboutLine(L["Client"], "WotLK 3.3.5a")

	InterfaceOptions_AddCategory(about)
end

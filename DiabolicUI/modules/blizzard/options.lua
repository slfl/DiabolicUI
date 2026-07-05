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

Module.OnEnable = function(self)
	local panel = CreateFrame("Frame", "DiabolicUIOptionsPanel", UIParent)
	panel.name = "DiabolicUI"

	-- Title
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("DiabolicUI")

	-- Subtitle
	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	sub:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
	sub:SetJustifyH("LEFT")
	sub:SetText(L["Additional interface options."])

	-- Scrollable content area (so all the options fit on smaller screens)
	local scroll = CreateFrame("ScrollFrame", "DiabolicUIOptionsScroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 16)

	local content = CreateFrame("Frame", "DiabolicUIOptionsContent", scroll)
	content:SetSize(1, 1) -- height grows as we anchor controls; width set below
	scroll:SetScrollChild(content)
	-- match content width to the scroll viewport
	scroll:SetScript("OnSizeChanged", function(f, w, h)
		content:SetWidth(w)
	end)

	-- all controls below are parented to `content` instead of `panel`
	local panel_content = content

	-- Checkbox: FPS / latency readout
	local perf = CreateCheckbox(
		panel_content,
		"Performance",
		L["Show FPS and latency"],
		L["Toggles the performance readout (frames per second and latency) on the micro menu."],
		function()
			return Engine:GetConfig("UI", "character").show_performance
		end,
		function(checked)
			Engine:GetConfig("UI", "character").show_performance = checked
			-- apply immediately if the action bars module is ready
			local ActionBars = Engine:GetModule("ActionBars", true)
			if ActionBars and ActionBars.UpdatePerformanceVisibility then
				ActionBars:UpdatePerformanceVisibility()
			end
		end,
		nil
	)

	-- Checkbox: player coordinates
	local coords = CreateCheckbox(
		panel_content,
		"Coordinates",
		L["Show player coordinates"],
		L["Shows your map coordinates in the lower-left corner."],
		function()
			return Engine:GetConfig("UI", "character").show_coordinates
		end,
		function(checked)
			Engine:GetConfig("UI", "character").show_coordinates = checked
			local ActionBars = Engine:GetModule("ActionBars", true)
			if ActionBars and ActionBars.UpdateCoordinatesVisibility then
				ActionBars:UpdateCoordinatesVisibility()
			end
		end,
		perf
	)

	-- Checkbox: menu / bags / chat / friends buttons
	local buttons = CreateCheckbox(
		panel_content,
		"ShowButtons",
		L["Show menu buttons"],
		L["Shows the menu, bags, chat and friends buttons. Turn off for a cleaner interface."],
		function()
			return Engine:GetConfig("UI", "character").show_buttons
		end,
		function(checked)
			Engine:GetConfig("UI", "character").show_buttons = checked
			local ActionBars = Engine:GetModule("ActionBars", true)
			if ActionBars and ActionBars.UpdateButtonsVisibility then
				ActionBars:UpdateButtonsVisibility()
			end
		end,
		coords
	)

	-- Checkbox: class-colored health orb
	local classcolor = CreateCheckbox(
		panel_content,
		"ClassHealthColor",
		L["Class colored health orb"],
		L["Colors the player health orb using your class color instead of the default red."],
		function()
			return Engine:GetConfig("UI", "character").class_health_color
		end,
		function(checked)
			Engine:GetConfig("UI", "character").class_health_color = checked
			local UnitFrames = Engine:GetModule("UnitFrames", true)
			if UnitFrames and UnitFrames.RefreshHealthColor then
				UnitFrames:RefreshHealthColor()
			end
		end,
		buttons
	)

	-- Sub-option: also color the pet health orb
	local classcolorpet = CreateCheckbox(
		panel_content,
		"ClassHealthColorPet",
		L["Also color the pet health orb"],
		L["Also colors the pet health orb using your class color."],
		function()
			return Engine:GetConfig("UI", "character").class_health_color_pet
		end,
		function(checked)
			Engine:GetConfig("UI", "character").class_health_color_pet = checked
			local UnitFrames = Engine:GetModule("UnitFrames", true)
			if UnitFrames and UnitFrames.RefreshHealthColor then
				UnitFrames:RefreshHealthColor()
			end
		end,
		classcolor
	)
	-- indent the sub-option slightly to show it belongs to the one above
	classcolorpet:SetPoint("TOPLEFT", classcolor, "BOTTOMLEFT", 16, -8)

	-- Checkbox: custom minimap on/off
	local minimap = CreateCheckbox(
		panel_content,
		"CustomMinimap",
		L["Custom minimap"],
		L["Shows the custom square minimap. Turn off to use another minimap addon. Requires a relog to take effect."],
		function()
			return Engine:GetConfig("Minimap", "character").enabled
		end,
		function(checked)
			Engine:GetConfig("Minimap", "character").enabled = checked
			print("|cff4488ffDiabolicUI:|r "..L["The minimap change will take effect after your next relog."])
		end,
		classcolorpet
	)
	-- reset the indent (this one is a top-level option again)
	minimap:SetPoint("TOPLEFT", classcolorpet, "BOTTOMLEFT", -16, -8)

	-- helper: minimap config + live apply
	local function mmdb() return Engine:GetConfig("Minimap", "character") end
	local function applyMinimap()
		local Minimap = Engine:GetModule("Minimap", true)
		if Minimap and Minimap.ApplySettings then Minimap:ApplySettings() end
	end

	-- Sub: 24-hour clock
	local clock24 = CreateCheckbox(
		panel_content, "Clock24",
		L["24-hour clock"],
		L["Use a 24-hour clock (15:55) instead of 12-hour (3:55 PM)."],
		function() return mmdb().use24hrClock end,
		function(checked) mmdb().use24hrClock = checked; applyMinimap() end,
		minimap
	)
	clock24:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 16, -8)

	-- Sub: date format dropdown (day / day.month / day.month.year)
	local dateFormat = CreateDropdown(
		panel_content, "DateFormat",
		L["Date format"],
		{
			{ value = "d",   text = L["Day only"] },
			{ value = "dm",  text = L["Day and month"] },
			{ value = "dmy", text = L["Day, month and year"] },
		},
		function() return mmdb().date_format end,
		function(v) mmdb().date_format = v; applyMinimap() end,
		clock24
	)

	-- Sub: date separator dropdown (dot / colon / slash)
	local dateSep = CreateDropdown(
		panel_content, "DateSeparator",
		L["Date separator"],
		{
			{ value = ".", text = L["Dot (.)"] },
			{ value = ":", text = L["Colon (:)"] },
			{ value = "/", text = L["Slash (/)"] },
		},
		function() return mmdb().date_separator end,
		function(v) mmdb().date_separator = v; applyMinimap() end,
		clock24, dateFormat  -- anchorTo (unused when rightOf set), rightOf = beside date format
	)
	-- anchor following controls below the date format dropdown (left column)
	local dateSlash = dateFormat

	-- Sub: show addon buttons
	local mmButtons = CreateCheckbox(
		panel_content, "MinimapButtons",
		L["Show addon buttons"],
		L["Show the collapsible addon-button holder under the minimap."],
		function() return mmdb().show_buttons end,
		function(checked) mmdb().show_buttons = checked; applyMinimap() end,
		dateSlash
	)
	mmButtons:SetPoint("TOPLEFT", dateSlash, "BOTTOMLEFT", 12, -10)

	-- Sub: show vignette
	local shade = CreateCheckbox(
		panel_content, "MinimapShade",
		L["Show vignette"],
		L["Show a dark vignette overlay on the minimap."],
		function() return mmdb().show_shade end,
		function(checked) mmdb().show_shade = checked; applyMinimap() end,
		mmButtons
	)
	shade:SetPoint("TOPLEFT", mmButtons, "BOTTOMLEFT", 0, -8)

	-- Sub: vignette strength slider
	local shadeSlider = CreateSlider(
		panel_content, "MinimapShadeAlpha",
		L["Vignette strength"],
		L["Adjust the vignette opacity."],
		0, 1, 0.05,
		function() return mmdb().shade_alpha end,
		function(v) mmdb().shade_alpha = v; applyMinimap() end,
		function(v) return ("%d%%"):format(v * 100) end,
		shade
	)

	-- Sub: minimap opacity slider (5 steps 0..100)
	local alphaSlider = CreateSlider(
		panel_content, "MinimapAlpha",
		L["Minimap opacity"],
		L["Adjust the overall minimap opacity."],
		0, 1, 0.25,
		function() return mmdb().map_alpha end,
		function(v) mmdb().map_alpha = v; applyMinimap() end,
		function(v) return ("%d%%"):format(v * 100) end,
		shadeSlider
	)

	-- Give the scroll content enough height to hold everything, so the
	-- scrollbar appears and all options are reachable.
	content:SetHeight(860)

	-- Register the panel in the Interface -> AddOns list
	InterfaceOptions_AddCategory(panel)

	self.panel = panel
end

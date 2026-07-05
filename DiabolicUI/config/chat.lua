local Addon, Engine = ...
local path = ([[Interface\AddOns\%s\media\]]):format(Addon)
local tex = path .. [[textures\chat\]]

-- Saved (per-character-able) settings
local db = {
	timestamp = {
		enabled = true,       -- show a timestamp before each message
		format = "HH:MM",     -- "HH:MM" or "HH:MM:SS"
		brackets = true,      -- wrap the time in [ ]
		use_custom_color = false,
		color = { 0.5, 0.5, 0.5 } -- default grey
	},
	style = {
		enabled = true,       -- apply the dark Diablo styling
		bg_alpha = 0.5,       -- dark background strength (0..1)
		show_buttons = true,  -- show the up/down/menu chat buttons
		hide_friends_button = false -- hide the top "Social" (friends) micro button
	}
}

-- Static layout config
local config = {
	buttons = {
		size = { 32, 32 },
		texture_size = { 32, 32 },
		menu = {
			normal    = tex .. [[DiabolicUI_ChatButtons_36x36_ChatMenu.tga]],
			highlight = tex .. [[DiabolicUI_ChatButtons_36x36_ChatMenuHighlight.tga]],
			disabled  = tex .. [[DiabolicUI_ChatButtons_36x36_ChatMenuDisabled.tga]]
		},
		up = {
			normal    = tex .. [[DiabolicUI_ChatButtons_36x36_Up.tga]],
			highlight = tex .. [[DiabolicUI_ChatButtons_36x36_UpHighlight.tga]],
			disabled  = tex .. [[DiabolicUI_ChatButtons_36x36_UpDisabled.tga]]
		},
		down = {
			normal    = tex .. [[DiabolicUI_ChatButtons_36x36_Down.tga]],
			highlight = tex .. [[DiabolicUI_ChatButtons_36x36_DownHighlight.tga]],
			disabled  = tex .. [[DiabolicUI_ChatButtons_36x36_DownDisabled.tga]]
		},
		bottom = {
			normal    = tex .. [[DiabolicUI_ChatButtons_36x36_Bottom.tga]],
			highlight = tex .. [[DiabolicUI_ChatButtons_36x36_BottomHighlight.tga]],
			disabled  = tex .. [[DiabolicUI_ChatButtons_36x36_BottomDisabled.tga]]
		},
		copy = {
			normal    = tex .. [[DiabolicUI_ChatButtons_36x36_Maximize.tga]],
			highlight = tex .. [[DiabolicUI_ChatButtons_36x36_MaximizeHighlight.tga]],
			disabled  = tex .. [[DiabolicUI_ChatButtons_36x36_MaximizeDisabled.tga]]
		}
	},
	background = {
		texture = [[Interface\ChatFrame\ChatFrameBackground]]
	},
	editbox = {
		backdrop = {
			bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
			edgeFile = [[Interface\ChatFrame\ChatFrameBackground]],
			edgeSize = 1,
			insets = { left = 0, right = 0, top = 0, bottom = 0 }
		},
		border_alpha = 0.4 -- subtle border relative to the background alpha
	}
}

Engine:NewStaticConfig("Chat", config)
Engine:NewConfig("Chat", db)

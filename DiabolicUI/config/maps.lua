local Addon, Engine = ...
local path = ([[Interface\AddOns\%s\media\]]):format(Addon)

-- Saved (per-character-able) settings
local db = {
	useGameTime = false,
	use24hrClock = true
}

-- Static layout config
local config = {
	-- overall holder size
	size = { 240, 240 },
	-- NOTE: the anchor frame is resolved in code (UICenter = Engine:GetFrame()),
	-- so we store only point/offsets here, not the frame reference.
	point = { "TOPRIGHT", 0, -33 },

	-- the actual map surface
	map = {
		size = { 204, 204 },
		point = { "TOPLEFT", 18, -18 },
		-- a plain white texture used as a SQUARE mask, so the map renders square
		mask = [[Interface\ChatFrame\ChatFrameBackground]]
	},

	-- dark vignette overlaid on the whole map (Diablo-style)
	shade = {
		texture = path .. [[textures\auras\DiabolicUI_Shade_64x64.tga]],
		alpha = 0.5
	},

	-- simple border around the square map
	border = {
		size = 2,
		color = { 0, 0, 0, 1 },
		backdrop_color = { 0, 0, 0, 0 }
	},

	-- texts above the map, right-aligned (Diablo 3 style)
	text = {
		-- current zone name (top line, large)
		zone = {
			point = { "BOTTOMRIGHT", "map", "TOPRIGHT", 0, 10 },
			font = { path = path .. [[fonts\ExocetBlizzardLight.ttf]], size = 18, style = "" },
			shadow = { offset = { -.75, -.75 }, color = { 0, 0, 0, 1 } }
		},
		-- character name (level) + local time, one line under the zone
		info = {
			point = { "BOTTOMRIGHT", "map", "TOPRIGHT", 0, -14 },
			font = { path = path .. [[fonts\DejaVuSansCondensed.ttf]], size = 13, style = "" },
			shadow = { offset = { -.75, -.75 }, color = { 0, 0, 0, 1 } }
		},
		colors = {
			sanctuary = { .41, .8, .94 },
			friendly = { 64/255, 175/255, 38/255 },
			hostile = { 175/255, 76/255, 56/255 },
			contested = { 229/255, 159/255, 28/255 },
			combat = { 175/255, 76/255, 56/255 },
			normal = { 255/255, 234/255, 137/255 }, -- default zone / info
			unknown = { 1, .9294, .7607 }
		}
	},

	-- collapsible holder for third-party addon minimap buttons
	buttons = {
		-- frames that our name patterns miss but should still be collected.
		-- add the exact frame name here to force-collect a button.
		whitelist = {
			"HealBot_MMButton",
			"HealBBGButton",
			"HealBBg",
			"HealBotMinimapButton",
		},
		-- the expand/collapse toggle button (bottom-right of the map)
		toggle = {
			size = { 22, 21 },
			point = { "TOPRIGHT", "map", "BOTTOMRIGHT", 0, -9 },
			texture = path .. [[textures\objectives\DiabolicUI_ExpandCollapseButton_22x21.tga]],
			texture_disabled = path .. [[textures\objectives\DiabolicUI_ExpandCollapseButton_22x21_Disabled.tga]],
			-- the main texture is a 64x64 atlas of four states; each quadrant's
			-- content spans pixels 1..31 x 1..30 (a ~30x29 button)
			texcoords = {
				collapsed_normal = { 1/64, 31/64, 1/64, 30/64 },   -- top-left
				collapsed_hover  = { 33/64, 63/64, 1/64, 30/64 },  -- top-right
				expanded_normal  = { 1/64, 31/64, 33/64, 62/64 },  -- bottom-left
				expanded_hover   = { 33/64, 63/64, 33/64, 62/64 }  -- bottom-right
			},
			-- disabled texture is 32x32 with content at 1..31 x 1..30
			texcoord_disabled = { 1/32, 31/32, 1/32, 30/32 }
		},
		-- each collected addon button is wrapped in this border, laid out to the
		-- LEFT of the toggle button
		icon = {
			slot = 30,        -- visible slot size (borders touch at this width)
			icon = 20,        -- the addon icon inside the border
			texture_scale = 64/37, -- border art is 64px but visible frame is ~37px
			padding = 0,
			border = path .. [[textures\actionbars\DiabolicUI_Button_36x36_Border.tga]]
		}
	}
}

Engine:NewStaticConfig("Minimap", config)
Engine:NewConfig("Minimap", db)

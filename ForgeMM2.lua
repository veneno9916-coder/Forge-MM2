--[[
    FORGE MM2 v2.0 - Murder Mystery 2 utility panel (single file, client-side)

    Tabs     : ESP | Aim | Combat | Move | World | Safety | Cosmetics | Players | Misc | Visuals | Trade | Tracker | Weather
    Controls : RightShift = show/hide menu | End (configurable) = PANIC (restore everything + destroy GUI)
               Aim = hold Right-Click / Q / on-screen AIM button / hold screen (touch)
    Roles    : Murderer = carries "Knife", Sheriff = carries "Gun", everyone else = Innocent
    Notes    : Silent Aim needs an executor with hookmetamethod/newcclosure (the menu shows if it is available).
               Several features (silent aim, auto-shoot, reach) depend on how MM2 reads input / registers hits
               and may stop working after a game update.
]]

--// Bootstrap: wait for the game, player and camera before building anything
do
	if not game:IsLoaded() then game.Loaded:Wait() end
	local plrs = game:GetService("Players")
	while not plrs.LocalPlayer do task.wait() end
	local t0 = os.clock()
	while not workspace.CurrentCamera and os.clock() - t0 < 10 do task.wait() end
end

local __ok, __err = xpcall(function()

--// Services
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local Lighting         = game:GetService("Lighting")
local StarterGui       = game:GetService("StarterGui")
local TextChatService  = game:GetService("TextChatService")

local LP   = Players.LocalPlayer

--// Single-instance guard
local ENV = (getgenv and getgenv()) or _G
if ENV.ForgeMM2 and ENV.ForgeMM2.Unload then
	pcall(ENV.ForgeMM2.Unload)
end

--// Theme ---------------------------------------------------------------
local THEME = {
	Bg      = Color3.fromRGB(8, 8, 10),
	Panel   = Color3.fromRGB(22, 22, 25),
	Off     = Color3.fromRGB(48, 48, 53),
	Accent  = Color3.fromRGB(245, 245, 245),
	Accent2 = Color3.fromRGB(110, 110, 118),
	Text    = Color3.fromRGB(240, 240, 244),
	Sub     = Color3.fromRGB(140, 140, 148),
	White   = Color3.fromRGB(255, 255, 255),
}

local PRESETS = {
	["Monochrome"]   = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(110, 110, 118) },
	["Cyber Cyan"]   = { Color3.fromRGB(0, 229, 255),  Color3.fromRGB(150, 90, 255) },
	["Neon Orange"]  = { Color3.fromRGB(255, 128, 0),  Color3.fromRGB(255, 45, 110) },
	["Matrix Green"] = { Color3.fromRGB(0, 255, 95),   Color3.fromRGB(0, 130, 60) },
	["Deep Purple"]  = { Color3.fromRGB(165, 95, 255), Color3.fromRGB(80, 40, 210) },
	["Blood Red"]    = { Color3.fromRGB(255, 40, 55),  Color3.fromRGB(130, 0, 20) },
}
local PRESET_ORDER = { "Monochrome", "Cyber Cyan", "Neon Orange", "Matrix Green", "Deep Purple", "Blood Red" }
local CurrentTheme = "Monochrome"

local ROLE_COLORS = {
	Murderer = Color3.fromRGB(255, 50, 50),
	Sheriff  = Color3.fromRGB(50, 150, 255),
	Innocent = Color3.fromRGB(50, 255, 100),
}

--// Config ----------------------------------------------------------------
local Config = {
	ESP    = { Murderer = false, Sheriff = false, Gun = false, Tracers = false, Toast = true, Chat = false },
	Aim    = { Enabled = false, Speed = 12, Prediction = false, PredictionTime = 0.1, TouchHold = true },
	Silent = { Enabled = false, FOV = 120, ShowFOV = true },
	Auto   = { Enabled = false, Radius = 60, WallCheck = true },
	Hitbox = { Enabled = false, Size = 8, Target = "Murderer" },
	Reach  = { Enabled = false, Size = 10, Tool = "Knife" },
	Move   = {
		WalkEnabled = false, WalkSpeed = 32, JumpEnabled = false, JumpPower = 80,
		InfJump = false, Noclip = false, AutoGun = false, ReturnAfter = true,
	},
	Kill   = { Enabled = false, Delay = 0.3, Return = true },
	World  = { Fullbright = false, NoFog = false, FPS = false },
	AntiAim = { Enabled = false }, -- rotates your character so aim-predicting players/bots are thrown off
	Cosmetic = { Trail = false, KillFX = false, KillSoundId = "" },
	Spectate = { Enabled = false, Target = "Murderer" },
	Watch   = { Enabled = false, AutoHop = false },
	System  = { AntiAFK = false },
	UI      = { HopButton = true },
	Visual  = {
		Enabled = false, Preset = "Off", Bloom = 1.2, Contrast = 0.2, Saturation = 0.1, Blur = 0,
		Scanlines = false, Aberration = false, Vignette = false,
		Shadows = "Default", Sky = "Off", SkyId = "",
	},
	Trade   = { Mine = "", Theirs = "", Values = "", Margin = 10 },
	Tracker = { HUD = true, Weight = 0.5 },
	Weather = {
		Type = "Off", Intensity = 1, Wind = 0, Audio = true, Volume = 0.5,
		IdRain = "", IdSnow = "", IdBlossoms = "", IdEmbers = "", IdLofi = "",
	},
	Dodge   = { Enabled = false, Range = 16, Distance = 9, Cooldown = 0.7, Jump = true, Thrown = true },
	Extras  = {
		XRay = false, XRayAlpha = 0.7,
		DeathCam = false,
		Profiler = false,
		Lead = false, LeadTime = 0.15,
		KnifePath = false, Chime = true,
		AutoDodge = false, DodgeMode = "Smart", DodgeWindow = 0.4,
		DodgeBullets = false, EvadeAim = false, AimAngle = 8,
		AutoThrow = false, ThrowRange = 60, ThrowCooldown = 1.5, KnifeSpeed = 100,
		ThrowStable = true, PingComp = 1.0,
		RoundTimer = false, TimerServer = true, TimerWarn = 30, TimerAlert = true,
	},
}

local MENU_KEYS = { "RightShift", "RightAlt", "F4", "Backquote" }
local MenuKey = Enum.KeyCode.RightShift

local AIM_KEY = Enum.KeyCode.Q
local PANIC_KEYS = { "End", "Delete", "Insert", "RightControl" }
local PanicKey = Enum.KeyCode.End

--// Helpers -----------------------------------------------------------------
local Connections = {}
local function track(conn)
	Connections[#Connections + 1] = conn
	return conn
end

-- Dot-path get/set on the Config table, used by the save/load config system below
local function getPath(tbl, path)
	local cur = tbl
	for key in path:gmatch("[^.]+") do
		if type(cur) ~= "table" then return nil end
		cur = cur[key]
	end
	return cur
end
local function setPath(tbl, path, value)
	local keys = {}
	for key in path:gmatch("[^.]+") do keys[#keys + 1] = key end
	local cur = tbl
	for i = 1, #keys - 1 do
		if type(cur[keys[i]]) ~= "table" then return end
		cur = cur[keys[i]]
	end
	cur[keys[#keys]] = value
end
-- UI controls register themselves here (path -> setter) so Load Config can refresh the menu
local ControlRegistry = {}

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function tween(obj, time, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, color, transparency, thickness)
	return new("UIStroke", {
		Color = color, Transparency = transparency, Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- Theme registry: any element that uses the accent registers a refresher here
local ThemeHooks = {}
local function onTheme(fn)
	ThemeHooks[#ThemeHooks + 1] = fn
	fn()
end
local function themed(inst, prop, key)
	onTheme(function() inst[prop] = THEME[key] end)
end
local function applyTheme(name)
	local p = PRESETS[name]
	if not p then return end
	CurrentTheme = name
	THEME.Accent, THEME.Accent2 = p[1], p[2]
	for _, fn in ipairs(ThemeHooks) do pcall(fn) end
end

local function resolveGuiParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and typeof(h) == "Instance" then return h end

	local probe = Instance.new("Folder")
	local canUseCoreGui = pcall(function() probe.Parent = CoreGui end)
	probe:Destroy()
	if canUseCoreGui then return CoreGui end

	return LP:WaitForChild("PlayerGui")
end

--// Root GUI + overlays ------------------------------------------------------
local Gui = new("ScreenGui", {
	Name = "ForgeMM2", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function() if syn and syn.protect_gui then syn.protect_gui(Gui) end end)
Gui.Parent = resolveGuiParent()

--// Logo loading: tries each URL and swaps every logo in place once one loads ----
local logoImage, LogoReady -- the only two names this module needs to expose
do
	local LOGO_ID = 134885781177002
	-- Tried in order: direct asset first, then the thumbnail URL (works even when the ID is a Decal)
	local LOGO_CANDIDATES = {
		"rbxassetid://" .. LOGO_ID,
		("rbxthumb://type=Asset&id=%d&w=420&h=420"):format(LOGO_ID),
	}
	local ContentProvider = game:GetService("ContentProvider")
	local LogoImages = {}
	local CurrentLogo, LogoFailed = LOGO_CANDIDATES[1], false
	LogoReady = false

	local function applyLogo(img)
		img.Image = CurrentLogo
	end

	function logoImage(class, props, parent)
		props.Image = CurrentLogo
		local img = new(class, props, parent)
		LogoImages[#LogoImages + 1] = img
		return img
	end

	task.spawn(function()
		local found
		for _, url in ipairs(LOGO_CANDIDATES) do
			local probe = Instance.new("ImageLabel")
			probe.Image = url
			pcall(function() ContentProvider:PreloadAsync({ probe }) end)
			local loaded = probe.IsLoaded
			probe:Destroy()
			if loaded then
				found = url
				break
			end
		end
		LogoFailed = (found == nil)
		CurrentLogo = found or LOGO_CANDIDATES[2]
		LogoReady = true
		for _, img in ipairs(LogoImages) do
			if img.Parent then applyLogo(img) end
		end
	end)
	task.delay(6, function() LogoReady = true end)
end

local ESPFolder    = new("Folder", { Name = "ESP" }, Gui)
local TracerFolder = new("Frame", { Name = "Tracers", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, Gui)

-- Silent-aim FOV circle (screen centre)
local Fov = new("Frame", {
	Name = "FOV", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(240, 240), BackgroundTransparency = 1, Visible = false, ZIndex = 2,
}, Gui)
corner(Fov, 9999)
local FovStroke = stroke(Fov, THEME.Accent, 0.1, 2)

-- Toast notifications
local ToastHolder = new("Frame", {
	Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18),
	Size = UDim2.fromOffset(300, 200), BackgroundTransparency = 1, ZIndex = 200,
}, Gui)
new("UIListLayout", {
	Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, ToastHolder)

local function notify(text, color)
	color = color or THEME.Accent
	local t = new("CanvasGroup", {
		Size = UDim2.fromOffset(280, 34), BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.1,
		GroupTransparency = 1, ZIndex = 200, BorderSizePixel = 0,
	}, ToastHolder)
	corner(t, 10)
	stroke(t, color, 0.3, 1.5)
	new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0 }, t)
	new("TextLabel", {
		Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.Text, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
	}, t)
	tween(t, 0.25, { GroupTransparency = 0 })
	task.delay(4, function()
		pcall(function()
			tween(t, 0.3, { GroupTransparency = 1 })
			task.wait(0.3)
			t:Destroy()
		end)
	end)
end

local function chatSay(text, color)
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
			if ch then ch:DisplaySystemMessage(text) end
		else
			StarterGui:SetCore("ChatMakeSystemMessage", { Text = text, Color = color or THEME.White, Font = Enum.Font.GothamBold })
		end
	end)
end

--// Dragging (mouse + touch) ---------------------------------------------------
local function makeDraggable(handle, target)
	local state = { Moved = false }
	local dragging, dragStart, startPos = false, nil, nil

	track(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, state.Moved = true, false
			dragStart, startPos = input.Position, target.Position
			local c
			c = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					c:Disconnect()
				end
			end)
		end
	end))

	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			if d.Magnitude > 8 then state.Moved = true end
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))

	return state
end

------------------------------------------------------------------------
-- CORE LOGIC
------------------------------------------------------------------------

--// Roles ------------------------------------------------------------------
local RoleCache, RoleNames = {}, {}
local Murderer = nil -- murderer other than the local player

local function refreshRoles()
	local m, mAny, s = nil, nil, nil
	for _, plr in ipairs(Players:GetPlayers()) do
		local role = "Innocent"
		local char = plr.Character
		local backpack = plr:FindFirstChildOfClass("Backpack")
		if (char and char:FindFirstChild("Knife")) or (backpack and backpack:FindFirstChild("Knife")) then
			role = "Murderer"
		elseif (char and char:FindFirstChild("Gun")) or (backpack and backpack:FindFirstChild("Gun")) then
			role = "Sheriff"
		end
		RoleCache[plr] = role
		if role == "Murderer" then
			mAny = plr
			if plr ~= LP then m = plr end
		elseif role == "Sheriff" then
			s = plr
		end
	end
	Murderer = m
	RoleNames.Murderer, RoleNames.Sheriff = mAny, s
end

local function holdingGun()
	local char = LP.Character
	return char ~= nil and char:FindFirstChild("Gun") ~= nil
end

local function aliveRoot(plr)
	local char = plr and plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 then return hrp end
	return nil
end

--// ESP: whole-body highlight for the Murderer (red) and Sheriff (blue) -------------
local ESPStore = {}

local function removeESP(plr)
	local e = ESPStore[plr]
	if not e then return end
	pcall(function() e.Highlight:Destroy() end)
	pcall(function() e.Tag:Destroy() end)
	pcall(function() e.Tracer:Destroy() end)
	ESPStore[plr] = nil
end

local function createESP(plr, char, hrp)
	local hl = new("Highlight", {
		Name = plr.Name .. "_Highlight", Adornee = char, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 0.35, OutlineTransparency = 0, FillColor = THEME.White, OutlineColor = THEME.White,
	}, ESPFolder)

	local tracer = new("Frame", {
		Name = plr.Name .. "_Tracer", AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
		BackgroundTransparency = 0.15, Visible = false, Size = UDim2.fromOffset(0, 2),
	}, TracerFolder)
	local tracerGlow = stroke(tracer, THEME.White, 0.75, 3)

	local tag = new("BillboardGui", {
		Name = plr.Name .. "_Tag", Adornee = char:FindFirstChild("Head") or hrp, AlwaysOnTop = true,
		Size = UDim2.fromOffset(180, 24), StudsOffset = Vector3.new(0, 2.2, 0), LightInfluence = 0,
	}, ESPFolder)
	local nameLabel = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
		TextColor3 = THEME.White, TextStrokeTransparency = 0.35, Text = plr.DisplayName,
	}, tag)

	local e = { Highlight = hl, Tag = tag, NameLabel = nameLabel, Tracer = tracer, TracerGlow = tracerGlow, Root = hrp }
	ESPStore[plr] = e
	return e
end

local function roleWanted(role)
	return (role == "Murderer" and Config.ESP.Murderer) or (role == "Sheriff" and Config.ESP.Sheriff)
end

local function updateESP()
	local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local role = RoleCache[plr] or "Innocent"
			local hrp = aliveRoot(plr)

			if not hrp or not roleWanted(role) then
				removeESP(plr)
			else
				local char = plr.Character
				local e = ESPStore[plr]
				if e and (e.Highlight.Adornee ~= char or e.Root ~= hrp) then
					removeESP(plr) -- respawned: rebuild on the new character
					e = nil
				end
				e = e or createESP(plr, char, hrp)

				local color = ROLE_COLORS[role]
				e.Highlight.FillColor = color
				e.Highlight.OutlineColor = color
				e.NameLabel.TextColor3 = color
				if myRoot then
					e.NameLabel.Text = string.format("%s [%dm]", plr.DisplayName, (hrp.Position - myRoot.Position).Magnitude)
				else
					e.NameLabel.Text = plr.DisplayName
				end
			end
		end
	end
end

-- Runs every frame so tracer lines stay glued to players
local function updateTracers()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	local origin = Vector2.new(vp.X / 2, vp.Y)

	for plr, e in pairs(ESPStore) do
		local t = e.Tracer
		local hrp = e.Root
		if not (Config.ESP.Tracers and hrp and hrp.Parent) then
			t.Visible = false
		else
			local v, onScreen = cam:WorldToViewportPoint(hrp.Position)
			if onScreen then
				local d = Vector2.new(v.X, v.Y) - origin
				local color = ROLE_COLORS[RoleCache[plr] or "Innocent"]
				t.Visible = true
				t.Size = UDim2.fromOffset(d.Magnitude, 2)
				t.Position = UDim2.fromOffset(origin.X + d.X / 2, origin.Y + d.Y / 2)
				t.Rotation = math.deg(math.atan2(d.Y, d.X))
				t.BackgroundColor3 = color
				e.TracerGlow.Color = color
			else
				t.Visible = false
			end
		end
	end
end

--// ESP: dropped gun (yellow) -------------------------------------------------------------
local GUN_COLOR = Color3.fromRGB(255, 215, 0)
local GunESP = nil

-- The dropped gun may sit directly in workspace or inside the map, so search recursively,
-- cache the result and also catch it the instant it is added.
local gunDropCache, lastGunScan = nil, 0
local function isGunDropName(n)
	n = string.lower(n)
	return n == "gundrop" or n == "droppedgun" or n == "gun_drop"
end

local function findGunDrop()
	if gunDropCache and gunDropCache.Parent then return gunDropCache end
	gunDropCache = nil
	if os.clock() - lastGunScan < 0.3 then return nil end
	lastGunScan = os.clock()

	local found = workspace:FindFirstChild("GunDrop", true)
	if not found then
		for _, c in ipairs(workspace:GetChildren()) do
			if isGunDropName(c.Name) then
				found = c
				break
			end
		end
	end
	gunDropCache = found
	return found
end

track(workspace.DescendantAdded:Connect(function(inst)
	if isGunDropName(inst.Name) then gunDropCache = inst end
end))

local function removeGunESP()
	if not GunESP then return end
	pcall(function() GunESP.Highlight:Destroy() end)
	pcall(function() GunESP.Box:Destroy() end)
	pcall(function() GunESP.Tag:Destroy() end)
	GunESP = nil
end

local function updateGunESP()
	if not Config.ESP.Gun then
		removeGunESP()
		return
	end

	local drop = findGunDrop()
	local part = drop and (drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true))
	if not drop or not part then
		removeGunESP()
		return
	end

	if GunESP and GunESP.Part ~= part then removeGunESP() end

	if not GunESP then
		local hl = new("Highlight", {
			Name = "GunDrop_Highlight", Adornee = (drop:IsA("Model") or drop:IsA("BasePart")) and drop or part, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			FillColor = GUN_COLOR, OutlineColor = GUN_COLOR, FillTransparency = 0.25, OutlineTransparency = 0,
		}, ESPFolder)
		local tag = new("BillboardGui", {
			Name = "GunDrop_Tag", Adornee = part, AlwaysOnTop = true, Size = UDim2.fromOffset(140, 22),
			StudsOffset = Vector3.new(0, 2, 0), LightInfluence = 0,
		}, ESPFolder)
		local label = new("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
			TextColor3 = GUN_COLOR, TextStrokeTransparency = 0.35, Text = "GUN",
		}, tag)
		-- Solid box as a second layer so the gun is visible even if the Highlight can't draw on it
		local box = new("BoxHandleAdornment", {
			Name = "GunDrop_Box", Adornee = part, AlwaysOnTop = true, ZIndex = 3, Color3 = GUN_COLOR,
			Transparency = 0.4, Size = part.Size + Vector3.new(0.6, 0.6, 0.6),
		}, ESPFolder)
		GunESP = { Highlight = hl, Box = box, Tag = tag, Label = label, Part = part }
	end

	local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if myRoot then
		GunESP.Label.Text = string.format("GUN [%dm]", (part.Position - myRoot.Position).Magnitude)
	end
end

--// Hitbox multiplier ----------------------------------------------------------------
local HB = {}

local function restoreHitbox(plr)
	local d = HB[plr]
	if d and d.Part and d.Part.Parent then
		pcall(function()
			d.Part.Size = d.Size
			d.Part.Transparency = d.Transparency
			d.Part.CanCollide = d.CanCollide
			d.Part.Massless = d.Massless
		end)
	end
	HB[plr] = nil
end

local function updateHitboxes()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local want = Config.Hitbox.Enabled and hrp
				and (Config.Hitbox.Target == "All Players" or RoleCache[plr] == "Murderer")

			if want then
				local d = HB[plr]
				if not d or d.Part ~= hrp then
					restoreHitbox(plr)
					HB[plr] = {
						Part = hrp, Size = hrp.Size, Transparency = hrp.Transparency,
						CanCollide = hrp.CanCollide, Massless = hrp.Massless,
					}
				end
				local s = Config.Hitbox.Size
				hrp.Size = Vector3.new(s, s, s)
				hrp.Transparency = 0.8
				hrp.CanCollide = false
				hrp.Massless = true
			else
				restoreHitbox(plr)
			end
		end
	end
end

--// Reach modifier (Knife / Gun handle) -------------------------------------------------
local ReachStore = {}

local function restoreReach(handle)
	local d = ReachStore[handle]
	ReachStore[handle] = nil
	if d then
		pcall(function()
			handle.Size = d.Size
			handle.CanCollide = d.CanCollide
			handle.Massless = d.Massless
		end)
	end
end

local function reachWants(name)
	local t = Config.Reach.Tool
	return t == name or (t == "Both" and (name == "Knife" or name == "Gun"))
end

local function updateReach()
	local char = LP.Character

	for handle in pairs(ReachStore) do
		local tool = handle.Parent
		if not (Config.Reach.Enabled and tool and tool.Parent == char and reachWants(tool.Name)) then
			restoreReach(handle)
		end
	end

	if Config.Reach.Enabled and char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") and reachWants(tool.Name) then
				local h = tool:FindFirstChild("Handle")
				if h and h:IsA("BasePart") then
					if not ReachStore[h] then
						ReachStore[h] = { Size = h.Size, CanCollide = h.CanCollide, Massless = h.Massless }
					end
					local s = Config.Reach.Size
					h.Size = Vector3.new(s, s, s)
					h.CanCollide = false
					h.Massless = true
				end
			end
		end
	end
end

--// Smooth aimlock (camera) ---------------------------------------------------------------
local AimInputs = { Mouse = false, Key = false, Button = false }
local ActiveTouches = 0

local function isAimHeld()
	return AimInputs.Mouse or AimInputs.Key or AimInputs.Button or ActiveTouches > 0
end

RunService:BindToRenderStep("ForgeAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not Config.Aim.Enabled or not isAimHeld() or not holdingGun() or not Murderer then return end

	local hrp = aliveRoot(Murderer)
	local cam = workspace.CurrentCamera
	if not hrp or not cam then return end

	local targetPos = hrp.Position
	if Config.Aim.Prediction then
		targetPos += hrp.AssemblyLinearVelocity * Config.Aim.PredictionTime
	end

	local goal = CFrame.lookAt(cam.CFrame.Position, targetPos)
	local alpha = 1 - math.exp(-Config.Aim.Speed * dt)
	cam.CFrame = cam.CFrame:Lerp(goal, alpha)
end)

--// Gun firing helper: calls the gun's remote directly (falls back to Tool:Activate) ---------
local function shootGun(targetPos)
	local char = LP.Character
	local gun = char and char:FindFirstChild("Gun")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not gun or not root then return false end

	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or root
	local origin = hand.Position

	-- Current MM2 gun: Gun.Shoot:FireServer(originCFrame, targetCFrame)
	local shoot = gun:FindFirstChild("Shoot", true)
	if shoot and shoot:IsA("RemoteEvent") then
		return (pcall(function() shoot:FireServer(CFrame.new(origin), CFrame.new(targetPos)) end))
	end

	-- Older MM2 gun: Gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, pos, "AH2")
	local rf = gun:FindFirstChild("RemoteFunction", true)
	if rf and rf:IsA("RemoteFunction") then
		task.spawn(function() pcall(function() rf:InvokeServer(1, targetPos, "AH2") end) end)
		return true
	end

	pcall(function() gun:Activate() end)
	return true
end

--// Silent aim: redirect the gun's shot to the Murderer while they are inside the FOV circle -----
-- Two hooks (either one is enough):
--   * __namecall : rewrites the target argument of the gun's Shoot / RemoteFunction call
--   * __index    : spoofs Mouse.Hit / Mouse.Target / Mouse.UnitRay for guns that read the mouse
-- Without any hook support, a tap/click fallback fires the gun remote at the target itself.
local HookAlive, HookOK = true, false
local IndexHookOK, RemoteHookOK = false, false
local SilentPos, SilentPart = nil, nil

do
	local mouse = LP:GetMouse()

	IndexHookOK = pcall(function()
		assert(hookmetamethod and newcclosure, "hookmetamethod unavailable")
		local old
		old = hookmetamethod(game, "__index", newcclosure(function(self, key)
			if HookAlive and SilentPos and self == mouse and not (checkcaller and checkcaller()) then
				if key == "Hit" then
					return CFrame.new(SilentPos)
				elseif key == "Target" then
					return SilentPart
				elseif key == "UnitRay" then
					local o = workspace.CurrentCamera.CFrame.Position
					return Ray.new(o, (SilentPos - o).Unit)
				end
			end
			return old(self, key)
		end))
	end)

	RemoteHookOK = pcall(function()
		assert(hookmetamethod and newcclosure and getnamecallmethod, "namecall hook unavailable")
		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			if HookAlive and SilentPos and not (checkcaller and checkcaller()) and typeof(self) == "Instance" then
				local method = getnamecallmethod() -- read first, before touching the instance
				if method == "FireServer" and self.Name == "Shoot" then
					local args = table.pack(...)
					if typeof(args[2]) == "CFrame" then
						args[2] = CFrame.new(SilentPos)
						return old(self, table.unpack(args, 1, args.n))
					end
				elseif method == "InvokeServer" and self.Name == "RemoteFunction" then
					local args = table.pack(...)
					if typeof(args[2]) == "Vector3" then
						args[2] = SilentPos
						return old(self, table.unpack(args, 1, args.n))
					end
				end
			end
			return old(self, ...)
		end))
	end)

	HookOK = IndexHookOK or RemoteHookOK
end

local function updateSilent()
	SilentPos, SilentPart = nil, nil
	local show = Config.Silent.Enabled and Config.Silent.ShowFOV
	Fov.Visible = show
	if show then
		local d = Config.Silent.FOV * 2
		Fov.Size = UDim2.fromOffset(d, d)
	end

	local cam = workspace.CurrentCamera
	if Config.Silent.Enabled and cam and Murderer and holdingGun() then
		local hrp = aliveRoot(Murderer)
		if hrp then
			local v, onScreen = cam:WorldToViewportPoint(hrp.Position)
			if onScreen then
				local center = cam.ViewportSize / 2
				if (Vector2.new(v.X, v.Y) - center).Magnitude <= Config.Silent.FOV then
					local pos = hrp.Position
					if Config.Aim.Prediction then
						pos += hrp.AssemblyLinearVelocity * Config.Aim.PredictionTime
					end
					SilentPos, SilentPart = pos, hrp
				end
			end
		end
	end
	FovStroke.Color = SilentPos and THEME.White or THEME.Accent
end

-- Fallback when the executor has no hook support: fire the gun ourselves on tap / click
local lastClickShot = 0
track(UserInputService.InputBegan:Connect(function(input, processed)
	if HookOK or processed or not Config.Silent.Enabled then return end
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
	if SilentPos and os.clock() - lastClickShot > 0.3 then
		lastClickShot = os.clock()
		shootGun(SilentPos)
	end
end))

--// Auto-shoot: fires the gun remote straight at the Murderer (no camera movement needed) ----------
local lastShot = 0
local ShootParams = RaycastParams.new()
ShootParams.FilterType = Enum.RaycastFilterType.Exclude

local function autoShoot()
	if not Config.Auto.Enabled or not Murderer then return end
	if os.clock() - lastShot < 0.6 then return end

	local char = LP.Character
	if not char or not char:FindFirstChild("Gun") then return end

	local hrp = aliveRoot(Murderer)
	local cam = workspace.CurrentCamera
	if not hrp or not cam then return end

	local v, onScreen = cam:WorldToViewportPoint(hrp.Position)
	if not onScreen then return end
	if (Vector2.new(v.X, v.Y) - cam.ViewportSize / 2).Magnitude > Config.Auto.Radius then return end

	-- Optional line-of-sight check (ignores both characters)
	if Config.Auto.WallCheck then
		ShootParams.FilterDescendantsInstances = { char, Murderer.Character }
		local origin = cam.CFrame.Position
		if workspace:Raycast(origin, hrp.Position - origin, ShootParams) then return end
	end

	local pos = hrp.Position
	if Config.Aim.Prediction then
		pos += hrp.AssemblyLinearVelocity * Config.Aim.PredictionTime
	end

	lastShot = os.clock()
	shootGun(pos)
end

--// Movement ----------------------------------------------------------------------------------------
local MoveOrig = {}

local function updateMovement()
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if Config.Move.WalkEnabled then
		if MoveOrig.WalkSpeed == nil then MoveOrig.WalkSpeed = hum.WalkSpeed end
		hum.WalkSpeed = Config.Move.WalkSpeed
	elseif MoveOrig.WalkSpeed then
		hum.WalkSpeed = MoveOrig.WalkSpeed
		MoveOrig.WalkSpeed = nil
	end

	if Config.Move.JumpEnabled then
		if MoveOrig.JumpPower == nil then
			MoveOrig.JumpPower, MoveOrig.UseJumpPower = hum.JumpPower, hum.UseJumpPower
		end
		hum.UseJumpPower = true
		hum.JumpPower = Config.Move.JumpPower
	elseif MoveOrig.JumpPower then
		hum.UseJumpPower = MoveOrig.UseJumpPower
		hum.JumpPower = MoveOrig.JumpPower
		MoveOrig.JumpPower, MoveOrig.UseJumpPower = nil, nil
	end
end

track(UserInputService.JumpRequest:Connect(function()
	if not Config.Move.InfJump then return end
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

-- Noclip (remembers original collision so it restores cleanly)
local NoclipOrig = setmetatable({}, { __mode = "k" })

local function restoreNoclip()
	for part, cc in pairs(NoclipOrig) do
		pcall(function() part.CanCollide = cc end)
		NoclipOrig[part] = nil
	end
end

track(RunService.Stepped:Connect(function()
	if Config.Move.Noclip then
		local char = LP.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					if NoclipOrig[part] == nil then NoclipOrig[part] = part.CanCollide end
					part.CanCollide = false
				end
			end
		end
	elseif next(NoclipOrig) then
		restoreNoclip()
	end
end))

-- Anti-aim / anti-look (rotates your character so knife-throw / aimbot prediction is thrown off)
local AntiAimOrig = nil

local function updateAntiAim()
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	if Config.AntiAim.Enabled then
		if AntiAimOrig == nil then AntiAimOrig = hum.AutoRotate end
		hum.AutoRotate = false
		local yaw = math.sin(os.clock() * 6) * 180 -- fast visual sweep; does not affect your real hitbox or movement
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(yaw), 0)
	elseif AntiAimOrig ~= nil then
		hum.AutoRotate = AntiAimOrig
		AntiAimOrig = nil
	end
end

-- Auto grab dropped gun (MM2 drops it as "GunDrop" in workspace)
local gunBusy = false

local function autoGun()
	if not Config.Move.AutoGun or gunBusy or RoleCache[LP] == "Murderer" then return end
	local drop = findGunDrop()
	if not drop then return end

	local part = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true)
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not part or not hrp then return end

	gunBusy = true
	task.spawn(function()
		local back = hrp.CFrame

		-- 1) Touch-based pickup when the executor supports it
		if firetouchinterest then
			pcall(function()
				firetouchinterest(hrp, part, 0)
				task.wait()
				firetouchinterest(hrp, part, 1)
			end)
		end
		task.wait(0.15)

		-- 2) Fallback: teleport onto it
		if drop.Parent and hrp.Parent then
			hrp.CFrame = part.CFrame + Vector3.new(0, 2, 0)
			task.wait(0.35)
			if Config.Move.ReturnAfter and hrp.Parent then
				hrp.CFrame = back
			end
		end

		task.wait(1)
		gunBusy = false
	end)
end

--// World: fullbright / fog / FPS booster ------------------------------------------------------------
local LightOrig, AtmoOrig = {}, {}

local function lightSet(prop, value)
	if LightOrig[prop] == nil then LightOrig[prop] = Lighting[prop] end
	Lighting[prop] = value
end

local function lightRestore(props)
	for _, p in ipairs(props) do
		if LightOrig[p] ~= nil then
			Lighting[p] = LightOrig[p]
			LightOrig[p] = nil
		end
	end
end

local FB_PROPS  = { "Brightness", "ClockTime", "Ambient", "OutdoorAmbient" }
local FOG_PROPS = { "FogEnd", "FogStart" }

local function applyWorld()
	pcall(function()
		if Config.World.Fullbright then
			lightSet("Brightness", 2)
			lightSet("ClockTime", 14)
			lightSet("Ambient", Color3.fromRGB(190, 190, 190))
			lightSet("OutdoorAmbient", Color3.fromRGB(190, 190, 190))
		else
			lightRestore(FB_PROPS)
		end

		if Config.World.NoFog then
			lightSet("FogEnd", 1e6)
			lightSet("FogStart", 0)
			for _, a in ipairs(Lighting:GetChildren()) do
				if a:IsA("Atmosphere") then
					if not AtmoOrig[a] then AtmoOrig[a] = { Density = a.Density, Haze = a.Haze } end
					a.Density, a.Haze = 0, 0
				end
			end
		else
			lightRestore(FOG_PROPS)
			for a, d in pairs(AtmoOrig) do
				pcall(function() a.Density, a.Haze = d.Density, d.Haze end)
				AtmoOrig[a] = nil
			end
		end
	end)
end

-- FPS booster: reversible (originals are remembered), applied in chunks to avoid hitches
local FPSStore = setmetatable({}, { __mode = "k" })
local fpsConn, fpsOn, fpsQuality = nil, false, nil

local function fpsApply(inst)
	if FPSStore[inst] then return end
	if inst:IsA("BasePart") then
		FPSStore[inst] = { Material = inst.Material, CastShadow = inst.CastShadow }
		inst.Material = Enum.Material.SmoothPlastic
		inst.CastShadow = false
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		FPSStore[inst] = { Transparency = inst.Transparency }
		inst.Transparency = 1
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Fire")
		or inst:IsA("Smoke") or inst:IsA("Sparkles") or inst:IsA("PostEffect") then
		FPSStore[inst] = { Enabled = inst.Enabled }
		inst.Enabled = false
	end
end

local function setFPS(on)
	if on == fpsOn then return end
	fpsOn = on

	if on then
		pcall(function() fpsQuality = settings().Rendering.QualityLevel end)
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		pcall(function() lightSet("GlobalShadows", false) end)
		fpsConn = workspace.DescendantAdded:Connect(function(i) pcall(fpsApply, i) end)

		task.spawn(function()
			local n = 0
			for _, inst in ipairs(workspace:GetDescendants()) do
				if not fpsOn then return end
				pcall(fpsApply, inst)
				n += 1
				if n % 400 == 0 then task.wait() end
			end
			for _, inst in ipairs(Lighting:GetDescendants()) do
				pcall(fpsApply, inst)
			end
		end)
	else
		if fpsConn then fpsConn:Disconnect() fpsConn = nil end
		pcall(function() lightRestore({ "GlobalShadows" }) end)
		if fpsQuality then pcall(function() settings().Rendering.QualityLevel = fpsQuality end) end

		task.spawn(function()
			local n = 0
			for inst, props in pairs(FPSStore) do
				if fpsOn then return end -- re-enabled mid-restore
				pcall(function()
					for k, v in pairs(props) do inst[k] = v end
				end)
				FPSStore[inst] = nil
				n += 1
				if n % 400 == 0 then task.wait() end
			end
		end)
	end
end

--// Server tools: rejoin / hop / anti-AFK ----------------------------------------------------------
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local function rejoinServer()
	pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
end
-- Smart hop: asks Roblox's public server list for servers with room, prefers the lowest ping, never picks the
-- current server or one already tried this session. Falls back to a plain random Teleport if the list is unavailable.
local Hop = { busy = false, tried = {}, setText = nil, cmds = {} } -- one table keeps this file under Lua's local-variable limit

-- Every UI control registers itself here so chat commands can drive it (see the chat command block)
function Hop.reg(page, label, run)
	Hop.cmds[#Hop.cmds + 1] = { key = (tostring(label):lower():gsub("[^%w]", "")), label = label, page = page.Name, run = run }
end

function Hop.get(url)
	local req = (syn and syn.request) or request or http_request or (http and http.request)
	if req then
		local ok, res = pcall(req, { Url = url, Method = "GET" })
		if ok and type(res) == "table" and res.Body and (res.StatusCode == nil or res.StatusCode == 200) then
			return res.Body
		end
	end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and type(body) == "string" then return body end
	return nil
end

function Hop.find()
	local Http = game:GetService("HttpService")
	local good, loose, cursor = {}, {}, nil
	for _ = 1, 3 do -- up to 300 servers
		local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true%s")
			:format(game.PlaceId, cursor and ("&cursor=" .. cursor) or "")
		local body = Hop.get(url)
		if not body then break end
		local ok, data = pcall(function() return Http:JSONDecode(body) end)
		if not ok or type(data) ~= "table" or type(data.data) ~= "table" then break end
		for _, srv in ipairs(data.data) do
			local playing, maxp = tonumber(srv.playing) or 0, tonumber(srv.maxPlayers) or 0
			if srv.id and srv.id ~= game.JobId and not Hop.tried[srv.id] and playing < maxp - 1 then
				loose[#loose + 1] = srv
				if playing >= 3 then good[#good + 1] = srv end -- prefer servers where a round can actually run
			end
		end
		cursor = data.nextPageCursor
		if not cursor then break end
	end
	local pool = (#good > 0) and good or loose
	if #pool == 0 then return nil end
	table.sort(pool, function(a, b) return (tonumber(a.ping) or 9999) < (tonumber(b.ping) or 9999) end)
	return pool[math.random(1, math.min(3, #pool))] -- random among the 3 best so repeated taps don't collide
end

local function hopServer()
	if Hop.busy then return end
	Hop.busy = true
	if Hop.setText then Hop.setText("...") end
	task.spawn(function()
		local srv = Hop.find()
		if srv then
			Hop.tried[srv.id] = true
			notify(("Hopping: %d/%d players%s"):format(
				tonumber(srv.playing) or 0, tonumber(srv.maxPlayers) or 0,
				srv.ping and (" | " .. math.floor(tonumber(srv.ping) or 0) .. " ms") or ""), THEME.Accent)
			local ok = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LP) end)
			if not ok then pcall(function() TeleportService:Teleport(game.PlaceId, LP) end) end
		else
			notify("Server list unavailable - random hop", THEME.Sub)
			pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
		end
		task.wait(8)
		Hop.busy = false
		if Hop.setText then Hop.setText("HOP") end
	end)
end
track(TeleportService.TeleportInitFailed:Connect(function()
	Hop.busy = false
	if Hop.setText then Hop.setText("HOP") end
	notify("Teleport failed - tap HOP to try another server", THEME.Sub)
end))

local antiAFKConn = nil
local function setAntiAFK(on)
	if on and not antiAFKConn then
		antiAFKConn = LP.Idled:Connect(function()
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end)
	elseif not on and antiAFKConn then
		antiAFKConn:Disconnect()
		antiAFKConn = nil
	end
end

--// Save / Load config (writes a JSON file through the executor's file functions) -----------------
local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "ForgeMM2_Config.json"

local function saveConfig()
	if not (writefile and HttpService) then
		notify("This executor can't save files", THEME.Sub)
		return
	end
	local ok, enc = pcall(function() return HttpService:JSONEncode(Config) end)
	if ok and pcall(writefile, CONFIG_FILE, enc) then
		notify("Config saved", THEME.Accent)
	else
		notify("Save failed", THEME.Sub)
	end
end

local function loadConfig(silent)
	if not (readfile and isfile and pcall(isfile, CONFIG_FILE) and isfile(CONFIG_FILE)) then
		if not silent then notify("No saved config found", THEME.Sub) end
		return
	end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
	if not ok or type(data) ~= "table" then
		if not silent then notify("Config load failed", THEME.Sub) end
		return
	end
	local function merge(dst, src)
		for k, v in pairs(src) do
			if type(v) == "table" and type(dst[k]) == "table" then
				merge(dst[k], v)
			elseif dst[k] ~= nil and type(v) == type(dst[k]) then
				dst[k] = v
			end
		end
	end
	merge(Config, data)
	for path, setter in pairs(ControlRegistry) do
		local v = getPath(Config, path)
		if v ~= nil then pcall(setter, v) end
	end
	if not silent then notify("Config loaded", THEME.Accent) end
end

--// Cosmetics: weapon trail + local kill effects ---------------------------------------------------
local TrailStore = setmetatable({}, { __mode = "k" })
local Debris = game:GetService("Debris")

local function updateTrail()
	local char = LP.Character
	if not char then return end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				local existing = handle:FindFirstChild("ForgeTrail")
				if Config.Cosmetic.Trail then
					if not existing then
						local a0 = new("Attachment", { Position = Vector3.new(0, 0, -handle.Size.Z / 2) }, handle)
						local a1 = new("Attachment", { Position = Vector3.new(0, 0, handle.Size.Z / 2) }, handle)
						local trail = new("Trail", {
							Name = "ForgeTrail", Attachment0 = a0, Attachment1 = a1, Lifetime = 0.35,
							MinLength = 0, FaceCamera = true, WidthScale = NumberSequence.new(1, 0),
						}, handle)
						onTheme(function() trail.Color = ColorSequence.new(THEME.Accent, THEME.Accent2) end)
						TrailStore[handle] = trail
					end
				elseif existing then
					existing:Destroy()
					TrailStore[handle] = nil
				end
			end
		end
	end
end

local function playKillEffect(atPos)
	if not atPos then return end
	if Config.Cosmetic.KillSoundId ~= "" then
		pcall(function()
			local snd = new("Sound", { SoundId = Config.Cosmetic.KillSoundId, Volume = 1 }, workspace)
			snd:Play()
			Debris:AddItem(snd, 4)
		end)
	end
	pcall(function()
		local part = new("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1,
			Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(atPos),
		}, workspace)
		local emitter = new("ParticleEmitter", {
			Color = ColorSequence.new(THEME.Accent), Lifetime = NumberRange.new(0.3, 0.7),
			Speed = NumberRange.new(6, 14), Rate = 0, SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.4), Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1),
			}),
		}, part)
		emitter:Emit(28)
		Debris:AddItem(part, 2)
	end)
end

local WasAlive = {}
local function checkKillEffects()
	if not Config.Cosmetic.KillFX then return end
	local myRole = RoleCache[LP]
	if myRole ~= "Murderer" and myRole ~= "Sheriff" then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local alive = aliveRoot(plr) ~= nil
			if WasAlive[plr] == nil then WasAlive[plr] = alive end
			if WasAlive[plr] and not alive then
				local char = plr.Character
				local pos = char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position
				playKillEffect(pos)
			end
			WasAlive[plr] = alive
		end
	end
end

--// Target lock: live info panel for a chosen player --------------------------------------------
local Target = nil
local TargetInfoRefresh = nil -- set once the Players tab builds the labels

local function updateTarget()
	if TargetInfoRefresh then TargetInfoRefresh() end
end

--// Spectate: follow whoever holds the Knife or Gun, even after you die -------------------------
local SpectateOrigSubject, SpectateOrigType = nil, nil

local function updateSpectate()
	local cam = workspace.CurrentCamera
	if not cam then return end

	if Config.Spectate.Enabled then
		local plr = Config.Spectate.Target == "Murderer" and RoleNames.Murderer or RoleNames.Sheriff
		local hum = plr and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			if SpectateOrigSubject == nil then
				SpectateOrigSubject, SpectateOrigType = cam.CameraSubject, cam.CameraType
			end
			cam.CameraType = Enum.CameraType.Custom
			cam.CameraSubject = hum
		end
	elseif SpectateOrigSubject ~= nil then
		cam.CameraType = SpectateOrigType
		cam.CameraSubject = SpectateOrigSubject
		SpectateOrigSubject, SpectateOrigType = nil, nil
	end
end

--// Player watchlist: notifies (and optionally server-hops) when a named player joins ------------
-- NOTE: this can only match specific names/IDs you add yourself. There is no reliable client-side
-- way to detect Roblox staff or "flagged" accounts, so this does not attempt that.
local WatchList = {} -- lowercase username -> true
local WatchListRefresh = nil

local function watchCheck(plr)
	if not Config.Watch.Enabled then return end
	if WatchList[string.lower(plr.Name)] then
		notify("Watchlisted player joined: " .. plr.Name, Color3.fromRGB(255, 80, 80))
		if Config.Watch.AutoHop then
			task.wait(1)
			hopServer()
		end
	end
end
track(Players.PlayerAdded:Connect(watchCheck))

--// Round announcer --------------------------------------------------------------------------------------
local lastRoundKey, murdererMissing = nil, 0

local function announceRoles()
	local m, s = RoleNames.Murderer, RoleNames.Sheriff
	local function nm(p)
		if not p then return "Unknown" end
		return p.DisplayName .. (p == LP and " (you)" or "")
	end

	if Config.ESP.Toast and not (Hop.toastAt and os.clock() - Hop.toastAt < 5) then -- the tracker already toasted the instant roles were handed out
		notify("Murderer: " .. nm(m), ROLE_COLORS.Murderer)
		notify("Sheriff: " .. nm(s), ROLE_COLORS.Sheriff)
	end
	if Config.ESP.Chat then
		chatSay(string.format("[Forge] Murderer: %s | Sheriff: %s", nm(m), nm(s)), ROLE_COLORS.Murderer)
	end
end

local function checkRound(step)
	local m = RoleNames.Murderer
	if m then
		murdererMissing = 0
		if m.UserId ~= lastRoundKey then
			lastRoundKey = m.UserId
			task.delay(0.8, function() -- let the sheriff's gun replicate first
				if Gui.Parent then announceRoles() end
			end)
		end
	else
		murdererMissing += step
		if murdererMissing > 6 then lastRoundKey = nil end
	end
end

--// Auto kill all (hold the Knife) ---------------------------------------------------------
-- While you hold the Knife the loop re-scans the server every cycle: if any other player is
-- still alive it teleports behind the nearest one (any distance) and stabs; when nobody is
-- left it announces VICTORY, returns you to where you started and idles until the next round.
local killRunning = false

local function stabTarget(knife, targetChar)
	pcall(function() knife:Activate() end)
	local handle = knife:FindFirstChild("Handle")
	local troot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	if firetouchinterest and handle and troot then
		pcall(function()
			firetouchinterest(handle, troot, 0)
			firetouchinterest(handle, troot, 1)
		end)
	end
end

local function startKillAll()
	if killRunning then return end
	killRunning = true

	task.spawn(function()
		local home, victory = nil, false

		while Config.Kill.Enabled and Gui.Parent do
			local char = LP.Character
			local myRoot = char and char:FindFirstChild("HumanoidRootPart")
			local knife = char and char:FindFirstChild("Knife") -- must be equipped

			if not (knife and myRoot) then
				victory, home = false, nil -- not holding the knife: idle
				task.wait(0.3)
			else
				home = home or myRoot.CFrame

				-- Who is still alive?
				local targets = {}
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= LP then
						local r = aliveRoot(plr)
						if r then targets[#targets + 1] = { plr = plr, root = r } end
					end
				end
				table.sort(targets, function(a, b)
					return (a.root.Position - myRoot.Position).Magnitude < (b.root.Position - myRoot.Position).Magnitude
				end)

				if #targets == 0 then
					-- Nobody left: victory
					if not victory then
						victory = true
						notify("VICTORY - no players left", Color3.fromRGB(255, 215, 0))
						if Config.Kill.Return and home then myRoot.CFrame = home end
						home = nil
					end
					task.wait(0.5)
				else
					victory = false
					for _, t in ipairs(targets) do
						if not Config.Kill.Enabled or not Gui.Parent then break end
						for _ = 1, 3 do -- up to 3 stabs per target
							local root = aliveRoot(t.plr)
							local c = LP.Character
							myRoot = c and c:FindFirstChild("HumanoidRootPart")
							knife = c and c:FindFirstChild("Knife")
							if not root or not myRoot or not knife then break end -- target dead / we lost the knife
							local behind = (root.CFrame * CFrame.new(0, 0, 2.5)).Position
							myRoot.CFrame = CFrame.lookAt(behind, root.Position)
							stabTarget(knife, t.plr.Character)
							task.wait(Config.Kill.Delay)
						end
					end
				end
			end
			task.wait(0.05)
		end

		-- Stopped by the user: go back to where we started
		local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if r and home and Config.Kill.Return and Gui.Parent then r.CFrame = home end
		killRunning = false
	end)
end

--// Unload / panic ----------------------------------------------------------------------------------------------
local unloaded = false

local function unload()
	if unloaded then return end
	unloaded = true
	HookAlive = false
	SilentPos, SilentPart = nil, nil

	for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
	table.clear(Connections)
	pcall(function() RunService:UnbindFromRenderStep("ForgeAim") end)

	-- turn every feature off, then run each restore path once
	Config.Hitbox.Enabled, Config.Reach.Enabled = false, false
	Config.Move.WalkEnabled, Config.Move.JumpEnabled = false, false
	Config.Move.Noclip, Config.Move.InfJump, Config.Move.AutoGun = false, false, false
	Config.World.Fullbright, Config.World.NoFog = false, false
	Config.Kill.Enabled = false
	Config.AntiAim.Enabled = false
	Config.Cosmetic.Trail = false
	Config.Spectate.Enabled = false
	setAntiAFK(false)

	pcall(updateMovement)
	pcall(restoreNoclip)
	pcall(updateReach)
	pcall(updateAntiAim)
	pcall(updateSpectate)
	for plr in pairs(HB) do restoreHitbox(plr) end
	for plr in pairs(ESPStore) do removeESP(plr) end
	for handle, trail in pairs(TrailStore) do pcall(function() trail:Destroy() end) TrailStore[handle] = nil end
	removeGunESP()
	applyWorld()
	setFPS(false)

	pcall(function() Gui:Destroy() end)
	ENV.ForgeMM2 = nil
end

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local baseScale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 720, 0.72, 1)

local Main = new("CanvasGroup", {
	Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(520, 340), BackgroundTransparency = 1,
	GroupTransparency = 1, Visible = false, BorderSizePixel = 0,
}, Gui)
corner(Main, 14)
stroke(Main, THEME.White, 0.75, 1)
-- Solid glass backdrop lives in its own Frame. A UIGradient placed directly on a
-- CanvasGroup tints everything inside it, which is what made the menu look invisible.
local MainBg = new("Frame", {
	Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.White,
	BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 0,
}, Main)
new("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(26, 26, 29), Color3.fromRGB(4, 4, 5)), Rotation = 90,
}, MainBg)
logoImage("ImageLabel", { -- Forge logo watermark
	Name = "Watermark", BackgroundTransparency = 1, ImageTransparency = 0.9,
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -10), Size = UDim2.fromOffset(170, 170),
	ScaleType = Enum.ScaleType.Fit, ZIndex = 1,
}, Main)
local MainScale = new("UIScale", { Scale = baseScale * 0.9 }, Main)

-- Top bar
local TopBar = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1 }, Main)
logoImage("ImageLabel", {
	BackgroundTransparency = 1, Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(12, 8),
}, TopBar)
local Title = new("TextLabel", {
	Text = "", RichText = true, BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 0),
	Size = UDim2.new(0, 200, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = THEME.Text,
}, TopBar)
onTheme(function()
	Title.Text = string.format('FORGE <font color="#%s">MM2</font>', THEME.Accent:ToHex())
end)
local CloseBtn = new("TextButton", {
	Text = "–", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = THEME.Text, AutoButtonColor = false,
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.3,
}, TopBar)
corner(CloseBtn, 8)
new("Frame", {
	Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = THEME.White, BackgroundTransparency = 0.9, BorderSizePixel = 0,
}, TopBar)
makeDraggable(TopBar, Main)

-- Sidebar + content
local Sidebar = new("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 42), Size = UDim2.new(0, 118, 1, -42), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, Main)
themed(Sidebar, "ScrollBarImageColor3", "Accent")
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, Sidebar)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, Sidebar)

local Content = new("Frame", {
	Position = UDim2.fromOffset(126, 50), Size = UDim2.new(1, -136, 1, -60), BackgroundTransparency = 1,
}, Main)

local pages, tabButtons, currentTab = {}, {}, nil

local function selectTab(name)
	currentTab = name
	for n, page in pairs(pages) do page.Visible = (n == name) end
	for n, btn in pairs(tabButtons) do
		local active = (n == name)
		tween(btn, 0.2, { BackgroundTransparency = active and 0.15 or 1, TextColor3 = active and THEME.Accent or THEME.Sub })
	end
end
onTheme(function() if currentTab then selectTab(currentTab) end end)

local function makePage(name, order)
	local page = new("ScrollingFrame", {
		Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
	}, Content)
	themed(page, "ScrollBarImageColor3", "Accent")
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	new("UIPadding", { PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 6) }, page)
	pages[name] = page

	local btn = new("TextButton", {
		Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.Sub, AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = THEME.Panel, BackgroundTransparency = 1, LayoutOrder = order,
	}, Sidebar)
	corner(btn, 8)
	btn.Activated:Connect(function() selectTab(name) end)
	tabButtons[name] = btn
	return page
end

-- Control builders
local function makeRow(page, height)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
	}, page)
	corner(row, 8)
	stroke(row, THEME.White, 0.92, 1)
	return row
end

local function rowLabel(row, text, widthOffset)
	return new("TextLabel", {
		Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.Text,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, widthOffset or -70, 0, 36),
	}, row)
end

local function addSection(page, text)
	new("TextLabel", {
		Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = THEME.Sub,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18),
	}, page)
end

local function addInfo(page, text)
	new("TextLabel", {
		Text = text, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = THEME.Sub, TextWrapped = true,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 44),
	}, page)
end

local function addToggle(page, text, default, callback, path)
	local row = makeRow(page, 36)
	rowLabel(row, text)
	local sw = new("TextButton", {
		Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 20), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = THEME.Off,
	}, row)
	corner(sw, 10)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
		BackgroundColor3 = THEME.White,
	}, sw)
	corner(knob, 7)

	local state = default
	local function render(animate)
		local c = state and THEME.Accent or THEME.Off
		local p = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		local kc = state and Color3.fromRGB(10, 10, 12) or Color3.fromRGB(210, 210, 215)
		if animate then
			tween(sw, 0.18, { BackgroundColor3 = c })
			tween(knob, 0.18, { Position = p, BackgroundColor3 = kc })
		else
			sw.BackgroundColor3, knob.Position, knob.BackgroundColor3 = c, p, kc
		end
	end
	onTheme(function() render(false) end)

	sw.Activated:Connect(function()
		state = not state
		render(true)
		local ok, err = pcall(callback, state)
		if not ok then warn("[Forge MM2] toggle error:", err) end
	end)

	if path then
		ControlRegistry[path] = function(v)
			state = v
			render(false)
		end
	end
	Hop.reg(page, text, function(arg)
		local v
		if arg == "on" or arg == "1" or arg == "true" then v = true
		elseif arg == "off" or arg == "0" or arg == "false" then v = false
		else v = not state end
		state = v
		render(true)
		pcall(callback, v)
		return text .. (v and ": ON" or ": OFF")
	end)
end

local function addSlider(page, text, min, max, default, step, callback, path)
	local row = makeRow(page, 52)
	rowLabel(row, text, -80).Size = UDim2.new(1, -80, 0, 26)
	local fmt = step < 1 and "%.2f" or "%d"
	local valueLabel = new("TextLabel", {
		Text = string.format(fmt, default), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.Accent,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(60, 26),
	}, row)
	themed(valueLabel, "TextColor3", "Accent")

	local hit = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -24, 0, 22),
	}, row)
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = THEME.Off, BorderSizePixel = 0,
	}, hit)
	corner(bar, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.White, BorderSizePixel = 0 }, bar)
	corner(fill, 3)
	local grad = new("UIGradient", {}, fill)
	onTheme(function() grad.Color = ColorSequence.new(THEME.Accent2, THEME.Accent) end)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = THEME.White,
	}, bar)
	corner(knob, 7)
	themed(stroke(knob, THEME.Accent, 0.2, 2), "Color", "Accent")

	local cur = default
	local function setValue(v, fire)
		v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
		cur = v
		local rel = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(rel, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		valueLabel.Text = string.format(fmt, v)
		if fire then pcall(callback, v) end
	end
	setValue(default, false)

	local dragging = false
	local function fromX(x)
		local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		setValue(min + (max - min) * rel, true)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			page.ScrollingEnabled = false
			fromX(input.Position.X)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			page.ScrollingEnabled = true
		end
	end))

	if path then
		ControlRegistry[path] = function(v) setValue(v, false) end
	end
	Hop.reg(page, text, function(arg)
		local n = tonumber(arg)
		if not n then return text .. ": " .. string.format(fmt, cur) .. "  (range " .. min .. " to " .. max .. ")" end
		setValue(n, true)
		return text .. ": " .. string.format(fmt, cur)
	end)
end

local function addCycle(page, text, options, default, callback, path)
	local row = makeRow(page, 36)
	rowLabel(row, text, -120)
	local idx = table.find(options, default) or 1
	local btn = new("TextButton", {
		Text = options[idx], Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.Accent, AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(104, 24),
		BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.2,
	}, row)
	corner(btn, 6)
	themed(btn, "TextColor3", "Accent")
	themed(stroke(btn, THEME.Accent, 0.6, 1), "Color", "Accent")
	btn.Activated:Connect(function()
		idx = idx % #options + 1
		btn.Text = options[idx]
		pcall(callback, options[idx])
	end)

	if path then
		ControlRegistry[path] = function(v)
			local i = table.find(options, v)
			if i then
				idx = i
				btn.Text = options[idx]
			end
		end
	end
	Hop.reg(page, text, function(arg)
		local pick
		local want = (arg:lower():gsub("[^%w]", ""))
		if want ~= "" then
			for i, o in ipairs(options) do
				local key = (o:lower():gsub("[^%w]", ""))
				if key == want then pick = i break end
				if not pick and key:sub(1, #want) == want then pick = i end
			end
			if not pick then return text .. " options: " .. table.concat(options, ", ") end
		end
		idx = pick or (idx % #options + 1)
		btn.Text = options[idx]
		pcall(callback, options[idx])
		return text .. ": " .. options[idx]
	end)
end

local function addButton(page, text, callback)
	local btn = new("TextButton", {
		Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.Text, AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.35,
	}, page)
	corner(btn, 8)
	themed(stroke(btn, THEME.Accent, 0.6, 1), "Color", "Accent")
	btn.Activated:Connect(function() pcall(callback) end)
	Hop.reg(page, text, function()
		pcall(callback)
		return text
	end)
	return btn
end

local function addInput(page, text, default, placeholder, callback, path)
	local row = makeRow(page, 58)
	rowLabel(row, text, -12).Size = UDim2.new(1, -24, 0, 22)
	local box = new("TextBox", {
		Text = default or "", PlaceholderText = placeholder or "", ClearTextOnFocus = false,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = THEME.Text, PlaceholderColor3 = THEME.Sub,
		TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.2,
		Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 24),
	}, row)
	corner(box, 6)
	themed(stroke(box, THEME.Accent, 0.6, 1), "Color", "Accent")
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)
	box.FocusLost:Connect(function(enter)
		if enter then pcall(callback, box.Text) end
	end)
	if path then
		ControlRegistry[path] = function(v) box.Text = tostring(v) end
	end
	Hop.reg(page, text, function(_, raw)
		if raw == nil or raw == "" then return text .. ": " .. box.Text end
		box.Text = raw
		pcall(callback, raw)
		return text .. " set"
	end)
	return box
end

local function addSwatches(page)
	local row = makeRow(page, 58)
	rowLabel(row, "Accent Theme", -12).Size = UDim2.new(1, -140, 0, 26)
	local nameLabel = new("TextLabel", {
		Font = Enum.Font.GothamBold, TextSize = 12, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(120, 26), Text = "",
	}, row)
	onTheme(function()
		nameLabel.Text = CurrentTheme
		nameLabel.TextColor3 = THEME.Accent
	end)

	local holder = new("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 24),
	}, row)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }, holder)
	for _, name in ipairs(PRESET_ORDER) do
		local b = new("TextButton", {
			Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(24, 24), BackgroundColor3 = PRESETS[name][1],
		}, holder)
		corner(b, 12)
		stroke(b, THEME.White, 0.6, 1)
		b.Activated:Connect(function() applyTheme(name) end)
	end
end

-- Pages
local espPage      = makePage("ESP", 1)
local aimPage      = makePage("Aim", 2)
local combatPage   = makePage("Combat", 3)
local movePage     = makePage("Move", 4)
local worldPage    = makePage("World", 5)
local safetyPage   = makePage("Safety", 6)
local cosmeticPage = makePage("Cosmetics", 7)
local playersPage  = makePage("Players", 8)
local miscPage     = makePage("Misc", 9)

-- ESP
addSection(espPage, "Body highlight")
addToggle(espPage, "ESP Murderer (Red)", Config.ESP.Murderer, function(v) Config.ESP.Murderer = v end, "ESP.Murderer")
addToggle(espPage, "ESP Sheriff (Blue)", Config.ESP.Sheriff, function(v) Config.ESP.Sheriff = v end, "ESP.Sheriff")
addToggle(espPage, "ESP Dropped Gun (Yellow)", Config.ESP.Gun, function(v) Config.ESP.Gun = v end, "ESP.Gun")
addToggle(espPage, "Tracer Lines", Config.ESP.Tracers, function(v) Config.ESP.Tracers = v end, "ESP.Tracers")
addInfo(espPage, "Highlights the whole body and shows the player's name through walls. Tracers only draw to the roles you turn on.")
addSection(espPage, "Round announcer")
addToggle(espPage, "On-Screen Notification", Config.ESP.Toast, function(v) Config.ESP.Toast = v end, "ESP.Toast")
addToggle(espPage, "Local Chat Message", Config.ESP.Chat, function(v) Config.ESP.Chat = v end, "ESP.Chat")

-- Aim
local AimBtn
addSection(aimPage, "Smooth aimlock")
addToggle(aimPage, "Enable Aimlock", Config.Aim.Enabled, function(v)
	Config.Aim.Enabled = v
	if AimBtn then AimBtn.Visible = v end
end, "Aim.Enabled")
addSlider(aimPage, "Lock Speed (low = smoother)", 1, 30, Config.Aim.Speed, 1, function(v) Config.Aim.Speed = v end)
addToggle(aimPage, "Movement Prediction", Config.Aim.Prediction, function(v) Config.Aim.Prediction = v end, "Aim.Prediction")
addToggle(aimPage, "Touch: Hold Screen To Aim", Config.Aim.TouchHold, function(v) Config.Aim.TouchHold = v end, "Aim.TouchHold")
addSection(aimPage, "Silent aim")
addToggle(aimPage, "Enable Silent Aim", Config.Silent.Enabled, function(v) Config.Silent.Enabled = v end, "Silent.Enabled")
addSlider(aimPage, "FOV Radius (px)", 30, 400, Config.Silent.FOV, 5, function(v) Config.Silent.FOV = v end)
addToggle(aimPage, "Show FOV Circle", Config.Silent.ShowFOV, function(v) Config.Silent.ShowFOV = v end, "Silent.ShowFOV")
addInfo(aimPage, (RemoteHookOK and IndexHookOK) and "Silent aim: remote + mouse hooks ACTIVE. Shots go to the Murderer while they are inside the circle."
	or HookOK and ("Silent aim: " .. (RemoteHookOK and "remote" or "mouse") .. " hook ACTIVE (other hook unavailable).")
	or "Silent aim: no hook support in this executor, using tap/click fallback (taps fire the gun at the Murderer).")
addSection(aimPage, "Auto-shoot")
addToggle(aimPage, "Auto-Shoot Murderer", Config.Auto.Enabled, function(v) Config.Auto.Enabled = v end, "Auto.Enabled")
addSlider(aimPage, "Trigger Radius (px)", 5, 200, Config.Auto.Radius, 1, function(v) Config.Auto.Radius = v end)
addToggle(aimPage, "Wall Check", Config.Auto.WallCheck, function(v) Config.Auto.WallCheck = v end, "Auto.WallCheck")
addInfo(aimPage, "Fires when the Murderer is in your crosshair with a clear line of sight (Gun equipped).")

-- Combat
addSection(combatPage, "Hitbox multiplier")
addToggle(combatPage, "Enable Hitbox", Config.Hitbox.Enabled, function(v)
	Config.Hitbox.Enabled = v
	if not v then
		for plr in pairs(HB) do restoreHitbox(plr) end
	end
end)
addSlider(combatPage, "Hitbox Size", 2, 30, Config.Hitbox.Size, 1, function(v) Config.Hitbox.Size = v end)
addCycle(combatPage, "Target", { "Murderer", "All Players" }, Config.Hitbox.Target, function(v) Config.Hitbox.Target = v end)
addSection(combatPage, "Reach modifier")
addToggle(combatPage, "Enable Reach", Config.Reach.Enabled, function(v) Config.Reach.Enabled = v end, "Reach.Enabled")
addSlider(combatPage, "Reach Size", 2, 30, Config.Reach.Size, 1, function(v) Config.Reach.Size = v end)
addCycle(combatPage, "Tool", { "Knife", "Gun", "Both" }, Config.Reach.Tool, function(v) Config.Reach.Tool = v end)
addInfo(combatPage, "Reach enlarges the tool handle. Whether hits count depends on how the game validates them.")
addSection(combatPage, "Murderer tools")
addToggle(combatPage, "Auto Kill All", Config.Kill.Enabled, function(v)
	Config.Kill.Enabled = v
	if v then startKillAll() end
end)
addSlider(combatPage, "Stab Delay (sec)", 0.1, 1, Config.Kill.Delay, 0.05, function(v) Config.Kill.Delay = v end)
addToggle(combatPage, "Return To Start When Done", Config.Kill.Return, function(v) Config.Kill.Return = v end, "Kill.Return")
addInfo(combatPage, "Hold the Knife: teleports behind every living player from any distance and stabs, rechecking until nobody is left, then shows VICTORY.")

-- Move
addSection(movePage, "Speed & jump")
addToggle(movePage, "Custom WalkSpeed", Config.Move.WalkEnabled, function(v) Config.Move.WalkEnabled = v end, "Move.WalkEnabled")
addSlider(movePage, "WalkSpeed", 16, 150, Config.Move.WalkSpeed, 1, function(v) Config.Move.WalkSpeed = v end)
addToggle(movePage, "Custom JumpPower", Config.Move.JumpEnabled, function(v) Config.Move.JumpEnabled = v end, "Move.JumpEnabled")
addSlider(movePage, "JumpPower", 50, 250, Config.Move.JumpPower, 1, function(v) Config.Move.JumpPower = v end)
addSection(movePage, "Mobility")
addToggle(movePage, "Infinite Jump", Config.Move.InfJump, function(v) Config.Move.InfJump = v end, "Move.InfJump")
addToggle(movePage, "Noclip", Config.Move.Noclip, function(v) Config.Move.Noclip = v end, "Move.Noclip")
addSection(movePage, "Gun pickup")
addToggle(movePage, "Auto-Grab Dropped Gun", Config.Move.AutoGun, function(v) Config.Move.AutoGun = v end, "Move.AutoGun")
addToggle(movePage, "Return After Pickup", Config.Move.ReturnAfter, function(v) Config.Move.ReturnAfter = v end, "Move.ReturnAfter")

-- World
addSection(worldPage, "Lighting")
addToggle(worldPage, "Fullbright", Config.World.Fullbright, function(v) Config.World.Fullbright = v end, "World.Fullbright")
addToggle(worldPage, "Remove Fog", Config.World.NoFog, function(v) Config.World.NoFog = v end, "World.NoFog")
addSection(worldPage, "Performance")
addToggle(worldPage, "FPS Booster", Config.World.FPS, function(v)
	Config.World.FPS = v
	setFPS(v)
end)
addInfo(worldPage, "FPS Booster flattens materials, hides decals/particles and disables shadows. Turning it off restores them.")

-- Safety
addSection(safetyPage, "Anti-detection")
addToggle(safetyPage, "Anti-Aim (random body rotation)", Config.AntiAim.Enabled, function(v) Config.AntiAim.Enabled = v end, "AntiAim.Enabled")
addInfo(safetyPage, "Decouples which way your character visually faces from your real movement, to throw off aim-predicting players or bots. It does not change your hitbox or movement.")
addSection(safetyPage, "Server")
addButton(safetyPage, "Rejoin This Server", rejoinServer)
addButton(safetyPage, "Hop To A New Server", hopServer)
addToggle(safetyPage, "Anti-AFK Kicker", Config.System.AntiAFK, function(v)
	Config.System.AntiAFK = v
	setAntiAFK(v)
end, "System.AntiAFK")
addSection(safetyPage, "Menu keybind")
addCycle(safetyPage, "Toggle Menu Key", MENU_KEYS, "RightShift", function(v) MenuKey = Enum.KeyCode[v] end)
addSection(safetyPage, "Config file")
addButton(safetyPage, "Save Config", saveConfig)
addButton(safetyPage, "Load Config", function() loadConfig(false) end)
addInfo(safetyPage, "Saving/loading needs an executor with file support (writefile/readfile). Your last saved config loads automatically on startup.")

-- Cosmetics
addSection(cosmeticPage, "Weapon trail")
addToggle(cosmeticPage, "Knife / Gun Trail", Config.Cosmetic.Trail, function(v) Config.Cosmetic.Trail = v end, "Cosmetic.Trail")
addInfo(cosmeticPage, "Adds a glowing trail to whatever tool you're holding, in your current accent colors. Visible to you only.")
addSection(cosmeticPage, "Kill effects")
addToggle(cosmeticPage, "Kill Particle + Sound", Config.Cosmetic.KillFX, function(v) Config.Cosmetic.KillFX = v end, "Cosmetic.KillFX")
addInput(cosmeticPage, "Kill Sound ID", Config.Cosmetic.KillSoundId, "rbxassetid://... (optional)",
	function(text) Config.Cosmetic.KillSoundId = text end, "Cosmetic.KillSoundId")
addInfo(cosmeticPage, "Plays locally whenever a player dies while you're the Murderer or Sheriff. Leave the Sound ID blank for particles only.")
addInfo(cosmeticPage, "No weapon-skin changer: real MM2 skins are paid Roblox assets and we don't have their IDs to swap in correctly. The trail above is a safe stand-in.")

-- Players
addSection(playersPage, "Target lock")
local targetListFrame = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
}, playersPage)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, targetListFrame)

local targetInfoRow = makeRow(playersPage, 76)
local targetNameLabel = new("TextLabel", {
	Text = "No target selected", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.Text,
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18),
}, targetInfoRow)
local targetDistLabel = new("TextLabel", {
	Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = THEME.Sub, BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 16),
}, targetInfoRow)
local targetItemLabel = new("TextLabel", {
	Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = THEME.Sub, BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 16),
}, targetInfoRow)
local targetHealthLabel = new("TextLabel", {
	Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = THEME.Sub, BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 16),
}, targetInfoRow)

local function rebuildTargetList()
	targetListFrame:ClearAllChildren()
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, targetListFrame)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local row = makeRow(targetListFrame, 30)
			local btn = new("TextButton", {
				Text = plr.DisplayName, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.Text,
				AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
			}, row)
			new("UIPadding", { PaddingLeft = UDim.new(0, 12) }, btn)
			btn.Activated:Connect(function()
				Target = plr
				rebuildTargetList()
			end)
			if plr == Target then stroke(row, THEME.Accent, 0.3, 1) end
		end
	end
end
rebuildTargetList()
track(Players.PlayerAdded:Connect(rebuildTargetList))
track(Players.PlayerRemoving:Connect(function(plr)
	if Target == plr then Target = nil end
	task.defer(rebuildTargetList)
end))

TargetInfoRefresh = function()
	if not Target or not Target.Parent then
		targetNameLabel.Text, targetDistLabel.Text, targetItemLabel.Text, targetHealthLabel.Text = "No target selected", "", "", ""
		return
	end
	local char = Target.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")

	targetNameLabel.Text = Target.DisplayName .. " (" .. (RoleCache[Target] or "Innocent") .. ")"
	targetDistLabel.Text = (hrp and myRoot) and ("Distance: " .. math.floor((hrp.Position - myRoot.Position).Magnitude) .. " studs") or "Distance: --"
	local tool = char and char:FindFirstChildWhichIsA("Tool")
	targetItemLabel.Text = "Holding: " .. (tool and tool.Name or "None")
	targetHealthLabel.Text = hum and ("Health: " .. math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)) or "Health: --"
end

addSection(playersPage, "Spectate")
addToggle(playersPage, "Spectate Enabled", Config.Spectate.Enabled, function(v) Config.Spectate.Enabled = v end, "Spectate.Enabled")
addCycle(playersPage, "Spectate Target", { "Murderer", "Sheriff" }, Config.Spectate.Target, function(v) Config.Spectate.Target = v end, "Spectate.Target")
addInfo(playersPage, "Switches your camera to whoever holds the Knife or Gun. Works even after you die; turn it off to return to normal.")

addSection(playersPage, "Player watchlist")
addInput(playersPage, "Add Username", "", "exact username", function(text)
	text = text:gsub("%s+", "")
	if text ~= "" then
		WatchList[string.lower(text)] = true
		notify("Added to watchlist: " .. text, THEME.Accent)
		if WatchListRefresh then WatchListRefresh() end
	end
end)
local watchListFrame = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
}, playersPage)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, watchListFrame)
WatchListRefresh = function()
	watchListFrame:ClearAllChildren()
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, watchListFrame)
	for name in pairs(WatchList) do
		local row = makeRow(watchListFrame, 30)
		new("TextLabel", {
			Text = name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.Text,
			BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -44, 1, 0),
		}, row)
		local x = new("TextButton", {
			Text = "x", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.Sub, AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
		}, row)
		x.Activated:Connect(function()
			WatchList[name] = nil
			WatchListRefresh()
		end)
	end
end
addToggle(playersPage, "Enable Watchlist Alerts", Config.Watch.Enabled, function(v) Config.Watch.Enabled = v end, "Watch.Enabled")
addToggle(playersPage, "Auto-Hop On Match", Config.Watch.AutoHop, function(v) Config.Watch.AutoHop = v end, "Watch.AutoHop")
addInfo(playersPage, "Matches only the exact usernames you add above. There's no reliable way to detect Roblox staff or \"flagged\" accounts from a script, so this can't do that.")


--// EXTRAS: X-Ray, map teleports, death replay, murderer profiler, lead dot, knife predictor, auto-dodge
-- Kept inside one function so it doesn't use up the script's 200-local limit.
xpcall(function()
	local X = Config.Extras
	local Workspace = workspace
	local Debris = game:GetService("Debris")

	local cleanups = {}
	local function onCleanup(f) cleanups[#cleanups + 1] = f end
	track({ Disconnect = function() for _, f in ipairs(cleanups) do pcall(f) end end })

	local function myRoot()
		local c = LP.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local function myHum()
		local c = LP.Character
		return c and c:FindFirstChildOfClass("Humanoid")
	end

	-- Client-side scratch folder for 3D drawings (trajectory arc, replay ghosts)
	local Draw = Instance.new("Folder")
	Draw.Name = "ForgeDraw"
	Draw.Parent = Workspace
	onCleanup(function() Draw:Destroy() end)

	local rayP = RaycastParams.new()
	rayP.FilterType = Enum.RaycastFilterType.Exclude
	local function setFilter(...)
		local t = { Draw }
		local c = LP.Character
		if c then t[#t + 1] = c end
		for _, inst in ipairs({ ... }) do t[#t + 1] = inst end
		rayP.FilterDescendantsInstances = t
	end

	-- Target velocity tracker (from real position history, more reliable than AssemblyLinearVelocity on other players)
	local hist = setmetatable({}, { __mode = "k" })
	track(RunService.Heartbeat:Connect(function()
		if not (X.AutoThrow or X.Lead) then return end
		local now = os.clock()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LP then
				local hrp = aliveRoot(plr)
				local h = hist[plr]
				if hrp then
					if not h then h = {} hist[plr] = h end
					h[#h + 1] = { t = now, p = hrp.Position }
					while #h > 0 and now - h[1].t > 0.8 do table.remove(h, 1) end
				elseif h then
					hist[plr] = nil
				end
			end
		end
	end))

	local function sampleAt(h, tt)
		for i = 1, #h do
			if h[i].t >= tt then return h[i] end
		end
		return h[#h]
	end

	-- returns horizontal velocity and whether the target has been moving steadily (not turning / starting / stopping)
	local function getVel(plr)
		local h = hist[plr]
		if not h or #h < 6 then
			local hrp = aliveRoot(plr)
			if hrp then
				local v = hrp.AssemblyLinearVelocity
				return Vector3.new(v.X, 0, v.Z), true
			end
			return Vector3.zero, true
		end
		local a = h[#h]
		local b, c = sampleAt(h, a.t - 0.25), sampleAt(h, a.t - 0.5)
		local dt1, dt0 = a.t - b.t, b.t - c.t
		if dt1 < 0.05 then return Vector3.zero, true end
		local v1 = (a.p - b.p) / dt1
		v1 = Vector3.new(v1.X, 0, v1.Z)
		local stable = true
		if dt0 > 0.05 then
			local v0 = (b.p - c.p) / dt0
			v0 = Vector3.new(v0.X, 0, v0.Z)
			local m1, m0 = v1.Magnitude, v0.Magnitude
			if m1 > 4 and m0 > 4 then
				stable = (v1:Dot(v0) / (m1 * m0)) > 0.8 and math.abs(m1 - m0) < 6
			elseif math.abs(m1 - m0) > 8 then
				stable = false
			end
		end
		return v1, stable
	end

	local function getPing()
		local ok, p = pcall(function() return LP:GetNetworkPing() end)
		if not ok or type(p) ~= "number" then return 0.08 end
		return math.clamp(p, 0, 0.4)
	end

	------------------------------------------------------------------
	-- 1) X-RAY VISION: makes big map parts (walls/floors) see-through, client-side only
	------------------------------------------------------------------
	local xrayOrig = setmetatable({}, { __mode = "k" }) -- part -> original LocalTransparencyModifier
	local xrayToken = 0

	local function xrayEligible(p)
		if not p:IsA("BasePart") or p:IsA("Terrain") then return false end
		if p.Transparency >= 0.95 or p.Size.Magnitude < 7 then return false end
		local m = p:FindFirstAncestorOfClass("Model")
		if m and m:FindFirstChildOfClass("Humanoid") then return false end
		return true
	end
	local function xrayApply(p)
		if xrayOrig[p] == nil then xrayOrig[p] = p.LocalTransparencyModifier end
		p.LocalTransparencyModifier = X.XRayAlpha
	end
	local function xrayScan()
		xrayToken += 1
		local mine = xrayToken
		task.spawn(function()
			local n = 0
			for _, d in ipairs(Workspace:GetDescendants()) do
				if mine ~= xrayToken or not X.XRay then return end
				if xrayEligible(d) then pcall(xrayApply, d) end
				n += 1
				if n % 400 == 0 then task.wait() end
			end
		end)
	end
	local function xrayRestore()
		xrayToken += 1
		for p, v in pairs(xrayOrig) do
			pcall(function() p.LocalTransparencyModifier = v end)
			xrayOrig[p] = nil
		end
	end
	local function xrayRetint()
		for p in pairs(xrayOrig) do
			pcall(function() p.LocalTransparencyModifier = X.XRayAlpha end)
		end
	end
	onCleanup(xrayRestore)

	track(Workspace.DescendantAdded:Connect(function(d)
		if X.XRay and d:IsA("BasePart") then
			task.defer(function()
				if X.XRay and d.Parent and xrayEligible(d) then pcall(xrayApply, d) end
			end)
		end
	end))

	local xrayOn, xrayShownAlpha, xrayAcc = false, nil, 0
	track(RunService.Heartbeat:Connect(function(dt)
		xrayAcc += dt
		if xrayAcc < 0.4 then return end
		xrayAcc = 0
		if X.XRay and not xrayOn then
			xrayOn, xrayShownAlpha = true, X.XRayAlpha
			xrayScan()
		elseif not X.XRay and xrayOn then
			xrayOn = false
			xrayRestore()
		elseif xrayOn and xrayShownAlpha ~= X.XRayAlpha then
			xrayShownAlpha = X.XRayAlpha
			xrayRetint()
		end
	end))

	------------------------------------------------------------------
	-- 2) MAP TELEPORTS (auto-scans the loaded map + per-map saved spots)
	------------------------------------------------------------------
	local prevCF
	local slots, slotSel = {}, 1

	local function findMap()
		local cc = Workspace:FindFirstChild("CoinContainer", true)
		if cc and cc.Parent and cc.Parent ~= Workspace then return cc.Parent end
		for _, m in ipairs(Workspace:GetChildren()) do
			if m:IsA("Model") and not Players:GetPlayerFromCharacter(m)
				and (m:FindFirstChild("Spawns") or m:FindFirstChild("Spawn")) then
				return m
			end
		end
		return nil
	end

	local function teleportTo(pos, label)
		local hrp = myRoot()
		if not hrp then notify("No character to teleport", THEME.Sub) return end
		prevCF = hrp.CFrame
		hrp.CFrame = CFrame.new(pos)
		hrp.AssemblyLinearVelocity = Vector3.zero
		notify("Teleported: " .. label, THEME.Accent)
	end

	local function collectCandidates(map)
		local list = {}
		for _, d in ipairs(map:GetDescendants()) do
			if d:IsA("BasePart") and d.CanCollide and d.Transparency < 0.9 and d.Size.X >= 3 and d.Size.Z >= 3 then
				list[#list + 1] = { pos = Vector3.new(d.Position.X, d.Position.Y + d.Size.Y / 2 + 3.2, d.Position.Z), part = d }
				if #list >= 2500 then break end
			end
		end
		return list
	end

	local function validSpot(c)
		setFilter()
		local down = Workspace:Raycast(c.pos + Vector3.new(0, 1, 0), Vector3.new(0, -6, 0), rayP)
		if not down or down.Normal.Y < 0.7 then return false end
		if Workspace:Raycast(c.pos, Vector3.new(0, 5, 0), rayP) then return false end
		return true
	end

	local DIRS = {}
	for i = 0, 7 do
		local a = math.rad(i * 45)
		DIRS[i + 1] = Vector3.new(math.cos(a), 0, math.sin(a))
	end
	local function enclosure(pos) -- how many of 8 directions are blocked within 10 studs (higher = more hidden nook)
		setFilter()
		local n = 0
		for _, d in ipairs(DIRS) do
			if Workspace:Raycast(pos + Vector3.new(0, 1, 0), d * 10, rayP) then n += 1 end
		end
		return n
	end

	local function runTeleport(kind)
		local map = findMap()
		if not map then notify("No map found (is a round running?)", THEME.Sub) return end
		local hrp = myRoot()
		if not hrp then return end

		if kind == "spawn" then
			local sp = map:FindFirstChild("Spawns") or map:FindFirstChild("Spawn")
			local parts = {}
			if sp then
				for _, c in ipairs(sp:GetDescendants()) do
					if c:IsA("BasePart") then parts[#parts + 1] = c end
				end
			end
			if #parts == 0 then notify("No spawn points found on " .. map.Name, THEME.Sub) return end
			teleportTo(parts[math.random(#parts)].Position + Vector3.new(0, 4, 0), "spawn (" .. map.Name .. ")")
			return
		end

		local list = collectCandidates(map)
		if #list == 0 then notify("Couldn't read this map's geometry", THEME.Sub) return end
		local mr = Murderer and aliveRoot(Murderer)
		local ref = mr and mr.Position or hrp.Position
		for _, c in ipairs(list) do c.d = (c.pos - ref).Magnitude end

		if kind == "high" then
			table.sort(list, function(a, b) return a.pos.Y > b.pos.Y end)
			for i = 1, math.min(#list, 250) do
				if validSpot(list[i]) then teleportTo(list[i].pos, "high ground (" .. map.Name .. ")") return end
			end
		elseif kind == "far" then
			table.sort(list, function(a, b) return a.d > b.d end)
			for i = 1, math.min(#list, 250) do
				if validSpot(list[i]) then
					teleportTo(list[i].pos, (mr and "farthest from Murderer" or "farthest from you") .. " (" .. map.Name .. ")")
					return
				end
			end
		elseif kind == "hide" then
			for i = #list, 2, -1 do
				local j = math.random(i)
				list[i], list[j] = list[j], list[i]
			end
			local best, bestScore
			for i = 1, math.min(#list, 220) do
				local c = list[i]
				if validSpot(c) then
					local score = enclosure(c.pos) * 8 + math.min(c.d, 150) * 0.25
					if not bestScore or score > bestScore then best, bestScore = c, score end
				end
			end
			if best then teleportTo(best.pos, "hideout (" .. map.Name .. ")") return end
		end
		notify("No suitable spot found", THEME.Sub)
	end

	local function slotKey()
		local m = findMap()
		return (m and m.Name or "?") .. ":" .. slotSel
	end

	------------------------------------------------------------------
	-- 3) DEATH / REPLAY CAMERA (records the last 5s of every player, replays top-down)
	------------------------------------------------------------------
	local REC_SECONDS, REC_HZ = 5, 10
	local rec, recAcc = {}, 0
	local replaying, ghosts, replayLabel = false, {}, nil

	track(RunService.Heartbeat:Connect(function(dt)
		if replaying or not X.DeathCam then return end
		recAcc += dt
		if recAcc < 1 / REC_HZ then return end
		recAcc = 0
		local h = myHum()
		if not h or h.Health <= 0 then return end -- keep the footage from before we died
		local frame = { t = os.clock(), d = {}, role = {} }
		for _, plr in ipairs(Players:GetPlayers()) do
			local hrp = aliveRoot(plr)
			if hrp then
				frame.d[plr] = hrp.CFrame
				frame.role[plr] = RoleCache[plr] or "Innocent"
			end
		end
		rec[#rec + 1] = frame
		while #rec > 1 and rec[#rec].t - rec[1].t > REC_SECONDS do table.remove(rec, 1) end
	end))

	local function stopReplay()
		if not replaying then return end
		replaying = false
		pcall(function() RunService:UnbindFromRenderStep("ForgeReplay") end)
		for _, g in pairs(ghosts) do pcall(function() g:Destroy() end) end
		ghosts = {}
		if replayLabel then pcall(function() replayLabel:Destroy() end) replayLabel = nil end
		local c = Workspace.CurrentCamera
		if c then
			c.CameraType = Enum.CameraType.Custom
			local h = myHum()
			if h then c.CameraSubject = h end
		end
	end
	onCleanup(stopReplay)

	local function startReplay()
		if replaying then return end
		if #rec < 8 then notify("Not enough footage recorded yet", THEME.Sub) return end
		local c0 = Workspace.CurrentCamera
		if not c0 then return end
		local frames = rec
		rec = {}
		replaying = true
		c0.CameraType = Enum.CameraType.Scriptable

		for _, f in ipairs(frames) do
			for plr in pairs(f.d) do
				if not ghosts[plr] then
					local role = f.role[plr]
					local col = (plr == LP) and Color3.new(1, 1, 1) or (ROLE_COLORS[role] or ROLE_COLORS.Innocent)
					local g = Instance.new("Part")
					g.Shape = Enum.PartType.Ball
					g.Size = Vector3.new(3, 3, 3)
					g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
					g.Material = Enum.Material.Neon
					g.Color = col
					g.Transparency = 0.15
					g.Parent = Draw
					local bb = Instance.new("BillboardGui")
					bb.Size = UDim2.fromOffset(120, 20)
					bb.StudsOffset = Vector3.new(0, 3, 0)
					bb.AlwaysOnTop = true
					bb.Adornee = g
					bb.Parent = g
					local tl = Instance.new("TextLabel")
					tl.Size = UDim2.fromScale(1, 1)
					tl.BackgroundTransparency = 1
					tl.Text = (plr == LP) and "YOU" or plr.DisplayName
					tl.TextColor3 = col
					tl.Font = Enum.Font.GothamBold
					tl.TextSize = 13
					tl.TextStrokeTransparency = 0.4
					tl.Parent = bb
					if plr == LP or role == "Murderer" then
						local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
						a0.Position, a1.Position = Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)
						a0.Parent, a1.Parent = g, g
						local tr = Instance.new("Trail")
						tr.Attachment0, tr.Attachment1 = a0, a1
						tr.Lifetime = 1.5
						tr.Color = ColorSequence.new(col)
						tr.Transparency = NumberSequence.new(0.2, 1)
						tr.LightEmission = 1
						tr.Parent = g
					end
					ghosts[plr] = g
				end
			end
		end

		replayLabel = new("TextButton", {
			Text = "REPLAY  -  last 5s  (tap to skip)", Font = Enum.Font.GothamBold, TextSize = 14,
			TextColor3 = THEME.Text, BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.25,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70),
			Size = UDim2.fromOffset(280, 30), AutoButtonColor = false, ZIndex = 50,
		}, Gui)
		corner(replayLabel, 8)
		replayLabel.Activated:Connect(stopReplay)

		local t0 = frames[1].t
		local duration = frames[#frames].t - t0
		local elapsed, loops, focus = 0, 2, nil

		RunService:BindToRenderStep("ForgeReplay", Enum.RenderPriority.Camera.Value + 2, function(dt)
			elapsed += dt
			if elapsed > duration + 0.5 then
				loops -= 1
				if loops <= 0 then stopReplay() return end
				elapsed = 0
			end
			local t = math.min(elapsed, duration)
			local i = 1
			while i < #frames - 1 and frames[i + 1].t - t0 < t do i += 1 end
			local f1, f2 = frames[i], frames[i + 1]
			local span = f2.t - f1.t
			local a = span > 0 and math.clamp((t - (f1.t - t0)) / span, 0, 1) or 0

			local myPos, killerPos
			for plr, g in pairs(ghosts) do
				local c1, c2 = f1.d[plr], f2.d[plr]
				local cf = c1 and (c2 and c1:Lerp(c2, a) or c1) or c2
				if cf then
					g.CFrame = cf
					g.Transparency = 0.15
					if plr == LP then myPos = cf.Position end
					if plr ~= LP and f1.role[plr] == "Murderer" then killerPos = cf.Position end
				else
					g.Transparency = 1
				end
			end

			local target, sep = myPos or killerPos, 0
			if myPos and killerPos then
				target = (myPos + killerPos) / 2
				sep = (myPos - killerPos).Magnitude
			end
			if not target then return end
			focus = focus and focus:Lerp(target, 1 - math.exp(-6 * dt)) or target
			local height = 45 + sep * 0.6
			local yaw = elapsed * 0.35
			local off = Vector3.new(math.sin(yaw) * height * 0.3, height, math.cos(yaw) * height * 0.3)
			local cam = Workspace.CurrentCamera
			if cam then
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = CFrame.lookAt(focus + off, focus)
			end
		end)
	end

	local diedConn
	local function hookChar(ch)
		local hum = ch:WaitForChild("Humanoid", 10)
		if not hum then return end
		if diedConn then diedConn:Disconnect() end
		diedConn = hum.Died:Connect(function()
			if X.DeathCam then task.delay(0.1, startReplay) end
		end)
	end
	if LP.Character then task.spawn(hookChar, LP.Character) end
	track(LP.CharacterAdded:Connect(function(ch)
		stopReplay()
		rec = {}
		hookChar(ch)
	end))
	onCleanup(function() if diedConn then diedConn:Disconnect() end end)

	------------------------------------------------------------------
	-- 4) MURDERER PLAYSTYLE PROFILER
	------------------------------------------------------------------
	local prof = { plr = nil, samples = {}, throws = {}, acc = 0, lastClass = nil, lastAlert = 0 }

	track(RunService.Heartbeat:Connect(function(dt)
		if not X.Profiler then return end
		prof.acc += dt
		if prof.acc < 0.25 then return end
		prof.acc = 0

		local m = Murderer
		if m ~= prof.plr then
			prof.plr, prof.samples, prof.throws, prof.lastClass = m, {}, {}, nil
		end
		if not m then return end
		local hrp = aliveRoot(m)
		if not hrp then return end

		local now = os.clock()
		local v = hrp.AssemblyLinearVelocity
		local nd = math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= m then
				local r = aliveRoot(p)
				if r then nd = math.min(nd, (r.Position - hrp.Position).Magnitude) end
			end
		end
		prof.samples[#prof.samples + 1] = { t = now, speed = Vector3.new(v.X, 0, v.Z).Magnitude, near = nd }
		while #prof.samples > 0 and now - prof.samples[1].t > 25 do table.remove(prof.samples, 1) end
		while #prof.throws > 0 and now - prof.throws[1] > 25 do table.remove(prof.throws, 1) end
		if #prof.samples < 40 then return end -- need roughly 10s of data first

		local still, sum, closing, n = 0, 0, 0, #prof.samples
		for i, s in ipairs(prof.samples) do
			sum += s.speed
			if s.speed < 2 then still += 1 end
			if i > 1 and s.near < prof.samples[i - 1].near and s.speed > 8 then closing += 1 end
		end
		local avg, stillR, closeR = sum / n, still / n, closing / n

		local class
		if #prof.throws >= 2 then class = "Knife Thrower"
		elseif stillR > 0.5 then class = "Camper"
		elseif avg > 13 and closeR > 0.35 then class = "Aggressive Rusher"
		else class = "Roamer" end

		if class ~= prof.lastClass and now - prof.lastAlert > 12 then
			prof.lastClass, prof.lastAlert = class, now
			notify(m.DisplayName .. ": " .. class, ROLE_COLORS.Murderer)
			chatSay("[Forge] Murderer profile - " .. m.DisplayName .. " looks like a " .. class, ROLE_COLORS.Murderer)
		end
	end))

	------------------------------------------------------------------
	-- 5) SHERIFF LEAD INDICATOR (dot ahead of the Murderer's velocity)
	------------------------------------------------------------------
	local leadLine = new("Frame", {
		Name = "ForgeLeadLine", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = Color3.fromRGB(255, 90, 90), BackgroundTransparency = 0.4, BorderSizePixel = 0,
		Visible = false, ZIndex = 5,
	}, Gui)
	local leadDot = new("Frame", {
		Name = "ForgeLead", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.fromRGB(255, 60, 60), BorderSizePixel = 0, Visible = false, ZIndex = 6,
	}, Gui)
	corner(leadDot, 6)
	stroke(leadDot, Color3.new(1, 1, 1), 0.1, 1.5)

	track(RunService.RenderStepped:Connect(function()
		local show = false
		local m = Murderer
		local cam = Workspace.CurrentCamera
		if X.Lead and m and cam and holdingGun() then
			local hrp = aliveRoot(m)
			if hrp then
				local v = getVel(m)
				local dist = (hrp.Position - cam.CFrame.Position).Magnitude
				local t = X.LeadTime + dist / 300 -- base lead + rough bullet flight time
				local leadPos = hrp.Position + Vector3.new(v.X, 0, v.Z) * t
				local a, onA = cam:WorldToViewportPoint(hrp.Position)
				local b, onB = cam:WorldToViewportPoint(leadPos)
				if onB and b.Z > 0 then
					show = true
					leadDot.Position = UDim2.fromOffset(b.X, b.Y)
					if onA then
						local d = Vector2.new(b.X - a.X, b.Y - a.Y)
						leadLine.Size = UDim2.fromOffset(d.Magnitude, 2)
						leadLine.Position = UDim2.fromOffset(a.X + d.X / 2, a.Y + d.Y / 2)
						leadLine.Rotation = math.deg(math.atan2(d.Y, d.X))
						leadLine.Visible = d.Magnitude > 4
					else
						leadLine.Visible = false
					end
				end
			end
		end
		leadDot.Visible = show
		if not show then leadLine.Visible = false end
	end))

	------------------------------------------------------------------
	-- 6 + 7) KNIFE TRAJECTORY PREDICTOR + AUTO-DODGE
	-- Detection is heuristic: any moving part/model with "knife" in its name that is not held by a player.
	------------------------------------------------------------------
	local knives = {}
	local STEP = 0.04
	local HIT_RADIUS = 3.0
	local OFFS = { 0, 1.6, -1.6 }
	local pool, marker = {}, nil
	local dodgeUntil = 0
	local knifeSpeedEst, knifeGravEst = nil, nil -- learned from your own thrown knives

	local function heldByPlayer(part)
		local tool = part:FindFirstAncestorOfClass("Tool")
		if tool then
			local par = tool.Parent
			if par and (par:IsA("Backpack") or par:FindFirstChildOfClass("Humanoid")) then return true end
		end
		local m = part:FindFirstAncestorOfClass("Model")
		if m and m:FindFirstChildOfClass("Humanoid") then return true end
		if part:FindFirstAncestorOfClass("Backpack") then return true end
		return false
	end

	local function registerKnife(inst, kind)
		if not inst.Parent then return end
		local part = inst:IsA("BasePart") and inst
			or (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)))
		if not part or knives[part] or heldByPlayer(part) then return end
		local nearest, nd = nil, math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local d = (r.Position - part.Position).Magnitude
				if d < nd then nd, nearest = d, p end
			end
		end
		knives[part] = {
			inst = inst, part = part, kind = kind or "knife", pos = part.Position, vel = Vector3.zero, accY = 0,
			born = os.clock(), thrower = nearest, mine = (nearest == LP),
			hasPrev = false, confirmed = false, warned = false, slowSince = nil,
		}
	end

	local function projectileKind(name)
		name = string.lower(name)
		if string.find(name, "knife", 1, true) then return "knife" end
		if string.find(name, "bullet", 1, true) then return "bullet" end
		return nil
	end

	track(Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") or d:IsA("Model") then
			local kind = projectileKind(d.Name)
			if kind then task.defer(registerKnife, d, kind) end
		end
	end))

	local function ensurePool()
		if #pool > 0 then return end
		for i = 1, 40 do
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Material = Enum.Material.Neon
			p.Size = Vector3.new(0.2, 0.2, 1)
			p.Transparency = 1
			p.Parent = Draw
			pool[i] = p
		end
		marker = Instance.new("Part")
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(1.6, 1.6, 1.6)
		marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch, marker.CastShadow = true, false, false, false, false
		marker.Material = Enum.Material.Neon
		marker.Transparency = 1
		marker.Parent = Draw
	end

	local function hidePath()
		for _, p in ipairs(pool) do p.Transparency = 1 end
		if marker then marker.Transparency = 1 end
	end

	local function drawPath(points, hit, danger)
		ensurePool()
		local col = danger and Color3.fromRGB(255, 50, 50) or THEME.Accent
		local n = #points
		for i = 1, #pool do
			local seg = pool[i]
			if i < n then
				local a, b = points[i], points[i + 1]
				local len = (b - a).Magnitude
				if len > 0.01 then
					seg.Size = Vector3.new(0.2, 0.2, len)
					seg.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
					seg.Color = col
					seg.Transparency = 0.1 + 0.6 * (i / n)
				else
					seg.Transparency = 1
				end
			else
				seg.Transparency = 1
			end
		end
		if hit then
			marker.Position = hit
			marker.Color = col
			marker.Transparency = 0.2
		else
			marker.Transparency = 1
		end
	end

	local function simulate(k)
		local filter = { k.inst }
		if k.thrower and k.thrower.Character then filter[#filter + 1] = k.thrower.Character end
		setFilter(table.unpack(filter))
		local g = (k.accY < -Workspace.Gravity * 0.5) and k.accY or 0 -- only arc if it really is falling
		local pts, p, v, hit = { k.pos }, k.pos, k.vel, nil
		for _ = 1, 39 do
			local np = p + v * STEP + Vector3.new(0, 0.5 * g * STEP * STEP, 0)
			local res = Workspace:Raycast(p, np - p, rayP)
			if res then
				pts[#pts + 1] = res.Position
				hit = res.Position
				break
			end
			pts[#pts + 1] = np
			v = v + Vector3.new(0, g * STEP, 0)
			p = np
		end
		return pts, hit
	end

	local function threatOf(points)
		local hrp = myRoot()
		if not hrp then return math.huge, nil end
		local c = hrp.Position
		local best, bestT = math.huge, nil
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local ab = b - a
			local len2 = ab:Dot(ab)
			for _, off in ipairs(OFFS) do
				local pt = c + Vector3.new(0, off, 0)
				local t = len2 > 0 and math.clamp((pt - a):Dot(ab) / len2, 0, 1) or 0
				local d = (a + ab * t - pt).Magnitude
				if d < best then best, bestT = d, (i - 1 + t) * STEP end
			end
		end
		return best, bestT
	end

	local function chime()
		if not X.Chime then return end
		local s = Instance.new("Sound")
		s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		s.Volume = 1.2
		s.Parent = Gui
		s:Play()
		Debris:AddItem(s, 2)
	end

	local function dash(move, jump)
		local hum = myHum()
		if not hum or hum.Health <= 0 then return end
		task.spawn(function()
			if jump then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
			if move then
				local t0 = os.clock()
				while os.clock() - t0 < 0.22 do
					local r = myRoot()
					if not r then break end
					r.AssemblyLinearVelocity = Vector3.new(move.X * 46, r.AssemblyLinearVelocity.Y, move.Z * 46)
					RunService.Heartbeat:Wait()
				end
			end
		end)
	end

	local function pickMove(dir, mode) -- dir = incoming horizontal direction (unit vector)
		local hrp = myRoot()
		if not hrp then return nil, false end
		setFilter()
		local function clear(d) return not Workspace:Raycast(hrp.Position, d * 7, rayP) end
		local right = Vector3.new(-dir.Z, 0, dir.X)
		local move, jump = nil, false
		if mode == "Jump" then
			jump = true
		elseif mode == "Back" then
			move = dir -- away from the shooter
		else -- Smart / Sidestep
			if clear(right) then move = right
			elseif clear(-right) then move = -right
			end
			if mode == "Smart" then jump = true end
		end
		return move, jump
	end

	local function doDodge(k)
		local hrp, hum = myRoot(), myHum()
		if not hrp or not hum or hum.Health <= 0 then return end
		dodgeUntil = os.clock() + 0.9
		local dir = Vector3.new(k.vel.X, 0, k.vel.Z)
		if dir.Magnitude < 0.1 then return end
		local move, jump = pickMove(dir.Unit, X.DodgeMode)
		dash(move, jump)
		notify("Dodged incoming " .. (k.kind == "bullet" and "bullet" or "knife"), Color3.fromRGB(255, 200, 60))
	end

	-- Evade when the Sheriff is holding the gun and facing you with a clear line of sight (jinks left/right)
	local aimedUntil, aimedSide, aimAcc = 0, 1, 0
	track(RunService.Heartbeat:Connect(function(dt)
		if not X.EvadeAim then return end
		aimAcc += dt
		if aimAcc < 0.1 then return end
		aimAcc = 0
		local sh = RoleNames.Sheriff
		if not sh or sh == LP then return end
		local sc = sh.Character
		if not sc or not sc:FindFirstChild("Gun") then return end
		local shr, me, hum = aliveRoot(sh), myRoot(), myHum()
		if not shr or not me or not hum or hum.Health <= 0 then return end
		local to = me.Position - shr.Position
		local dist = to.Magnitude
		if dist > 150 or dist < 3 then return end
		local flat = Vector3.new(to.X, 0, to.Z)
		local look = shr.CFrame.LookVector
		local fl = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 or fl.Magnitude < 0.1 then return end
		local angle = math.deg(math.acos(math.clamp(flat.Unit:Dot(fl.Unit), -1, 1)))
		if angle > X.AimAngle then return end
		setFilter(sc)
		if Workspace:Raycast(shr.Position, to, rayP) then return end -- wall in the way
		local now = os.clock()
		if now < aimedUntil then return end
		aimedUntil = now + 0.35
		aimedSide = -aimedSide
		local right = Vector3.new(-flat.Unit.Z, 0, flat.Unit.X) * aimedSide
		setFilter()
		local move = right
		if Workspace:Raycast(me.Position, right * 7, rayP) then move = -right end
		dash(move, math.random() < 0.3)
	end))

	-- Auto-throw: leads the target (intercept maths), needs a clear line of sight, then fires the knife's throw remote
	local function intercept(origin, tpos, tvel, speed)
		local rel = tpos - origin
		local a = tvel:Dot(tvel) - speed * speed
		local b = 2 * rel:Dot(tvel)
		local c = rel:Dot(rel)
		local t
		if math.abs(a) < 1e-3 then
			if math.abs(b) > 1e-6 then t = -c / b end
		else
			local disc = b * b - 4 * a * c
			if disc >= 0 then
				local sq = math.sqrt(disc)
				local t1, t2 = (-b - sq) / (2 * a), (-b + sq) / (2 * a)
				if t1 > 0 and t2 > 0 then t = math.min(t1, t2)
				elseif t1 > 0 then t = t1
				elseif t2 > 0 then t = t2 end
			end
		end
		if not t or t <= 0 or t > 3 then t = rel.Magnitude / speed end
		return tpos + tvel * t, t
	end

	local function findThrowRemote(knife)
		for _, d in ipairs(knife:GetDescendants()) do
			if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and string.find(string.lower(d.Name), "throw", 1, true) then
				return d
			end
		end
		return nil
	end

	local function fireThrow(knife, origin, aim)
		local remote = findThrowRemote(knife)
		if not remote then return false end
		return (pcall(function()
			if remote:IsA("RemoteEvent") then
				remote:FireServer(CFrame.new(origin), CFrame.new(aim))
			else
				task.spawn(function() pcall(function() remote:InvokeServer(CFrame.new(origin), CFrame.new(aim)) end) end)
			end
		end))
	end

	local function handPos()
		local c = LP.Character
		local h = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm") or c:FindFirstChild("HumanoidRootPart"))
		return h and h.Position
	end

	local nextThrow, throwAcc, lastThrowWarn = 0, 0, 0
	local leadGain, pending = 1, nil

	track(RunService.Heartbeat:Connect(function(dt)
		if not X.AutoThrow then return end
		throwAcc += dt
		if throwAcc < 0.05 then return end
		throwAcc = 0
		local now = os.clock()
		if now < nextThrow then return end
		local char = LP.Character
		local knife = char and char:FindFirstChild("Knife")
		local me, hum = myRoot(), myHum()
		if not knife or not me or not hum or hum.Health <= 0 then return end
		for _, k in pairs(knives) do
			if k.mine and k.confirmed then return end -- my last knife is still in the air
		end

		local origin = handPos()
		if not origin then return end
		local speed = math.clamp(knifeSpeedEst or X.KnifeSpeed, 30, 400)
		local ping = getPing() * X.PingComp

		local best, bestD, bestAim, bestT, bestV
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LP then
				local hrp = aliveRoot(plr)
				if hrp then
					local d = (hrp.Position - origin).Magnitude
					if d <= X.ThrowRange and (not bestD or d < bestD) then
						local th = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
						local airborne = th and th.FloorMaterial == Enum.Material.Air
						local v, stable = getVel(plr)
						if not airborne and (stable or not X.ThrowStable or d < 25) then
							-- our view of the target is ~ping old, so push it forward before leading the flight time
							local tpos = hrp.Position + v * ping
							local aim, t = intercept(origin, tpos, v * leadGain, speed)
							if knifeGravEst and knifeGravEst < 0 then
								aim = aim + Vector3.new(0, 0.5 * -knifeGravEst * t * t, 0) -- compensate knife drop
							end
							if t <= 1.2 then
								setFilter(plr.Character)
								if not Workspace:Raycast(origin, aim - origin, rayP) then
									best, bestD, bestAim, bestT, bestV = plr, d, aim, t, v
								end
							end
						end
					end
				end
			end
		end
		if not best then return end -- nobody hittable right now: keep the knife

		nextThrow = now + X.ThrowCooldown
		if not findThrowRemote(knife) then
			if now - lastThrowWarn > 10 then
				lastThrowWarn = now
				notify("Couldn't find the knife's throw remote", THEME.Sub)
			end
			return
		end
		if fireThrow(knife, origin, bestAim) then
			pending = { plr = best, t0 = now, flight = bestT, dir = bestV }
			notify("Knife thrown at " .. best.DisplayName, ROLE_COLORS.Murderer)
		end
	end))

	-- Self-correcting lead: after each throw, see whether the knife passed ahead of or behind the target and adjust
	track(RunService.Heartbeat:Connect(function()
		local pt = pending
		if not pt then return end
		local now = os.clock()
		local troot = aliveRoot(pt.plr)
		local kp
		for _, k in pairs(knives) do
			if k.mine and k.confirmed and k.kind == "knife" then kp = k.pos break end
		end
		if kp and troot then
			local err = Vector3.new(kp.X - troot.Position.X, 0, kp.Z - troot.Position.Z)
			local d = err.Magnitude
			if not pt.minD or d < pt.minD then
				pt.minD = d
				pt.minE = pt.dir.Magnitude > 0.1 and err:Dot(pt.dir.Unit) or 0
			end
		end
		if (not kp and now - pt.t0 > 0.15) or now - pt.t0 > pt.flight + 0.6 then
			pending = nil
			if pt.minD and pt.minD < 14 and pt.dir.Magnitude > 4 then
				local D = pt.dir.Magnitude * pt.flight
				local ratio = math.clamp(pt.minE / math.max(D, 1), -0.5, 0.5)
				leadGain = math.clamp(leadGain * (1 - ratio * 0.5), 0.5, 1.6) -- knife ahead of target => lead less
			end
		end
	end))

	------------------------------------------------------------------
	-- 5) SERVER TIME ELAPSED TRACKER (round HUD)
	--    * ROUND  : time since the current round started (first frame a Murderer exists)
	--    * LEFT   : the game's own countdown, read from its Timer label when one can be found
	--    * SERVER : how long this server has been running (workspace.DistributedGameTime)
	--    Colours shift amber / red as the round clock runs low, with an optional toast.
	------------------------------------------------------------------
	local RT = { roundStart = nil, lastM = nil, missing = 0, acc = 0, warned = false, urgent = false, last = nil }

	local function fmtClock(sec)
		sec = math.max(0, math.floor(sec + 0.5))
		local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
		if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
		return string.format("%d:%02d", m, s)
	end

	-- Best effort: MM2 shows its countdown in a TextLabel named "Timer" under PlayerGui.MainGUI.
	-- Returns remaining seconds or nil. Cached so we don't search the whole GUI every tick.
	local timerLabel, nextTimerScan = nil, 0
	local function readGameTimer()
		if not (timerLabel and timerLabel.Parent) then
			timerLabel = nil
			if os.clock() < nextTimerScan then return nil end
			nextTimerScan = os.clock() + 2
			pcall(function()
				local pg = LP:FindFirstChildOfClass("PlayerGui")
				local main = pg and pg:FindFirstChild("MainGUI")
				local t = main and main:FindFirstChild("Timer", true)
				if t and t:IsA("TextLabel") then timerLabel = t end
			end)
			if not timerLabel then return nil end
		end
		local txt = timerLabel.Text or ""
		local m, s = txt:match("(%d+):(%d+)")
		if m then return tonumber(m) * 60 + tonumber(s) end
		local only = txt:match("^%s*(%d+)%s*$")
		return only and tonumber(only) or nil
	end

	local RTHud = new("Frame", {
		Name = "ForgeRoundTimer", Size = UDim2.fromOffset(150, 74), AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 80), BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.2,
		Visible = false, ZIndex = 10, BorderSizePixel = 0,
	}, Gui)
	corner(RTHud, 10)
	local rtStroke = stroke(RTHud, THEME.Accent, 0.35, 1.5)
	onTheme(function() rtStroke.Color = THEME.Accent end)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, RTHud)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, RTHud)
	local function rtRow(order)
		return new("TextLabel", {
			LayoutOrder = order, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, RichText = true,
			Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left,
			Text = "", ZIndex = 11,
		}, RTHud)
	end
	local rtRound, rtLeft, rtServer = rtRow(1), rtRow(2), rtRow(3)
	makeDraggable(RTHud, RTHud)

	local function rtLine(label, value, color)
		return string.format('<font color="rgb(140,140,148)">%s</font>  <font color="rgb(%d,%d,%d)">%s</font>',
			label, math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255), value)
	end

	local function updateRoundTimer(step)
		if not X.RoundTimer then
			RTHud.Visible = false
			return
		end
		RTHud.Visible = true

		-- Round start / end detection from the role scan
		local m = RoleNames.Murderer
		if m then
			RT.missing = 0
			if m ~= RT.lastM or not RT.roundStart then
				RT.lastM, RT.roundStart = m, os.clock()
				RT.warned, RT.urgent = false, false
			end
		else
			RT.missing += step
			if RT.missing > 3 then RT.roundStart, RT.lastM = nil, nil end
		end

		local now = os.clock()
		local left = readGameTimer()
		local base = THEME.Text

		-- ROUND (elapsed)
		if RT.roundStart then
			rtRound.Text = rtLine("ROUND", fmtClock(now - RT.roundStart), base)
		else
			rtRound.Text = rtLine("ROUND", "waiting", THEME.Sub)
		end

		-- LEFT (game countdown) with warning colours
		if left then
			local col = base
			if left <= 10 then col = Color3.fromRGB(255, 70, 70)
			elseif left <= X.TimerWarn then col = Color3.fromRGB(255, 190, 60) end
			rtLeft.Text = rtLine("LEFT ", fmtClock(left), col)
			rtStroke.Color = (col == base) and THEME.Accent or col

			if X.TimerAlert and RT.roundStart then
				if left <= 10 and not RT.urgent then
					RT.urgent, RT.warned = true, true
					notify("Round ends in " .. math.floor(left) .. "s - expect a rush", Color3.fromRGB(255, 70, 70))
				elseif left <= X.TimerWarn and left > 10 and not RT.warned then
					RT.warned = true
					notify("Round ends in " .. math.floor(left) .. "s", Color3.fromRGB(255, 190, 60))
				end
			end
			if left > X.TimerWarn then RT.warned, RT.urgent = false, false end -- new countdown (next round)
		else
			rtLeft.Text = rtLine("LEFT ", "n/a", THEME.Sub)
			rtStroke.Color = THEME.Accent
		end

		-- SERVER uptime
		rtServer.Visible = X.TimerServer
		RTHud.Size = UDim2.fromOffset(150, X.TimerServer and 74 or 56)
		if X.TimerServer then
			rtServer.Text = rtLine("SERVER", fmtClock(workspace.DistributedGameTime), base)
		end
	end

	track(RunService.Heartbeat:Connect(function(dt)
		RT.acc += dt
		if RT.acc < 0.2 then return end
		local step = RT.acc
		RT.acc = 0
		local ok, err = pcall(updateRoundTimer, step)
		if not ok and err ~= RT.last then
			RT.last = err
			warn("[Forge MM2] round timer error:", err)
		end
	end))

	------------------------------------------------------------------
	-- UI: Extras tab
	------------------------------------------------------------------
	local extraPage = makePage("Extras", 10)

	addSection(extraPage, "Server time elapsed tracker")
	addToggle(extraPage, "Show Round Timer HUD", X.RoundTimer, function(v) X.RoundTimer = v end, "Extras.RoundTimer")
	addToggle(extraPage, "Show Server Uptime", X.TimerServer, function(v) X.TimerServer = v end, "Extras.TimerServer")
	addToggle(extraPage, "Low-Time Alerts", X.TimerAlert, function(v) X.TimerAlert = v end, "Extras.TimerAlert")
	addSlider(extraPage, "Warn When Time Left (sec)", 10, 90, X.TimerWarn, 5, function(v) X.TimerWarn = v end, "Extras.TimerWarn")
	addInfo(extraPage, "Draggable HUD: ROUND = time since the round started, LEFT = the game's own countdown (turns amber then red as it runs out; shows n/a if the game's timer label can't be found), SERVER = how long this server has been up. A toast fires at your warn time and again at 10s, when players tend to rush.")

	addSection(extraPage, "X-Ray vision")
	addToggle(extraPage, "X-Ray Walls", X.XRay, function(v) X.XRay = v end, "Extras.XRay")
	addSlider(extraPage, "Wall Transparency", 0.3, 0.95, X.XRayAlpha, 0.05, function(v) X.XRayAlpha = v end, "Extras.XRayAlpha")
	addInfo(extraPage, "Makes big map parts see-through (client-side only) so players and coins show through walls without ESP outlines. Turning it off restores everything.")

	addSection(extraPage, "Map teleports")
	addButton(extraPage, "TP: Highest Ground", function() runTeleport("high") end)
	addButton(extraPage, "TP: Hideout (enclosed nook, far from Murderer)", function() runTeleport("hide") end)
	addButton(extraPage, "TP: Farthest From Murderer", function() runTeleport("far") end)
	addButton(extraPage, "TP: Random Spawn", function() runTeleport("spawn") end)
	addButton(extraPage, "TP: Back To Previous Spot", function()
		local hrp = myRoot()
		if hrp and prevCF then
			local here = hrp.CFrame
			hrp.CFrame = prevCF
			prevCF = here
		else
			notify("No previous spot", THEME.Sub)
		end
	end)
	addCycle(extraPage, "Saved Spot Slot", { "1", "2", "3" }, "1", function(v) slotSel = tonumber(v) or 1 end)
	addButton(extraPage, "Save My Position As Spot (this map)", function()
		local hrp = myRoot()
		if not hrp then return end
		slots[slotKey()] = hrp.Position
		notify("Saved spot " .. slotSel, THEME.Accent)
	end)
	addButton(extraPage, "TP To Saved Spot (this map)", function()
		local p = slots[slotKey()]
		if p then teleportTo(p, "saved spot " .. slotSel) else notify("Nothing saved in this slot", THEME.Sub) end
	end)
	addInfo(extraPage, "Spots are found by scanning the loaded map, so they work on every map. I don't have verified hand-picked coordinates for each MM2 map, so save your own favourites with the slots above (remembered per map until you rejoin).")

	addSection(extraPage, "Death replay camera")
	addToggle(extraPage, "Replay Camera On Death", X.DeathCam, function(v)
		X.DeathCam = v
		if not v then rec = {} end
	end, "Extras.DeathCam")
	addButton(extraPage, "Replay Last 5s Now", function() startReplay() end)
	addInfo(extraPage, "Records everyone's movement while enabled. When you die it plays the last 5 seconds from a top-down orbit (white = you, red = Murderer). Tap the banner to skip.")

	addSection(extraPage, "Tactical intel")
	addToggle(extraPage, "Murderer Playstyle Profiler", X.Profiler, function(v) X.Profiler = v end, "Extras.Profiler")
	addInfo(extraPage, "After ~10s of data it labels the Murderer (Camper / Knife Thrower / Aggressive Rusher / Roamer) and posts it to your local chat.")
	addToggle(extraPage, "Sheriff Lead Indicator", X.Lead, function(v) X.Lead = v end, "Extras.Lead")
	addSlider(extraPage, "Lead Time (sec)", 0.05, 0.6, X.LeadTime, 0.05, function(v) X.LeadTime = v end, "Extras.LeadTime")
	addInfo(extraPage, "While holding the Gun, draws a dot where the Murderer will be based on their current velocity. Aim at the dot.")

	addSection(extraPage, "Knife defence")
	addToggle(extraPage, "Knife Trajectory + Warning", X.KnifePath, function(v) X.KnifePath = v end, "Extras.KnifePath")
	addToggle(extraPage, "Warning Chime", X.Chime, function(v) X.Chime = v end, "Extras.Chime")
	addToggle(extraPage, "Auto-Dodge Knives", X.AutoDodge, function(v) X.AutoDodge = v end, "Extras.AutoDodge")
	addCycle(extraPage, "Dodge Style", { "Smart", "Sidestep", "Jump", "Back" }, X.DodgeMode, function(v) X.DodgeMode = v end, "Extras.DodgeMode")
	addSlider(extraPage, "Dodge Window (sec)", 0.15, 0.8, X.DodgeWindow, 0.05, function(v) X.DodgeWindow = v end, "Extras.DodgeWindow")
	addInfo(extraPage, "Spots thrown knives by name + speed, draws their predicted path (red = heading at you) and dodges when the path crosses your body. Detection is heuristic and may need tuning if MM2 changes how knives are thrown.")

	addToggle(extraPage, "Auto-Dodge Bullets", X.DodgeBullets, function(v) X.DodgeBullets = v end, "Extras.DodgeBullets")
	addToggle(extraPage, "Evade When Sheriff Aims At You", X.EvadeAim, function(v) X.EvadeAim = v end, "Extras.EvadeAim")
	addSlider(extraPage, "Aim Detection Angle (deg)", 3, 20, X.AimAngle, 1, function(v) X.AimAngle = v end, "Extras.AimAngle")
	addInfo(extraPage, "Bullets are caught the same way as knives (moving parts named 'bullet'). If the gun is instant-hit there is nothing to see in flight, so 'Evade When Sheriff Aims At You' jinks left/right while the Sheriff faces you with a clear line of sight. Both are heuristics.")

	addSection(extraPage, "Auto knife throw (Murderer)")
	addToggle(extraPage, "Auto-Throw Knife (predicted aim)", X.AutoThrow, function(v) X.AutoThrow = v end, "Extras.AutoThrow")
	addSlider(extraPage, "Throw Range (studs)", 20, 200, X.ThrowRange, 5, function(v) X.ThrowRange = v end, "Extras.ThrowRange")
	addSlider(extraPage, "Throw Cooldown (sec)", 0.5, 5, X.ThrowCooldown, 0.1, function(v) X.ThrowCooldown = v end, "Extras.ThrowCooldown")
	addSlider(extraPage, "Knife Speed Fallback", 40, 250, X.KnifeSpeed, 5, function(v) X.KnifeSpeed = v end, "Extras.KnifeSpeed")
	addToggle(extraPage, "Only Throw At Steady Targets", X.ThrowStable, function(v) X.ThrowStable = v end, "Extras.ThrowStable")
	addSlider(extraPage, "Latency Compensation", 0, 2, X.PingComp, 0.1, function(v) X.PingComp = v end, "Extras.PingComp")
	addInfo(extraPage, "Hold the Knife. Throws only when a target is in range, on the ground, in a clear line of sight and moving steadily (close targets always count). Aim = their real position (latency-corrected) led by the knife's flight time, plus drop compensation. It also learns from each throw whether it passed ahead of or behind the target and corrects its lead automatically. Raise 'Latency Compensation' if it keeps missing behind targets, lower it if it leads too far.")
end, function(e) warn("[Forge MM2] Extras error: " .. tostring(e)) end)


-- Misc
local menuOpen = false
local function setMenu(open)
	menuOpen = open
	if open then
		Main.Visible = true
		tween(Main, 0.3, { GroupTransparency = 0 })
		tween(MainScale, 0.3, { Scale = baseScale }, Enum.EasingStyle.Back)
	else
		tween(Main, 0.2, { GroupTransparency = 1 })
		tween(MainScale, 0.2, { Scale = baseScale * 0.92 })
		task.delay(0.22, function()
			if not menuOpen then Main.Visible = false end
		end)
	end
end

addSection(miscPage, "Customization")
addSwatches(miscPage)
addSection(miscPage, "Panic / killswitch")
addCycle(miscPage, "Panic Key", PANIC_KEYS, "End", function(v) PanicKey = Enum.KeyCode[v] end)
addButton(miscPage, "PANIC (restore + destroy GUI)", unload)
addInfo(miscPage, "Panic reverts every change, stops all loops and removes the GUI. It does not make you undetectable.")
addSection(miscPage, "Interface")
addButton(miscPage, "Hide Menu", function() setMenu(false) end)
addButton(miscPage, "Unload Forge MM2", unload)

selectTab("ESP")
CloseBtn.Activated:Connect(function() setMenu(false) end)

-- Floating logo button (draggable, toggles the menu)
local Mini = logoImage("ImageButton", {
	Name = "ForgeToggle", AutoButtonColor = false, Size = UDim2.fromOffset(46, 46),
	Position = UDim2.new(0, 14, 0.5, -23), BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.15,
	Visible = false, ZIndex = 10,
}, Gui)
corner(Mini, 23)
themed(stroke(Mini, THEME.Accent, 0.35, 2), "Color", "Accent")
local miniState = makeDraggable(Mini, Mini)
Mini.Activated:Connect(function()
	if not miniState.Moved then setMenu(not menuOpen) end
end)

-- Floating AIM button (hold to lock; draggable)
AimBtn = new("TextButton", {
	Name = "ForgeAimButton", Text = "AIM", Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = THEME.Accent,
	AutoButtonColor = false, Size = UDim2.fromOffset(64, 64), AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -140), BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.2,
	Visible = false, ZIndex = 10,
}, Gui)
corner(AimBtn, 32)
themed(AimBtn, "TextColor3", "Accent")
local aimStroke = stroke(AimBtn, THEME.Accent, 0.3, 2)
themed(aimStroke, "Color", "Accent")
makeDraggable(AimBtn, AimBtn)
AimBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		AimInputs.Button = true
		tween(AimBtn, 0.1, { BackgroundTransparency = 0.6 })
		tween(aimStroke, 0.1, { Transparency = 0 })
		local c
		c = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				AimInputs.Button = false
				tween(AimBtn, 0.15, { BackgroundTransparency = 0.2 })
				tween(aimStroke, 0.15, { Transparency = 0.3 })
				c:Disconnect()
			end
		end)
	end
end)

do -- Quick Hop button (scoped: the main chunk is close to Lua's 200-local limit)
-- Auto-height note label (addInfo has a fixed height and clips long text)
function Hop.note(page, text)
	return new("TextLabel", {
		Text = text, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = THEME.Sub, TextWrapped = true,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	}, page)
end
--// Quick Hop button (floating, draggable, always one tap away) ------------------------------------------------
local HopBtn = new("TextButton", {
	Name = "ForgeHopButton", Text = "HOP", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = THEME.Accent,
	AutoButtonColor = false, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 14, 0.5, 34),
	BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.15, Visible = false, ZIndex = 10,
}, Gui)
corner(HopBtn, 23)
themed(HopBtn, "TextColor3", "Accent")
themed(stroke(HopBtn, THEME.Accent, 0.35, 2), "Color", "Accent")
local hopBtnState = makeDraggable(HopBtn, HopBtn)
Hop.setText = function(text) HopBtn.Text = text end
local function syncHopBtn() HopBtn.Visible = Mini.Visible and Config.UI.HopButton end
track(Mini:GetPropertyChangedSignal("Visible"):Connect(syncHopBtn))
HopBtn.Activated:Connect(function()
	if not hopBtnState.Moved then hopServer() end
end)
syncHopBtn()

addSection(miscPage, "Quick access")
addToggle(miscPage, "Quick Hop Button", Config.UI.HopButton, function(v)
	Config.UI.HopButton = v
	syncHopBtn()
end, "UI.HopButton")
Hop.note(miscPage, "HOP (under the logo, draggable) jumps to the lowest-ping server with room.")
Hop.note(miscPage, "Chat commands (also /forge or /fg): every toggle, slider, dropdown and button has one. Type /e <setting name> [on|off|value], e.g. /e walk speed 50 or /e noclip off; names ignore case, spaces and dashes, and a unique start is enough. /e cmds lists tabs, /e cmds <tab> lists that tab's settings, /e tab <name> opens a tab. Shortcuts: hide, show, menu, reset (everything off, menu kept), esp, aim, silent, noclip, fb, dodge, hop, rejoin, panic, help.")
end -- Quick Hop button

do -- Chat commands
local C = {} -- all chat-command state lives in this one table (keeps the file under Lua's 200-local limit)
--// Chat commands ------------------------------------------------------------------------------------------------
-- Works as "/e <cmd>", "/forge <cmd>" or "/fg <cmd>". Everything is local - nothing is sent to other players.
C.RESET_PATHS = {
	"ESP.Murderer", "ESP.Sheriff", "ESP.Gun", "ESP.Tracers", "Aim.Enabled", "Silent.Enabled", "Auto.Enabled",
	"Hitbox.Enabled", "Reach.Enabled", "Move.WalkEnabled", "Move.JumpEnabled", "Move.InfJump", "Move.Noclip",
	"Move.AutoGun", "Kill.Enabled", "World.Fullbright", "World.NoFog", "World.FPS", "AntiAim.Enabled",
	"Cosmetic.Trail", "Spectate.Enabled", "Dodge.Enabled",
}
C.ESP_PATHS = { "ESP.Murderer", "ESP.Sheriff", "ESP.Gun" }
C.ESP_ALIAS = {
	murderer = "ESP.Murderer", murd = "ESP.Murderer", m = "ESP.Murderer",
	sheriff = "ESP.Sheriff", sher = "ESP.Sheriff", s = "ESP.Sheriff",
	gun = "ESP.Gun", g = "ESP.Gun", tracers = "ESP.Tracers", tracer = "ESP.Tracers", t = "ESP.Tracers",
}

function C.say(text) chatSay("[Forge] " .. text, THEME.White) end

-- Sets a config value, refreshes its menu switch and runs the same side effects the menu toggle would
function C.setFeature(path, v)
	setPath(Config, path, v)
	local setter = ControlRegistry[path]
	if setter then pcall(setter, v) end
	if path == "Aim.Enabled" then
		if AimBtn then AimBtn.Visible = v end
	elseif path == "Move.Noclip" then
		if not v then pcall(restoreNoclip) end
	elseif path == "World.FPS" then
		pcall(setFPS, v)
	elseif path:sub(1, 6) == "World." then
		pcall(applyWorld)
	end
end

function C.toggleFeature(path, label)
	local v = not getPath(Config, path)
	C.setFeature(path, v)
	C.say(label .. (v and ": ON" or ": OFF"))
end

function C.resetAll()
	for _, path in ipairs(C.RESET_PATHS) do C.setFeature(path, false) end
	pcall(updateMovement)
	pcall(restoreNoclip)
	pcall(updateReach)
	pcall(updateAntiAim)
	pcall(updateSpectate)
	for plr in pairs(HB) do pcall(restoreHitbox, plr) end
	for handle, trail in pairs(TrailStore) do pcall(function() trail:Destroy() end) TrailStore[handle] = nil end
	pcall(removeGunESP)
	pcall(applyWorld)
	pcall(setFPS, false)
	C.say("all features reset (menu kept)")
end

C.CHAT_HELP = "any setting by name: /e <name> [on|off|value] (e.g. /e walk speed 50) | /e cmds [tab] lists them | /e tab <name> | hide show menu reset esp aim silent noclip fb dodge hop rejoin panic"

C.ChatCommands = {
	hide   = function() Gui.Enabled = not Gui.Enabled; C.say(Gui.Enabled and "UI shown" or "UI hidden (type the same command to bring it back)") end,
	show   = function() Gui.Enabled = true; C.say("UI shown") end,
	menu   = function() Gui.Enabled = true; setMenu(not menuOpen) end,
	reset  = function() C.resetAll() end,
	esp    = function(arg)
		if arg ~= "" then
			local path = C.ESP_ALIAS[arg]
			if path then C.toggleFeature(path, "ESP " .. arg) else C.say("esp options: murd, sheriff, gun, tracers") end
			return
		end
		local anyOn = false
		for _, p in ipairs(C.ESP_PATHS) do if getPath(Config, p) then anyOn = true end end
		for _, p in ipairs(C.ESP_PATHS) do C.setFeature(p, not anyOn) end
		C.say("ESP: " .. (anyOn and "OFF" or "ON"))
	end,
	aim    = function() C.toggleFeature("Aim.Enabled", "Aimlock") end,
	silent = function() C.toggleFeature("Silent.Enabled", "Silent aim") end,
	noclip = function() C.toggleFeature("Move.Noclip", "Noclip") end,
	fb     = function() C.toggleFeature("World.Fullbright", "Fullbright") end,
	dodge  = function() C.toggleFeature("Dodge.Enabled", "Auto dodge") end,
	tab    = function(arg)
		local want = (arg:lower():gsub("[^%w]", ""))
		if want == "" then C.say("usage: /e tab <name>  (see /e cmds)") return end
		for name in pairs(pages) do
			if (name:lower():gsub("[^%w]", "")):sub(1, #want) == want then
				Gui.Enabled = true
				setMenu(true)
				selectTab(name)
				C.say("opened " .. name)
				return
			end
		end
		C.say("no such tab")
	end,
	cmds   = function(arg)
		local want = (arg:lower():gsub("[^%w]", ""))
		task.spawn(function()
			if want == "" then
				local seen, names = {}, {}
				for _, e in ipairs(Hop.cmds) do
					if not seen[e.page] then seen[e.page] = true; names[#names + 1] = e.page end
				end
				C.say("tabs: " .. table.concat(names, ", "))
				C.say("/e cmds <tab> lists a tab's settings. Use any setting by name: /e <name> [on|off|value]. Example: /e walk speed 50")
				return
			end
			local list = {}
			for _, e in ipairs(Hop.cmds) do
				if (e.page:lower():gsub("[^%w]", "")):sub(1, #want) == want then
					list[#list + 1] = (e.label:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))
				end
			end
			if #list == 0 then C.say("no such tab") return end
			local line = ""
			for _, name in ipairs(list) do
				if #line + #name > 170 then
					C.say(line)
					line = ""
					task.wait(0.4)
				end
				line = line .. (line == "" and "" or ", ") .. name
			end
			if line ~= "" then C.say(line) end
		end)
	end,
	hop    = function() hopServer() end,
	rejoin = function() C.say("rejoining..."); rejoinServer() end,
	panic  = function() unload() end,
	help   = function() C.say(C.CHAT_HELP) end,
}

C.lastText, C.lastAt = nil, 0

-- Finds a UI control from the typed words. Longest word-run wins; exact name beats prefix. Names ignore case/spaces/dashes.
function C.findControl(tokens, rawTokens, exactOnly, minN)
	local ambiguous
	for n = #tokens, minN, -1 do
		local typed = (table.concat(tokens, "", 1, n):gsub("[^%w]", ""))
		if typed ~= "" then
			local hit, partial = nil, {}
			for _, e in ipairs(Hop.cmds) do
				if e.key == typed then
					hit = hit or e
				elseif not exactOnly and #typed >= 3 and e.key:sub(1, #typed) == typed then
					partial[#partial + 1] = e
				end
			end
			local found = hit or (#partial == 1 and partial[1]) or nil
			if found then
				return found, table.concat(tokens, " ", n + 1), table.concat(rawTokens, " ", n + 1)
			end
			if #partial > 1 and not ambiguous then
				ambiguous = {}
				for i = 1, math.min(5, #partial) do ambiguous[i] = partial[i].label end
			end
		end
	end
	return nil, nil, nil, ambiguous
end

-- returns true when the text was one of our commands
function C.runChatCommand(raw)
	if type(raw) ~= "string" then return false end
	local clean = (raw:gsub("^%s+", ""))
	local text = clean:lower()
	local rest = text:match("^/e%s+(.-)%s*$") or text:match("^/forge%s*(.-)%s*$") or text:match("^/fg%s*(.-)%s*$")
	if not rest then return false end
	local rawRest = clean:match("^/[eE]%s+(.-)%s*$") or clean:match("^/[fF][oO][rR][gG][eE]%s*(.-)%s*$") or clean:match("^/[fF][gG]%s*(.-)%s*$") or ""
	local tokens, rawTokens = {}, {}
	for w in rest:gmatch("%S+") do tokens[#tokens + 1] = w end
	for w in rawRest:gmatch("%S+") do rawTokens[#rawTokens + 1] = w end
	local cmd = tokens[1] or "help"
	local arg = table.concat(tokens, " ", 2)
	local isForge = text:match("^/forge") or text:match("^/fg")

	local handler
	if #tokens >= 2 then -- multi-word setting names ("walk speed 50") beat the one-word shortcuts
		local e, a, ra = C.findControl(tokens, rawTokens, true, 2)
		if e then handler = function() return e.run(a, ra) end end
	end
	if not handler and C.ChatCommands[cmd] then
		local fn = C.ChatCommands[cmd]
		handler = function() return fn(arg) end
	end
	if not handler then
		local e, a, ra, amb = C.findControl(tokens, rawTokens, false, 1)
		if e then
			handler = function() return e.run(a, ra) end
		elseif amb then
			C.say("did you mean: " .. table.concat(amb, " | ") .. " ?")
			return true
		end
	end
	if not handler then
		if isForge then C.say("unknown command - try /e cmds") end
		return false
	end

	-- the same message can arrive through more than one chat hook; only run it once
	if text == C.lastText and os.clock() - C.lastAt < 0.5 then return true end
	C.lastText, C.lastAt = text, os.clock()
	local ok, res = pcall(handler)
	if not ok then
		warn("[Forge MM2] chat command error:", res)
	elseif type(res) == "string" and res ~= "" then
		C.say(res)
	end
	return true
end

-- Legacy chat (and some TextChatService setups) report your own messages through Player.Chatted
track(LP.Chatted:Connect(function(msg) C.runChatCommand(msg) end))
pcall(function() -- newer TextChatService event for messages you send (skipped if the engine doesn't have it)
	track(TextChatService.SendingMessage:Connect(function(m) C.runChatCommand(m.Text) end))
end)

-- TextChatService: register real slash commands. "/e" is Roblox's emote command, so while Forge is loaded we take
-- it over, run our commands, and forward anything else to Humanoid:PlayEmote so emotes keep working.
pcall(function()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end
	local function register(name, primary, secondary, onUnhandled)
		local cmd = Instance.new("TextChatCommand")
		cmd.Name, cmd.PrimaryAlias, cmd.SecondaryAlias = name, primary, secondary or ""
		cmd.Triggered:Connect(function(_, text)
			if not C.runChatCommand(text) and onUnhandled then onUnhandled(text) end
		end)
		cmd.Parent = TextChatService
		track({ Disconnect = function() cmd:Destroy() end })
	end
	register("ForgeCommand", "/forge", "/fg")

	local builtin = TextChatService:FindFirstChild("RBXEmoteCommand")
	if builtin and builtin:IsA("TextChatCommand") then
		local wasEnabled = builtin.Enabled
		builtin.Enabled = false
		track({ Disconnect = function() builtin.Enabled = wasEnabled end })
		register("ForgeEmoteBridge", "/e", "/emote", function(text)
			local emote = text:match("^/%a+%s+(.-)%s*$")
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if emote and hum then pcall(function() hum:PlayEmote(emote) end) end
		end)
	end
end)
end -- Quick Hop / chat commands

do -- Visuals: post-processing, shadows, skyboxes (one table + one page local keeps us under the local limit)
local V = { fx = nil, ov = nil, stash = {}, captured = false, sig = "" }
local rgb = Color3.fromRGB
local pg = makePage("Visuals", 10)

V.PRESET_NAMES = { "Off", "Cinematic", "Retro VHS", "Neon", "Noir" }
V.PRESETS = {
	["Cinematic"] = { Bloom = 1.6, Contrast = 0.25, Saturation = 0.15, Blur = 0,   Scan = false, Aber = false, Vig = true, Tint = rgb(255, 250, 245), Rays = 0.12, Thresh = 0.85 },
	["Retro VHS"] = { Bloom = 0.6, Contrast = 0.1,  Saturation = -0.2, Blur = 1.5, Scan = true,  Aber = true,  Vig = true, Tint = rgb(255, 232, 215), Rays = 0,    Thresh = 0.9 },
	["Neon"]      = { Bloom = 2.4, Contrast = 0.35, Saturation = 0.6,  Blur = 0,   Scan = false, Aber = true,  Vig = true, Tint = rgb(255, 225, 255), Rays = 0.05, Thresh = 0.7 },
	["Noir"]      = { Bloom = 0.5, Contrast = 0.45, Saturation = -1,   Blur = 0,   Scan = false, Aber = false, Vig = true, Tint = rgb(240, 240, 245), Rays = 0,    Thresh = 0.95 },
}
V.CONTROL_PATHS = { "Visual.Enabled", "Visual.Bloom", "Visual.Contrast", "Visual.Saturation", "Visual.Blur",
	"Visual.Scanlines", "Visual.Aberration", "Visual.Vignette" }

function V.refreshControls(paths)
	for _, path in ipairs(paths) do
		local setter = ControlRegistry[path]
		if setter then pcall(setter, getPath(Config, path)) end
	end
end

--// Post-processing effects (live in Lighting, client-side only)
function V.ensureFX()
	if V.fx and V.fx.Bloom.Parent then return end
	local function mk(class, name)
		local old = Lighting:FindFirstChild(name)
		if old then old:Destroy() end
		local e = Instance.new(class)
		e.Name, e.Enabled = name, false
		e.Parent = Lighting
		return e
	end
	V.fx = {
		Bloom = mk("BloomEffect", "ForgeFX_Bloom"), CC = mk("ColorCorrectionEffect", "ForgeFX_CC"),
		Blur = mk("BlurEffect", "ForgeFX_Blur"), Rays = mk("SunRaysEffect", "ForgeFX_Rays"),
	}
end

--// Screen overlays: scanlines, vignette, edge colour fringing (no assets needed)
function V.ensureOverlay()
	if V.ov and V.ov.Gui.Parent then return V.ov end
	local sg = Instance.new("ScreenGui")
	sg.Name, sg.IgnoreGuiInset, sg.ResetOnSpawn, sg.DisplayOrder = "ForgeFX", true, false, 50
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(sg) end end)
	sg.Parent = Gui.Parent
	local ov = { Gui = sg }
	local function layer()
		local f = Instance.new("Frame")
		f.BackgroundTransparency, f.BorderSizePixel, f.Size, f.Visible = 1, 0, UDim2.fromScale(1, 1), false
		f.Parent = sg
		return f
	end
	ov.Scan, ov.Vig, ov.Aber = layer(), layer(), layer()

	for i = 0, 179 do
		local l = Instance.new("Frame")
		l.BackgroundColor3, l.BackgroundTransparency, l.BorderSizePixel = Color3.new(0, 0, 0), 0.8, 0
		l.Position, l.Size = UDim2.fromScale(0, i / 180), UDim2.new(1, 0, 0, 2)
		l.Parent = ov.Scan
	end
	local band = Instance.new("Frame")
	band.BackgroundColor3, band.BorderSizePixel, band.Size = Color3.new(1, 1, 1), 0, UDim2.fromScale(1, 0.08)
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 1) })
	bg.Parent = band
	band.Parent = ov.Scan
	ov.Band = band

	local function edge(parent, pos, size, anchor, rot, color, a)
		local f = Instance.new("Frame")
		f.BackgroundColor3, f.BorderSizePixel, f.Position, f.Size, f.AnchorPoint = color, 0, pos, size, anchor
		local g = Instance.new("UIGradient")
		g.Rotation = rot
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = parent
	end
	local black = Color3.new(0, 0, 0)
	edge(ov.Vig, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), Vector2.new(0, 0), 90, black, 0.35)
	edge(ov.Vig, UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.22), Vector2.new(0, 1), 270, black, 0.35)
	edge(ov.Vig, UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), Vector2.new(0, 0), 0, black, 0.4)
	edge(ov.Vig, UDim2.fromScale(1, 0), UDim2.fromScale(0.16, 1), Vector2.new(1, 0), 180, black, 0.4)
	edge(ov.Aber, UDim2.fromScale(0, 0), UDim2.fromScale(0.07, 1), Vector2.new(0, 0), 0, rgb(255, 0, 90), 0.55)
	edge(ov.Aber, UDim2.fromScale(1, 0), UDim2.fromScale(0.07, 1), Vector2.new(1, 0), 180, rgb(0, 230, 255), 0.55)
	V.ov = ov
	return ov
end

track(RunService.RenderStepped:Connect(function()
	local ov = V.ov
	if ov and ov.Scan.Visible then
		ov.Band.Position = UDim2.fromScale(0, (os.clock() * 0.1) % 1.15 - 0.1) -- slow VHS tracking bar
	end
end))

function V.applyOverlay(on)
	local c = Config.Visual
	if not on and not V.ov then return end
	local ov = V.ensureOverlay()
	ov.Scan.Visible = on and c.Scanlines
	ov.Vig.Visible = on and c.Vignette
	ov.Aber.Visible = on and c.Aberration
end

--// Shadows
function V.applyShadows()
	local mode = Config.Visual.Shadows
	if mode == "Default" then
		if V.shadowOrig then
			pcall(function() Lighting.GlobalShadows, Lighting.ShadowSoftness = V.shadowOrig[1], V.shadowOrig[2] end)
			V.shadowOrig = nil
		end
		return
	end
	pcall(function()
		if not V.shadowOrig then V.shadowOrig = { Lighting.GlobalShadows, Lighting.ShadowSoftness } end
		if mode == "Hard" then
			Lighting.GlobalShadows, Lighting.ShadowSoftness = true, 0
		elseif mode == "Soft" then
			Lighting.GlobalShadows, Lighting.ShadowSoftness = true, 1
		else
			Lighting.GlobalShadows = false
		end
	end)
end

--// Sky / atmosphere presets
V.SKY_NAMES = { "Off", "Cyberpunk", "Deep Space", "Sunset Pink", "Midnight", "Custom ID" }
V.LPROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "FogColor" }
V.FACES = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
V.SKIES = {
	["Cyberpunk"] = {
		L = { ClockTime = 21.5, Brightness = 1.4, Ambient = rgb(70, 25, 120), OutdoorAmbient = rgb(100, 40, 170),
			ColorShift_Top = rgb(255, 0, 170), ColorShift_Bottom = rgb(0, 220, 255), FogColor = rgb(40, 10, 70) },
		A = { Color = rgb(190, 70, 255), Decay = rgb(70, 0, 130), Density = 0.45, Haze = 1.8, Glare = 0.2, Offset = 0.25 },
		Stars = 1500, Bodies = false,
	},
	["Deep Space"] = {
		L = { ClockTime = 0, Brightness = 0.6, Ambient = rgb(10, 12, 28), OutdoorAmbient = rgb(25, 30, 60),
			ColorShift_Top = rgb(0, 0, 0), ColorShift_Bottom = rgb(0, 0, 0), FogColor = rgb(0, 0, 0) },
		A = { Color = rgb(10, 10, 30), Decay = rgb(0, 0, 0), Density = 0, Haze = 0, Glare = 0, Offset = 0 },
		Stars = 5000, Bodies = false,
	},
	["Sunset Pink"] = {
		L = { ClockTime = 18.2, Brightness = 2, Ambient = rgb(150, 90, 120), OutdoorAmbient = rgb(230, 130, 170),
			ColorShift_Top = rgb(255, 150, 190), ColorShift_Bottom = rgb(255, 190, 150), FogColor = rgb(255, 170, 200) },
		A = { Color = rgb(255, 170, 200), Decay = rgb(255, 110, 150), Density = 0.35, Haze = 1.2, Glare = 0.6, Offset = 0.1 },
		Stars = 0, Bodies = true,
	},
	["Midnight"] = {
		L = { ClockTime = 0, Brightness = 0, Ambient = rgb(6, 6, 10), OutdoorAmbient = rgb(10, 10, 16),
			ColorShift_Top = rgb(0, 0, 0), ColorShift_Bottom = rgb(0, 0, 0), FogColor = rgb(0, 0, 0) },
		A = { Color = rgb(0, 0, 0), Decay = rgb(0, 0, 0), Density = 0, Haze = 0, Glare = 0, Offset = 0 },
		Stars = 0, Bodies = false,
	},
}

function V.restoreSky()
	if not V.captured then return end
	V.captured = false
	pcall(function() for prop, val in pairs(V.lightOrig) do Lighting[prop] = val end end)
	pcall(function()
		if V.atmoMade then
			if V.atmo then V.atmo:Destroy() end
		elseif V.atmo and V.atmoOrig then
			for prop, val in pairs(V.atmoOrig) do V.atmo[prop] = val end
		end
	end)
	V.atmo, V.atmoOrig, V.atmoMade = nil, nil, false
	if V.mySky then pcall(function() V.mySky:Destroy() end) V.mySky = nil end
	for sky in pairs(V.stash) do
		pcall(function() sky.Parent = Lighting end)
		V.stash[sky] = nil
	end
end

function V.applySky()
	local name = Config.Visual.Sky
	local def = V.SKIES[name]
	if name == "Off" or (not def and name ~= "Custom ID") then
		V.restoreSky()
		return
	end
	pcall(function()
		if not V.captured then
			V.captured, V.lightOrig = true, {}
			for _, prop in ipairs(V.LPROPS) do V.lightOrig[prop] = Lighting[prop] end
			V.atmo = Lighting:FindFirstChildOfClass("Atmosphere")
			if V.atmo then
				local a = V.atmo
				V.atmoOrig = { Color = a.Color, Decay = a.Decay, Density = a.Density, Haze = a.Haze, Glare = a.Glare, Offset = a.Offset }
				V.atmoMade = false
			else
				V.atmoMade = true
			end
		end
		-- hide the map's own skyboxes (a new one can appear every round)
		for _, ch in ipairs(Lighting:GetChildren()) do
			if ch:IsA("Sky") and ch ~= V.mySky then
				V.stash[ch] = true
				ch.Parent = nil
			end
		end
		if not V.mySky or V.mySky.Parent ~= Lighting then
			V.mySky = Instance.new("Sky")
			V.mySky.Name = "ForgeSky"
			V.mySky.Parent = Lighting
		end
		local tex = ""
		if name == "Custom ID" then
			local id = (tostring(Config.Visual.SkyId or ""):gsub("%D", ""))
			if id ~= "" then tex = "rbxassetid://" .. id end
		end
		for _, face in ipairs(V.FACES) do V.mySky[face] = tex end
		V.mySky.StarCount = def and def.Stars or 0
		V.mySky.CelestialBodiesShown = def and def.Bodies or false
		if def then
			for prop, val in pairs(def.L) do Lighting[prop] = val end
			if not V.atmo or not V.atmo.Parent then
				V.atmo = Instance.new("Atmosphere")
				V.atmo.Name = "ForgeAtmo"
				V.atmo.Parent = Lighting
				V.atmoMade = true
			end
			for prop, val in pairs(def.A) do V.atmo[prop] = val end
		end
	end)
end

function V.apply()
	local c = Config.Visual
	local on = c.Enabled
	pcall(function()
		if on then
			V.ensureFX()
			local p = V.PRESETS[c.Preset] or {}
			local fx = V.fx
			fx.Bloom.Enabled, fx.Bloom.Intensity, fx.Bloom.Size, fx.Bloom.Threshold = c.Bloom > 0.01, c.Bloom, 40, p.Thresh or 0.85
			fx.CC.Enabled = true
			fx.CC.Contrast, fx.CC.Saturation, fx.CC.TintColor = c.Contrast, c.Saturation, p.Tint or rgb(255, 255, 255)
			fx.Blur.Enabled, fx.Blur.Size = c.Blur > 0.05, c.Blur
			fx.Rays.Enabled, fx.Rays.Intensity = (p.Rays or 0) > 0, p.Rays or 0
		elseif V.fx then
			for _, e in pairs(V.fx) do e.Enabled = false end
		end
	end)
	pcall(V.applyOverlay, on)
	V.applyShadows()
	V.applySky()
end

function V.pickPreset(name)
	local c = Config.Visual
	c.Preset = name
	local p = V.PRESETS[name]
	if p then
		c.Enabled = true
		c.Bloom, c.Contrast, c.Saturation, c.Blur = p.Bloom, p.Contrast, p.Saturation, p.Blur
		c.Scanlines, c.Aberration, c.Vignette = p.Scan, p.Aber, p.Vig
	else
		c.Enabled = false
	end
	V.refreshControls(V.CONTROL_PATHS)
	V.apply()
end

function V.destroy()
	pcall(function()
		local c = Config.Visual
		c.Enabled, c.Sky, c.Shadows = false, "Off", "Default"
	end)
	pcall(V.restoreSky)
	pcall(V.applyShadows)
	if V.fx then for _, e in pairs(V.fx) do pcall(function() e:Destroy() end) end V.fx = nil end
	if V.ov then pcall(function() V.ov.Gui:Destroy() end) V.ov = nil end
end
track({ Disconnect = V.destroy })

-- Re-applies when a config file is loaded, and re-asserts the sky because the map can reset Lighting each round
task.spawn(function()
	while Gui.Parent do
		task.wait(1)
		local c = Config.Visual
		local sig = table.concat({ tostring(c.Enabled), c.Preset, tostring(c.Bloom), tostring(c.Contrast), tostring(c.Saturation),
			tostring(c.Blur), tostring(c.Scanlines), tostring(c.Aberration), tostring(c.Vignette), c.Shadows, c.Sky, tostring(c.SkyId) }, "|")
		if sig ~= V.sig then
			V.sig = sig
			V.apply()
		elseif c.Sky ~= "Off" then
			V.applySky()
		end
	end
end)

-- UI
addSection(pg, "Post-processing")
addCycle(pg, "Look Preset", V.PRESET_NAMES, Config.Visual.Preset, function(v) V.pickPreset(v) end, "Visual.Preset")
addToggle(pg, "Enable Effects", Config.Visual.Enabled, function(v) Config.Visual.Enabled = v; V.apply() end, "Visual.Enabled")
addSlider(pg, "Bloom", 0, 3, Config.Visual.Bloom, 0.05, function(v) Config.Visual.Bloom = v; V.apply() end, "Visual.Bloom")
addSlider(pg, "Contrast", -1, 1, Config.Visual.Contrast, 0.05, function(v) Config.Visual.Contrast = v; V.apply() end, "Visual.Contrast")
addSlider(pg, "Saturation", -1, 1, Config.Visual.Saturation, 0.05, function(v) Config.Visual.Saturation = v; V.apply() end, "Visual.Saturation")
addSlider(pg, "Blur", 0, 12, Config.Visual.Blur, 0.5, function(v) Config.Visual.Blur = v; V.apply() end, "Visual.Blur")
addToggle(pg, "VHS Scanlines", Config.Visual.Scanlines, function(v) Config.Visual.Scanlines = v; V.apply() end, "Visual.Scanlines")
addToggle(pg, "Colour Fringe (aberration look)", Config.Visual.Aberration, function(v) Config.Visual.Aberration = v; V.apply() end, "Visual.Aberration")
addToggle(pg, "Vignette", Config.Visual.Vignette, function(v) Config.Visual.Vignette = v; V.apply() end, "Visual.Vignette")
Hop.note(pg, "Everything here is local to your screen. Roblox scripts can't run custom shaders, so 'aberration' is a red/cyan edge-fringe overlay on top of bloom + colour grading, not a true lens effect.")
addSection(pg, "Shadows")
addCycle(pg, "Shadow Style", { "Default", "Hard", "Soft", "No Shadows" }, Config.Visual.Shadows, function(v) Config.Visual.Shadows = v; V.apply() end, "Visual.Shadows")
addSection(pg, "Skybox & lighting")
addCycle(pg, "Atmosphere", V.SKY_NAMES, Config.Visual.Sky, function(v) Config.Visual.Sky = v; V.apply() end, "Visual.Sky")
addInput(pg, "Custom sky image ID (use with 'Custom ID')", Config.Visual.SkyId, "e.g. 1234567890", function(t)
	Config.Visual.SkyId = (t:gsub("%D", ""))
	V.apply()
end, "Visual.SkyId")
Hop.note(pg, "Presets recolour the sky, ambient light, fog and atmosphere (no downloaded assets). 'Custom ID' puts one image on all six sky faces. Fullbright overrides ambient light while both are on.")
addButton(pg, "Reset All Visuals", function()
	Config.Visual.Sky, Config.Visual.Shadows = "Off", "Default"
	V.refreshControls({ "Visual.Sky", "Visual.Shadows" })
	V.pickPreset("Off")
end)
V.apply()
end -- Visuals

do -- Trade evaluator
local T = {}
local pg = makePage("Trade", 11)

function T.norm(s) return (tostring(s):lower():gsub("[^%w]", "")) end

function T.num(str)
	local n, suf = tostring(str):match("^%s*([%d%.]+)%s*([kKmM]?)%s*$")
	n = tonumber(n)
	if not n then return nil end
	suf = (suf or ""):lower()
	if suf == "k" then n = n * 1e3 elseif suf == "m" then n = n * 1e6 end
	return n
end

function T.fmt(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- "name=value, name=value" (k/m suffixes allowed) -> { normalisedName = value }
function T.parseValues(str)
	local map = {}
	for part in tostring(str):gmatch("[^,;\n]+") do
		local name, val = part:match("^%s*(.-)%s*[=:]%s*(.-)%s*$")
		local n = name and T.num(val)
		if name and name ~= "" and n then map[T.norm(name)] = n end
	end
	return map
end

function T.lookup(map, key)
	if key == "" then return nil end
	if map[key] then return map[key] end
	local best, bestLen = nil, 0
	for k, v in pairs(map) do
		if #k >= 3 and #k > bestLen and (k:find(key, 1, true) or key:find(k, 1, true)) then
			best, bestLen = v, #k
		end
	end
	return best
end

-- "Harvester, Luger x2, 3x Knife, Godly=450" -> total value, unknown item names
function T.offer(str, vals)
	local total, unknown, count = 0, {}, 0
	for part in tostring(str):gmatch("[^,;\n]+") do
		local tok = part:match("^%s*(.-)%s*$")
		if tok ~= "" then
			local name, inline = tok, nil
			local a, b = tok:match("^(.-)%s*[=:]%s*(.-)$")
			if a then name, inline = a, T.num(b) end
			local qty = 1
			local q1, rest = name:match("^(%d+)%s*[xX*]%s*(.+)$")
			if q1 then
				qty, name = tonumber(q1), rest
			else
				local r2, q2 = name:match("^(.-)%s+[xX]%s*(%d+)$")
				if not r2 then r2, q2 = name:match("^(.-)%s*%*%s*(%d+)$") end
				if r2 and r2 ~= "" then name, qty = r2, tonumber(q2) end
			end
			name = name:match("^%s*(.-)%s*$")
			local val = inline or T.lookup(vals, T.norm(name))
			count += qty
			if val then total += val * qty else unknown[#unknown + 1] = name end
		end
	end
	return total, unknown, count
end

function T.evaluate()
	local vals = T.parseValues(T.vbox.Text)
	local giveT, giveU, giveN = T.offer(T.mine.Text, vals)
	local getT, getU, getN = T.offer(T.theirs.Text, vals)
	local c = Config.Trade
	c.Mine, c.Theirs, c.Values = T.mine.Text, T.theirs.Text, T.vbox.Text
	local m = (tonumber(c.Margin) or 10) / 100

	local verdict, color, word
	if giveN == 0 and getN == 0 then
		T.out.Text = "Enter what you give and what you get, plus your item values, then press Evaluate."
		return
	elseif getT >= giveT * (1 + m) and getT > 0 then
		verdict, color, word = "W", "#55ff77", "Win"
	elseif getT <= giveT * (1 - m) then
		verdict, color, word = "L", "#ff5555", "Loss"
	else
		verdict, color, word = "F", "#ffd84d", "Fair"
	end

	local lines = {
		string.format('<font color="%s"><b>%s  -  %s</b></font>', color, verdict, word),
		string.format("You give: <b>%s</b>   |   You get: <b>%s</b>", T.fmt(giveT), T.fmt(getT)),
	}
	if giveT > 0 then
		lines[#lines + 1] = string.format("Difference: %+.1f%%  (fair band +/-%d%%)", (getT - giveT) / giveT * 100, math.floor(m * 100 + 0.5))
	end
	local unk = {}
	for _, n in ipairs(giveU) do unk[#unk + 1] = n end
	for _, n in ipairs(getU) do unk[#unk + 1] = n end
	if #unk > 0 then
		local shown = {}
		for i = 1, math.min(5, #unk) do shown[i] = unk[i] end
		lines[#lines + 1] = string.format('<font color="#ff9f43">No value for: %s%s - counted as 0.</font>',
			table.concat(shown, ", "), #unk > 5 and (" +" .. (#unk - 5) .. " more") or "")
	end
	T.out.Text = table.concat(lines, "\n")
end

addSection(pg, "Trade evaluator")
T.mine = addInput(pg, "You give", Config.Trade.Mine, "Harvester, Luger x2", function() T.evaluate() end, "Trade.Mine")
T.theirs = addInput(pg, "You get", Config.Trade.Theirs, "Icepiercer, 2x Chroma Seer", function() T.evaluate() end, "Trade.Theirs")
T.vbox = addInput(pg, "Item values (name=value, ...)", Config.Trade.Values, "harvester=300, luger=120, seer=1.5k", function() T.evaluate() end, "Trade.Values")
addSlider(pg, "Fair margin (%)", 0, 50, Config.Trade.Margin, 1, function(v) Config.Trade.Margin = v; T.evaluate() end, "Trade.Margin")
addButton(pg, "Evaluate Trade", T.evaluate)
addButton(pg, "Clear Offers", function()
	T.mine.Text, T.theirs.Text = "", ""
	T.evaluate()
end)

local resultBox = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.35, BorderSizePixel = 0,
}, pg)
corner(resultBox, 8)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, resultBox)
T.out = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.Gotham,
	TextSize = 13, TextColor3 = THEME.Text, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, resultBox)
Hop.note(pg, "Item values change often, so the script ships none: type your own list once (it's saved with Save Config). Offers accept quantities like 'Luger x2' or '2x Luger', and a one-off value like 'Godly=450'. Names match loosely. You get at least +margin% = W, within the margin = F, below it = L.")
T.evaluate()
end -- Trade evaluator

do -- Role tracker: pre-round odds + instant live-round confirmation
local R = {
	round = 0, players = {}, phase = "lobby", roles = {}, inst = {}, conns = {}, cards = {},
	startedAt = 0, counted = false, idleSince = nil, WINDOW = 4,
}
local pg = makePage("Tracker", 12)

function R.hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function R.get(plr)
	local d = R.players[plr.UserId]
	if not d then
		d = { name = plr.DisplayName, seen = 0, m = 0, s = 0, lastM = 0, lastS = 0, streak = 0, sm = 0, ss = 0 }
		R.players[plr.UserId] = d
	end
	d.name = plr.DisplayName
	return d
end

--// Phase 1: lobby odds. Each role has its own streak (rounds in a row without that role); the longer the wait, the higher the weight.
-- Murderer odds = weight / total weight (they add up to 100%), same for Sheriff.
function R.predict()
	local list, totalM, totalS = {}, 0, 0
	local k = tonumber(Config.Tracker.Weight) or 0.5
	for _, plr in ipairs(Players:GetPlayers()) do
		local d = R.get(plr)
		local e = { plr = plr, d = d, wm = 1 + d.sm * k, ws = 1 + d.ss * k }
		list[#list + 1] = e
		totalM += e.wm
		totalS += e.ws
	end
	for _, e in ipairs(list) do
		e.pm = e.wm / math.max(totalM, 1e-6) * 100
		e.ps = e.ws / math.max(totalS, 1e-6) * 100
	end
	return list
end

function R.who(plr)
	if not plr then return "waiting..." end
	return plr.DisplayName .. (plr == LP and " (you)" or "")
end

function R.render()
	local title, body
	if R.phase == "live" then
		title = "CONFIRMED ROLES"
		body = string.format('<font color="%s"><b>Murderer</b></font>   %s\n<font color="%s"><b>Sheriff</b></font>   %s',
			R.hex(ROLE_COLORS.Murderer), R.who(R.roles.m), R.hex(ROLE_COLORS.Sheriff), R.who(R.roles.s))
	else
		title = "Next Round Predictions"
		local list = R.predict()
		local function top(key, label, col, streakKey)
			local sorted = table.clone(list)
			table.sort(sorted, function(x, y)
				if x[key] ~= y[key] then return x[key] > y[key] end
				return x.d.name < y.d.name
			end)
			local lines = { string.format('<font color="%s"><b>%s</b></font>', R.hex(col), label) }
			for i = 1, math.min(3, #sorted) do
				local e = sorted[i]
				lines[#lines + 1] = string.format('%d. %s  <b>%.0f%%</b>  <font color="#8c8c94">%d round%s without</font>',
					i, R.who(e.plr), e[key], e.d[streakKey], e.d[streakKey] == 1 and "" or "s")
			end
			return table.concat(lines, "\n")
		end
		if #list == 0 then
			body = "No players yet."
		else
			body = string.format('%s\n\n%s\n<font color="#8c8c94">estimate | %d in lobby | %d round%s tracked</font>',
				top("pm", "Likely Murderer", ROLE_COLORS.Murderer, "sm"), top("ps", "Likely Sheriff", ROLE_COLORS.Sheriff, "ss"),
				#list, R.round, R.round == 1 and "" or "s")
		end
	end
	for _, c in ipairs(R.cards) do
		c.title.Text, c.body.Text = title, body
		c.title.TextColor3 = R.phase == "live" and THEME.Accent or THEME.Text
	end
end

--// Phase 2: live round. Roles are known the moment the Knife / Gun lands in a Backpack or Character.
function R.assign(plr, role, silent)
	R.roles[role] = plr
	if silent then -- script loaded mid-round: show roles but don't touch the streaks
		R.counted = true
		R.render()
		return
	end
	if not R.counted then
		R.counted = true
		R.round += 1
		for _, q in ipairs(Players:GetPlayers()) do
			local d = R.get(q)
			d.seen += 1
			if q ~= plr then d.streak += 1 end -- everyone else played another round as Innocent
			if not (q == plr and role == "m") then d.sm += 1 end -- rounds in a row without Murderer
			if not (q == plr and role == "s") then d.ss += 1 end -- rounds in a row without Sheriff
		end
	end
	local d = R.get(plr)
	d.streak = 0 -- the Murderer / Sheriff goes back to 0
	if role == "m" then d.sm = 0 else d.ss = 0 end
	d[role] += 1
	d[role == "m" and "lastM" or "lastS"] = R.round
	Hop.toastAt = os.clock()
	if Config.ESP.Toast then
		notify((role == "m" and "Murderer: " or "Sheriff: ") .. R.who(plr), role == "m" and ROLE_COLORS.Murderer or ROLE_COLORS.Sheriff)
	end
	R.render()
end

function R.begin()
	R.phase, R.startedAt, R.counted, R.idleSince = "live", os.clock(), false, nil
	R.roles, R.inst = {}, {}
end

function R.endRound()
	R.phase, R.roles, R.inst, R.counted, R.idleSince = "lobby", {}, {}, false, nil
	R.render()
end

function R.onTool(plr, inst, silent)
	if not inst:IsA("Tool") then return end
	local role = (inst.Name == "Knife" and "m") or (inst.Name == "Gun" and "s") or nil
	if not role then return end
	if R.phase == "live" then
		local oldM, oldS = R.inst.m, R.inst.s
		local knifeGone = oldM ~= nil and oldM.Parent == nil
		local newRound = (role == "m" and oldM ~= inst and knifeGone)
			or (role == "s" and oldS ~= inst and knifeGone and (oldS == nil or oldS.Parent == nil))
		if newRound then
			R.endRound() -- last round's tools were destroyed and fresh ones appeared
		else
			-- equips move the same Tool between Backpack and Character; a Gun picked up later is a pickup, not a new role
			if R.roles[role] == nil and os.clock() - R.startedAt <= R.WINDOW then
				R.inst[role] = inst
				R.assign(plr, role, silent)
			end
			return
		end
	end
	R.begin()
	R.inst[role] = inst
	R.assign(plr, role, silent)
end

function R.hook(plr, list, container)
	if not container then return end
	list[#list + 1] = container.ChildAdded:Connect(function(ch) R.onTool(plr, ch) end)
end

function R.watch(plr)
	if R.conns[plr] then return end
	local list = {}
	R.conns[plr] = list
	R.hook(plr, list, plr:FindFirstChildOfClass("Backpack"))
	R.hook(plr, list, plr.Character)
	list[#list + 1] = plr.ChildAdded:Connect(function(ch) -- the Backpack is recreated on every respawn
		if ch:IsA("Backpack") then R.hook(plr, list, ch) end
	end)
	list[#list + 1] = plr.CharacterAdded:Connect(function(ch) R.hook(plr, list, ch) end)
end

function R.unwatch(plr)
	local list = R.conns[plr]
	if list then
		for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
		R.conns[plr] = nil
	end
end

function R.holds(plr, name)
	local bp, ch = plr:FindFirstChildOfClass("Backpack"), plr.Character
	return (bp ~= nil and bp:FindFirstChild(name) ~= nil) or (ch ~= nil and ch:FindFirstChild(name) ~= nil)
end

for _, plr in ipairs(Players:GetPlayers()) do R.watch(plr) end
track(Players.PlayerAdded:Connect(function(plr) R.watch(plr); R.render() end))
track(Players.PlayerRemoving:Connect(function(plr) R.unwatch(plr); task.defer(R.render) end))
track({ Disconnect = function() for plr in pairs(R.conns) do R.unwatch(plr) end end })

-- Script loaded mid-round: pick up whoever already holds a Knife / Gun (no streak changes)
for _, name in ipairs({ "Knife", "Gun" }) do
	for _, plr in ipairs(Players:GetPlayers()) do
		local bp, ch = plr:FindFirstChildOfClass("Backpack"), plr.Character
		local tool = (bp and bp:FindFirstChild(name)) or (ch and ch:FindFirstChild(name))
		if tool then R.onTool(plr, tool, true) end
	end
end

-- Round over once nobody holds a Knife or Gun any more
task.spawn(function()
	while Gui.Parent do
		task.wait(0.5)
		if R.phase == "live" then
			local any = false
			for _, plr in ipairs(Players:GetPlayers()) do
				if R.holds(plr, "Knife") or R.holds(plr, "Gun") then any = true break end
			end
			if any then
				R.idleSince = nil
			else
				R.idleSince = R.idleSince or os.clock()
				if os.clock() - R.idleSince > 4 and os.clock() - R.startedAt > 5 then R.endRound() end
			end
		end
	end
end)

task.spawn(function() -- keeps the lobby list current as players join/leave
	while Gui.Parent do
		task.wait(1)
		R.render()
	end
end)

--// UI: one card on the Tracker tab, one floating card (draggable) on screen
function R.card(parent, width)
	local f = new("Frame", {
		Size = width and UDim2.fromOffset(width, 0) or UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.25, BorderSizePixel = 0,
	}, parent)
	corner(f, 8)
	themed(stroke(f, THEME.Accent, 0.6, 1), "Color", "Accent")
	new("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11) }, f)
	new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	local title = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", LayoutOrder = 1,
	}, f)
	local body = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.Gotham,
		TextSize = 12, TextColor3 = THEME.Text, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Text = "", LayoutOrder = 2,
	}, f)
	local c = { frame = f, title = title, body = body }
	R.cards[#R.cards + 1] = c
	return c
end

addSection(pg, "Role card")
R.card(pg)
local hud = R.card(Gui, 250)
hud.frame.AnchorPoint, hud.frame.Position, hud.frame.Visible, hud.frame.ZIndex = Vector2.new(1, 0), UDim2.new(1, -14, 0, 64), false, 5
makeDraggable(hud.frame, hud.frame)
function R.syncHud() hud.frame.Visible = Config.Tracker.HUD and Mini.Visible end
track(Mini:GetPropertyChangedSignal("Visible"):Connect(R.syncHud))
R.syncHud()

addToggle(pg, "Role Card HUD", Config.Tracker.HUD, function(v) Config.Tracker.HUD = v; R.syncHud() end, "Tracker.HUD")
addSlider(pg, "Streak Weight", 0, 2, Config.Tracker.Weight, 0.1, function(v) Config.Tracker.Weight = v; R.render() end, "Tracker.Weight")
addButton(pg, "Clear History", function()
	R.players, R.round = {}, 0
	R.render()
end)
Hop.note(pg, "Before a round the card lists who is most likely to be Murderer and who is most likely to be Sheriff, ranked by how many rounds in a row each player has gone without that role, as an estimated % chance (each list adds up to 100%). When the Knife or Gun is handed out it switches to CONFIRMED ROLES and the streaks update. The script can't see how the server really picks roles, so the percentages are a guess, not a guarantee.")
R.render()
end -- Role tracker

do -- Auto dodge (knife stabs + thrown knives)
local D = { last = 0, count = 0, knives = {}, params = RaycastParams.new() }
D.params.FilterType = Enum.RaycastFilterType.Exclude

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- True while the murderer's character is playing a stab/slash style animation
function D.isStabbing(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return false end
	for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
		local n = (t.Name or ""):lower()
		if n:find("stab") or n:find("slash") or n:find("attack") or n:find("swing") or n:find("knife") then
			return true
		end
	end
	return false
end

-- Picks a safe spot to step to: sideways first (randomised), then straight away if allowed. Rejects walls and drops.
function D.pick(myPos, dirFlat, allowAway)
	local right = Vector3.new(-dirFlat.Z, 0, dirFlat.X)
	local opts = { right, -right }
	if math.random() < 0.5 then opts[1], opts[2] = opts[2], opts[1] end
	if allowAway then opts[3] = dirFlat end
	for _, dir in ipairs(opts) do
		local dist = Config.Dodge.Distance
		local wall = workspace:Raycast(myPos, dir * (dist + 1), D.params)
		if wall then dist = math.max(0, wall.Distance - 2) end
		if dist >= 4 then
			local target = myPos + dir * dist
			if workspace:Raycast(target + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), D.params) then
				return target
			end
		end
	end
	return nil
end

function D.dodge(dirFlat, allowAway)
	local now = os.clock()
	if now - D.last < Config.Dodge.Cooldown then return end
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end
	D.params.FilterDescendantsInstances = { char }
	local target = D.pick(hrp.Position, dirFlat, allowAway)
	if not target then return end
	D.last = now
	hrp.CFrame = CFrame.new(target) * (hrp.CFrame - hrp.CFrame.Position)
	if Config.Dodge.Jump then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
	D.count += 1
	if D.label then D.label.Text = "Dodges this session: " .. D.count end
end

-- Thrown knives: remember loose parts with "knife" in the name that are not held by a player
track(workspace.DescendantAdded:Connect(function(inst)
	if not Config.Dodge.Thrown or not inst:IsA("BasePart") or not inst.Name:lower():find("knife") then return end
	if inst:FindFirstAncestorOfClass("Tool") then return end
	local model = inst:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then return end
	D.knives[inst] = { pos = inst.Position, t = os.clock() }
end))

function D.checkThrown(myPos)
	for part, info in pairs(D.knives) do
		if not part.Parent then
			D.knives[part] = nil
		else
			local now = os.clock()
			local dt = now - info.t
			if dt > 0.016 then
				local vel = (part.Position - info.pos) / dt
				info.pos, info.t = part.Position, now
				if vel.Magnitude > 20 then
					local rel = myPos - part.Position
					local t = rel:Dot(vel) / vel:Dot(vel)
					if t > 0 and t < 0.7 then
						local closest = (part.Position + vel * t - myPos).Magnitude
						if closest < 6 and flat(vel).Magnitude > 1 then
							D.dodge(flat(vel).Unit, false) -- step perpendicular to its flight path
							return
						end
					end
				end
			end
		end
	end
end

track(RunService.RenderStepped:Connect(function()
	if not Config.Dodge.Enabled then return end
	pcall(function()
		local char = LP.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		if Config.Dodge.Thrown then D.checkThrown(hrp.Position) end

		local m = Murderer -- never the local player
		local mchar = m and m.Character
		local mhrp = mchar and mchar:FindFirstChild("HumanoidRootPart")
		local mhum = mchar and mchar:FindFirstChildOfClass("Humanoid")
		if not mhrp or not mhum or mhum.Health <= 0 or not mchar:FindFirstChild("Knife") then return end -- knife must be out

		local away = flat(hrp.Position - mhrp.Position)
		local d = away.Magnitude
		if d > Config.Dodge.Range or d < 0.1 then return end
		away = away.Unit

		local facing = flat(mhrp.CFrame.LookVector):Dot(away) -- > 0: he is facing you
		if facing < 0.3 then return end
		local closing = mhrp.AssemblyLinearVelocity:Dot(away) -- studs/s toward you
		if D.isStabbing(mchar) or d <= 7 or (d <= Config.Dodge.Range * 0.7 and closing > 10) then
			D.dodge(away, true)
		end
	end)
end))

addSection(safetyPage, "Auto dodge")
addToggle(safetyPage, "Auto Dodge Knife", Config.Dodge.Enabled, function(v) Config.Dodge.Enabled = v end, "Dodge.Enabled")
addToggle(safetyPage, "Dodge Thrown Knives", Config.Dodge.Thrown, function(v) Config.Dodge.Thrown = v end, "Dodge.Thrown")
addToggle(safetyPage, "Jump While Dodging", Config.Dodge.Jump, function(v) Config.Dodge.Jump = v end, "Dodge.Jump")
addSlider(safetyPage, "Detect Range", 8, 30, Config.Dodge.Range, 1, function(v) Config.Dodge.Range = v end, "Dodge.Range")
addSlider(safetyPage, "Sidestep Distance", 5, 15, Config.Dodge.Distance, 1, function(v) Config.Dodge.Distance = v end, "Dodge.Distance")
addSlider(safetyPage, "Cooldown (s)", 0.2, 2, Config.Dodge.Cooldown, 0.1, function(v) Config.Dodge.Cooldown = v end, "Dodge.Cooldown")
D.label = Hop.note(safetyPage, "Dodges this session: 0")
Hop.note(safetyPage, "Triggers when the murderer has the knife out, is facing you and is close, closing in, or playing a stab animation. It steps you sideways (or back) to a spot that has ground and no wall. Thrown knives are found by name, which is a best guess. The game's server may snap you back if it dislikes the move.")
end -- Auto dodge

do -- Weather & particle engine (client-side only)
local W = { part = nil, em = nil, prof = nil, curType = "Off", covered = false, lastCheck = 0, nextFlash = 0, sounds = {}, sig = "" }
local rgb = Color3.fromRGB
local pg = makePage("Weather", 13)
W.rp = RaycastParams.new()
W.rp.FilterType = Enum.RaycastFilterType.Exclude
W.rp.RespectCanCollide = true

W.TYPES = { "Off", "Rain", "Storm", "Snow", "Blizzard", "Blossoms", "Embers" }
-- which audio-ID setting each weather plays
W.AUDIO_KEYS = { Rain = "IdRain", Storm = "IdRain", Snow = "IdSnow", Blizzard = "IdSnow", Blossoms = "IdBlossoms", Embers = "IdEmbers" }
W.SOUND_KEYS = { "IdRain", "IdSnow", "IdBlossoms", "IdEmbers" }

W.PROFILES = {
	Rain = {
		area = Vector3.new(90, 1, 90), offset = Vector3.new(0, 38, 0), falling = true, rate = 420, vol = 0.8,
		accel = Vector3.new(0, -40, 0), windScale = 1.5,
		props = {
			Lifetime = NumberRange.new(1.0, 1.3), Speed = NumberRange.new(70, 85), Size = NumberSequence.new(0.16),
			Transparency = NumberSequence.new(0.35), Color = ColorSequence.new(rgb(170, 200, 255)), LightEmission = 0.25,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(-3),
			SpreadAngle = Vector2.new(2, 2), EmissionDirection = Enum.NormalId.Bottom,
		},
	},
	Storm = {
		area = Vector3.new(100, 1, 100), offset = Vector3.new(0, 40, 0), falling = true, rate = 800, vol = 1,
		accel = Vector3.new(-12, -55, 0), windScale = 2,
		props = {
			Lifetime = NumberRange.new(0.8, 1.1), Speed = NumberRange.new(90, 110), Size = NumberSequence.new(0.18),
			Transparency = NumberSequence.new(0.3), Color = ColorSequence.new(rgb(150, 180, 240)), LightEmission = 0.2,
			Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(-3),
			SpreadAngle = Vector2.new(3, 3), EmissionDirection = Enum.NormalId.Bottom,
		},
	},
	Snow = {
		area = Vector3.new(90, 1, 90), offset = Vector3.new(0, 30, 0), falling = true, rate = 170, vol = 0.6,
		accel = Vector3.new(1, -1.5, 0.5), windScale = 0.4,
		props = {
			Lifetime = NumberRange.new(7, 9), Speed = NumberRange.new(3, 6), Size = NumberSequence.new(0.32),
			Transparency = NumberSequence.new(0.1), Color = ColorSequence.new(rgb(255, 255, 255)), LightEmission = 0.6,
			Orientation = Enum.ParticleOrientation.FacingCamera, RotSpeed = NumberRange.new(-60, 60), Rotation = NumberRange.new(0, 360),
			SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Bottom,
		},
	},
	Blizzard = {
		area = Vector3.new(100, 1, 100), offset = Vector3.new(0, 32, 0), falling = true, rate = 560, vol = 1,
		accel = Vector3.new(-35, -6, 8), windScale = 1.2,
		props = {
			Lifetime = NumberRange.new(3.5, 5), Speed = NumberRange.new(12, 20), Size = NumberSequence.new(0.36),
			Transparency = NumberSequence.new(0.2), Color = ColorSequence.new(rgb(245, 250, 255)), LightEmission = 0.7,
			Orientation = Enum.ParticleOrientation.FacingCamera, RotSpeed = NumberRange.new(-120, 120), Rotation = NumberRange.new(0, 360),
			SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Bottom,
		},
	},
	Blossoms = {
		area = Vector3.new(80, 1, 80), offset = Vector3.new(0, 26, 0), falling = true, rate = 45, vol = 0.5,
		accel = Vector3.new(3, -1.5, 2), windScale = 0.5,
		props = {
			Lifetime = NumberRange.new(9, 12), Speed = NumberRange.new(2, 4), Size = NumberSequence.new(0.5),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.05),
				NumberSequenceKeypoint.new(0.9, 0.05), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(rgb(255, 183, 197), rgb(255, 228, 234)), LightEmission = 0.1,
			Orientation = Enum.ParticleOrientation.FacingCamera, RotSpeed = NumberRange.new(-120, 120), Rotation = NumberRange.new(0, 360),
			SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Bottom,
		},
	},
	Embers = {
		area = Vector3.new(60, 1, 60), offset = Vector3.new(0, -6, 0), falling = false, rate = 55, vol = 0.6,
		accel = Vector3.new(0, 3, 0), windScale = 0.3,
		props = {
			Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(2, 5),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(rgb(255, 170, 60), rgb(255, 60, 20)), LightEmission = 1,
			Orientation = Enum.ParticleOrientation.FacingCamera, RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360),
			SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Top,
		},
	},
}

function W.clear()
	if W.part then pcall(function() W.part:Destroy() end) end
	W.part, W.em, W.prof = nil, nil, nil
end

function W.build(prof)
	W.clear()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local part = Instance.new("Part")
	part.Name, part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = "ForgeWX", true, false, false, false
	part.CastShadow, part.Transparency, part.Size = false, 1, prof.area
	local em = Instance.new("ParticleEmitter")
	for k, v in pairs(prof.props) do em[k] = v end
	em.Parent = part
	part.Parent = cam -- camera children are client-only and follow no one else
	W.part, W.em, W.prof = part, em, prof
end

function W.tune()
	local c, prof = Config.Weather, W.prof
	if not W.em or not prof then return end
	W.em.Rate = prof.rate * c.Intensity
	W.em.Acceleration = prof.accel + Vector3.new(c.Wind * prof.windScale, 0, 0)
end

--// Audio: one looped Sound per track, crossfaded when the weather changes
function W.setSound(name, id, vol)
	local snd = W.sounds[name]
	if id == "" or vol <= 0 then
		if snd then
			W.sounds[name] = nil
			TweenService:Create(snd, TweenInfo.new(1.2), { Volume = 0 }):Play()
			task.delay(1.4, function() pcall(function() snd:Stop(); snd:Destroy() end) end)
		end
		return
	end
	local want = "rbxassetid://" .. id
	if snd and snd.SoundId ~= want then
		pcall(function() snd:Destroy() end)
		snd = nil
	end
	if not snd then
		snd = Instance.new("Sound")
		snd.Name, snd.Looped, snd.Volume, snd.SoundId = "ForgeWX_" .. name, true, 0, want
		snd.Parent = game:GetService("SoundService")
		snd:Play()
		W.sounds[name] = snd
	end
	TweenService:Create(snd, TweenInfo.new(1.5), { Volume = vol }):Play()
end

function W.syncAudio()
	local c = Config.Weather
	local prof = W.PROFILES[c.Type]
	local function id(key) return (tostring(c[key] or ""):gsub("%D", "")) end
	local on = c.Audio and prof ~= nil
	local level = on and (c.Volume * prof.vol * (0.4 + 0.4 * c.Intensity) * (W.covered and 0.4 or 1)) or 0 -- heavier = louder, muffled indoors
	for _, key in ipairs(W.SOUND_KEYS) do
		W.setSound(key, id(key), (on and key == W.AUDIO_KEYS[c.Type]) and level or 0)
	end
	W.setSound("IdLofi", id("IdLofi"), on and c.Volume * 0.7 or 0)
end

function W.apply()
	local c = Config.Weather
	local prof = W.PROFILES[c.Type]
	if not prof then
		W.clear()
		W.curType = "Off"
	else
		if W.curType ~= c.Type or not W.part or not W.part.Parent then
			W.build(prof)
			W.curType = c.Type
		end
		W.tune()
	end
	W.syncAudio()
end

function W.flash() -- storm lightning
	local cc = Lighting:FindFirstChild("ForgeWX_Flash")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ForgeWX_Flash"
		cc.Parent = Lighting
	end
	cc.Brightness = 0.5
	TweenService:Create(cc, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	task.wait(0.14)
	cc.Brightness = 0.3
	TweenService:Create(cc, TweenInfo.new(0.5), { Brightness = 0 }):Play()
end

track(RunService.RenderStepped:Connect(function()
	local part, prof = W.part, W.prof
	if not part or not prof then return end
	if not part.Parent then W.curType = "Off" return end -- camera was replaced; the sync loop rebuilds
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cp = cam.CFrame.Position
	part.CFrame = CFrame.new(cp + prof.offset)

	local now = os.clock()
	if now - W.lastCheck > 0.25 then
		W.lastCheck = now
		local covered = false
		if prof.falling then -- no rain/snow indoors: stop emitting while something solid is overhead
			local filter = { cam }
			if LP.Character then filter[2] = LP.Character end
			W.rp.FilterDescendantsInstances = filter
			covered = workspace:Raycast(cp, Vector3.new(0, 60, 0), W.rp) ~= nil
		end
		if covered ~= W.covered then
			W.covered = covered
			W.syncAudio()
		end
		if W.em then W.em.Enabled = not covered end
	end
	if Config.Weather.Type == "Storm" and now > W.nextFlash then
		W.nextFlash = now + math.random(6, 14)
		task.spawn(W.flash)
	end
end))

function W.destroy()
	pcall(function() Config.Weather.Type = "Off" end)
	W.clear()
	for name, snd in pairs(W.sounds) do
		pcall(function() snd:Stop(); snd:Destroy() end)
		W.sounds[name] = nil
	end
	local cc = Lighting:FindFirstChild("ForgeWX_Flash")
	if cc then cc:Destroy() end
end
track({ Disconnect = W.destroy })

task.spawn(function() -- picks up a loaded config and rebuilds the emitter if the camera was swapped
	while Gui.Parent do
		task.wait(1)
		local c = Config.Weather
		local sig = table.concat({ c.Type, tostring(c.Intensity), tostring(c.Wind), tostring(c.Audio), tostring(c.Volume),
			tostring(c.IdRain), tostring(c.IdSnow), tostring(c.IdBlossoms), tostring(c.IdEmbers), tostring(c.IdLofi) }, "|")
		if sig ~= W.sig or (c.Type ~= "Off" and (not W.part or not W.part.Parent)) then
			W.sig = sig
			pcall(W.apply)
		end
	end
end)

-- UI
local function idInput(label, key)
	addInput(pg, label, Config.Weather[key], "audio asset ID", function(t)
		Config.Weather[key] = (t:gsub("%D", ""))
		W.syncAudio()
	end, "Weather." .. key)
end

addSection(pg, "Weather")
addCycle(pg, "Weather", W.TYPES, Config.Weather.Type, function(v) Config.Weather.Type = v; W.apply() end, "Weather.Type")
addSlider(pg, "Intensity", 0.2, 2, Config.Weather.Intensity, 0.1, function(v) Config.Weather.Intensity = v; W.apply() end, "Weather.Intensity")
addSlider(pg, "Wind", -20, 20, Config.Weather.Wind, 1, function(v) Config.Weather.Wind = v; W.apply() end, "Weather.Wind")
addButton(pg, "Stop Weather", function()
	Config.Weather.Type = "Off"
	if ControlRegistry["Weather.Type"] then ControlRegistry["Weather.Type"]("Off") end
	W.apply()
end)
Hop.note(pg, "Particles follow your camera and only you see them. Rain, snow and blossoms pause while something solid is overhead. Storm adds lightning flashes.")
addSection(pg, "Ambient audio")
addToggle(pg, "Weather Audio", Config.Weather.Audio, function(v) Config.Weather.Audio = v; W.syncAudio() end, "Weather.Audio")
addSlider(pg, "Audio Volume", 0, 1, Config.Weather.Volume, 0.05, function(v) Config.Weather.Volume = v; W.syncAudio() end, "Weather.Volume")
idInput("Rain / Storm track ID", "IdRain")
idInput("Snow / Blizzard track ID", "IdSnow")
idInput("Blossoms track ID (lo-fi works well)", "IdBlossoms")
idInput("Embers track ID", "IdEmbers")
idInput("Lo-fi layer ID (plays under any weather)", "IdLofi")
Hop.note(pg, "No audio is bundled: paste IDs of audio assets you're allowed to play (your own uploads or public ones that work in-game). Each track fades in and out with its weather, gets louder with Intensity and is muffled indoors; the lo-fi layer plays under whatever weather is on.")
W.apply()
end -- Weather

------------------------------------------------------------------------
-- INPUT
------------------------------------------------------------------------
track(UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == PanicKey then
		unload()
		return
	end
	if input.KeyCode == MenuKey then
		setMenu(not menuOpen)
		return
	end
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		AimInputs.Mouse = true
	elseif input.KeyCode == AIM_KEY then
		AimInputs.Key = true
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		AimInputs.Mouse = false
	elseif input.KeyCode == AIM_KEY then
		AimInputs.Key = false
	end
end))

local heldTouches = {}
track(UserInputService.TouchStarted:Connect(function(touch, processed)
	if processed or not Config.Aim.TouchHold then return end
	heldTouches[touch] = true
	ActiveTouches += 1
end))
track(UserInputService.TouchEnded:Connect(function(touch)
	if heldTouches[touch] then
		heldTouches[touch] = nil
		ActiveTouches = math.max(ActiveTouches - 1, 0)
	end
end))

------------------------------------------------------------------------
-- LOOPS
------------------------------------------------------------------------
-- Slow loop (10 Hz): roles, ESP boxes, hitbox, reach, world, gun pickup, announcer
local acc = 0
track(RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then return end
	local step = acc
	acc = 0
	local ok, err = pcall(function()
		refreshRoles()
		updateESP()
		updateGunESP()
		updateHitboxes()
		updateReach()
		applyWorld()
		autoGun()
		checkRound(step)
		updateTrail()
		checkKillEffects()
	end)
	if not ok then warn("[Forge MM2] loop error:", err) end
end))

-- Fast loop (every frame): tracers, silent target, auto-shoot, speed/jump
local lastErr
track(RunService.RenderStepped:Connect(function()
	local ok, err = pcall(function()
		updateTracers()
		updateSilent()
		autoShoot()
		updateMovement()
		updateAntiAim()
		updateSpectate()
		updateTarget()
	end)
	if not ok and err ~= lastErr then
		lastErr = err
		warn("[Forge MM2] frame error:", err)
	end
end))

track(Players.PlayerRemoving:Connect(function(plr)
	removeESP(plr)
	restoreHitbox(plr)
	RoleCache[plr] = nil
	if Murderer == plr then Murderer = nil end
end))

ENV.ForgeMM2 = { Unload = unload, Config = Config }
task.defer(function() pcall(loadConfig, true) end)

------------------------------------------------------------------------
-- LOADING SCREEN
------------------------------------------------------------------------
local function runLoader()
	local rng = Random.new()
	local waited = os.clock()
	while not LogoReady and os.clock() - waited < 4 do task.wait(0.05) end

	-- Strict black / white / grey palette
	local INK   = Color3.fromRGB(245, 245, 245)
	local SILV  = Color3.fromRGB(185, 185, 185)
	local GREY  = Color3.fromRGB(130, 130, 130)
	local BLACK = Color3.fromRGB(0, 0, 0)
	local kp    = NumberSequenceKeypoint.new

	local alive, cleaned = true, false
	local conns = {}
	local loader, flash

	-- Depth-of-field blur behind the loader, removed again on exit
	local blur = Instance.new("BlurEffect")
	blur.Name, blur.Size = "ForgeLoadBlur", 0
	blur.Parent = Lighting
	TweenService:Create(blur, TweenInfo.new(0.5), { Size = 22 }):Play()

	local function cleanup()
		if cleaned then return end
		cleaned, alive = true, false
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		pcall(function() blur:Destroy() end)
		if flash then pcall(function() flash:Destroy() end) end
		if loader then pcall(function() loader:Destroy() end) end
	end
	track({ Disconnect = cleanup })

	local ok, err = pcall(function()
		loader = new("CanvasGroup", {
			Name = "Loader", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			GroupTransparency = 1, ZIndex = 100, BorderSizePixel = 0,
		}, Gui)
		local function isAlive() return alive and loader.Parent ~= nil end

		--// 1. Cinematic backdrop + vignette
		new("Frame", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(8, 8, 8),
			BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 1,
		}, loader)

		local vig = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, loader)
		local function edge(anchor, pos, size, rot)
			local f = new("Frame", { AnchorPoint = anchor, Position = pos, Size = size, BackgroundColor3 = BLACK, BorderSizePixel = 0 }, vig)
			new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new({ kp(0, 0.04), kp(0.45, 0.55), kp(1, 1) }) }, f)
		end
		edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.32), 90)
		edge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.32), 270)
		edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.28, 1), 0)
		edge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.28, 1), 180)
		-- corner boosters make the falloff feel radial
		edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.45, 0.45), 45)
		edge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.45, 0.45), 135)
		edge(Vector2.new(1, 1), UDim2.fromScale(1, 1), UDim2.fromScale(0.45, 0.45), 225)
		edge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(0.45, 0.45), 315)

		--// 2. Floating cyber-dust (28 glowing specks drifting up with a sine sway)
		local dust = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, loader)
		local specks = {}
		for i = 1, 28 do
			local f = new("Frame", {
				Size = UDim2.new(0, 4, 0, 4), BackgroundColor3 = (i % 2 == 0) and INK or SILV,
				BorderSizePixel = 0, BackgroundTransparency = 1,
			}, dust)
			if i % 3 ~= 0 then corner(f, 9999) end -- mix of round and square specks
			local glow = stroke(f, INK, 1, 2)
			specks[i] = {
				f = f, glow = glow, x = rng:NextNumber(), y = rng:NextNumber(), v = rng:NextNumber(0.025, 0.07),
				amp = rng:NextNumber(0.008, 0.03), freq = rng:NextNumber(0.6, 1.6), ph = rng:NextNumber(0, 6.28),
				base = rng:NextNumber(0.45, 0.9),
			}
		end
		local t0 = os.clock()
		conns[#conns + 1] = RunService.RenderStepped:Connect(function(dt)
			local t = os.clock() - t0
			for _, sp in ipairs(specks) do
				sp.y -= sp.v * dt
				if sp.y < -0.05 then sp.y, sp.x = 1.05, rng:NextNumber() end
				sp.f.Position = UDim2.fromScale(sp.x + math.sin(t * sp.freq + sp.ph) * sp.amp, sp.y)
				local fade = math.clamp(math.min(sp.y, 1 - sp.y) * 5, 0, 1) -- fades out at the top and bottom
				local twinkle = 0.75 + 0.25 * math.sin(t * 2.2 + sp.ph)
				local a = fade * twinkle
				sp.f.BackgroundTransparency = 1 - a * sp.base
				sp.glow.Transparency = 1 - a * 0.4
			end
		end)

		--// 3. Holographic core: counter-rotating rings + laser scanner
		local stage = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(420, 400), BackgroundTransparency = 1, ZIndex = 4,
		}, loader)
		new("UIScale", { Scale = baseScale }, stage)

		local core = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(210, 150),
			Size = UDim2.fromOffset(240, 240), BackgroundTransparency = 1,
		}, stage)
		local coreScale = new("UIScale", { Scale = 1 }, core)

		local function ring(scale, thickness, color, seconds, reverse)
			local fr = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(scale, scale), BackgroundTransparency = 1,
			}, core)
			corner(fr, 9999)
			stroke(fr, color, 0.88, thickness) -- faint full track
			local st = stroke(fr, color, 0, thickness) -- bright arc that travels around it
			local grad = new("UIGradient", {
				Transparency = NumberSequence.new({ kp(0, 0), kp(0.3, 0.55), kp(0.55, 1), kp(0.86, 1), kp(1, 0.15) }),
			}, st)
			TweenService:Create(grad, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
				{ Rotation = reverse and -360 or 360 }):Play()
		end
		ring(1, 3, INK, 4.2, false)      -- outer ring: bright white, clockwise
		ring(0.8, 2, GREY, 2.6, true)    -- inner ring: grey, counter-clockwise, faster

		-- Scanner: a laser line sweeping up and down inside a circular window
		local window = new("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.68, 0.68), BackgroundTransparency = 1,
		}, core)
		corner(window, 9999)
		local sweep = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.05),
			Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
		}, window)
		local glow = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BorderSizePixel = 0 }, sweep)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0.8), kp(1, 1) }) }, glow)
		local beam = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = INK, BorderSizePixel = 0,
		}, sweep)
		new("UIGradient", { Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0), kp(1, 1) }) }, beam)
		TweenService:Create(sweep, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromScale(0.5, 0.95) }):Play()

		--// 4. Logo with a breathing pulse and an occasional hologram flicker
		local logo = logoImage("ImageLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(96, 96), ScaleType = Enum.ScaleType.Fit, ImageTransparency = 1, ZIndex = 5,
		}, core)
		local logoScale = new("UIScale", { Scale = 0.6 }, logo)
		tween(logo, 0.6, { ImageTransparency = 0 })
		tween(logoScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
		local breathe
		task.delay(0.7, function()
			if isAlive() then
				breathe = TweenService:Create(logoScale, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.07 })
				breathe:Play()
			end
		end)
		task.spawn(function()
			task.wait(1.2)
			while isAlive() do
				task.wait(rng:NextNumber(1.4, 3))
				for _ = 1, 3 do
					if not isAlive() then return end
					logo.ImageTransparency = rng:NextNumber(0.35, 0.7)
					task.wait(0.04)
					logo.ImageTransparency = 0
					task.wait(0.03)
				end
			end
		end)

		-- Tiny corner brackets frame the stage
		for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
			for _, sz in ipairs({ UDim2.fromOffset(26, 2), UDim2.fromOffset(2, 26) }) do
				new("Frame", {
					AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = sz,
					BackgroundColor3 = INK, BackgroundTransparency = 0.5, BorderSizePixel = 0,
				}, stage)
			end
		end

		-- Status line (monospace) with hologram ghosts for the glitch effect
		local STATUS_Y = 292
		local function statusLabel(color, z)
			return new("TextLabel", {
				Text = "", Font = Enum.Font.Code, TextSize = 14, TextColor3 = color, BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, STATUS_Y), Size = UDim2.new(1, 0, 0, 18), ZIndex = z,
			}, stage)
		end
		local ghostA, ghostB = statusLabel(SILV, 1), statusLabel(GREY, 1)
		local status = statusLabel(INK, 2)
		ghostA.TextTransparency, ghostB.TextTransparency = 1, 1

		local GLYPHS = { "#", "%", "&", "@", "0", "1", "/", "\\", "|", "?", "<", ">", "=", "+" }
		local typeToken = 0
		local function showStatus(full)
			typeToken += 1
			local mine = typeToken
			task.spawn(function()
				for _ = 1, 7 do -- scramble + RGB-split style jitter
					if mine ~= typeToken or not isAlive() then return end
					local chars = {}
					for ch in full:gmatch(".") do
						chars[#chars + 1] = (ch ~= " " and rng:NextNumber() < 0.35) and GLYPHS[rng:NextInteger(1, #GLYPHS)] or ch
					end
					local scrambled = table.concat(chars)
					status.Text, ghostA.Text, ghostB.Text = scrambled, scrambled, scrambled
					local dx = rng:NextInteger(-4, 4)
					ghostA.Position = UDim2.new(0.5, dx, 0, STATUS_Y + rng:NextInteger(-1, 1))
					ghostB.Position = UDim2.new(0.5, -dx, 0, STATUS_Y + rng:NextInteger(-1, 1))
					ghostA.TextTransparency, ghostB.TextTransparency = 0.5, 0.7
					task.wait(0.035)
				end
				ghostA.TextTransparency, ghostB.TextTransparency = 1, 1
				ghostA.Position = UDim2.new(0.5, 0, 0, STATUS_Y)
				ghostB.Position = UDim2.new(0.5, 0, 0, STATUS_Y)
				status.Text, ghostA.Text, ghostB.Text = full, full, full
				status.MaxVisibleGraphemes = 0
				for i = 1, #full do
					if mine ~= typeToken or not isAlive() then return end
					status.MaxVisibleGraphemes = i
					task.wait(0.012)
				end
				status.MaxVisibleGraphemes = -1
			end)
		end

		-- Progress bar + live percentage
		local barBack = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 326), Size = UDim2.new(0.74, 0, 0, 3),
			BackgroundColor3 = Color3.fromRGB(35, 35, 35), BorderSizePixel = 0,
		}, stage)
		corner(barBack, 2)
		local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = INK, BorderSizePixel = 0 }, barBack)
		corner(barFill, 2)
		stroke(barFill, INK, 0.7, 2)
		local percent = new("TextLabel", {
			Text = "0%", Font = Enum.Font.Code, TextSize = 11, TextColor3 = GREY, BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 338), Size = UDim2.new(1, 0, 0, 14),
		}, stage)

		--// Intro
		tween(loader, 0.4, { GroupTransparency = 0 })
		task.wait(0.5)

		--// Boot sequence
		local PHASES = {
			{ 0,   "[INIT] Establishing secure memory hook..." },
			{ 35,  "[LOAD] Injecting Glassmorphism UI framework..." },
			{ 70,  "[SYNC] Mounting Role Odds & ESP modules..." },
			{ 100, "[SUCCESS] Welcome, operator." },
		}
		local phase, prog = 0, 0
		while prog < 100 and isAlive() do
			while phase < #PHASES and prog >= PHASES[phase + 1][1] do
				phase += 1
				showStatus(string.format("%d%% - %s", PHASES[phase][1], PHASES[phase][2]))
			end
			barFill.Size = UDim2.fromScale(prog / 100, 1)
			percent.Text = string.format("%d%%", math.floor(prog))
			local dt = RunService.RenderStepped:Wait()
			prog = math.min(100, prog + dt * (20 + 12 * math.abs(math.sin(prog * 0.13)))) -- ~4s with natural pacing
		end
		barFill.Size = UDim2.fromScale(1, 1)
		percent.Text = "100%"
		if phase < #PHASES then showStatus(string.format("%d%% - %s", PHASES[#PHASES][1], PHASES[#PHASES][2])) end
		task.wait(0.75)

		--// 5. Cinematic exit: light burst, core blows up, everything fades (0.4s), blur lifts, panel opens
		if breathe then breathe:Cancel() end
		flash = new("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
			ZIndex = 400, BorderSizePixel = 0,
		}, Gui)
		tween(flash, 0.08, { BackgroundTransparency = 0.2 })
		tween(coreScale, 0.4, { Scale = 2.8 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(loader, 0.4, { GroupTransparency = 1 })
		tween(blur, 0.4, { Size = 0 })
		task.delay(0.08, function()
			if flash and flash.Parent then tween(flash, 0.32, { BackgroundTransparency = 1 }) end
		end)
		task.wait(0.12) -- the main panel pops open right after we return, while the last of the fade plays out
	end)

	if ok then
		task.delay(0.5, cleanup)
	else
		cleanup()
		error(err, 0)
	end
end

task.spawn(function()
	math.randomseed(tick() % 1 * 1e6)
	local ok, err = pcall(runLoader)
	if not ok then warn("[Forge MM2] loader error:", err) end
	if Gui.Parent then
		Mini.Visible = true
		setMenu(true)
	end
end)

task.delay(15, function()
	if Gui and Gui.Parent and not Main.Visible then
		local l = Gui:FindFirstChild("Loader")
		if l then l:Destroy() end
		local lb = Lighting:FindFirstChild("ForgeLoadBlur")
		if lb then lb:Destroy() end
		Mini.Visible = true
		setMenu(true)
	end
end)


end, function(e) return tostring(e) .. "\n" .. tostring(debug.traceback()) end)

if not __ok then
	warn("[Forge MM2] failed to load:\n" .. tostring(__err))
	pcall(function()
		local sg = Instance.new("ScreenGui")
		sg.Name = "ForgeMM2Error"; sg.ResetOnSpawn = false; sg.DisplayOrder = 10000; sg.IgnoreGuiInset = true
		local parent
		local okh, h = pcall(function() return gethui and gethui() end)
		if okh and typeof(h) == "Instance" then parent = h end
		if not parent then
			local okc = pcall(function() sg.Parent = game:GetService("CoreGui") end)
			if okc and sg.Parent then parent = sg.Parent end
		end
		sg.Parent = parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.9, 0, 0.5, 0); b.Position = UDim2.new(0.05, 0, 0.05, 0)
		b.BackgroundColor3 = Color3.fromRGB(20, 0, 0); b.BackgroundTransparency = 0.1
		b.TextColor3 = Color3.fromRGB(255, 120, 120); b.TextSize = 13; b.Font = Enum.Font.Code
		b.TextWrapped = true; b.TextXAlignment = Enum.TextXAlignment.Left; b.TextYAlignment = Enum.TextYAlignment.Top
		b.Text = "Forge MM2 failed to load (tap to close). Send this to Claude:\n\n" .. tostring(__err)
		b.Activated:Connect(function() sg:Destroy() end)
		b.Parent = sg
	end)
end

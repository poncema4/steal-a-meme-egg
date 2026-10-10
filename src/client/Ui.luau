--!strict
-- The look of the game, in one place: chunky gradient buttons with a thick outline, dark panels with a bright title bar and
-- a red close button, heavy rounded text with a black stroke. Modelled on the reference screenshots (docs/REFERENCE.md).
-- Every screen made here scales to the real screen size (touch gets bigger), keeps clear of device safe areas, and works
-- with a gamepad: buttons are selectable, a panel selects its first button when it opens, and B closes it.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local UiScale = require(ReplicatedStorage.Shared.Game.UiScale)

local Ui = {}

export type Palette = { top: Color3, bottom: Color3 }

Ui.Palettes = {
	Green = { top = Color3.fromRGB(120, 245, 70), bottom = Color3.fromRGB(28, 178, 36) },
	Blue = { top = Color3.fromRGB(100, 210, 255), bottom = Color3.fromRGB(22, 118, 232) },
	Red = { top = Color3.fromRGB(255, 96, 96), bottom = Color3.fromRGB(198, 22, 22) },
	Orange = { top = Color3.fromRGB(255, 196, 70), bottom = Color3.fromRGB(240, 112, 20) },
	Gold = { top = Color3.fromRGB(255, 230, 90), bottom = Color3.fromRGB(232, 158, 12) },
	Purple = { top = Color3.fromRGB(196, 130, 255), bottom = Color3.fromRGB(116, 50, 210) },
	Slot = { top = Color3.fromRGB(96, 80, 74), bottom = Color3.fromRGB(58, 46, 44) },
	SlotUsed = { top = Color3.fromRGB(46, 42, 44), bottom = Color3.fromRGB(28, 26, 30) },
	Grey = { top = Color3.fromRGB(120, 120, 134), bottom = Color3.fromRGB(70, 70, 84) },
} :: { [string]: Palette }

Ui.PANEL = Color3.fromRGB(36, 36, 46)
Ui.PANEL_DARK = Color3.fromRGB(24, 24, 32)
Ui.FONT = Enum.Font.FredokaOne
Ui.BLACK = Color3.new(0, 0, 0)

-- A UIStroke outlines either the box (Border) or the text inside it (Contextual); a button gets one of each.
local function stroke(parent: Instance, thickness: number, color: Color3?, mode: Enum.ApplyStrokeMode?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or Ui.BLACK
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function gradient(parent: Instance, palette: Palette)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(palette.top, palette.bottom)
	g.Rotation = 90
	g.Parent = parent
end

function Ui.isTouch(): boolean
	return UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled ~= true
end

-- A full-screen layer that scales itself to the real screen and keeps out of the notch and rounded corners.
function Ui.screen(player: Player, name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order or 1
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Parent = gui
	local function fit()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = UiScale.factor(size.X, size.Y, Ui.isTouch())
	end
	fit()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- The design-size number for a button that must stay tappable at the current scale.
function Ui.tap(gui: ScreenGui, designSize: number): number
	local scale = gui:FindFirstChild("Scale") :: UIScale?
	return UiScale.tap(designSize, if scale then scale.Scale else 1)
end

-- Heavy rounded text with a black outline.
function Ui.label(parent: Instance, name: string, textSize: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Ui.FONT
	l.TextSize = textSize
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.Text = ""
	l.Parent = parent
	stroke(l, math.max(2, math.floor(textSize / 12)), nil, Enum.ApplyStrokeMode.Contextual)
	return l
end

-- A chunky button: gradient fill, thick black outline, a little shrink while held. Selectable with a gamepad.
function Ui.button(parent: Instance, name: string, text: string, palette: Palette, size: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Selectable = true
	b.Font = Ui.FONT
	b.TextSize = 24
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Parent = parent
	corner(b, 10)
	stroke(b, 3)
	gradient(b, palette)
	stroke(b, 2, nil, Enum.ApplyStrokeMode.Contextual)
	local press = Instance.new("UIScale")
	press.Name = "Press"
	press.Parent = b
	b.MouseButton1Down:Connect(function()
		press.Scale = 0.94
	end)
	b.MouseButton1Up:Connect(function()
		press.Scale = 1
	end)
	return b
end

-- Recolours a button made by Ui.button (they are tinted by their gradient, not by BackgroundColor3).
function Ui.setPalette(button: GuiObject, palette: Palette)
	for _, child in button:GetChildren() do
		if child:IsA("UIGradient") then
			child.Color = ColorSequence.new(palette.top, palette.bottom)
		end
	end
end

-- The asset id of a HUD icon, or nil if it is missing (the caller then falls back to a glyph).
function Ui.iconId(key: string): string?
	local id = (Config.Icons :: { [string]: string })[key]
	return if id and id ~= "" then id else nil
end

-- The portrait of a character, or nil if it has none yet.
function Ui.petIconId(characterId: string): string?
	local id = (Config.PetIcons :: { [string]: string })[characterId]
	return if id and id ~= "" then id else nil
end

-- Puts a picture on a button or label. `side` "center" fills the middle (icon-only buttons); "left" sits at the left edge and
-- pads the text so it does not run under the picture. Returns false (and shows `glyph` as text instead) if there is no art.
function Ui.addIcon(target: GuiObject, key: string, side: string, glyph: string, pad: number?, grow: number?): boolean
	local id = Ui.iconId(key)
	local text = target :: any
	if not id then
		if side == "center" then
			text.Text = glyph
		end
		return false
	end
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.Image = id
	image.ScaleType = Enum.ScaleType.Fit
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	if side == "center" then
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(0.78, 0.78)
		text.Text = ""
	else
		image.Position = UDim2.new(0, 6, 0.5, 0)
		image.AnchorPoint = Vector2.new(0, 0.5)
		image.Size = UDim2.fromScale(0.3, grow or 1.1)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = image
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, pad or 40)
		padding.Parent = target
	end
	image.Parent = target
	return true
end

-- A square icon button (an emoji glyph for now) with an optional count badge in the corner.
function Ui.iconButton(
	parent: Instance,
	name: string,
	icon: string,
	glyph: string,
	palette: Palette,
	side: number
): TextButton
	local b = Ui.button(parent, name, glyph, palette, UDim2.fromOffset(side, side))
	b.TextSize = math.floor(side * 0.55)
	Ui.addIcon(b, icon, "center", glyph)
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(26, 26)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 1, -4)
	badge.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
	badge.Font = Ui.FONT
	badge.TextSize = 16
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Text = ""
	badge.Visible = false
	badge.Parent = b
	corner(badge, 13)
	stroke(badge, 2)
	return b
end

export type Panel = {
	frame: Frame,
	body: Frame,
	close: TextButton,
	isOpen: () -> boolean,
	open: () -> (),
	hide: () -> (),
	toggle: () -> (),
}

local current: Panel? = nil

-- A dark panel with a bright title bar and a red X, centred on screen. Only one panel is open at a time; B on a gamepad
-- closes it and a gamepad cursor starts on its first selectable button.
function Ui.panel(screen: ScreenGui, title: string, width: number, height: number): Panel
	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	-- never bigger than the screen (a phone's design screen is only 460 tall), never bigger than asked for
	frame.Size = UDim2.fromScale(0.94, 0.88)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(width, height)
	limit.Parent = frame
	frame.BackgroundColor3 = Ui.PANEL
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen
	corner(frame, 14)
	stroke(frame, 4)

	local bar = Instance.new("Frame")
	bar.Name = "TitleBar"
	bar.Size = UDim2.new(1, 0, 0, 56)
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.Parent = frame
	corner(bar, 14)
	gradient(bar, Ui.Palettes.Green)
	local heading = Ui.label(bar, "Title", 30)
	heading.Size = UDim2.new(1, -90, 1, 0)
	heading.Position = UDim2.fromOffset(16, 0)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = title

	local closeSide = Ui.tap(screen, 44)
	local close = Ui.button(frame, "Close", "X", Ui.Palettes.Red, UDim2.fromOffset(closeSide, closeSide))
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.TextSize = 26

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(14, 68)
	body.Size = UDim2.new(1, -28, 1, -82)
	body.Parent = frame

	local panel: Panel
	local action = `ClosePanel_{title}`
	local function hide()
		frame.Visible = false
		ContextActionService:UnbindAction(action)
		if current == panel then
			current = nil
		end
	end
	local function open()
		if current and current ~= panel then
			current.hide()
		end
		current = panel
		frame.Visible = true
		ContextActionService:BindAction(action, function(_, state)
			if state == Enum.UserInputState.Begin then
				hide()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonB)
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = close
		end
	end
	panel = {
		frame = frame,
		body = body,
		close = close,
		isOpen = function()
			return frame.Visible
		end,
		open = open,
		hide = hide,
		toggle = function()
			if frame.Visible then
				hide()
			else
				open()
			end
		end,
	}
	close.Activated:Connect(hide)
	return panel
end

-- The default Roblox player list is replaced by our own leaderboard, so hide it (leaderstats still exist for other tools).
function Ui.hideDefaultList()
	local ok = pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	return ok
end

return Ui

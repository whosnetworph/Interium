local cloneref = cloneref or function(o) return o end
local function svc(n) return cloneref(game:GetService(n)) end

local Players      = svc("Players")
local UIS          = svc("UserInputService")
local RunService   = svc("RunService")
local TweenService = svc("TweenService")
local TextService  = svc("TextService")
local CoreGui      = svc("CoreGui")
local Stats        = svc("Stats")
local HttpService  = svc("HttpService")
local GuiService   = svc("GuiService")

local LocalPlayer = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
for _, key in ipairs({ "InteriumUI", "AkaneUI" }) do
	local old = env[key]
	if type(old) == "table" and type(old.Unload) == "function" then pcall(old.Unload, old) end
	env[key] = nil
end

local Theme = { Font = Enum.Font.Code, TextSize = 11, TitleSize = 13 }

local function lum(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end

local function derive(s)
	local bg, panel, text = s.Background, s.Panel, s.Text
	local dark = lum(bg) < 0.5
	local lift = dark and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	return {
		Window        = bg,
		Section       = panel,
		SectionHeader = panel:Lerp(lift, 0.02),
		Element       = panel:Lerp(lift, 0.017),
		Box           = panel:Lerp(lift, 0.05),
		Border        = s.Outline,
		BorderDark    = bg:Lerp(Color3.new(0, 0, 0), dark and 0.4 or 0.12),
		BorderHover   = s.Outline:Lerp(text, 0.14),
		Accent        = s.Accent,
		Text          = text,
		TextHover     = text:Lerp(bg, 0.28),
		TextMid       = text:Lerp(bg, 0.22),
		TextDim       = text:Lerp(bg, 0.52),
		TextOff       = text:Lerp(bg, 0.66),
	}
end

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local Builtin = {
	{ Name = "Interium", Accent = rgb(204, 51, 71),   Background = rgb(10, 10, 13),    Panel = rgb(14, 14, 18),    Outline = rgb(33, 33, 41),    Text = rgb(224, 224, 230) },
	{ Name = "Midnight", Accent = rgb(96, 138, 255),  Background = rgb(8, 10, 18),     Panel = rgb(12, 15, 26),    Outline = rgb(28, 34, 54),    Text = rgb(222, 226, 240) },
	{ Name = "Ocean",    Accent = rgb(45, 190, 200),  Background = rgb(8, 14, 17),     Panel = rgb(12, 20, 24),    Outline = rgb(28, 44, 52),    Text = rgb(220, 235, 238) },
	{ Name = "Forest",   Accent = rgb(92, 196, 110),  Background = rgb(9, 13, 10),     Panel = rgb(13, 19, 14),    Outline = rgb(30, 44, 32),    Text = rgb(222, 234, 222) },
	{ Name = "Amethyst", Accent = rgb(160, 110, 235), Background = rgb(11, 9, 15),     Panel = rgb(16, 13, 22),    Outline = rgb(38, 32, 52),    Text = rgb(230, 224, 240) },
	{ Name = "Sunset",   Accent = rgb(255, 140, 66),  Background = rgb(14, 10, 9),     Panel = rgb(20, 15, 13),    Outline = rgb(48, 36, 32),    Text = rgb(236, 226, 220) },
	{ Name = "Mono",     Accent = rgb(230, 230, 230), Background = rgb(9, 9, 9),       Panel = rgb(14, 14, 14),    Outline = rgb(36, 36, 36),    Text = rgb(225, 225, 225) },
	{ Name = "Light",    Accent = rgb(214, 60, 84),   Background = rgb(238, 238, 242), Panel = rgb(248, 248, 251), Outline = rgb(206, 206, 214), Text = rgb(34, 34, 42) },
}

for k, v in pairs(derive(Builtin[1])) do Theme[k] = v end

local M = {
	Pad = 8, Gap = 6, Page = 10, ColGap = 12,
	Row = 16, Label = 13, LabelGap = 4, Box = 22, Item = 22, SecHead = 24, Header = 28,
	DD = 39, Slider = 24, Btn = 22, KLRow = 20,
	Win = Vector2.new(642, 520),
}

local Library = {
	Theme = Theme,
	Flags = {},
	Options = {},
	Searchable = {},
	ToggleKey = Enum.KeyCode.LeftAlt,
	Name = "Interium",
	Folder = "Interium",
	MenuVisible = true,
	Animations = true,
	TabDetach = false,
	Windows = {},
	Builtin = Builtin,
	CustomThemes = {},
	CurrentTheme = {},
	PlayerStatus = {},
	_conns = {},
	_kb = {},
	_animated = {},
	_drag = nil,
	_dragEnd = nil,
	_listening = nil,
	_unloaded = false,
	_touch = function() end,
}

for _, k in ipairs({ "Name", "Accent", "Background", "Panel", "Outline", "Text" }) do
	Library.CurrentTheme[k] = Builtin[1][k]
end

local QUINT, QUAD, BACK = Enum.EasingStyle.Quint, Enum.EasingStyle.Quad, Enum.EasingStyle.Back
local OUT, IN = Enum.EasingDirection.Out, Enum.EasingDirection.In

local skins, binders = {}, {}

local function skin(inst, map)
	for prop, key in pairs(map) do inst[prop] = Theme[key] end
	skins[#skins + 1] = { inst, map }
	return inst
end

local function bind(owner, fn)
	fn()
	binders[#binders + 1] = { owner, fn }
end

local function restyle()
	for i = #skins, 1, -1 do
		local e = skins[i]
		if e[1].Parent == nil then
			table.remove(skins, i)
		else
			for prop, key in pairs(e[2]) do e[1][prop] = Theme[key] end
		end
	end
	for i = #binders, 1, -1 do
		local e = binders[i]
		if e[1].Parent == nil then
			table.remove(binders, i)
		else
			pcall(e[2])
		end
	end
end

local function tween(inst, props, t, style, dir)
	if not Library.Animations then
		for k, v in pairs(props) do inst[k] = v end
		return nil
	end
	local tw = TweenService:Create(inst, TweenInfo.new(t or 0.15, style or QUAD, dir or OUT), props)
	tw:Play()
	return tw
end

local BORDERLESS = {
	Frame = true, TextButton = true, TextLabel = true, TextBox = true,
	ScrollingFrame = true, ImageLabel = true, CanvasGroup = true,
}

local function new(class, props, kids)
	props = props or {}
	local o = Instance.new(class)
	if BORDERLESS[class] then o.BorderSizePixel = 0 end
	local textual = class == "TextLabel" or class == "TextButton" or class == "TextBox"
	if textual then
		o.BackgroundTransparency = 1
		o.Font = Theme.Font
		o.TextSize = Theme.TextSize
		if class == "TextButton" then
			o.AutoButtonColor = false
			o.Text = ""
		end
		if class == "TextBox" then o.ClearTextOnFocus = false end
	end
	if class == "ImageLabel" then o.BackgroundTransparency = 1 end
	local parent
	for k, v in pairs(props) do
		if k == "Parent" then parent = v elseif k ~= "Skin" then o[k] = v end
	end
	local map = props.Skin
	if textual and props.TextColor3 == nil and not (map and map.TextColor3) then
		local m = { TextColor3 = "Text" }
		for k, v in pairs(map or {}) do m[k] = v end
		map = m
	end
	if map then skin(o, map) end
	if textual and props.BackgroundTransparency == nil and (props.BackgroundColor3 ~= nil or (map and map.BackgroundColor3)) then
		o.BackgroundTransparency = 0
	end
	for _, c in ipairs(kids or {}) do c.Parent = o end
	if parent then o.Parent = parent end
	return o
end

local function stroke(parent, key, thick)
	local s = new("UIStroke", {
		Thickness = thick or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
	if typeof(key) == "Color3" then s.Color = key else skin(s, { Color = key or "Border" }) end
	return s
end

local function pad(parent, l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l),
		PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l), Parent = parent,
	})
end

local function vlist(parent, gap)
	return new("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = parent })
end

local function hlist(parent, gap, valign)
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap or 0),
		VerticalAlignment = valign or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = parent,
	})
end

local function textW(str, size)
	return TextService:GetTextSize(str, size or Theme.TextSize, Theme.Font, Vector2.new(10000, 10000)).X
end

local function inside(gui, pos)
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local mouseOffset, mouseSolved = Vector2.new(0, 0), false

local function mouse()
	local m = UIS:GetMouseLocation()
	return Vector2.new(m.X - mouseOffset.X, m.Y - mouseOffset.Y)
end

local function calibrate(gui, i)
	if mouseSolved then return end
	local m = UIS:GetMouseLocation()
	local ip = Vector2.new(i.Position.X, i.Position.Y)
	local a, b = inside(gui, m), inside(gui, ip)
	if a ~= b then
		mouseSolved = true
		mouseOffset = a and Vector2.new(0, 0) or Vector2.new(m.X - ip.X, m.Y - ip.Y)
		return
	end
	if not a then
		local ok, gi = pcall(function() return GuiService:GetGuiInset() end)
		if ok and gi and inside(gui, Vector2.new(m.X - gi.X, m.Y - gi.Y)) then
			mouseSolved = true
			mouseOffset = Vector2.new(gi.X, gi.Y)
		end
	end
end

local function calib(gui)
	gui.InputBegan:Connect(function(i)
		if not mouseSolved and isPress(i) then calibrate(gui, i) end
	end)
end

local function emit(obj, ...)
	if obj.Callback then task.spawn(obj.Callback, ...) end
	for _, f in ipairs(obj.Changed or {}) do task.spawn(f, ...) end
end

local function fire(obj, ...)
	emit(obj, ...)
	if obj.Id and not obj.NoConfig and obj.Type ~= "Keybind" then Library:_touch() end
end

local function register(id, obj)
	if id then
		Library.Options[id] = obj
		Library.Flags[id] = obj.Value
	end
end

local function fmtNum(n, round)
	local s = string.format("%." .. round .. "f", n)
	local int, frac = s:match("^(-?%d+)(.*)$")
	local r = int:reverse():gsub("(%d%d%d)", "%1,")
	r = r:reverse()
	r = r:gsub("^(%-?),", "%1")
	return r .. frac
end

local function toHex(c) return c:ToHex():upper() end

local function flashRow(row)
	if not row or not row.Parent or row:IsA("ScrollingFrame") then return end
	local f = new("Frame", {
		Position = UDim2.fromOffset(-3, -1), Size = UDim2.new(1, 6, 1, 2),
		BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.78, ZIndex = 0, Parent = row,
	})
	tween(f, { BackgroundTransparency = 1 }, 0.7, QUAD)
	task.delay(0.75, function() f:Destroy() end)
end

local function pulseText(lbl)
	if not Library.Animations then return end
	lbl.TextTransparency = 0.65
	tween(lbl, { TextTransparency = 0 }, 0.22, QUAD)
end

local function sweep(container)
	pcall(function()
		for _, c in ipairs(container:GetChildren()) do
			if c:GetAttribute("InteriumUI") or c:GetAttribute("AkaneUI") then c:Destroy() end
		end
	end)
end

local Gui = new("ScreenGui", {
	Name = HttpService:GenerateGUID(false), ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10000,
})
Gui:SetAttribute("InteriumUI", true)
do
	local ok, parent = pcall(function() return (gethui and gethui()) or CoreGui end)
	if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end
	local target = ok and parent or LocalPlayer:WaitForChild("PlayerGui")
	sweep(target)
	Gui.Parent = target
end

local HUD = new("Frame", { Name = "HUD", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = Gui })
local Overlay = new("Frame", { Name = "Overlay", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 100, Parent = Gui })

local function viewport()
	local v = Overlay.AbsoluteSize
	if v.X == 0 then v = workspace.CurrentCamera.ViewportSize end
	return v
end

local Popups, PopupOf, zc = {}, {}, 100

local function newPopup(w, h, parent)
	local root = new("Frame", {
		Visible = false, ClipsDescendants = true, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(w + 2, 0), Parent = parent or Overlay,
	})
	local panel = new("Frame", { Size = UDim2.fromOffset(w, h), Skin = { BackgroundColor3 = "Section" }, Parent = root })
	stroke(panel, "Border")
	PopupOf[root] = { W = w, H = h, Panel = panel, Up = false, Token = 0 }
	return root, panel
end

local function isOpen(frame)
	for _, p in ipairs(Popups) do if p.Frame == frame then return true end end
	return false
end

local function hidePopup(frame)
	local meta = PopupOf[frame]
	meta.Token = meta.Token + 1
	local tok = meta.Token
	if not Library.Animations then
		frame.Visible = false
		return
	end
	tween(frame, { Size = UDim2.fromOffset(meta.W + 2, 0) }, 0.16, QUAD, IN)
	task.delay(0.17, function()
		if meta.Token == tok then frame.Visible = false end
	end)
end

local function closePopup(frame)
	local idx
	for i, p in ipairs(Popups) do
		if p.Frame == frame then idx = i break end
	end
	if not idx then return end
	for i = #Popups, idx, -1 do
		local p = table.remove(Popups, i)
		p.Frame.Active = false
		if p.Close then p.Close() else hidePopup(p.Frame) end
		if p.OnClose then p.OnClose() end
	end
end

local function closeAllPopups(except)
	for i = #Popups, 1, -1 do
		local p = Popups[i]
		if p and p.Frame ~= except then closePopup(p.Frame) end
	end
end

local function resizePopup(frame, w, h, animate)
	local meta = PopupOf[frame]
	meta.W, meta.H = w, h
	local rootSize = UDim2.fromOffset(w + 2, h > 0 and h + 2 or 0)
	local panelSize = UDim2.fromOffset(w, h)
	if animate and Library.Animations then
		tween(meta.Panel, { Size = panelSize }, 0.24, QUINT)
		tween(frame, { Size = rootSize }, 0.24, QUINT)
	else
		meta.Panel.Size = panelSize
		frame.Size = rootSize
	end
end

local function openPopup(frame, anchor, o)
	o = o or {}
	if not o.Child then closeAllPopups(frame) end
	if isOpen(frame) then return end
	local meta = PopupOf[frame]
	local w, h = meta.W, meta.H
	local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
	local vp = viewport()
	local gap = o.Gap or 3

	local x = ap.X - 1
	if o.Align == "right" then x = ap.X + as.X - w - 1 end
	x = math.clamp(x, 4, math.max(4, vp.X - (w + 2) - 4))

	local below = ap.Y + as.Y + 1 + gap
	local up = false
	if not o.NoFlip and below + h + 2 > vp.Y - 4 and ap.Y - 1 - gap - (h + 2) >= 4 then up = true end

	meta.Up = up
	frame.AnchorPoint = up and Vector2.new(0, 1) or Vector2.new(0, 0)
	frame.Position = UDim2.fromOffset(math.floor(x), math.floor(up and (ap.Y - 1 - gap) or below))
	meta.Panel.AnchorPoint = up and Vector2.new(0, 1) or Vector2.new(0, 0)
	meta.Panel.Position = up and UDim2.new(0, 1, 1, -1) or UDim2.fromOffset(1, 1)

	zc = zc + 1
	frame.ZIndex = zc
	meta.Token = meta.Token + 1
	frame.Visible = true
	frame.Active = true
	table.insert(Popups, { Frame = frame, Anchor = anchor, OnClose = o.OnClose, Hit = { frame, anchor } })

	local full = UDim2.fromOffset(w + 2, h + 2)
	if Library.Animations then
		frame.Size = UDim2.fromOffset(w + 2, 0)
		tween(frame, { Size = full }, 0.2, QUINT)
	else
		frame.Size = full
	end
end

local TipRoot = new("CanvasGroup", {
	Visible = false, AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1,
	GroupTransparency = 1, ZIndex = 5000, Parent = Overlay,
})
pad(TipRoot, 1, 1, 1, 1)
local TipPanel = new("Frame", {
	AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), Skin = { BackgroundColor3 = "Section" }, Parent = TipRoot,
})
stroke(TipPanel, "Border")
local TipLabel = new("TextLabel", {
	AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), Text = "", Parent = TipPanel,
})
pad(TipLabel, 8, 0, 8, 0)

local function tip(gui, str)
	if not str then return end
	local token, hovering = 0, false
	local function move()
		local m = mouse()
		local vp = viewport()
		local w = TipRoot.AbsoluteSize.X
		TipRoot.Position = UDim2.fromOffset(math.min(m.X + 14, vp.X - w - 4), m.Y + 16)
	end
	gui.MouseEnter:Connect(function()
		hovering = true
		token = token + 1
		local my = token
		task.delay(0.4, function()
			if hovering and my == token then
				TipLabel.Text = str
				move()
				TipRoot.Visible = true
				TipRoot.GroupTransparency = 1
				tween(TipRoot, { GroupTransparency = 0 }, 0.15, QUAD)
			end
		end)
	end)
	gui.MouseMoved:Connect(function() if TipRoot.Visible then move() end end)
	gui.MouseLeave:Connect(function()
		hovering = false
		token = token + 1
		local my = token
		tween(TipRoot, { GroupTransparency = 1 }, 0.1, QUAD)
		task.delay(0.11, function() if my == token then TipRoot.Visible = false end end)
	end)
end

local function checker(parent, w, h, s)
	local bg = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 70, 76), ClipsDescendants = true, Parent = parent,
	})
	for y = 0, math.ceil(h / s) - 1 do
		for x = 0, math.ceil(w / s) - 1 do
			if (x + y) % 2 == 1 then
				new("Frame", {
					Position = UDim2.fromOffset(x * s, y * s), Size = UDim2.fromOffset(s, s),
					BackgroundColor3 = Color3.fromRGB(46, 46, 52), Parent = bg,
				})
			end
		end
	end
	return bg
end

local function chevron(parent, xoff)
	local c = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xoff or -7, 0.5, 0),
		Size = UDim2.fromOffset(7, 4), BackgroundTransparency = 1, Parent = parent,
	})
	local rows = {}
	for r = 0, 3 do
		rows[#rows + 1] = new("Frame", {
			Position = UDim2.fromOffset(r, r), Size = UDim2.fromOffset(7 - r * 2, 1),
			BackgroundColor3 = Theme.TextDim, Parent = c,
		})
	end
	local function setColor(col, instant)
		for _, p in ipairs(rows) do
			if instant then p.BackgroundColor3 = col else tween(p, { BackgroundColor3 = col }, 0.15, QUAD) end
		end
	end
	return setColor, c
end

local function magnifier(parent)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = parent,
	})
	local ring = new("Frame", { Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(5, 5), BackgroundTransparency = 1, Parent = f })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local rs = new("UIStroke", { Color = Theme.TextDim, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ring })
	local handle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(4, 1),
		Rotation = 45, BackgroundColor3 = Theme.TextDim, Parent = f,
	})
	return function(c, instant)
		if instant then
			rs.Color = c
			handle.BackgroundColor3 = c
		else
			tween(rs, { Color = c }, 0.15, QUAD)
			tween(handle, { BackgroundColor3 = c }, 0.15, QUAD)
		end
	end
end

local function logo(parent)
	local f = new("Frame", { Size = UDim2.fromOffset(10, 13), BackgroundTransparency = 1, Parent = parent })
	new("Frame", {
		Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(6, 2),
		Skin = { BackgroundColor3 = "Accent" }, Parent = f,
	})
	new("Frame", {
		Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(2, 9),
		Skin = { BackgroundColor3 = "Accent" }, Parent = f,
	})
	new("Frame", {
		Position = UDim2.fromOffset(2, 11), Size = UDim2.fromOffset(6, 2),
		Skin = { BackgroundColor3 = "Accent" }, Parent = f,
	})
	return f
end

local function spacer(parent, w)
	return new("Frame", { Size = UDim2.fromOffset(w, 1), BackgroundTransparency = 1, Parent = parent })
end

local function tabBar(parent, size, padding, opts)
	opts = opts or {}
	local B = { Tabs = {}, Width = 0, Active = nil }
	local ul = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2),
		ZIndex = 3, Visible = false, Skin = { BackgroundColor3 = "Accent" }, Parent = parent,
	})

	function B:Relayout()
		local order = {}
		for n, o in pairs(B.Tabs) do
			if o.Btn and o.Btn.Parent then order[#order + 1] = { n, o } end
		end
		table.sort(order, function(a, b)
			local ia, ib = a[2].Order or 0, b[2].Order or 0
			if ia == ib then return (a[2].X or 0) < (b[2].X or 0) end
			return ia < ib
		end)
		local x = 0
		for i, e in ipairs(order) do
			local n, o = e[1], e[2]
			o.Order = i
			o.W = math.ceil(textW(n, size)) + padding * 2
			o.X = x
			o.Btn.Position = UDim2.fromOffset(x, 0)
			o.Btn.Size = UDim2.new(0, o.W, 1, 0)
			x = x + o.W
		end
		B.Width = x
		if opts.OnWidth then opts.OnWidth(B.Width) end
		if B.Active and B.Tabs[B.Active] then
			local t = B.Tabs[B.Active]
			ul.Visible = true
			ul.Position = UDim2.new(0, t.X, 1, 0)
			ul.Size = UDim2.new(0, t.W, 0, 2)
		elseif not B.Active then
			ul.Visible = false
		end
	end

	function B:Remove(str)
		local t = B.Tabs[str]
		if not t then return end
		if t.Btn then pcall(function() t.Btn:Destroy() end) end
		B.Tabs[str] = nil
		if B.Active == str then B.Active = nil end
		B:Relayout()
	end

	function B:Add(str, onClick, atOrder)
		if B.Tabs[str] then return B.Tabs[str].Btn end
		local w = math.ceil(textW(str, size)) + padding * 2
		local b = new("TextButton", {
			Position = UDim2.fromOffset(B.Width, 0), Size = UDim2.new(0, w, 1, 0), Text = str,
			TextSize = size, TextColor3 = Theme.TextDim, Parent = parent,
		})
		local ord = atOrder
		if not ord then
			ord = 0
			for _, o in pairs(B.Tabs) do
				if (o.Order or 0) > ord then ord = o.Order end
			end
			ord = ord + 1
		else
			for _, o in pairs(B.Tabs) do
				if (o.Order or 0) >= ord then o.Order = (o.Order or 0) + 1 end
			end
		end
		B.Tabs[str] = { Btn = b, X = B.Width, W = w, OnClick = onClick, Order = ord }
		B:Relayout()
		b.MouseEnter:Connect(function()
			if B.Active ~= str then tween(b, { TextColor3 = Theme.TextHover }, 0.1, QUAD) end
		end)
		b.MouseLeave:Connect(function()
			if B.Active ~= str then tween(b, { TextColor3 = Theme.TextDim }, 0.18, QUAD) end
		end)
		calib(b)
		b.MouseButton1Click:Connect(function()
			if onClick then onClick(str) else B:Select(str) end
		end)
		return b
	end

	function B:Select(str, instant)
		local t = B.Tabs[str]
		if not t then return end
		local first = B.Active == nil
		B.Active = str
		for n, o in pairs(B.Tabs) do
			local col = n == str and Theme.Text or Theme.TextDim
			if instant then o.Btn.TextColor3 = col else tween(o.Btn, { TextColor3 = col }, 0.2, QUAD) end
		end
		ul.Visible = true
		local pos, sz = UDim2.new(0, t.X, 1, 0), UDim2.new(0, t.W, 0, 2)
		if first or instant then
			ul.Position, ul.Size = pos, sz
		else
			tween(ul, { Position = pos, Size = sz }, 0.3, QUINT)
		end
	end

	bind(ul, function()
		for n, o in pairs(B.Tabs) do
			o.Btn.TextColor3 = n == B.Active and Theme.Text or Theme.TextDim
		end
	end)
	return B
end

local function makeItem(parent, str, h, right)
	local b = new("TextButton", { Size = UDim2.new(1, 0, 0, h or M.Item), Parent = parent })
	local tint = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Skin = { BackgroundColor3 = "Accent" }, Parent = b })
	new("UIGradient", { Transparency = NumberSequence.new(0.72, 1), Parent = tint })
	local bar = new("Frame", { Size = UDim2.new(0, 2, 1, 0), BackgroundTransparency = 1, Skin = { BackgroundColor3 = "Accent" }, Parent = b })
	local rw = right and (math.ceil(textW(right)) + 8) or 0
	local lbl = new("TextLabel", {
		Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -(16 + rw), 1, 0), Text = str,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = Theme.TextDim, Parent = b,
	})
	local rl
	if right then
		rl = new("TextLabel", {
			Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Text = right,
			TextXAlignment = Enum.TextXAlignment.Right, Skin = { TextColor3 = "TextOff" }, Parent = b,
		})
	end
	calib(b)
	local sel = false
	local function set(s, instant)
		sel = s
		local tt, lc = s and 0 or 1, s and Theme.Text or Theme.TextDim
		if instant then
			tint.BackgroundTransparency = tt
			bar.BackgroundTransparency = tt
			lbl.TextColor3 = lc
		else
			tween(tint, { BackgroundTransparency = tt }, 0.22, QUAD)
			tween(bar, { BackgroundTransparency = tt }, 0.18, QUAD)
			tween(lbl, { TextColor3 = lc }, 0.18, QUAD)
		end
	end
	b.MouseEnter:Connect(function() if not sel then tween(lbl, { TextColor3 = Theme.TextHover }, 0.1, QUAD) end end)
	b.MouseLeave:Connect(function() if not sel then tween(lbl, { TextColor3 = Theme.TextDim }, 0.18, QUAD) end end)
	bind(b, function() lbl.TextColor3 = sel and Theme.Text or Theme.TextDim end)
	return b, set, rl
end

local function segmented(parent, items, width, onPick)
	local S = { Value = nil, Btns = {} }
	local frame = new("Frame", { Size = UDim2.new(1, 0, 0, M.Box), BackgroundTransparency = 1, Parent = parent })
	local inner = new("Frame", {
		Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Skin = { BackgroundColor3 = "Element" }, Parent = frame,
	})
	stroke(inner, "Border")
	local iw = width - 2
	local n = #items
	local bw = math.floor(iw / n)
	for i, name in ipairs(items) do
		local w = i == n and (iw - bw * (n - 1)) or bw
		local b = new("TextButton", {
			Position = UDim2.fromOffset((i - 1) * bw, 0), Size = UDim2.new(0, w, 1, 0), Text = name,
			TextColor3 = Theme.TextDim, Parent = inner,
		})
		if i > 1 then
			new("Frame", { Position = UDim2.fromOffset((i - 1) * bw, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = 2, Skin = { BackgroundColor3 = "Border" }, Parent = inner })
		end
		S.Btns[name] = b
		b.MouseEnter:Connect(function() if S.Value ~= name then tween(b, { TextColor3 = Theme.TextHover }, 0.1, QUAD) end end)
		b.MouseLeave:Connect(function() if S.Value ~= name then tween(b, { TextColor3 = Theme.TextDim }, 0.15, QUAD) end end)
		b.MouseButton1Click:Connect(function()
			S:Set(name)
			if onPick then onPick(name) end
		end)
	end
	function S:Set(name, instant)
		S.Value = name
		for n2, b in pairs(S.Btns) do
			local on = n2 == name
			local col = on and Theme.Accent or Theme.TextDim
			local bg = on and Theme.Box or Theme.Element
			if instant then
				b.TextColor3 = col
				b.BackgroundColor3 = bg
			else
				tween(b, { TextColor3 = col, BackgroundColor3 = bg }, 0.15, QUAD)
			end
			b.BackgroundTransparency = on and 0 or 1
		end
	end
	bind(frame, function() S:Set(S.Value, true) end)
	return S, frame
end

local Elements = {}
local function makeContainer(content, tab, popupParent)
	return setmetatable({ Content = content, Tab = tab, PopupParent = popupParent }, { __index = Elements })
end

local function buildDropdown(parent, o, inline)
	local D = {
		Type = "Dropdown", Items = o.Items or {}, Multi = o.Multi, Callback = o.Callback, Changed = {},
	}
	if D.Multi then
		D.Value = {}
		for _, v in ipairs(o.Default or {}) do D.Value[v] = true end
	else
		D.Value = o.Default or D.Items[1]
	end

	local box = new("TextButton", {
		Position = o.Position or UDim2.fromOffset(1, 1), Size = o.Size or UDim2.new(1, -2, 1, -2),
		Skin = { BackgroundColor3 = "Element" }, Parent = parent,
	})
	local bs = stroke(box, "Border")
	local txt = new("TextLabel", {
		Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -21, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Skin = { TextColor3 = "TextMid" }, Parent = box,
	})
	local setArrow, arrow = chevron(box, -7)
	D.Box = box

	local list, sf
	local itemSetters = {}

	local function isSel(v)
		if D.Multi then return D.Value[v] == true end
		return D.Value == v
	end

	local function display()
		local out
		if D.Multi then
			local t = {}
			for _, v in ipairs(D.Items) do if D.Value[v] then t[#t + 1] = tostring(v) end end
			out = #t > 0 and table.concat(t, ", ") or "None"
		else
			out = tostring(D.Value or "")
		end
		if txt.Text ~= out then
			txt.Text = out
			pulseText(txt)
		end
	end

	local function sync(instant)
		for v, set in pairs(itemSetters) do set(isSel(v), instant) end
	end

	local hovering = false
	local function paint(instant)
		local s = (list and isOpen(list)) and "open" or (hovering and "hover" or "idle")
		local bc = s == "open" and Theme.Border or (s == "hover" and Theme.BorderHover or Theme.Border)
		local ac = s == "idle" and Theme.TextDim or Theme.Text
		if instant then
			bs.Color = bc
			setArrow(ac, true)
			arrow.Rotation = s == "open" and 180 or 0
		else
			tween(bs, { Color = bc }, 0.14, QUAD)
			setArrow(ac)
			tween(arrow, { Rotation = s == "open" and 180 or 0 }, 0.22, QUINT)
		end
	end
	bind(box, function() paint(true) end)

	local slot, panel, inlineOpen
	local function ensureList()
		if list then return end
		local host
		if inline then
			slot = new("Frame", {
				Position = UDim2.fromOffset(0, M.Label + M.LabelGap + M.Box - 1), Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1, ClipsDescendants = true, Visible = false, Parent = parent,
			})
			panel = new("Frame", {
				Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 0, 0), Skin = { BackgroundColor3 = "Window" }, Parent = slot,
			})
			stroke(panel, "Border")
			list, host = slot, panel
		else
			list = newPopup(100, M.Item)
			host = PopupOf[list].Panel
		end
		sf = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 0,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = host,
		})
		vlist(sf, 0)
	end

	local function closeInline()
		inlineOpen = false
		tween(slot, { Size = UDim2.new(1, 0, 0, 0) }, 0.18, QUAD, IN)
		tween(parent, { Size = UDim2.new(1, 0, 0, M.DD) }, 0.18, QUAD, IN)
		task.delay(0.2, function() if not inlineOpen then slot.Visible = false end end)
	end

	local function populate()
		for _, c in ipairs(sf:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		itemSetters = {}
		for i, v in ipairs(D.Items) do
			local b, set = makeItem(sf, tostring(v), M.Item)
			b.LayoutOrder = i
			itemSetters[v] = set
			set(isSel(v), true)
			b.MouseButton1Click:Connect(function()
				if D.Multi then
					D.Value[v] = not D.Value[v] or nil
					display()
					sync()
					if D.Id then Library.Flags[D.Id] = D.Value end
					fire(D, D.Value)
				else
					D:SetValue(v)
					closePopup(list)
				end
			end)
		end
	end

	function D:SetValue(v, silent)
		if D.Multi then
			D.Value = {}
			if type(v) == "table" then
				for k, x in pairs(v) do
					if x == true then D.Value[k] = true elseif type(k) == "number" then D.Value[x] = true end
				end
			end
		else
			D.Value = v
		end
		display()
		sync()
		if D.Id then Library.Flags[D.Id] = D.Value end
		if not silent then fire(D, D.Value) end
	end
	function D:SetItems(items)
		D.Items = items
		if not D.Multi and not table.find(items, D.Value) then D.Value = items[1] end
		display()
	end
	function D:OnChanged(fn) table.insert(D.Changed, fn) end
	function D:Serialize()
		if not D.Multi then return D.Value end
		local t = {}
		for _, v in ipairs(D.Items) do if D.Value[v] then t[#t + 1] = v end end
		return t
	end
	function D:Deserialize(d) D:SetValue(d) end

	box.MouseEnter:Connect(function() hovering = true; if not (list and isOpen(list)) then paint() end end)
	box.MouseLeave:Connect(function() hovering = false; if not (list and isOpen(list)) then paint() end end)

	box.MouseButton1Click:Connect(function()
		ensureList()
		if isOpen(list) then closePopup(list) return end
		populate()
		local rows = math.max(1, math.min(#D.Items, 8))
		local h = rows * M.Item
		sf.ScrollingEnabled = #D.Items > 8
		sf.CanvasPosition = Vector2.new()
		if inline then
			closeAllPopups()
			inlineOpen = true
			slot.Visible = true
			panel.Size = UDim2.new(1, -2, 0, h)
			table.insert(Popups, { Frame = slot, Anchor = box, Hit = { slot, box }, Close = closeInline, OnClose = function() paint() end })
			tween(slot, { Size = UDim2.new(1, 0, 0, h + 2) }, 0.22, QUINT)
			tween(parent, { Size = UDim2.new(1, 0, 0, M.DD - 1 + h + 2) }, 0.22, QUINT)
		else
			resizePopup(list, box.AbsoluteSize.X, h, false)
			openPopup(list, box, { Child = true, Gap = -1, NoFlip = true, OnClose = function() paint() end })
		end
		paint()
	end)

	display()
	return D
end

local PUI = { Editing = "Color", H = 0, S = 0, V = 1, A = 1, Tab = nil, NoAlpha = false }

local PW      = 200
local PPAD    = 8
local CW      = PW - PPAD * 2
local HUEW    = 16
local SVS     = CW - HUEW - PPAD
local PHEAD   = 24
local ALPHAY  = PPAD + SVS + PPAD
local HEXW    = 60
local PANIM_H = PPAD + M.DD + M.Gap + M.Slider + M.Gap + M.Row + M.Gap + M.Row + PPAD

local function colorH() return PUI.NoAlpha and (ALPHAY + M.Box + PPAD) or (ALPHAY + 16 + PPAD + M.Box + PPAD) end
local function inputY() return PUI.NoAlpha and ALPHAY or (ALPHAY + 16 + PPAD) end

local function animColor(P, t)
	local a = P.Animation
	local rate = 0.15 + (P.Speed / 100) * 1.85
	if a == "Fading" then
		return P.Color:Lerp(P.Color2, (math.sin(t * rate * math.pi) + 1) / 2)
	elseif a == "Rainbow" then
		local _, s, v = P.Color:ToHSV()
		return Color3.fromHSV((t * rate * 0.5) % 1, math.max(s, 0.6), math.max(v, 0.8))
	elseif a == "Pulse" then
		return P.Color:Lerp(Color3.new(P.Color.R * 0.3, P.Color.G * 0.3, P.Color.B * 0.3), (math.sin(t * rate * math.pi) + 1) / 2)
	end
	return P.Color
end

local function swatchFace(parent, w, h)
	local face = new("Frame", {
		Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(w - 2, h - 2), BackgroundTransparency = 1,
		ClipsDescendants = true, Parent = parent,
	})
	stroke(face, "BorderDark")
	checker(face, w - 2, h - 2, 5)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = face })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)), Parent = fill })
	return fill, face
end

local function buildPickerUI()
	if PUI.Frame then return end
	local root, panel = newPopup(PW, PHEAD + colorH())
	PUI.Frame = root

	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, PHEAD), BackgroundTransparency = 1, Parent = panel })
	new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1),
		Skin = { BackgroundColor3 = "Border" }, Parent = bar,
	})
	local tabs = tabBar(bar, Theme.TitleSize, 10)

	local body = new("Frame", {
		Position = UDim2.fromOffset(0, PHEAD), Size = UDim2.new(1, 0, 1, -PHEAD),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = panel,
	})
	local colorPane = new("Frame", { Size = UDim2.new(1, 0, 0, 230), BackgroundTransparency = 1, Parent = body })
	local animPane = new("Frame", { Size = UDim2.new(1, 0, 0, PANIM_H), BackgroundTransparency = 1, Visible = false, Parent = body })

	function PUI.SetTab(name, instant)
		PUI.Tab = name
		tabs:Select(name, instant)
		colorPane.Visible = name == "Color"
		animPane.Visible = name == "Animation"
		local h = PHEAD + (name == "Color" and colorH() or PANIM_H)
		resizePopup(root, PW, h, (not instant) and isOpen(root))
	end
	tabs:Add("Color", function() PUI.Editing = "Color"; PUI.Sync(); PUI.SetTab("Color") end)
	PUI.AnimTab = tabs:Add("Animation", function() PUI.SetTab("Animation") end)

	local svW = SVS - 2
	local sv = new("TextButton", {
		Position = UDim2.fromOffset(PPAD + 1, PPAD + 1), Size = UDim2.fromOffset(svW, svW),
		BackgroundColor3 = Color3.new(1, 0, 0), BackgroundTransparency = 0, ClipsDescendants = true, Parent = colorPane,
	})
	stroke(sv, "BorderDark")
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv })
	new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
	local svMark = new("Frame", { Size = UDim2.fromOffset(5, 5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = sv })
	stroke(svMark, Color3.new(0, 0, 0))

	local hue = new("TextButton", {
		Position = UDim2.fromOffset(PPAD + SVS + PPAD + 1, PPAD + 1), Size = UDim2.fromOffset(HUEW - 2, svW),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ClipsDescendants = true, Parent = colorPane,
	})
	stroke(hue, "BorderDark")
	local keys = {}
	for k = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(k / 6, Color3.fromHSV((k % 6) / 6, 1, 1)) end
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(keys), Parent = hue })
	local hueMark = new("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = hue })
	stroke(hueMark, Color3.new(0, 0, 0))

	local aw = CW - 2
	local alpha = new("TextButton", {
		Position = UDim2.fromOffset(PPAD + 1, ALPHAY + 1), Size = UDim2.fromOffset(aw, 14),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ClipsDescendants = true, Parent = colorPane,
	})
	stroke(alpha, "BorderDark")
	checker(alpha, aw, 14, 7)
	local aFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = alpha })
	new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = aFill })
	local aMark = new("Frame", { Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = alpha })
	stroke(aMark, Color3.new(0, 0, 0))

	local inputs = {}
	local function inputBox(x, w)
		local slot = new("Frame", { Position = UDim2.fromOffset(x, inputY()), Size = UDim2.fromOffset(w, M.Box), BackgroundTransparency = 1, Parent = colorPane })
		local fr = new("Frame", { Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Skin = { BackgroundColor3 = "Element" }, Parent = slot })
		local st = stroke(fr, "Border")
		local tb = new("TextBox", {
			Size = UDim2.new(1, -14, 1, 0), Position = UDim2.fromOffset(7, 0), TextXAlignment = Enum.TextXAlignment.Left,
			Skin = { TextColor3 = "TextMid" }, Text = "", ClipsDescendants = true, Parent = fr,
		})
		tb.Focused:Connect(function() tween(st, { Color = Theme.Accent }, 0.15, QUAD) end)
		tb.FocusLost:Connect(function() tween(st, { Color = Theme.Border }, 0.2, QUAD) end)
		inputs[#inputs + 1] = slot
		return tb, slot
	end
	local hex, hexSlot = inputBox(PPAD, HEXW)
	local rgbBox, rgbSlot = inputBox(PPAD + HEXW + M.Gap, CW - HEXW - M.Gap)

	function PUI.Relayout()
		alpha.Visible = not PUI.NoAlpha
		for _, s in ipairs(inputs) do s.Position = UDim2.fromOffset(s.Position.X.Offset, inputY()) end
		colorPane.Size = UDim2.new(1, 0, 0, colorH())
	end

	function PUI.Draw()
		local P = PUI.Current
		if not P then return end
		local c = Color3.fromHSV(PUI.H, PUI.S, PUI.V)
		sv.BackgroundColor3 = Color3.fromHSV(PUI.H, 1, 1)
		svMark.Position = UDim2.fromOffset(math.floor(PUI.S * svW + 0.5) - 2, math.floor((1 - PUI.V) * svW + 0.5) - 2)
		hueMark.Position = UDim2.fromOffset(0, math.floor(PUI.H * svW + 0.5) - 1)
		aFill.BackgroundColor3 = c
		aMark.Position = UDim2.fromOffset(math.floor((1 - PUI.A) * (aw - 2) + 0.5), 0)
		if not hex:IsFocused() then hex.Text = "#" .. toHex(c) end
		if not rgbBox:IsFocused() then
			local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
			if PUI.NoAlpha or PUI.Editing == "Color2" then
				rgbBox.Text = string.format("%d,%d,%d", r, g, b)
			else
				rgbBox.Text = string.format("%d,%d,%d,%d", r, g, b, math.floor(PUI.A * 100 + 0.5))
			end
		end
	end

	function PUI.Sync()
		local P = PUI.Current
		if not P then return end
		local c = (PUI.Editing == "Color2") and P.Color2 or P.Color
		local h, s, v = c:ToHSV()
		if s > 0.001 and v > 0.001 then PUI.H = h end
		if v > 0.001 then PUI.S = s end
		PUI.V = v
		PUI.A = (PUI.Editing == "Color") and P.Alpha or 1
		PUI.Draw()
	end

	function PUI.Apply()
		local P = PUI.Current
		if not P then return end
		local c = Color3.fromHSV(PUI.H, PUI.S, PUI.V)
		if PUI.Editing == "Color2" then P.Color2 = c else P.Color = c; P.Alpha = PUI.A end
		PUI.Draw()
		P:_update(true)
	end

	local function drag(btn, fn)
		btn.InputBegan:Connect(function(i)
			if isPress(i) then
				calibrate(btn, i)
				fn(mouse())
				Library._drag = fn
				Library._dragEnd = nil
			end
		end)
	end
	drag(sv, function(mp)
		PUI.S = math.clamp((mp.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
		PUI.V = 1 - math.clamp((mp.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		PUI.Apply()
	end)
	drag(hue, function(mp)
		PUI.H = math.clamp((mp.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 0.9999)
		PUI.Apply()
	end)
	drag(alpha, function(mp)
		PUI.A = 1 - math.clamp((mp.X - alpha.AbsolutePosition.X) / alpha.AbsoluteSize.X, 0, 1)
		PUI.Apply()
	end)

	local function takeColor(c)
		local h, sat, v = c:ToHSV()
		if sat > 0.001 and v > 0.001 then PUI.H = h end
		PUI.S, PUI.V = sat, v
	end
	hex.FocusLost:Connect(function()
		local s = (hex.Text:gsub("[#%s]", ""))
		if #s == 3 then s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2) end
		if #s == 6 and s:match("^%x+$") then
			takeColor(Color3.fromHex(s))
			PUI.Apply()
		else
			PUI.Draw()
		end
	end)
	rgbBox.FocusLost:Connect(function()
		local n = {}
		for v in rgbBox.Text:gmatch("%d+%.?%d*") do n[#n + 1] = tonumber(v) end
		if #n >= 3 then
			takeColor(Color3.fromRGB(math.clamp(n[1], 0, 255), math.clamp(n[2], 0, 255), math.clamp(n[3], 0, 255)))
			if n[4] and PUI.Editing == "Color" and not PUI.NoAlpha then PUI.A = math.clamp(n[4] / 100, 0, 1) end
			PUI.Apply()
		else
			PUI.Draw()
		end
	end)

	local content = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = animPane })
	vlist(content, M.Gap)
	pad(content, PPAD, PPAD, PPAD, PPAD)
	local c = makeContainer(content, nil, root)
	PUI.AnimDD = c:AddDropdown(nil, {
		Text = "Animation", Items = { "None", "Fading", "Rainbow", "Pulse" }, Default = "None", NoConfig = true,
		Callback = function(v) if PUI.Current then PUI.Current.Animation = v; PUI.Current:_update(true) end end,
	})
	PUI.SpeedSl = c:AddSlider(nil, {
		Text = "Speed", Min = 0, Max = 100, Default = 50, Suffix = "%", NoConfig = true,
		Callback = function(v) if PUI.Current then PUI.Current.Speed = v; PUI.Current:_update(true) end end,
	})
	PUI.Swatches = {}
	for i, key in ipairs({ "Color", "Color2" }) do
		local row = new("TextButton", { Size = UDim2.new(1, 0, 0, M.Row), Parent = content })
		new("TextLabel", { Size = UDim2.fromScale(1, 1), Text = "Color " .. i, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local slot = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(20, 12),
			BackgroundTransparency = 1, Parent = row,
		})
		local fill, face = swatchFace(slot, 20, 12)
		local fs = face:FindFirstChildOfClass("UIStroke")
		PUI.Swatches[key] = fill
		row.MouseEnter:Connect(function() tween(fs, { Color = Theme.BorderHover }, 0.12, QUAD) end)
		row.MouseLeave:Connect(function() tween(fs, { Color = Theme.BorderDark }, 0.15, QUAD) end)
		row.MouseButton1Click:Connect(function()
			PUI.Editing = key
			PUI.Sync()
			PUI.SetTab("Color")
		end)
	end

	PUI.Relayout()
	PUI.SetTab("Color", true)
end

function PUI.UpdateSwatches()
	if not PUI.Current or not PUI.Swatches then return end
	PUI.Swatches.Color.BackgroundColor3 = PUI.Current.Color
	PUI.Swatches.Color2.BackgroundColor3 = PUI.Current.Color2
end

function PUI.Open(P, anchor)
	buildPickerUI()
	if isOpen(PUI.Frame) and PUI.Current == P then closePopup(PUI.Frame) return end
	PUI.Current = P
	PUI.Editing = "Color"
	PUI.NoAlpha = P.NoAlpha == true
	PUI.AnimTab.Visible = not P.NoAnim
	PUI.Relayout()
	PUI.SetTab("Color", true)
	PUI.AnimDD:SetValue(P.Animation, true)
	PUI.SpeedSl:SetValue(P.Speed, true, true)
	PUI.UpdateSwatches()
	PUI.Sync()
	openPopup(PUI.Frame, anchor, { Align = "left", Gap = 4 })
end

local function attachPicker(holder, id, o)
	o = o or {}
	local P = {
		Type = "ColorPicker", Color = o.Default or Color3.new(1, 1, 1), Alpha = o.Alpha or 1,
		Color2 = o.Color2 or Color3.fromRGB(100, 80, 190), Animation = o.Animation or "None",
		Speed = o.Speed or 50, Callback = o.Callback, Changed = {}, Id = id,
		NoConfig = o.NoConfig, NoAlpha = o.NoAlpha, NoAnim = o.NoAnim,
	}
	P.Value = P.Color

	local sw = new("TextButton", { Size = UDim2.fromOffset(20, 12), LayoutOrder = #holder:GetChildren(), Parent = holder })
	calib(sw)
	local fill, face = swatchFace(sw, 20, 12)
	local sws = face:FindFirstChildOfClass("UIStroke")
	sw.MouseEnter:Connect(function() tween(sws, { Color = Theme.BorderHover }, 0.12, QUAD) end)
	sw.MouseLeave:Connect(function() tween(sws, { Color = Theme.BorderDark }, 0.15, QUAD) end)

	local last
	local function paint(animate)
		local a = P.NoAlpha and 0 or 1 - P.Alpha
		if animate then
			tween(fill, { BackgroundColor3 = P.Value, BackgroundTransparency = a }, 0.28, QUAD)
		else
			fill.BackgroundColor3 = P.Value
			fill.BackgroundTransparency = a
		end
	end

	function P:_update(userDriven, animate)
		P.Value = animColor(P, os.clock())
		if P.Animation ~= "None" then Library._animated[P] = true else Library._animated[P] = nil end
		paint(animate)
		if id then Library.Flags[id] = P.Value end
		if PUI.Current == P then PUI.UpdateSwatches() end
		last = P.Value
		fire(P, P.Value, P.Alpha)
	end
	function P:_tick()
		local c = animColor(P, os.clock())
		if c ~= last then
			last = c
			P.Value = c
			paint(false)
			if id then Library.Flags[id] = c end
			emit(P, c, P.Alpha)
		end
	end
	function P:SetValue(c, a, silent)
		if typeof(c) == "table" then c, a = c.Color or c[1], c.Alpha or a end
		P.Color = c
		if a then P.Alpha = a end
		if silent then
			P.Value = animColor(P, os.clock())
			paint(false)
			if id then Library.Flags[id] = P.Value end
		else
			P:_update(false, true)
		end
		if PUI.Current == P and PUI.Frame then PUI.Sync() end
	end
	function P:SetAnimation(name, speed, c2)
		P.Animation = name or P.Animation
		P.Speed = speed or P.Speed
		P.Color2 = c2 or P.Color2
		P:_update()
	end
	function P:OnChanged(fn) table.insert(P.Changed, fn) end
	function P:Flash() flashRow(holder.Parent) end
	function P:Serialize()
		return { c = toHex(P.Color), a = P.Alpha, an = P.Animation, sp = P.Speed, c2 = toHex(P.Color2) }
	end
	function P:Deserialize(d)
		if type(d) ~= "table" then return end
		if d.c2 then P.Color2 = Color3.fromHex(d.c2) end
		if d.sp then P.Speed = d.sp end
		if d.an then P.Animation = d.an end
		if d.c then P:SetValue(Color3.fromHex(d.c), d.a) else P:_update() end
	end

	sw.MouseButton1Click:Connect(function() PUI.Open(P, sw) end)
	if o.Tooltip then tip(sw, o.Tooltip) end
	P:_update()
	register(id, P)
	return P
end

local MB = {
	[Enum.UserInputType.MouseButton1] = "MB1", [Enum.UserInputType.MouseButton2] = "MB2",
	[Enum.UserInputType.MouseButton3] = "MB3",
}
local KeyShort = {
	Insert = "INS", Delete = "DEL", LeftShift = "LSHIFT", RightShift = "RSHIFT", LeftControl = "LCTRL",
	RightControl = "RCTRL", LeftAlt = "LALT", RightAlt = "RALT", Return = "ENTER", Backspace = "BKSP",
	CapsLock = "CAPS", Escape = "ESC", PageUp = "PGUP", PageDown = "PGDN", Space = "SPACE",
}
local function shortKey(name) return (KeyShort[name] or name):upper() end
local function inputName(i)
	if i.UserInputType == Enum.UserInputType.Keyboard then return i.KeyCode.Name end
	return MB[i.UserInputType]
end

local KL = {}

local KBW = 160
local KBH = PPAD + M.Label + M.LabelGap + M.Box + M.Gap + M.Row + PPAD

local function openKeybindPopup(K, anchor)
	if not K.Popup then
		local root, panel = newPopup(KBW, KBH)
		local content = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = panel })
		pad(content, PPAD, PPAD, PPAD, PPAD)
		vlist(content, M.Gap)
		local modeRow = new("Frame", { Size = UDim2.new(1, 0, 0, M.Label + M.LabelGap + M.Box), BackgroundTransparency = 1, LayoutOrder = 1, Parent = content })
		new("TextLabel", { Size = UDim2.new(1, 0, 0, M.Label), Text = "Mode", TextXAlignment = Enum.TextXAlignment.Left, Parent = modeRow })
		local segHolder = new("Frame", { Position = UDim2.fromOffset(0, M.Label + M.LabelGap), Size = UDim2.new(1, 0, 0, M.Box), BackgroundTransparency = 1, Parent = modeRow })
		K.ModeSeg = segmented(segHolder, { "Always", "Toggle", "Hold" }, KBW - PPAD * 2, function(m) K:SetMode(m) end)
		local c = makeContainer(content, nil, root)
		K.ShowToggle = c:AddToggle(nil, { Text = "Show In List", Default = K.ShowInList, NoConfig = true, Callback = function(v) K.ShowInList = v; KL.Refresh(); Library:_touch() end })
		K.Popup = root
	end
	if isOpen(K.Popup) then closePopup(K.Popup) return end
	K.ShowToggle:SetValue(K.ShowInList, true)
	K.ModeSeg:Set(K.Mode, true)
	openPopup(K.Popup, anchor, { Align = "right", Gap = 4 })
end

local function attachKeybind(holder, id, o)
	o = o or {}
	local K = {
		Type = "Keybind", Key = o.Default or "None", Mode = o.Mode or "Toggle", State = false,
		ShowInList = o.ShowInList ~= false, Text = o.Text or id or "Keybind", Callback = o.Callback, Changed = {},
		Id = id, NoConfig = o.NoConfig, Simple = o.Simple, OnKey = o.OnKey,
	}
	K.Value = K.State
	local lbl = new("TextButton", { Size = UDim2.fromOffset(20, 14), LayoutOrder = #holder:GetChildren(), TextColor3 = Theme.TextDim, Parent = holder })
	local hovering = false
	calib(lbl)

	local function render(instant)
		local t = K.Listening and "[...]" or ("[" .. (K.Key == "None" and "NONE" or shortKey(K.Key)) .. "]")
		lbl.Text = t
		lbl.Size = UDim2.fromOffset(math.ceil(textW(t)) + 1, 14)
		local col = K.Listening and Theme.Accent or (hovering and Theme.TextHover or Theme.TextDim)
		if instant then lbl.TextColor3 = col else tween(lbl, { TextColor3 = col }, 0.15, QUAD) end
	end
	bind(lbl, function() render(true) end)

	function K:SetState(s, silent)
		if K.State == s then return end
		K.State = s
		K.Value = s
		if id then Library.Flags[id] = s end
		KL.Refresh()
		if not silent then fire(K, s) end
	end
	function K:SetKey(k)
		K.Key = k
		K.Listening = false
		render()
		KL.Refresh()
		if K.OnKey then task.spawn(K.OnKey, k) end
		Library:_touch()
	end
	function K:SetMode(m)
		K.Mode = m
		K:SetState(m == "Always")
		Library:_touch()
	end
	function K:OnChanged(fn) table.insert(K.Changed, fn) end
	function K:Serialize() return { k = K.Key, m = K.Mode, s = K.ShowInList } end
	function K:Deserialize(d)
		if type(d) ~= "table" then return end
		if d.s ~= nil then K.ShowInList = d.s end
		if d.m then K.Mode = d.m; K:SetState(d.m == "Always") end
		if d.k then K:SetKey(d.k) end
	end

	lbl.MouseEnter:Connect(function() hovering = true; render() end)
	lbl.MouseLeave:Connect(function() hovering = false; render() end)
	lbl.MouseButton1Click:Connect(function()
		K.Listening = true
		Library._listening = K
		render()
	end)
	if not K.Simple then
		lbl.MouseButton2Click:Connect(function() openKeybindPopup(K, lbl) end)
	end

	render(true)
	if K.Mode == "Always" then K.State = true; K.Value = true end
	if id then Library.Flags[id] = K.State end
	register(id, K)
	table.insert(Library._kb, K)
	KL.Refresh()
	return K
end

local function makeHolder(row)
	local h = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(0, M.Row),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = row,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = h,
	})
	return h
end

function Elements:_reg(str, row)
	if not self.Tab then return end
	table.insert(Library.Searchable, { Text = str, Tab = self.Tab, Row = row, Reveal = self.Reveal, Alive = self.Alive })
end

local function finish(self, obj, id, o, row, text)
	obj.Id = id
	obj.Row = row
	obj.NoConfig = o.NoConfig
	function obj:Flash() flashRow(row) end
	if not obj.OnChanged then
		function obj:OnChanged(fn) table.insert(obj.Changed, fn) end
	end
	if o.Tooltip then tip(row, o.Tooltip) end
	register(id, obj)
	self:_reg(text, row)
	return obj
end

function Elements:AddToggle(id, o)
	o = o or {}
	local host = self
	local T = { Type = "Toggle", Text = o.Text or id or "Toggle", Value = o.Default == true, Callback = o.Callback, Changed = {}, _subs = {} }
	local row = new("TextButton", { Size = UDim2.new(1, 0, 0, M.Row), Parent = self.Content })
	local box = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, M.Row / 2), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Theme.Box, Parent = row,
	})
	local bs = stroke(box, "Border")
	local lbl = new("TextLabel", {
		Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -20, 1, 0), Text = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.TextDim, Parent = row,
	})

	calib(row)
	local hovering = false
	local function render(animate)
		local on = T.Value
		local bg = on and Theme.Accent or Theme.Box
		local bd = on and Theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35) or (hovering and Theme.BorderHover or Theme.Border)
		local tc = on and Theme.Text or (hovering and Theme.TextHover or Theme.TextDim)
		if animate then
			tween(box, { BackgroundColor3 = bg }, 0.18, QUAD)
			tween(bs, { Color = bd }, 0.18, QUAD)
			tween(lbl, { TextColor3 = tc }, 0.18, QUAD)
		else
			box.BackgroundColor3 = bg
			bs.Color = bd
			lbl.TextColor3 = tc
		end
	end
	bind(row, function() render(false) end)

	row.MouseEnter:Connect(function() hovering = true; render(true) end)
	row.MouseLeave:Connect(function() hovering = false; render(true) end)
	row.MouseButton1Click:Connect(function() T:SetValue(not T.Value) end)

	local holder
	local function getHolder() holder = holder or makeHolder(row); return holder end

	function T:SetValue(v, silent)
		v = v and true or false
		local changed = v ~= T.Value
		T.Value = v
		render(true)
		if changed and Library.Animations then
			tween(box, { Size = UDim2.fromOffset(8, 8) }, 0.06, QUAD)
			task.delay(0.06, function() tween(box, { Size = UDim2.fromOffset(10, 10) }, 0.18, BACK) end)
		end
		if id then Library.Flags[id] = T.Value end
		for _, f in ipairs(T._subs) do f() end
		if not silent then fire(T, T.Value) end
	end
	function T:Serialize() return T.Value end
	function T:Deserialize(d) T:SetValue(d == true) end
	function T:AddColorPicker(cid, co) return attachPicker(getHolder(), cid, co) end
	function T:AddKeybind(kid, ko) ko = ko or {}; ko.Text = ko.Text or T.Text; return attachKeybind(getHolder(), kid, ko) end

	-- Options that slide open underneath this toggle while it is on.
	-- Call it straight after AddToggle, then add elements to the returned container.
	function T:AddSubOptions()
		if T.SubOptions then return T.SubOptions end
		local wrap = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ClipsDescendants = true,
			Visible = false, Parent = host.Content,
		})
		local inner = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = wrap,
		})
		pad(inner, 14, 0, 0, 0)
		vlist(inner, M.Gap)
		new("Frame", {
			Position = UDim2.fromOffset(5, 1), Size = UDim2.new(0, 1, 1, -2),
			Skin = { BackgroundColor3 = "Border" }, Parent = wrap,
		})

		local c = makeContainer(inner, host.Tab, host.PopupParent)
		c.Reveal = host.Reveal
		c.Alive = function() return T.Value and (not host.Alive or host.Alive()) end
		T.SubOptions = c

		local open, settled, token = false, true, 0
		local function innerH() return inner.AbsoluteSize.Y end
		inner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if open and settled then wrap.Size = UDim2.new(1, 0, 0, innerH()) end
		end)

		local function apply(instant)
			local want = T.Value
			if want == open and not instant then return end
			open = want
			token = token + 1
			local my = token
			if want then
				wrap.Visible = true
				local h = innerH()
				if instant or not Library.Animations then
					settled = true
					wrap.Size = UDim2.new(1, 0, 0, h)
				else
					settled = false
					tween(wrap, { Size = UDim2.new(1, 0, 0, h) }, 0.22, QUINT)
					task.delay(0.25, function()
						if token == my then
							settled = true
							wrap.Size = UDim2.new(1, 0, 0, innerH())
						end
					end)
				end
			else
				settled = false
				if instant or not Library.Animations then
					wrap.Size = UDim2.new(1, 0, 0, 0)
					wrap.Visible = false
				else
					tween(wrap, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, QUAD)
					task.delay(0.22, function() if token == my and not open then wrap.Visible = false end end)
				end
			end
		end
		table.insert(T._subs, apply)
		apply(true)
		return c
	end

	return finish(self, T, id, o, row, T.Text)
end

function Elements:AddSlider(id, o)
	o = o or {}
	local S = {
		Type = "Slider", Min = o.Min or 0, Max = o.Max or 100, Rounding = o.Rounding or 0,
		Suffix = o.Suffix or "", Prefix = o.Prefix or "", Callback = o.Callback, Changed = {},
	}
	S.Value = o.Default or S.Min
	local text = o.Text or id or "Slider"
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, M.Slider), BackgroundTransparency = 1, Parent = self.Content })
	new("TextLabel", { Size = UDim2.new(0.6, 0, 0, M.Label), Text = text, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local val = new("TextLabel", { Size = UDim2.new(1, 0, 0, M.Label), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	local track = new("Frame", {
		Position = UDim2.fromOffset(1, M.Label + M.LabelGap + 1), Size = UDim2.new(1, -2, 0, 5), Skin = { BackgroundColor3 = "Element" }, Parent = row,
	})
	local ts = stroke(track, "Border")
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), Skin = { BackgroundColor3 = "Accent" }, Parent = track })
	local hit = new("TextButton", { Position = UDim2.fromOffset(0, M.Label), Size = UDim2.new(1, 0, 0, M.Slider - M.Label), Parent = row })

	local function fmt(v) return S.Prefix .. fmtNum(v, S.Rounding) .. S.Suffix end
	local disp = Instance.new("NumberValue")
	disp.Value = S.Value
	disp.Changed:Connect(function(v) val.Text = fmt(v) end)
	val.Text = fmt(S.Value)

	local hovering, dragging = false, false
	local function border(instant)
		local c = (hovering or dragging) and Theme.BorderHover or Theme.Border
		if instant then ts.Color = c else tween(ts, { Color = c }, 0.14, QUAD) end
	end
	bind(row, function() border(true) end)
	hit.MouseEnter:Connect(function() hovering = true; border() end)
	hit.MouseLeave:Connect(function() hovering = false; border() end)

	local function render(mode)
		local a = (S.Value - S.Min) / math.max(S.Max - S.Min, 1e-9)
		if mode == "instant" then
			fill.Size = UDim2.fromScale(a, 1)
			disp.Value = S.Value
		elseif mode == "drag" then
			tween(fill, { Size = UDim2.fromScale(a, 1) }, 0.07, QUAD)
			disp.Value = S.Value
		else
			tween(fill, { Size = UDim2.fromScale(a, 1) }, 0.32, QUINT)
			tween(disp, { Value = S.Value }, 0.32, QUINT)
		end
	end

	local function commit(v, silent, mode)
		local m = 10 ^ S.Rounding
		v = math.clamp(math.floor(v * m + 0.5) / m, S.Min, S.Max)
		S.Value = v
		render(mode)
		if id then Library.Flags[id] = v end
		if not silent then fire(S, v) end
	end
	function S:SetValue(v, silent, instant) commit(v, silent, instant and "instant" or "tween") end
	function S:Serialize() return S.Value end
	function S:Deserialize(d) if type(d) == "number" then S:SetValue(d) end end

	local function setFromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		commit(S.Min + (S.Max - S.Min) * a, false, "drag")
	end
	hit.InputBegan:Connect(function(i)
		if isPress(i) then
			calibrate(hit, i)
			dragging = true
			border()
			setFromX(mouse().X)
			Library._drag = function(mp) setFromX(mp.X) end
			Library._dragEnd = function() dragging = false; border() end
		end
	end)

	render("instant")
	return finish(self, S, id, o, row, text)
end

function Elements:AddDropdown(id, o)
	o = o or {}
	local text = o.Text or id or "Dropdown"
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, M.DD), BackgroundTransparency = 1, Parent = self.Content })
	new("TextLabel", { Size = UDim2.new(1, 0, 0, M.Label), Text = text, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	o.Position = UDim2.fromOffset(1, M.Label + M.LabelGap + 1)
	o.Size = UDim2.new(1, -2, 0, M.Box - 2)
	o.PopupParent = self.PopupParent
	local D = buildDropdown(row, o, o.PopupParent == nil)
	return finish(self, D, id, o, row, text)
end

function Elements:AddTextbox(id, o)
	o = o or {}
	local text = o.Text or id or "Textbox"
	local B = { Type = "Textbox", Value = o.Default or "", Callback = o.Callback, Changed = {} }
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, M.DD), BackgroundTransparency = 1, Parent = self.Content })
	new("TextLabel", { Size = UDim2.new(1, 0, 0, M.Label), Text = text, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local fr = new("Frame", {
		Position = UDim2.fromOffset(1, M.Label + M.LabelGap + 1), Size = UDim2.new(1, -2, 0, M.Box - 2),
		Skin = { BackgroundColor3 = "Element" }, Parent = row,
	})
	local st = stroke(fr, "Border")
	local tb = new("TextBox", {
		Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -14, 1, 0), Text = B.Value,
		PlaceholderText = o.Placeholder or "", TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.TextMid, ClipsDescendants = true, Parent = fr,
	})
	local hovering = false
	local function paint(instant)
		local focused = tb:IsFocused()
		local bc = focused and Theme.Accent or (hovering and Theme.BorderHover or Theme.Border)
		local tc = focused and Theme.Text or Theme.TextMid
		if instant then
			st.Color = bc
			tb.TextColor3 = tc
		else
			tween(st, { Color = bc }, 0.15, QUAD)
			tween(tb, { TextColor3 = tc }, 0.15, QUAD)
		end
		tb.PlaceholderColor3 = Theme.TextDim
	end
	bind(fr, function() paint(true) end)
	fr.MouseEnter:Connect(function() hovering = true; if not tb:IsFocused() then paint() end end)
	fr.MouseLeave:Connect(function() hovering = false; if not tb:IsFocused() then paint() end end)
	tb.Focused:Connect(function() paint() end)
	tb.FocusLost:Connect(function()
		paint()
		B.Value = tb.Text
		if id then Library.Flags[id] = B.Value end
		fire(B, B.Value)
	end)
	function B:SetValue(v, silent)
		tb.Text = v
		B.Value = v
		if id then Library.Flags[id] = v end
		if not silent then fire(B, v) end
	end
	function B:Serialize() return B.Value end
	function B:Deserialize(d) if type(d) == "string" then B:SetValue(d) end end
	return finish(self, B, id, o, row, text)
end

local function makeButton(parent, o, size)
	local slot = new("Frame", { Size = size or UDim2.new(1, 0, 0, M.Btn), BackgroundTransparency = 1, Parent = parent })
	local b = new("TextButton", {
		Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Text = o.Text or "Button",
		BackgroundColor3 = Theme.Box, Parent = slot,
	})
	local st = stroke(b, "Box")
	calib(b)
	local B = { Slot = slot, Button = b, Active = false }
	local state = "idle"

	local function colors()
		if B.Active or o.Accent then
			local k = state == "down" and 0.26 or (state == "hover" and 0.2 or 0.14)
			local bg = Theme.Section:Lerp(Theme.Accent, k)
			return bg, bg, Theme.Accent
		end
		local bg = state == "down" and Theme.Element or (state == "hover" and Theme.Box:Lerp(Theme.Text, 0.05) or Theme.Box)
		return bg, bg, Theme.Text
	end
	local function apply(s, t)
		state = s
		local bg, bd, tc = colors()
		tween(b, { BackgroundColor3 = bg, TextColor3 = tc }, t or 0.12, QUAD)
		tween(st, { Color = bd }, t or 0.12, QUAD)
	end
	local function snap()
		local bg, bd, tc = colors()
		b.BackgroundColor3 = bg
		b.TextColor3 = tc
		st.Color = bd
	end
	bind(b, snap)

	b.MouseEnter:Connect(function() apply("hover") end)
	b.MouseLeave:Connect(function() apply("idle", 0.2) end)
	b.MouseButton1Down:Connect(function() apply("down", 0.05) end)
	b.MouseButton1Up:Connect(function() apply("hover", 0.14) end)
	b.MouseButton1Click:Connect(function() if o.Callback then task.spawn(o.Callback) end end)
	if o.Tooltip then tip(b, o.Tooltip) end

	function B:SetText(t) b.Text = t end
	function B:SetActive(v) B.Active = v and true or false; apply(state, 0.15) end
	function B:Flash() flashRow(slot) end
	return B
end

function Elements:AddButton(o)
	o = o or {}
	local B = makeButton(self.Content, o)
	self:_reg(o.Text or "Button", B.Slot)
	return B
end

function Elements:AddButtonRow(list)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, M.Btn), BackgroundTransparency = 1, Parent = self.Content })
	hlist(row, M.Gap)
	local n = #list
	local out = {}
	for i, o in ipairs(list) do
		out[i] = makeButton(row, o, UDim2.new(1 / n, -math.ceil(M.Gap * (n - 1) / n), 1, 0))
		out[i].Slot.LayoutOrder = i
		self:_reg(o.Text or "Button", out[i].Slot)
	end
	return out
end

function Elements:AddLabel(str, right)
	local L = { Type = "Label" }
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, M.Row), BackgroundTransparency = 1, Parent = self.Content })
	local l = new("TextLabel", { Size = UDim2.fromScale(1, 1), Text = str, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local r = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), Text = right or "", Skin = { TextColor3 = "TextDim" },
		TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
	})
	local holder
	function L:SetText(t) l.Text = t; pulseText(l) end
	function L:SetRightText(t) if r.Text ~= t then r.Text = t; pulseText(r) end end
	function L:Flash() flashRow(row) end
	function L:AddColorPicker(cid, co) holder = holder or makeHolder(row); return attachPicker(holder, cid, co) end
	function L:AddKeybind(kid, ko) holder = holder or makeHolder(row); ko = ko or {}; ko.Text = ko.Text or str; return attachKeybind(holder, kid, ko) end
	L.Row = row
	self:_reg(str, row)
	return L
end


function Elements:AddESPPreview(o)
	o = o or {}
	local height = o.Height or 280
	local slot = new("Frame", {
		Size = UDim2.new(1, 0, 0, height), Skin = { BackgroundColor3 = "Window" },
		ClipsDescendants = true, Parent = self.Content,
	})
	stroke(slot, "Border")

	local vp = Instance.new("ViewportFrame")
	vp.Name = "ESPPreview"
	vp.Size = UDim2.new(1, -2, 1, -2)
	vp.Position = UDim2.fromOffset(1, 1)
	vp.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	vp.BorderSizePixel = 0
	vp.Ambient = Color3.fromRGB(210, 210, 220)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = slot

	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam

	local model = Instance.new("Model")
	model.Name = "AvatarPreview"
	model.Parent = world

	local offsets = {} -- part -> Vector3/CFrame relative to root, stored as CFrame
	local bones = {}
	local ready = false
	local rootName = nil
	local displayName = o.Name or (LocalPlayer and LocalPlayer.DisplayName) or "LocalPlayer"

	local function bakeWelds(m)
		-- force accessory handles to the pose their welds describe before we anchor
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("Weld") or d:IsA("Motor6D") then
				local p0, p1 = d.Part0, d.Part1
				if p0 and p1 then
					-- standard: Part0.CFrame * C0 = Part1.CFrame * C1
					-- put Part0 where the weld says relative to Part1
					pcall(function()
						p0.CFrame = p1.CFrame * d.C1 * d.C0:Inverse()
					end)
				end
			elseif d:IsA("WeldConstraint") and d.Part0 and d.Part1 then
				-- WeldConstraint has no C0/C1; keep current relative by doing nothing
			end
		end
		-- accessory API path
		for _, acc in ipairs(m:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				local weld = handle and (handle:FindFirstChild("AccessoryWeld") or handle:FindFirstChildOfClass("Weld"))
				if handle and weld and weld.Part1 then
					pcall(function()
						handle.CFrame = weld.Part1.CFrame * weld.C1 * weld.C0:Inverse()
					end)
				end
			end
		end
	end

	local function getRoot(m)
		return m:FindFirstChild("HumanoidRootPart")
			or m:FindFirstChild("Torso")
			or m:FindFirstChild("UpperTorso")
			or m.PrimaryPart
	end

	local function snapshot(m)
		local root = getRoot(m)
		if not root then return false end
		rootName = root.Name
		m.PrimaryPart = root
		local origin = root.CFrame
		offsets = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				offsets[d] = origin:ToObjectSpace(d.CFrame)
			end
		end
		bones = {}
		local function part(n)
			return m:FindFirstChild(n, true)
		end
		for _, pr in ipairs({
			{ "Head", "UpperTorso" }, { "Head", "Torso" },
			{ "UpperTorso", "LowerTorso" },
			{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
			{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
			{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
			{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
			{ "Torso", "Left Arm" }, { "Torso", "Right Arm" },
			{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
		}) do
			local a, b = part(pr[1]), part(pr[2])
			if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
				bones[#bones + 1] = { a, b }
			end
		end
		return next(offsets) ~= nil
	end

	local function freeze(m)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CastShadow = false
				d.LocalTransparencyModifier = 0
				pcall(function()
					d.AssemblyLinearVelocity = Vector3.zero
					d.AssemblyAngularVelocity = Vector3.zero
				end)
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d.Disabled = true
			elseif d:IsA("Humanoid") then
				d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				d.PlatformStand = true
				d.AutoRotate = false
				pcall(function() d.EvaluateStateMachine = false end)
			end
		end
	end

	local function pose(yaw)
		local world = CFrame.Angles(0, yaw, 0)
		for part, rel in pairs(offsets) do
			if part.Parent then
				part.CFrame = world * rel
			end
		end
	end

	local function centerSnapshot(m)
		-- compute bounds of current offsets, shift so midpoint is at origin
		local minV = Vector3.new(1e9, 1e9, 1e9)
		local maxV = Vector3.new(-1e9, -1e9, -1e9)
		for part, rel in pairs(offsets) do
			if part.Parent then
				local pos = rel.Position
				local half = part.Size * 0.5
				minV = Vector3.new(
					math.min(minV.X, pos.X - half.X),
					math.min(minV.Y, pos.Y - half.Y),
					math.min(minV.Z, pos.Z - half.Z)
				)
				maxV = Vector3.new(
					math.max(maxV.X, pos.X + half.X),
					math.max(maxV.Y, pos.Y + half.Y),
					math.max(maxV.Z, pos.Z + half.Z)
				)
			end
		end
		local mid = (minV + maxV) * 0.5
		local shift = CFrame.new(-mid)
		for part, rel in pairs(offsets) do
			offsets[part] = shift * rel
		end
		pose(0)
	end

	local function fallbackR6()
		local function limb(name, size, cf, color)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = cf
			p.Anchored = true
			p.CanCollide = false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = color
			p.Parent = model
			return p
		end
		local skin, shirt, pants = Color3.fromRGB(204, 170, 140), Color3.fromRGB(72, 120, 190), Color3.fromRGB(42, 46, 58)
		limb("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 1, 0), shirt)
		local head = limb("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 2.6, 0), skin)
		limb("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 1, 0), skin)
		limb("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 1, 0), skin)
		limb("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -1, 0), pants)
		limb("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, -1, 0), pants)
		local face = Instance.new("Decal")
		face.Face = Enum.NormalId.Front
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = head
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 1, 1)
		hrp.CFrame = CFrame.new(0, 1, 0)
		hrp.Transparency = 1
		hrp.Anchored = true
		hrp.CanCollide = false
		hrp.Parent = model
		model.PrimaryPart = hrp
		freeze(model)
		snapshot(model)
		centerSnapshot(model)
		ready = true
	end

	task.spawn(function()
		local ok, result = pcall(function()
			local desc = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
			if Players.CreateHumanoidModelFromDescription then
				return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
			end
			return nil
		end)
		if not ok or not result then
			ok, result = pcall(function()
				return Players:CreateHumanoidModelFromUserId(LocalPlayer.UserId)
			end)
		end
		if not (ok and result) then
			fallbackR6()
			return
		end

		for _, c in ipairs(model:GetChildren()) do c:Destroy() end
		result.Name = "Avatar"
		result.Parent = world
		model:Destroy()
		model = result

		-- let accessories finish streaming before freeze
		local deadline = os.clock() + 2.5
		while os.clock() < deadline do
			local handles = 0
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("Accessory") and d:FindFirstChild("Handle") then
					handles = handles + 1
				end
			end
			if handles > 0 then
				task.wait(0.25)
				break
			end
			task.wait(0.05)
		end
		task.wait(0.1)

		bakeWelds(model)
		freeze(model)
		if not snapshot(model) then
			fallbackR6()
			return
		end
		centerSnapshot(model)
		ready = true

		-- one more pass if more accessories arrive
		task.delay(0.75, function()
			if Library._unloaded or not model.Parent then return end
			bakeWelds(model)
			freeze(model)
			snapshot(model)
			centerSnapshot(model)
		end)
	end)

	cam.CFrame = CFrame.new(Vector3.new(0, 1.4, 14), Vector3.new(0, 1.2, 0))

	local overlay = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5, Parent = slot,
	})
	local box = new("Frame", { BackgroundTransparency = 1, Visible = false, Parent = overlay })
	local boxStroke = stroke(box, "Accent", 1)
	local nameLbl = new("TextLabel", {
		Size = UDim2.fromOffset(120, 14), Text = displayName, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Parent = overlay,
	})
	local hpBg = new("Frame", {
		Size = UDim2.fromOffset(3, 40), BackgroundColor3 = Color3.fromRGB(28, 28, 32), Visible = false, Parent = overlay,
	})
	stroke(hpBg, "BorderDark")
	local hpFill = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.78),
		Skin = { BackgroundColor3 = "Accent" }, Parent = hpBg,
	})
	local skLines = {}
	local function ensureLines(n)
		while #skLines < n do
			skLines[#skLines + 1] = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(1, 1),
				BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Visible = false, Parent = overlay,
			})
		end
	end

	local flags = o.Flags or {
		Box = "esp_box", Name = "esp_name", Health = "esp_health",
		Skeleton = "esp_skeleton", Color = "esp_color",
	}

	local angle = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		if Library._unloaded or not slot.Parent then return end
		if not ready then return end

		angle = (angle + dt * 0.35) % (math.pi * 2)
		pose(angle)

		local vs = vp.AbsoluteSize
		if vs.X < 2 or vs.Y < 2 then return end

		local okb, bbCF, bbSize = pcall(function()
			local c, sz = model:GetBoundingBox()
			return c, sz
		end)
		if okb and bbCF and bbSize then
			local dist = math.max(bbSize.X, bbSize.Y, bbSize.Z) * 2.5
			dist = math.clamp(dist, 12, 18)
			cam.CFrame = CFrame.new(bbCF.Position + Vector3.new(0, bbSize.Y * 0.02, dist), bbCF.Position)
		end

		local function project(worldPos)
			local rel = cam.CFrame:PointToObjectSpace(worldPos)
			if rel.Z >= -0.05 then return nil end
			local aspect = vs.X / vs.Y
			local fov = math.rad(cam.FieldOfView)
			local sy = 1 / math.tan(fov * 0.5)
			local sx = sy / aspect
			local ndcX = (rel.X * sx) / -rel.Z
			local ndcY = (rel.Y * sy) / -rel.Z
			return Vector2.new((ndcX * 0.5 + 0.5) * vs.X, (0.5 - ndcY * 0.5) * vs.Y)
		end

		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		local any = false
		for part in pairs(offsets) do
			if part.Parent and not part:FindFirstAncestorOfClass("Accessory") and part.Name ~= "HumanoidRootPart" then
				for _, c in ipairs({
					Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1),
					Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1),
				}) do
					local sp = project((part.CFrame * CFrame.new(c * part.Size * 0.5)).Position)
					if sp then
						any = true
						minX = math.min(minX, sp.X); minY = math.min(minY, sp.Y)
						maxX = math.max(maxX, sp.X); maxY = math.max(maxY, sp.Y)
					end
				end
			end
		end
		if any then
			minX = math.clamp(minX - 2, 1, vs.X - 1)
			minY = math.clamp(minY - 2, 1, vs.Y - 1)
			maxX = math.clamp(maxX + 2, 1, vs.X - 1)
			maxY = math.clamp(maxY + 2, 1, vs.Y - 1)
		end

		local col = Theme.Accent
		local cFlag = Library.Flags[flags.Color]
		if typeof(cFlag) == "Color3" then col = cFlag end
		local showBox = Library.Flags[flags.Box] == true
		local showName = Library.Flags[flags.Name] == true
		local showHp = Library.Flags[flags.Health] == true
		local showSk = Library.Flags[flags.Skeleton] == true

		if showBox and any and maxX > minX then
			box.Visible = true
			box.Position = UDim2.fromOffset(math.floor(minX), math.floor(minY))
			box.Size = UDim2.fromOffset(math.max(1, math.floor(maxX - minX)), math.max(1, math.floor(maxY - minY)))
			boxStroke.Color = col
		else
			box.Visible = false
		end
		if showName and any then
			nameLbl.Visible = true
			nameLbl.Text = displayName
			nameLbl.TextColor3 = col
			nameLbl.Position = UDim2.fromOffset(
				math.clamp(math.floor((minX + maxX) * 0.5 - 60), 0, math.max(0, vs.X - 120)),
				math.clamp(math.floor(minY - 16), 0, math.max(0, vs.Y - 14))
			)
		else
			nameLbl.Visible = false
		end
		if showHp and any then
			hpBg.Visible = true
			local h = math.max(16, maxY - minY)
			hpBg.Size = UDim2.fromOffset(3, math.floor(h))
			hpBg.Position = UDim2.fromOffset(math.clamp(math.floor(minX - 6), 0, math.max(0, vs.X - 3)), math.floor(minY))
			hpFill.BackgroundColor3 = col
		else
			hpBg.Visible = false
		end
		if showSk then
			ensureLines(#bones)
			for i, pair in ipairs(bones) do
				local a = project(pair[1].Position)
				local b = project(pair[2].Position)
				local ln = skLines[i]
				if a and b then
					local mid = (a + b) * 0.5
					local delta = b - a
					ln.Visible = true
					ln.BackgroundColor3 = col
					ln.Position = UDim2.fromOffset(mid.X, mid.Y)
					ln.Size = UDim2.fromOffset(math.max(1, delta.Magnitude), 1)
					ln.Rotation = math.deg(math.atan2(delta.Y, delta.X))
				else
					ln.Visible = false
				end
			end
			for i = #bones + 1, #skLines do skLines[i].Visible = false end
		else
			for _, ln in ipairs(skLines) do ln.Visible = false end
		end
	end)
	table.insert(Library._conns, conn)
	self:_reg(o.Text or "ESP Preview", slot)
	return slot
end

function Elements:AddDivider()
	return new("Frame", { Size = UDim2.new(1, 0, 0, 1), Skin = { BackgroundColor3 = "Border" }, Parent = self.Content })
end

function Elements:AddCustom(height)
	return new("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, Parent = self.Content })
end

function Elements:AddListbox(id, o)
	o = o or {}
	local Lb = {
		Type = "Listbox", Items = o.Items or {}, Value = o.Default or (o.Items or {})[1],
		Callback = o.Callback, Changed = {}, Format = o.Format,
	}
	local slot = new("Frame", { Size = UDim2.new(1, 0, 0, o.Height or 110), BackgroundTransparency = 1, Parent = self.Content })
	local sf = new("ScrollingFrame", {
		Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Skin = { BackgroundColor3 = "Window" },
		ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = slot,
	})
	stroke(sf, "Border")
	vlist(sf, 0)
	local empty = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, M.Item), Text = o.Empty or "Nothing here", Skin = { TextColor3 = "TextOff" },
		Visible = false, LayoutOrder = 0, Parent = sf,
	})
	local setters = {}
	local function sync(instant) for v, set in pairs(setters) do set(v == Lb.Value, instant) end end
	local function populate()
		for _, c in ipairs(sf:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		setters = {}
		empty.Visible = #Lb.Items == 0
		for i, v in ipairs(Lb.Items) do
			local b, set = makeItem(sf, tostring(v), M.Item, Lb.Format and Lb.Format(v) or nil)
			b.LayoutOrder = i
			setters[v] = set
			b.MouseButton1Click:Connect(function() Lb:SetValue(v) end)
		end
		sync(true)
	end
	function Lb:SetValue(v, silent)
		Lb.Value = v
		sync()
		if id then Library.Flags[id] = v end
		if not silent then fire(Lb, v) end
	end
	function Lb:SetItems(items)
		Lb.Items = items
		if not table.find(items, Lb.Value) then Lb.Value = nil end
		populate()
		if id then Library.Flags[id] = Lb.Value end
	end
	function Lb:Serialize() return Lb.Value end
	function Lb:Deserialize(d) Lb:SetValue(d) end
	populate()
	return finish(self, Lb, id, o, slot, o.Text or id or "List")
end

local function newSectionFrame(column, order)
	local sec = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Skin = { BackgroundColor3 = "Section" },
		LayoutOrder = order, Parent = column,
	})
	stroke(sec, "Border")
	vlist(sec, 0)
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, M.SecHead), Skin = { BackgroundColor3 = "SectionHeader" }, LayoutOrder = 1, Parent = sec })
	new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1),
		Skin = { BackgroundColor3 = "Border" }, Parent = head,
	})
	return sec, head
end

local function newContent(parent, order, canvas)
	local c = new(canvas and "CanvasGroup" or "Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = order, Parent = parent,
	})
	pad(c, M.Pad, M.Pad, M.Pad, M.Pad)
	vlist(c, M.Gap)
	return c
end

local TabMethods = {}
TabMethods.__index = TabMethods

function TabMethods:_column(side)
	if not side then side = (self.Count.Left <= self.Count.Right) and "Left" or "Right" end
	self.Count[side] = self.Count[side] + 1
	return self[side .. "Col"], self.Count[side]
end

function TabMethods:AddSection(name, side)
	local col, order = self:_column(side)
	local sec, head = newSectionFrame(col, order)
	new("TextLabel", {
		Position = UDim2.fromOffset(M.Pad, 0), Size = UDim2.new(1, -M.Pad * 2, 1, 0), Text = name, TextSize = Theme.TitleSize,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
	})
	local content = newContent(sec, 2)
	return makeContainer(content, self)
end

function TabMethods:AddTabSection(names, side)
	local col, order = self:_column(side)
	local sec, head = newSectionFrame(col, order)
	local th = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = head })
	local bar = tabBar(th, Theme.TitleSize, 8)
	local out, subs = {}, {}
	local active
	local function pick(n, instant)
		if active == n then return end
		active = n
		bar:Select(n, instant)
		for name, s in pairs(subs) do
			if name == n then
				s.Content.Visible = true
				if instant then
					s.Content.GroupTransparency = 0
				else
					s.Content.GroupTransparency = 1
					tween(s.Content, { GroupTransparency = 0 }, 0.26, QUAD)
				end
			else
				s.Content.Visible = false
			end
		end
	end
	for _, n in ipairs(names) do
		bar:Add(n, function() pick(n) end)
		local content = newContent(sec, 2, true)
		content.Visible = false
		local c = makeContainer(content, self)
		c.Reveal = function() pick(n) end
		subs[n] = { Content = content }
		out[n] = c
	end
	pick(names[1], true)
	return out
end

function Library:CreateWindow(o)
	o = o or {}
	if o.Name and o.Name ~= "Akane" and o.Name ~= "Interium" then Library.Name = o.Name end
	if o.Folder then Library.Folder = o.Folder end
	if o.ToggleKey then Library.ToggleKey = o.ToggleKey end
	local W = { Tabs = {}, Active = nil, Visible = false }
	local size = o.Size or M.Win
	local vp = viewport()

	W.Pos = o.Position or UDim2.fromOffset(math.floor((vp.X - size.X) / 2), math.floor((vp.Y - size.Y) / 2))
	local frame = new("Frame", {
		Name = "Window", Size = UDim2.fromOffset(size.X + 2, size.Y + 2), Skin = { BackgroundColor3 = "Window" },
		Position = W.Pos, Active = true, Parent = Gui,
	})
	local frameStroke = stroke(frame, "Border")
	local cg = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = frame })
	local inner = new("Frame", {
		Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Skin = { BackgroundColor3 = "Window" }, Parent = cg,
	})
	stroke(inner, "BorderDark")
	W.Frame = frame

	local head = new("Frame", { Size = UDim2.new(1, 0, 0, M.Header), Skin = { BackgroundColor3 = "Section" }, Parent = inner })
	new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Skin = { BackgroundColor3 = "Border" }, Parent = head })
	local hl = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = head })
	hlist(hl, 0)
	pad(hl, M.Page, 0, 0, 0)
	logo(hl)
	spacer(hl, 8)
	new("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), Text = Library.Name, TextSize = Theme.TitleSize, Parent = hl })
	spacer(hl, 10)
	new("Frame", { Size = UDim2.fromOffset(1, 13), Skin = { BackgroundColor3 = "Border" }, Parent = hl })
	local tabsHolder = new("CanvasGroup", { Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Parent = hl })
	local tabsBar = tabBar(tabsHolder, Theme.TitleSize, 10, {
		OnWidth = function(w) tabsHolder.Size = UDim2.new(0, w, 1, 0) end,
	})

	local running = {}
	local function track(tw) if tw then running[#running + 1] = tw end end
	local function cancelRunning()
		for _, tw in ipairs(running) do tw:Cancel() end
		running = {}
	end

	head.InputBegan:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		cancelRunning()
		if W.Visible then
			cg.GroupTransparency = 0
			frame.BackgroundTransparency = 0
			frameStroke.Transparency = 0
		end
		local origin = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
		local start = mouse()
		W.Pos = UDim2.fromOffset(origin.X, origin.Y)
		frame.Position = W.Pos
		Library._dragEnd = nil
		Library._drag = function(mp)
			local v = viewport()
			local x = math.clamp(origin.X + (mp.X - start.X), -frame.AbsoluteSize.X + 60, v.X - 60)
			local y = math.clamp(origin.Y + (mp.Y - start.Y), 0, v.Y - 30)
			W.Pos = UDim2.fromOffset(x, y)
			frame.Position = W.Pos
		end
	end)

	local body = new("Frame", {
		Position = UDim2.fromOffset(0, M.Header), Size = UDim2.new(1, 0, 1, -M.Header),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = inner,
	})

	local PG = M.Page
	function W:SelectTab(tab, instant)
		if not tab or tab.Detached then return end
		if W.Active == tab then return end
		closeAllPopups()
		local prev = W.Active
		W.Active = tab
		tabsBar:Select(tab.Name, instant)
		local dir = 1
		if prev then dir = (table.find(W.Tabs, tab) or 0) >= (table.find(W.Tabs, prev) or 0) and 1 or -1 end
		if prev then
			if instant then
				prev.Page.Visible = false
			else
				tween(prev.Page, { GroupTransparency = 1, Position = UDim2.fromOffset(PG - dir * 14, PG) }, 0.15, QUAD)
				task.delay(0.16, function() if W.Active ~= prev then prev.Page.Visible = false end end)
			end
		end
		tab.Page.Visible = true
		if instant or not prev then
			tab.Page.GroupTransparency = 0
			tab.Page.Position = UDim2.fromOffset(PG, PG)
		else
			tab.Page.GroupTransparency = 1
			tab.Page.Position = UDim2.fromOffset(PG + dir * 16, PG)
			tween(tab.Page, { GroupTransparency = 0, Position = UDim2.fromOffset(PG, PG) }, 0.34, QUINT)
		end
	end

	local dropOverlay = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 80, Parent = frame,
	})
	local dropTint = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.6, Skin = { BackgroundColor3 = "Accent" }, Parent = dropOverlay,
	})
	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(200, 22), Text = "Drop to reattach", TextSize = Theme.TitleSize, Parent = dropOverlay,
	})

	function W:AddTab(name)
		for _, t in ipairs(W.Tabs) do
			if t.Name == name then return t end
		end
		local tab = setmetatable({ Name = name, Count = { Left = 0, Right = 0 }, Detached = false }, TabMethods)
		local tabBtn = tabsBar:Add(name, function()
			if not tab.Detached then W:SelectTab(tab) end
		end)
		local page = new("CanvasGroup", {
			Position = UDim2.fromOffset(PG, PG), Size = UDim2.new(1, -PG * 2, 1, -PG * 2), BackgroundTransparency = 1,
			Visible = false, GroupTransparency = 1, Parent = body,
		})
		local scroll = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 2, Skin = { ScrollBarImageColor3 = "Accent" },
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = page,
		})
		pad(scroll, 1, 1, 1, 1)
		tab.Page, tab.Scroll, tab.Btn = page, scroll, tabBtn
		local half = M.ColGap / 2
		tab.LeftCol = new("Frame", { Size = UDim2.new(0.5, -half, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll })
		tab.RightCol = new("Frame", { Position = UDim2.new(0.5, half, 0, 0), Size = UDim2.new(0.5, -half, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll })
		vlist(tab.LeftCol, M.ColGap)
		vlist(tab.RightCol, M.ColGap)

		local detachWin, detachHead
		local grabOff = Vector2.new(0, 0)
		local savedOrder = 0

		local function destroyDetachWin()
			if detachWin then
				pcall(function() detachWin:Destroy() end)
				detachWin, detachHead = nil, nil
			end
			tab.DetachWin = nil
		end

		local function placePageInBody()
			page.Parent = body
			page.Size = UDim2.new(1, -PG * 2, 1, -PG * 2)
			page.Position = UDim2.fromOffset(PG, PG)
		end

		function tab:Reattach()
			if not tab.Detached then return end
			tab.Detached = false
			dropOverlay.Visible = false
			placePageInBody()
			destroyDetachWin()
			local btn = tabsBar:Add(name, function()
				if not tab.Detached then W:SelectTab(tab) end
			end, savedOrder > 0 and savedOrder or nil)
			tab.Btn = btn
			W:wireTabDrag(tab)
			local otherActive = W.Active and not W.Active.Detached and W.Active ~= tab
			if otherActive then
				page.Visible = false
				page.GroupTransparency = 1
			else
				W.Active = nil
				W:SelectTab(tab, true)
			end
		end

		function tab:Detach(at)
			if tab.Detached then return end
			tab.Detached = true
			local entry = tabsBar.Tabs[name]
			savedOrder = entry and entry.Order or 0
			if W.Active == tab then
				local other
				for _, t in ipairs(W.Tabs) do
					if t ~= tab and not t.Detached then other = t break end
				end
				W.Active = nil
				if other then
					W:SelectTab(other, true)
				else
					page.Visible = false
					page.GroupTransparency = 1
				end
			end
			tabsBar:Remove(name)
			tab.Btn = nil

			local dw = math.floor(frame.AbsoluteSize.X)
			local dh = math.floor(frame.AbsoluteSize.Y)
			local mp = at or mouse()
			local px = math.floor(mp.X - grabOff.X)
			local py = math.floor(mp.Y - grabOff.Y)

			detachWin = new("CanvasGroup", {
				Name = "Detached_" .. name,
				Size = UDim2.fromOffset(dw, dh),
				Position = UDim2.fromOffset(px, py),
				Skin = { BackgroundColor3 = "Window" }, Active = true, ZIndex = 60, Parent = Gui,
			})
			stroke(detachWin, "Border")
			local dInner = new("Frame", {
				Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2),
				Skin = { BackgroundColor3 = "Window" }, Parent = detachWin,
			})
			stroke(dInner, "BorderDark")
			detachHead = new("Frame", {
				Size = UDim2.new(1, 0, 0, M.Header), Skin = { BackgroundColor3 = "Section" }, Parent = dInner,
			})
			new("Frame", {
				Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
				Skin = { BackgroundColor3 = "Border" }, Parent = detachHead,
			})
			local dhl = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = detachHead })
			hlist(dhl, 0)
			pad(dhl, M.Page, 0, 0, 0)
			new("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14),
				Text = name, TextSize = Theme.TitleSize, Parent = dhl,
			})
			local closeBtn = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(18, 18), Text = "x", TextSize = 12,
				Skin = { TextColor3 = "TextDim" }, Parent = detachHead,
			})
			closeBtn.MouseButton1Click:Connect(function() tab:Reattach() end)

			local dBody = new("Frame", {
				Position = UDim2.fromOffset(0, M.Header), Size = UDim2.new(1, 0, 1, -M.Header),
				BackgroundTransparency = 1, ClipsDescendants = true, Parent = dInner,
			})
			page.Parent = dBody
			page.Position = UDim2.fromOffset(PG, PG)
			page.Size = UDim2.new(1, -PG * 2, 1, -PG * 2)
			page.Visible = true
			page.GroupTransparency = 0
			tab.DetachWin = detachWin
			detachWin.Visible = W.Visible

			local function startMove(i)
				if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				calibrate(detachHead, i)
				local origin = Vector2.new(detachWin.Position.X.Offset, detachWin.Position.Y.Offset)
				local start = mouse()
				Library._dragEnd = function()
					local mp2 = mouse()
					if inside(frame, mp2) then
						tab:Reattach()
					else
						dropOverlay.Visible = false
					end
				end
				Library._drag = function(mp2)
					local v = viewport()
					local x = math.clamp(origin.X + (mp2.X - start.X), 0, v.X - 40)
					local y = math.clamp(origin.Y + (mp2.Y - start.Y), 0, v.Y - 30)
					detachWin.Position = UDim2.fromOffset(x, y)
					dropOverlay.Visible = inside(frame, mp2)
				end
			end
			detachHead.InputBegan:Connect(startMove)
		end

		function W:wireTabDrag(t)
			local btn = t.Btn
			if not btn then return end
			btn.InputBegan:Connect(function(i)
				if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				if t.Detached then return end
				if not Library.TabDetach then return end
				calibrate(btn, i)
				local start = mouse()
				local ap = btn.AbsolutePosition
				-- keep cursor over the tab title: offset from click point within button to window top-left
				grabOff = Vector2.new(start.X - ap.X, start.Y - ap.Y + 2)
				local armed = false
				Library._dragEnd = function()
					dropOverlay.Visible = false
					if t.Detached then
						local mp2 = mouse()
						if inside(frame, mp2) then
							t:Reattach()
						end
					end
				end
				Library._drag = function(mp)
					if t.Detached then
						if t.DetachWin then
							t.DetachWin.Position = UDim2.fromOffset(
								math.floor(mp.X - grabOff.X),
								math.floor(mp.Y - grabOff.Y)
							)
						end
						dropOverlay.Visible = inside(frame, mp)
						return
					end
					if (mp - start).Magnitude > 8 and not armed then
						armed = true
						t:Detach(mp)
						if t.DetachWin then
							t.DetachWin.Position = UDim2.fromOffset(
								math.floor(mp.X - grabOff.X),
								math.floor(mp.Y - grabOff.Y)
							)
						end
					end
				end
			end)
		end

		W:wireTabDrag(tab)
		table.insert(W.Tabs, tab)
		if #W.Tabs == 1 then W:SelectTab(tab, true) end
		return tab
	end

	local sb = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(20, 20), ZIndex = 4, Parent = head,
	})
	local setMag = magnifier(sb)
	local field = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(18, 18),
		Visible = false, ClipsDescendants = true, Active = true, ZIndex = 2, Skin = { BackgroundColor3 = "Element" }, Parent = head,
	})
	local fst = stroke(field, "Border")
	local stb = new("TextBox", {
		Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -30, 1, 0), PlaceholderText = "Search", Text = "",
		TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true, TextTransparency = 1, PlaceholderColor3 = Theme.TextDim, Parent = field,
	})
	bind(field, function() stb.PlaceholderColor3 = Theme.TextDim end)

	local sres, spanel = newPopup(100, 0, inner)
	sres.ZIndex = 30
	spanel.ClipsDescendants = true
	vlist(spanel, 0)
	local SEARCH_W = 150
	local searchW = SEARCH_W
	local firstPick

	local function showResults(h, animate)
		local meta = PopupOf[sres]
		meta.Token = meta.Token + 1
		local tok = meta.Token
		if h > 0 then
			sres.Visible = true
			resizePopup(sres, searchW, h, animate)
		else
			resizePopup(sres, searchW, 0, animate)
			task.delay(animate and 0.26 or 0, function()
				if meta.Token == tok then sres.Visible = false end
			end)
		end
	end

	local function clearResults()
		for _, c in ipairs(spanel:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
		end
	end

	local function refresh()
		clearResults()
		firstPick = nil
		local q = stb.Text:lower()
		if q == "" then
			showResults(0, true)
			return
		end
		local n = 0
		for _, e in ipairs(Library.Searchable) do
			if n >= 8 then break end
			if e.Text:lower():find(q, 1, true) and e.Row.Parent and (not e.Alive or e.Alive()) then
				n = n + 1
				local b = makeItem(spanel, e.Text, M.Item, e.Tab.Name)
				b.LayoutOrder = n
				if Library.Animations then
					for _, d in ipairs(b:GetChildren()) do
						if d:IsA("TextLabel") then
							d.TextTransparency = 1
							task.delay(n * 0.025, function() if d.Parent then tween(d, { TextTransparency = 0 }, 0.2, QUAD) end end)
						end
					end
				end
				local function pick()
					closePopup(field)
					W:SelectTab(e.Tab)
					if e.Reveal then e.Reveal() end
					task.delay(0.28, function()
						pcall(function()
							local sc = e.Tab.Scroll
							local y = e.Row.AbsolutePosition.Y - sc.AbsolutePosition.Y + sc.CanvasPosition.Y - 24
							tween(sc, { CanvasPosition = Vector2.new(0, math.max(0, y)) }, 0.25, QUINT)
						end)
						flashRow(e.Row)
					end)
				end
				if n == 1 then firstPick = pick end
				b.MouseButton1Click:Connect(pick)
			end
		end
		if n == 0 then
			new("TextLabel", { Size = UDim2.new(1, 0, 0, M.Item), Text = "No results", Skin = { TextColor3 = "TextOff" }, LayoutOrder = 1, Parent = spanel })
			n = 1
		end
		showResults(n * M.Item, true)
	end
	stb:GetPropertyChangedSignal("Text"):Connect(refresh)
	stb.Focused:Connect(function() tween(fst, { Color = Theme.Accent }, 0.15, QUAD); setMag(Theme.Accent) end)
	stb.FocusLost:Connect(function(enter)
		tween(fst, { Color = Theme.Border }, 0.2, QUAD)
		if W.SearchOpen then setMag(Theme.Text) end
		if enter and firstPick then firstPick() end
	end)

	local searchToken = 0
	local function closeSearch()
		W.SearchOpen = false
		searchToken = searchToken + 1
		local my = searchToken
		stb:ReleaseFocus()
		setMag(Theme.TextDim)
		tween(field, { Size = UDim2.fromOffset(18, 18) }, 0.22, QUINT)
		tween(stb, { TextTransparency = 1 }, 0.1, QUAD)
		tween(tabsHolder, { GroupTransparency = 0 }, 0.22, QUAD)
		showResults(0, true)
		task.delay(0.25, function()
			if searchToken ~= my then return end
			field.Visible = false
			stb.Text = ""
			clearResults()
		end)
	end

	local function openSearch()
		if isOpen(field) then return end
		closeAllPopups(field)
		searchToken = searchToken + 1
		local tx = tabsHolder.AbsolutePosition.X - head.AbsolutePosition.X
		local hw = head.AbsoluteSize.X
		searchW = SEARCH_W
		local left = hw - 7 - searchW
		local overlap = tx + tabsBar.Width + 8 > left
		local meta = PopupOf[sres]
		meta.W = searchW
		sres.Position = UDim2.fromOffset(left, M.Header)
		sres.Size = UDim2.fromOffset(searchW + 2, 0)
		meta.Panel.Size = UDim2.fromOffset(searchW, 0)
		meta.Panel.Position = UDim2.fromOffset(1, 1)
		sres.Visible = false
		field.Visible = true
		field.Active = true
		W.SearchOpen = true
		setMag(Theme.Text)
		table.insert(Popups, { Frame = field, Anchor = sb, Hit = { field, sres, sb }, Close = closeSearch })
		field.Size = UDim2.fromOffset(18, 18)
		tween(field, { Size = UDim2.fromOffset(searchW, 18) }, 0.28, QUINT)
		tween(stb, { TextTransparency = 0 }, 0.22, QUAD)
		if overlap then tween(tabsHolder, { GroupTransparency = 1 }, 0.18, QUAD) end
		if not Library.Animations then
			field.Size = UDim2.fromOffset(searchW, 18)
			stb.TextTransparency = 0
		end
		task.delay(0.06, function() if W.SearchOpen then stb:CaptureFocus() end end)
	end

	sb.MouseEnter:Connect(function() if not W.SearchOpen then setMag(Theme.Text) end end)
	sb.MouseLeave:Connect(function() if not W.SearchOpen then setMag(Theme.TextDim) end end)
	sb.InputBegan:Connect(function(i)
		if isPress(i) then
			calibrate(sb, i)
			if isOpen(field) then closePopup(field) else openSearch() end
		end
	end)
	bind(sb, function() setMag(W.SearchOpen and Theme.Text or Theme.TextDim, true) end)

	local function offsetPos(dy) return UDim2.new(W.Pos.X.Scale, W.Pos.X.Offset, W.Pos.Y.Scale, W.Pos.Y.Offset + dy) end
	local function showDetached(t, v, instant)
		local dw = t.DetachWin
		if not dw then return end
		local st = dw:FindFirstChildOfClass("UIStroke")
		t._dtoken = (t._dtoken or 0) + 1
		local my = t._dtoken
		local anim = Library.Animations and not instant
		if v then
			dw.Visible = true
			if anim then
				dw.GroupTransparency = 1
				if st then st.Transparency = 1 end
				tween(dw, { GroupTransparency = 0 }, 0.3, QUAD)
				if st then tween(st, { Transparency = 0 }, 0.3, QUAD) end
			else
				dw.GroupTransparency = 0
				if st then st.Transparency = 0 end
			end
		else
			if anim then
				tween(dw, { GroupTransparency = 1 }, 0.2, QUAD)
				if st then tween(st, { Transparency = 1 }, 0.2, QUAD) end
				task.delay(0.22, function()
					if t._dtoken == my and dw.Parent and not W.Visible then dw.Visible = false end
				end)
			else
				dw.Visible = false
			end
		end
	end

	function W:SetVisible(v, instant)
		if W.Visible == v and not instant then return end
		W.Visible = v
		Library.MenuVisible = v
		cancelRunning()
		if v then
			frame.Visible = true
			if instant or not Library.Animations then
				cg.GroupTransparency = 0
				frame.BackgroundTransparency = 0
				frameStroke.Transparency = 0
				frame.Position = W.Pos
			else
				cg.GroupTransparency = 1
				frame.BackgroundTransparency = 1
				frameStroke.Transparency = 1
				frame.Position = offsetPos(12)
				track(tween(cg, { GroupTransparency = 0 }, 0.3, QUAD))
				track(tween(frame, { BackgroundTransparency = 0, Position = W.Pos }, 0.34, QUINT))
				track(tween(frameStroke, { Transparency = 0 }, 0.3, QUAD))
			end
		else
			closeAllPopups()
			if instant or not Library.Animations then
				frame.Visible = false
			else
				track(tween(cg, { GroupTransparency = 1 }, 0.2, QUAD))
				track(tween(frame, { BackgroundTransparency = 1, Position = offsetPos(8) }, 0.22, QUAD))
				track(tween(frameStroke, { Transparency = 1 }, 0.2, QUAD))
				task.delay(0.24, function() if not W.Visible then frame.Visible = false end end)
			end
		end
		for _, t in ipairs(W.Tabs) do
			if t.Detached and t.DetachWin then showDetached(t, v, instant) end
		end
		KL.Refresh()
	end

	function W:AddBuiltinTabs()
		if W._builtin then return end
		W._builtin = true
		if Library._buildBuiltin then Library._buildBuiltin(W) end
	end
	if o.Builtin ~= false then
		task.defer(function() W:AddBuiltinTabs() end)
	end

	table.insert(Library.Windows, W)
	W:SetVisible(true, false)
	return W
end

local Column = new("Frame", {
	Name = "Column", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 48), Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, Parent = HUD,
})
vlist(Column, 0).HorizontalAlignment = Enum.HorizontalAlignment.Right

local WM = { Opts = { Fps = true, Ping = true, Time = true } }
local wmFrame = new("Frame", {
	Name = "Watermark", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
	Skin = { BackgroundColor3 = "Section" }, Parent = HUD,
})
stroke(wmFrame, "Border")
new("Frame", { Size = UDim2.new(1, 0, 0, 2), Skin = { BackgroundColor3 = "Accent" }, ZIndex = 2, Parent = wmFrame })
local wmInner = new("Frame", {
	Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1, Parent = wmFrame,
})
hlist(wmInner, 8)
pad(wmInner, 10, 0, 10, 0)
local wmLabels = {}

local function wmSep()
	new("Frame", { Size = UDim2.fromOffset(1, 10), Skin = { BackgroundColor3 = "Border" }, Parent = wmInner })
end

local function wmStat(key, label)
	local g = new("Frame", { Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = wmInner })
	hlist(g, 5)
	new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), Text = label,
		Skin = { TextColor3 = "TextDim" }, LayoutOrder = 1, Parent = g,
	})
	wmLabels[key] = new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), Text = "",
		Skin = { TextColor3 = "TextMid" }, LayoutOrder = 2, Parent = g,
	})
end

local function buildWatermark()
	for _, c in ipairs(wmInner:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
	end
	wmLabels = {}
	logo(wmInner)
	new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), Text = WM.Opts.Name or Library.Name,
		TextSize = Theme.TitleSize, Parent = wmInner,
	})
	if WM.Opts.Fps then wmSep(); wmStat("Fps", "fps") end
	if WM.Opts.Ping then wmSep(); wmStat("Ping", "ping") end
	if WM.Opts.Time then wmSep(); wmStat("Time", "time") end
	if WM.Opts.Extra then
		wmSep()
		new("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), Text = WM.Opts.Extra,
			Skin = { TextColor3 = "TextMid" }, Parent = wmInner,
		})
	end
end
function Library:SetWatermark(opts)
	for k, v in pairs(opts or {}) do WM.Opts[k] = v end
	buildWatermark()
end
function Library:SetWatermarkVisible(v) wmFrame.Visible = v end
buildWatermark()

local KLW = 140
local KL_TOP = 28
local klFrame = new("Frame", {
	Name = "KeybindList", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(KLW, KL_TOP + M.KLRow + 3),
	Skin = { BackgroundColor3 = "Section" }, Parent = HUD,
})
stroke(klFrame, "Border")
new("Frame", { Size = UDim2.new(1, 0, 0, 2), Skin = { BackgroundColor3 = "Accent" }, ZIndex = 2, Parent = klFrame })
new("TextLabel", {
	Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 22), Text = "Keybinds", TextSize = Theme.TitleSize,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = klFrame,
})
new("Frame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 1), Skin = { BackgroundColor3 = "Border" }, Parent = klFrame })
local klGrab = new("TextButton", { Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 22), ZIndex = 3, Parent = klFrame })
klGrab.InputBegan:Connect(function(i)
	if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local origin = Vector2.new(klFrame.Position.X.Offset, klFrame.Position.Y.Offset)
	local start = mouse()
	Library._dragEnd = function() Library:_touch() end
	Library._drag = function(mp)
		local v = viewport()
		local x = math.clamp(origin.X + (mp.X - start.X), 0, math.max(0, v.X - klFrame.AbsoluteSize.X))
		local y = math.clamp(origin.Y + (mp.Y - start.Y), 0, math.max(0, v.Y - klFrame.AbsoluteSize.Y))
		klFrame.Position = UDim2.fromOffset(x, y)
	end
end)
Library.Options.__keylist_pos = {
	Type = "Position",
	Serialize = function() return { x = klFrame.Position.X.Offset, y = klFrame.Position.Y.Offset } end,
	Deserialize = function(_, d)
		if type(d) == "table" and type(d.x) == "number" and type(d.y) == "number" then
			local v = viewport()
			klFrame.Position = UDim2.fromOffset(math.clamp(d.x, 0, math.max(0, v.X - 40)), math.clamp(d.y, 0, math.max(0, v.Y - 40)))
		end
	end,
}
local klRows = new("Frame", {
	Position = UDim2.fromOffset(0, KL_TOP), Size = UDim2.new(1, 0, 1, -KL_TOP), BackgroundTransparency = 1,
	ClipsDescendants = true, Parent = klFrame,
})
vlist(klRows, 0)
local klRowsByKey = {}

function KL.Refresh()
	local entries = { { Id = "__menu", Name = "Menu", Key = Library.ToggleKey.Name, Active = Library.MenuVisible } }
	for _, K in ipairs(Library._kb) do
		if K.ShowInList and K.Key ~= "None" and not K.Simple then
			entries[#entries + 1] = { Id = K, Name = K.Text, Key = K.Key, Active = K.State }
		end
	end
	local used = {}
	local maxw = KLW
	for i, e in ipairs(entries) do
		used[e.Id] = true
		local keyTxt = "[" .. shortKey(e.Key) .. "]"
		maxw = math.max(maxw, 20 + math.ceil(textW(e.Name)) + 24 + math.ceil(textW(keyTxt)))
		local r = klRowsByKey[e.Id]
		if not r then
			local f = new("Frame", { Size = UDim2.new(1, 0, 0, M.KLRow), BackgroundTransparency = 1, Parent = klRows })
			local nm = new("TextLabel", {
				Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = e.Active and Theme.Text or Theme.TextDim, Parent = f,
			})
			local ky = new("TextLabel", {
				Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = e.Active and Theme.Accent or Theme.TextOff, Parent = f,
			})
			r = { Frame = f, Name = nm, Key = ky }
			klRowsByKey[e.Id] = r
			if Library.Animations then
				nm.TextTransparency = 1
				ky.TextTransparency = 1
				tween(nm, { TextTransparency = 0 }, 0.25, QUAD)
				tween(ky, { TextTransparency = 0 }, 0.25, QUAD)
			end
		end
		r.Frame.LayoutOrder = i
		r.Name.Text = e.Name
		r.Key.Text = keyTxt
		tween(r.Name, { TextColor3 = e.Active and Theme.Text or Theme.TextDim }, 0.2, QUAD)
		tween(r.Key, { TextColor3 = e.Active and Theme.Accent or Theme.TextOff }, 0.2, QUAD)
	end
	for id, r in pairs(klRowsByKey) do
		if not used[id] then
			klRowsByKey[id] = nil
			tween(r.Name, { TextTransparency = 1 }, 0.15, QUAD)
			tween(r.Key, { TextTransparency = 1 }, 0.15, QUAD)
			task.delay(0.16, function() r.Frame:Destroy() end)
		end
	end
	tween(klFrame, { Size = UDim2.fromOffset(maxw, KL_TOP + M.KLRow * #entries + 3) }, 0.24, QUINT)
end
bind(klFrame, function() KL.Refresh() end)
function Library:SetKeybindListVisible(v) klFrame.Visible = v end

local notifHolder = new("Frame", {
	Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, Parent = Column,
})
vlist(notifHolder, 0).HorizontalAlignment = Enum.HorizontalAlignment.Right
local notifCount = 0

function Library:Notify(o, duration)
	if type(o) == "string" then o = { Text = o, Duration = duration } end
	notifCount = notifCount + 1
	local title, msg = o.Title, o.Text or ""
	local dur = o.Duration or 4
	local GAP = 8
	local w = math.max(math.ceil(math.max(title and textW(title, Theme.TitleSize) or 0, textW(msg))) + 22, 120)
	local h = title and 44 or 28

	local wrap = new("Frame", { Size = UDim2.fromOffset(w + 2, 0), BackgroundTransparency = 1, LayoutOrder = notifCount, Parent = notifHolder })
	local box = new("CanvasGroup", {
		Position = UDim2.fromOffset(w + 30, 0), Size = UDim2.fromOffset(w + 2, h + 2), BackgroundTransparency = 1,
		GroupTransparency = 1, Parent = wrap,
	})
	pad(box, 1, 1, 1, 1)
	local panel = new("Frame", { Size = UDim2.fromScale(1, 1), Skin = { BackgroundColor3 = "Section" }, Parent = box })
	stroke(panel, "Border")
	new("Frame", { Size = UDim2.new(0, 2, 1, 0), Skin = { BackgroundColor3 = "Accent" }, Parent = panel })
	if title then
		new("TextLabel", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -22, 0, 14), Text = title, TextSize = Theme.TitleSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
		new("TextLabel", { Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -22, 0, 12), Text = msg, Skin = { TextColor3 = "TextMid" }, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	else
		new("TextLabel", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -22, 0, 12), Text = msg, Skin = { TextColor3 = "TextMid" }, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	end
	local prog = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 2, 1, 0), Size = UDim2.new(1, -2, 0, 1),
		Skin = { BackgroundColor3 = "Accent" }, Parent = panel,
	})

	local dismissed = false
	local function dismiss()
		if dismissed then return end
		dismissed = true
		tween(box, { Position = UDim2.fromOffset(w + 30, 0), GroupTransparency = 1 }, 0.3, QUINT, IN)
		task.delay(0.28, function()
			if not wrap.Parent then return end
			wrap.ClipsDescendants = true
			tween(wrap, { Size = UDim2.fromOffset(w + 2, 0) }, 0.24, QUINT)
			task.delay(0.26, function() wrap:Destroy() end)
		end)
	end
	local click = new("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = panel })
	click.MouseButton1Click:Connect(dismiss)

	tween(wrap, { Size = UDim2.fromOffset(w + 2, h + 2 + GAP) }, 0.3, QUINT)
	tween(box, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, 0.42, QUINT)
	tween(prog, { Size = UDim2.new(0, 0, 0, 1) }, dur, Enum.EasingStyle.Linear)
	task.delay(dur, dismiss)
end

local function conn(c) table.insert(Library._conns, c) return c end

conn(UIS.InputBegan:Connect(function(i, gp)
	local t = i.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then
		local mp = mouse()
		for idx = #Popups, 1, -1 do
			local p = Popups[idx]
			if p then
				local hit = false
				for _, g in ipairs(p.Hit) do
					if inside(g, mp) then hit = true break end
				end
				if hit then break end
				closePopup(p.Frame)
			end
		end
	end

	local K = Library._listening
	if K then
		local n = inputName(i)
		if n then
			Library._listening = nil
			if i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace then n = "None" end
			K:SetKey(n)
			return
		end
	end

	if i.KeyCode == Enum.KeyCode.Escape and #Popups > 0 then
		closePopup(Popups[#Popups].Frame)
		return
	end

	if gp or UIS:GetFocusedTextBox() then return end

	if i.KeyCode == Library.ToggleKey then
		local w = Library.Windows[1]
		if w then w:SetVisible(not w.Visible) end
		return
	end

	local n = inputName(i)
	if not n then return end
	for _, kb in ipairs(Library._kb) do
		if kb.Key == n and not kb.Simple then
			if kb.Mode == "Toggle" then kb:SetState(not kb.State)
			elseif kb.Mode == "Hold" then kb:SetState(true) end
		end
	end
end))

conn(UIS.InputEnded:Connect(function(i)
	if isPress(i) then
		Library._drag = nil
		if Library._dragEnd then
			local f = Library._dragEnd
			Library._dragEnd = nil
			f()
		end
	end
	local n = inputName(i)
	if n then
		for _, kb in ipairs(Library._kb) do
			if kb.Key == n and kb.Mode == "Hold" and not kb.Simple then kb:SetState(false) end
		end
	end
end))

conn(UIS.InputChanged:Connect(function(i)
	if Library._drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		Library._drag(mouse())
	end
end))

local frames, acc = 0, 0
conn(RunService.RenderStepped:Connect(function(dt)
	for P in pairs(Library._animated) do
		if P.Animation == "None" then Library._animated[P] = nil else P:_tick() end
	end
	frames = frames + 1
	acc = acc + dt
	if acc >= 0.5 then
		local fps = math.floor(frames / acc + 0.5)
		frames, acc = 0, 0
		if wmLabels.Fps then wmLabels.Fps.Text = tostring(fps) end
		if wmLabels.Ping then
			local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
			wmLabels.Ping.Text = math.floor(ok and v or 0) .. "ms"
		end
		if wmLabels.Time then wmLabels.Time.Text = os.date("%H:%M") end
	end
end))

function Library:SetTheme(key, color)
	Theme[key] = color
	restyle()
end
function Library:SetAccent(color) Library:SetTheme("Accent", color) end

function Library:SetThemeSpec(spec, name)
	local cur = Library.CurrentTheme
	cur.Name = name or spec.Name or cur.Name
	for _, k in ipairs({ "Accent", "Background", "Panel", "Outline", "Text" }) do cur[k] = spec[k] or cur[k] end
	for k, v in pairs(derive(cur)) do Theme[k] = v end
	restyle()
	if Library._syncThemeUI then Library._syncThemeUI() end
end

function Library:SetVisible(v) if Library.Windows[1] then Library.Windows[1]:SetVisible(v) end end
function Library:Toggle() if Library.Windows[1] then Library.Windows[1]:SetVisible(not Library.Windows[1].Visible) end end
function Library:SetToggleKey(k) Library.ToggleKey = k; KL.Refresh() end

function Library:SetFlags(map, stagger)
	stagger = stagger or 0.025
	local n = 0
	for k, v in pairs(map or {}) do
		local id, val = k, v
		if type(k) == "number" and type(v) == "table" then id, val = v[1], v[2] end
		local opt = Library.Options[id]
		if opt then
			n = n + 1
			task.delay((n - 1) * stagger, function()
				if opt.Type == "Keybind" then
					opt:SetKey(val)
				elseif opt.SetValue then
					opt:SetValue(val)
				end
				if opt.Flash then opt:Flash() end
			end)
		end
	end
end

Library._onUnload = {}
function Library:Unload()
	if Library._unloaded then return end
	Library._unloaded = true
	for _, f in ipairs(Library._onUnload) do pcall(f) end
	for _, c in ipairs(Library._conns) do pcall(function() c:Disconnect() end) end
	pcall(function() Gui:Destroy() end)
	if env.InteriumUI == Library then env.InteriumUI = nil end
end

local THEME_KEYS = { "Accent", "Background", "Panel", "Outline", "Text" }
local STATUS = { "Friendly", "Neutral", "Enemy" }
local STATUS_COLOR = {
	Friendly = Color3.fromRGB(95, 200, 120),
	Enemy = Color3.fromRGB(230, 75, 85),
}

local function specToData(spec)
	local d = { Name = spec.Name }
	for _, k in ipairs(THEME_KEYS) do d[k] = toHex(spec[k]) end
	return d
end

local function dataToSpec(d)
	if type(d) ~= "table" then return nil end
	local s = { Name = d.Name }
	for _, k in ipairs(THEME_KEYS) do
		if type(d[k]) ~= "string" then return nil end
		local ok, c = pcall(Color3.fromHex, d[k])
		if not ok then return nil end
		s[k] = c
	end
	return s
end

local function copySpec(spec)
	local s = { Name = spec.Name }
	for _, k in ipairs(THEME_KEYS) do s[k] = spec[k] end
	return s
end

function Library:GetPlayerStatus(p)
	return Library.PlayerStatus[p.UserId] or "Neutral"
end
function Library:IsFriendly(p) return Library:GetPlayerStatus(p) == "Friendly" end
function Library:IsEnemy(p) return Library:GetPlayerStatus(p) == "Enemy" end
Library._statusHooks = {}
function Library:SetPlayerStatus(p, status)
	if status == "Neutral" then Library.PlayerStatus[p.UserId] = nil else Library.PlayerStatus[p.UserId] = status end
	for _, f in ipairs(Library._statusHooks) do task.spawn(f, p, status) end
	Library:_touch()
end
function Library:OnPlayerStatusChanged(fn) table.insert(Library._statusHooks, fn) end

local FS = {
	Ok = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
		and type(isfolder) == "function" and type(makefolder) == "function" and type(listfiles) == "function",
	Memory = {},
	Settings = {},
}

local Config = { Current = nil, Autosave = false, Loading = false, Token = 0 }
Library.Config = Config

local function cfgDir() return Library.Folder .. "/configs" end
local function cfgPath(name) return cfgDir() .. "/" .. name .. ".json" end
local function settingsPath() return Library.Folder .. "/settings.json" end

local function ensureFolders()
	if not FS.Ok then return end
	pcall(function()
		if not isfolder(Library.Folder) then makefolder(Library.Folder) end
		if not isfolder(cfgDir()) then makefolder(cfgDir()) end
	end)
end

local function cleanName(name)
	name = tostring(name or "")
	name = name:gsub("[^%w%-_ ]", "")
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	return name
end

function Config:List()
	local out = {}
	if FS.Ok then
		ensureFolders()
		local ok, files = pcall(listfiles, cfgDir())
		if ok and type(files) == "table" then
			for _, f in ipairs(files) do
				local n = tostring(f):match("([^/\\]+)%.json$")
				if n then out[#out + 1] = n end
			end
		end
	else
		for n in pairs(FS.Memory) do out[#out + 1] = n end
	end
	table.sort(out, function(a, b) return a:lower() < b:lower() end)
	return out
end

function Config:Exists(name)
	if FS.Ok then
		local ok, r = pcall(isfile, cfgPath(name))
		return ok and r
	end
	return FS.Memory[name] ~= nil
end

function Config:Encode()
	local data = { version = 1, options = {}, themes = {}, theme = specToData(Library.CurrentTheme), players = {} }
	for id, opt in pairs(Library.Options) do
		if not opt.NoConfig and opt.Serialize then
			local ok, v = pcall(opt.Serialize, opt)
			if ok then data.options[id] = v end
		end
	end
	for n, spec in pairs(Library.CustomThemes) do data.themes[n] = specToData(spec) end
	for uid, st in pairs(Library.PlayerStatus) do data.players[tostring(uid)] = st end
	return HttpService:JSONEncode(data)
end

function Config:Write(name, silent)
	name = cleanName(name)
	if name == "" then return false end
	local str = Config:Encode()
	if FS.Ok then
		ensureFolders()
		local ok = pcall(writefile, cfgPath(name), str)
		if not ok then return false end
	else
		FS.Memory[name] = str
	end
	Config.Current = name
	if Library._configChanged then Library._configChanged() end
	return true
end

function Config:Read(name)
	local str
	if FS.Ok then
		local ok, r = pcall(readfile, cfgPath(name))
		if ok then str = r end
	else
		str = FS.Memory[name]
	end
	if not str then return nil end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, str)
	if ok and type(data) == "table" then return data end
	return nil
end

function Config:Delete(name)
	if FS.Ok then pcall(delfile, cfgPath(name)) else FS.Memory[name] = nil end
	if Config.Current == name then Config.Current = nil end
	if Library._configChanged then Library._configChanged() end
end

function Config:Apply(data)
	Config.Loading = true
	if type(data.themes) == "table" then
		for n, d in pairs(data.themes) do
			local spec = dataToSpec(d)
			if spec then spec.Name = n; Library.CustomThemes[n] = spec end
		end
	end
	if Library._themeItems then Library._themeItems() end
	local spec = dataToSpec(data.theme)
	if spec then Library:SetThemeSpec(spec, data.theme.Name) end
	if type(data.players) == "table" then
		Library.PlayerStatus = {}
		for k, v in pairs(data.players) do
			local uid = tonumber(k)
			if uid and (v == "Friendly" or v == "Enemy") then Library.PlayerStatus[uid] = v end
		end
		if Library._playersChanged then Library._playersChanged() end
	end
	local list = {}
	for id, d in pairs(data.options or {}) do
		local opt = Library.Options[id]
		if opt and opt.Deserialize and not opt.NoConfig then list[#list + 1] = { opt, d } end
	end
	local stagger = math.min(0.025, 0.7 / math.max(#list, 1))
	for i, e in ipairs(list) do
		task.delay((i - 1) * stagger, function()
			if Library._unloaded then return end
			pcall(e[1].Deserialize, e[1], e[2])
			if e[1].Flash then pcall(e[1].Flash, e[1]) end
		end)
	end
	task.delay(#list * stagger + 0.4, function() Config.Loading = false end)
end

function Config:Load(name)
	local data = Config:Read(name)
	if not data then return false end
	Config.Current = name
	Config:Apply(data)
	if Library._configChanged then Library._configChanged() end
	return true
end

function Config:LoadSettings()
	local s = {}
	if FS.Ok then
		local ok, str = pcall(function() return isfile(settingsPath()) and readfile(settingsPath()) or nil end)
		if ok and str then
			local ok2, d = pcall(HttpService.JSONDecode, HttpService, str)
			if ok2 and type(d) == "table" then s = d end
		end
	else
		s = FS.Settings
	end
	return s
end

function Config:SaveSettings(s)
	if FS.Ok then
		ensureFolders()
		pcall(writefile, settingsPath(), HttpService:JSONEncode(s))
	else
		FS.Settings = s
	end
end

function Config:GetAutoload() return Config:LoadSettings().autoload end
function Config:SetAutoload(name)
	local s = Config:LoadSettings()
	s.autoload = name
	Config:SaveSettings(s)
	if Library._configChanged then Library._configChanged() end
end
function Config:SetAutosave(v)
	Config.Autosave = v
	local s = Config:LoadSettings()
	s.autosave = v
	Config:SaveSettings(s)
end
function Config:LoadAutoload()
	local s = Config:LoadSettings()
	Config.Autosave = s.autosave == true
	if s.autoload and Config:Exists(s.autoload) then return Config:Load(s.autoload) end
	return false
end

function Library:_touch()
	if not Config.Autosave or not Config.Current or Config.Loading then return end
	Config.Token = Config.Token + 1
	local my = Config.Token
	task.delay(1, function()
		if my == Config.Token and Config.Autosave and Config.Current and not Config.Loading and not Library._unloaded then
			Config:Write(Config.Current, true)
		end
	end)
end

local Spectate = { Target = nil, Conns = {}, Hooks = {} }

local function specNotify() for _, f in ipairs(Spectate.Hooks) do task.spawn(f) end end

function Spectate:Stop()
	for _, c in ipairs(Spectate.Conns) do pcall(function() c:Disconnect() end) end
	Spectate.Conns = {}
	Spectate.Target = nil
	local cam = workspace.CurrentCamera
	local ch = LocalPlayer.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if cam and hum then cam.CameraSubject = hum end
	specNotify()
end

function Spectate:Start(p)
	for _, c in ipairs(Spectate.Conns) do pcall(function() c:Disconnect() end) end
	Spectate.Conns = {}
	Spectate.Target = p
	local function apply()
		local cam = workspace.CurrentCamera
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if cam and hum then cam.CameraSubject = hum end
	end
	apply()
	table.insert(Spectate.Conns, p.CharacterAdded:Connect(function(ch)
		ch:WaitForChild("Humanoid", 5)
		if Spectate.Target == p then apply() end
	end))
	table.insert(Spectate.Conns, LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.2)
		if Spectate.Target == p then apply() end
	end))
	table.insert(Spectate.Conns, Players.PlayerRemoving:Connect(function(q)
		if q == p then Spectate:Stop() end
	end))
	specNotify()
end

function Spectate:Toggle(p)
	if Spectate.Target == p then Spectate:Stop() else Spectate:Start(p) end
end

table.insert(Library._onUnload, function() Spectate:Stop() end)
Library.Spectate = Spectate

local function teleportTo(p)
	local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local theirs = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not (mine and theirs) then
		Library:Notify({ Title = "Teleport", Text = "Character not available" })
		return
	end
	mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 3)
end

Library._playerCustomQueue = {}
Library._selHooks = {}
function Library:GetSelectedPlayer() return nil end
function Library:OnPlayerSelected(fn) table.insert(Library._selHooks, fn) end
-- fn(container, tab) runs once the Players tab's Custom frame exists
function Library:OnPlayerCustom(fn)
	if Library.PlayerCustom then task.spawn(fn, Library.PlayerCustom, Library.PlayerTab)
	else table.insert(Library._playerCustomQueue, fn) end
end

local function buildPlayers(W)
	local tab = W:AddTab("Players")
	local left = tab:AddSection("Players", "Left")
	local right = tab:AddSection("Selected", "Right")
	local custom = tab:AddSection("Custom", "Right")
	local customNote = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, M.Row), Text = "No custom controls", Skin = { TextColor3 = "TextOff" }, Parent = custom.Content,
	})
	local function syncNote()
		local n = 0
		for _, c in ipairs(custom.Content:GetChildren()) do
			if c ~= customNote and c:IsA("GuiObject") then n = n + 1 end
		end
		customNote.Visible = n == 0
	end
	custom.Content.ChildAdded:Connect(function() task.defer(syncNote) end)
	custom.Content.ChildRemoved:Connect(function() task.defer(syncNote) end)
	Library.PlayerCustom, Library.PlayerTab = custom, tab
	for _, fn in ipairs(Library._playerCustomQueue) do task.spawn(fn, custom, tab) end
	Library._playerCustomQueue = {}

	local LIST_MAX = 388
	local slot = left:AddCustom(M.Item + 2)
	local sf = new("ScrollingFrame", {
		Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), Skin = { BackgroundColor3 = "Window" },
		ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = slot,
	})
	stroke(sf, "Border")
	vlist(sf, 0)
	local empty = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, M.Item), Text = "No other players", Skin = { TextColor3 = "TextOff" }, Visible = false, Parent = sf,
	})

	local selected
	local rows = {}
	local function notifySel() for _, f in ipairs(Library._selHooks) do task.spawn(f, selected) end end
	function Library:GetSelectedPlayer() return selected end

	local head = right:AddCustom(44)
	local avatarSlot = new("Frame", { Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, Parent = head })
	local face = new("Frame", {
		Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(42, 42), Skin = { BackgroundColor3 = "Element" },
		ClipsDescendants = true, Parent = avatarSlot,
	})
	stroke(face, "Border")
	local avatar = new("ImageLabel", { Size = UDim2.fromScale(1, 1), Image = "", Parent = face })
	local nameLbl = new("TextLabel", {
		Position = UDim2.fromOffset(54, 8), Size = UDim2.new(1, -54, 0, 14), Text = "No player selected", TextSize = Theme.TitleSize,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
	})
	local subLbl = new("TextLabel", {
		Position = UDim2.fromOffset(54, 26), Size = UDim2.new(1, -54, 0, 12), Text = "", Skin = { TextColor3 = "TextDim" },
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
	})

	right:AddDivider()
	local idLbl = right:AddLabel("User ID", "-")
	local teamLbl = right:AddLabel("Team", "-")
	local hpLbl = right:AddLabel("Health", "-")
	local distLbl = right:AddLabel("Distance", "-")
	right:AddDivider()

	local actions = right:AddButtonRow({
		{ Text = "Teleport", Callback = function()
			if not selected then Library:Notify({ Title = "Players", Text = "Select a player first" }) return end
			teleportTo(selected)
		end },
		{ Text = "Spectate", Callback = function()
			if not selected then Library:Notify({ Title = "Players", Text = "Select a player first" }) return end
			Spectate:Toggle(selected)
		end },
	})
	local specBtn = actions[2]

	right:AddLabel("Status")
	local statusBtns = right:AddButtonRow({
		{ Text = "Friendly", Callback = function() if selected then Library:SetPlayerStatus(selected, "Friendly"); Library._playersChanged() end end },
		{ Text = "Neutral", Callback = function() if selected then Library:SetPlayerStatus(selected, "Neutral"); Library._playersChanged() end end },
		{ Text = "Enemy", Callback = function() if selected then Library:SetPlayerStatus(selected, "Enemy"); Library._playersChanged() end end },
	})

	local function refreshSelected()
		if not selected or not selected.Parent then
			if selected then selected = nil; notifySel() end
			nameLbl.Text = "No player selected"
			subLbl.Text = ""
			avatar.Image = ""
			idLbl:SetRightText("-")
			teamLbl:SetRightText("-")
			hpLbl:SetRightText("-")
			distLbl:SetRightText("-")
			specBtn:SetText("Spectate")
			specBtn:SetActive(false)
			for _, b in ipairs(statusBtns) do b:SetActive(false) end
			return
		end
		local p = selected
		nameLbl.Text = p.DisplayName
		subLbl.Text = "@" .. p.Name
		idLbl:SetRightText(tostring(p.UserId))
		teamLbl:SetRightText(p.Team and p.Team.Name or "None")
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		hpLbl:SetRightText(hum and (math.floor(hum.Health + 0.5) .. " / " .. math.floor(hum.MaxHealth + 0.5)) or "-")
		local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local theirs = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		distLbl:SetRightText((mine and theirs) and (math.floor((mine.Position - theirs.Position).Magnitude) .. " studs") or "-")
		local spectating = Spectate.Target == p
		specBtn:SetText(spectating and "Stop Spectating" or "Spectate")
		specBtn:SetActive(spectating)
		local st = Library:GetPlayerStatus(p)
		for i, b in ipairs(statusBtns) do b:SetActive(STATUS[i] == st) end
	end

	local function select(p)
		selected = p
		if p then
			local url = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150"
			avatar.Image = url
		end
		for pl, r in pairs(rows) do r.Set(pl == p) end
		refreshSelected()
		notifySel()
	end

	local function rebuild()
		local keep = sf.CanvasPosition
		for _, c in ipairs(sf:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		rows = {}
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then list[#list + 1] = p end
		end
		table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
		empty.Visible = #list == 0
		if selected and not table.find(list, selected) then selected = nil; notifySel() end
		for i, p in ipairs(list) do
			local label = p.DisplayName
			if p.DisplayName ~= p.Name then label = label .. "  @" .. p.Name end
			local st = Library:GetPlayerStatus(p)
			local b, set, rl = makeItem(sf, label, M.Item, st)
			b.LayoutOrder = i
			rl.TextColor3 = STATUS_COLOR[st] or Theme.TextOff
			set(p == selected, true)
			rows[p] = { Set = set }
			b.MouseButton1Click:Connect(function() select(p) end)
		end
		sf.CanvasPosition = keep
		local want = math.clamp(math.max(#list, 1) * M.Item + 2, M.Item + 2, LIST_MAX)
		tween(slot, { Size = UDim2.new(1, 0, 0, want) }, 0.22, QUINT)
		refreshSelected()
	end

	Library._playersChanged = rebuild
	Spectate.Hooks[#Spectate.Hooks + 1] = refreshSelected
	table.insert(Library._conns, Players.PlayerAdded:Connect(function() task.wait(0.1); rebuild() end))
	table.insert(Library._conns, Players.PlayerRemoving:Connect(function(p)
		if p == selected then selected = nil; notifySel() end
		task.defer(rebuild)
	end))
	rebuild()

	task.spawn(function()
		while not Library._unloaded do
			task.wait(0.5)
			if W.Visible and W.Active == tab then pcall(refreshSelected) end
		end
	end)
end

local function buildConfig(W)
	local tab = W:AddTab("Config")
	local cfg = tab:AddSection("Configs", "Left")
	local menu = tab:AddSection("Menu", "Right")
	local themeSec = tab:AddSection("Theme", "Right")

	local nameBox = cfg:AddTextbox("__cfg_name", { Text = "Config name", Placeholder = "name", NoConfig = true })
	local list
	local autoToggle
	local loadedLbl, autoLbl

	local function tags(n)
		local t = {}
		if n == Config.Current then t[#t + 1] = "loaded" end
		if n == Config:GetAutoload() then t[#t + 1] = "autoload" end
		return #t > 0 and table.concat(t, ", ") or nil
	end
	list = cfg:AddListbox("__cfg_list", { Text = "Configs", Height = 154, NoConfig = true, Empty = "No configs saved", Format = tags })

	local function refreshList()
		local items = Config:List()
		list:SetItems(items)
		loadedLbl:SetRightText(Config.Current or "none")
		autoLbl:SetRightText(Config:GetAutoload() or "none")
		if autoToggle then autoToggle:SetValue(list.Value ~= nil and Config:GetAutoload() == list.Value, true) end
	end
	Library._configChanged = function() if loadedLbl then refreshList() end end

	local function pickedName()
		if not list.Value then
			Library:Notify({ Title = "Config", Text = "Select a config first" })
			return nil
		end
		return list.Value
	end

	cfg:AddButtonRow({
		{ Text = "Save", Callback = function()
			local n = cleanName(nameBox.Value)
			if n == "" then Library:Notify({ Title = "Config", Text = "Enter a name first" }) return end
			if Config:Exists(n) then Library:Notify({ Title = "Config", Text = n .. " already exists, use Overwrite" }) return end
			if Config:Write(n) then
				refreshList()
				list:SetValue(n, true)
				Library:Notify({ Title = "Config", Text = "Saved " .. n })
			end
		end },
		{ Text = "Load", Callback = function()
			local n = pickedName()
			if not n then return end
			if Config:Load(n) then Library:Notify({ Title = "Config", Text = "Loaded " .. n }) else Library:Notify({ Title = "Config", Text = "Could not read " .. n }) end
		end },
	})

	local armed, armToken = false, 0
	local deleteBtn
	local btns = cfg:AddButtonRow({
		{ Text = "Overwrite", Callback = function()
			local n = pickedName()
			if not n then return end
			if Config:Write(n) then
				refreshList()
				Library:Notify({ Title = "Config", Text = "Overwrote " .. n })
			end
		end },
		{ Text = "Delete", Callback = function()
			local n = pickedName()
			if not n then return end
			if not armed then
				armed = true
				armToken = armToken + 1
				local my = armToken
				deleteBtn:SetText("Confirm")
				deleteBtn:SetActive(true)
				task.delay(2.5, function()
					if armToken == my then
						armed = false
						deleteBtn:SetText("Delete")
						deleteBtn:SetActive(false)
					end
				end)
				return
			end
			armed = false
			armToken = armToken + 1
			deleteBtn:SetText("Delete")
			deleteBtn:SetActive(false)
			if Config:GetAutoload() == n then Config:SetAutoload(nil) end
			Config:Delete(n)
			list:SetValue(nil, true)
			refreshList()
			Library:Notify({ Title = "Config", Text = "Deleted " .. n })
		end },
	})
	deleteBtn = btns[2]

	cfg:AddDivider()
	autoToggle = cfg:AddToggle("__cfg_autoload", {
		Text = "Autoload selected", NoConfig = true,
		Callback = function(v)
			local n = list.Value
			if v then
				if not n then
					autoToggle:SetValue(false, true)
					Library:Notify({ Title = "Config", Text = "Select a config first" })
					return
				end
				Config:SetAutoload(n)
			elseif n and Config:GetAutoload() == n then
				Config:SetAutoload(nil)
			end
		end,
	})
	cfg:AddToggle("__cfg_autosave", {
		Text = "Autosave loaded config", NoConfig = true,
		Callback = function(v)
			if v and not Config.Current then
				Library:Notify({ Title = "Config", Text = "Load or save a config first" })
			end
			Config:SetAutosave(v)
		end,
	})
	loadedLbl = cfg:AddLabel("Loaded", "none")
	autoLbl = cfg:AddLabel("Autoload", "none")
	list:OnChanged(function(v)
		autoToggle:SetValue(v ~= nil and Config:GetAutoload() == v, true)
	end)

	local keyRow = menu:AddLabel("Menu key")
	keyRow:AddKeybind("__menu_key", {
		Default = Library.ToggleKey.Name, Mode = "Always", Simple = true, ShowInList = false,
		OnKey = function(k)
			local ok, code = pcall(function() return Enum.KeyCode[k] end)
			if ok and code then
				Library.ToggleKey = code
				KL.Refresh()
			elseif Library.Options.__menu_key then
				task.defer(function() Library.Options.__menu_key:SetKey(Library.ToggleKey.Name) end)
			end
		end,
	})
	menu:AddToggle("__watermark", { Text = "Watermark", Default = true, Callback = function(v) Library:SetWatermarkVisible(v) end })
	menu:AddToggle("__keylist", { Text = "Keybind list", Default = true, Callback = function(v) Library:SetKeybindListVisible(v) end })
	menu:AddToggle("__animations", { Text = "Animations", Default = true, Callback = function(v) Library.Animations = v end })
	menu:AddToggle("__tab_detach", {
		Text = "Detachable tabs",
		Default = false,
		Callback = function(v) Library.TabDetach = v == true end,
	})
	menu:AddButton({ Text = "Unload", Accent = true, Callback = function() Library:Unload() end })

	local themeDD
	local pickers = {}
	local nameInput

	local function themeNames()
		local out = {}
		for _, t in ipairs(Builtin) do out[#out + 1] = t.Name end
		local custom = {}
		for n in pairs(Library.CustomThemes) do custom[#custom + 1] = n end
		table.sort(custom, function(a, b) return a:lower() < b:lower() end)
		for _, n in ipairs(custom) do out[#out + 1] = n end
		return out
	end

	themeDD = themeSec:AddDropdown("__theme", {
		Text = "Theme", Items = themeNames(), Default = "Interium", NoConfig = true,
		Callback = function(name)
			local spec
			for _, t in ipairs(Builtin) do if t.Name == name then spec = t end end
			spec = spec or Library.CustomThemes[name]
			if spec then Library:SetThemeSpec(spec, name) end
		end,
	})

	Library._themeItems = function()
		themeDD:SetItems(themeNames())
		themeDD:SetValue(Library.CurrentTheme.Name, true)
	end
	Library._syncThemeUI = function()
		themeDD:SetValue(Library.CurrentTheme.Name, true)
		for k, p in pairs(pickers) do
			if p.Color ~= Library.CurrentTheme[k] then p:SetValue(Library.CurrentTheme[k], 1, true) end
		end
		if Library._playersChanged then Library._playersChanged() end
	end

	local labels = { Accent = "Accent", Background = "Background", Panel = "Panel", Outline = "Outline", Text = "Text" }
	for _, k in ipairs(THEME_KEYS) do
		local row = themeSec:AddLabel(labels[k])
		pickers[k] = row:AddColorPicker("__theme_" .. k, {
			Default = Library.CurrentTheme[k], NoAlpha = true, NoAnim = true, NoConfig = true,
			Callback = function(c)
				if Library.CurrentTheme[k] == c then return end
				Library.CurrentTheme[k] = c
				Library.CurrentTheme.Name = "Custom"
				Library:SetThemeSpec(Library.CurrentTheme, "Custom")
			end,
		})
	end

	nameInput = themeSec:AddTextbox("__theme_name", { Text = "Theme name", Placeholder = "name", NoConfig = true })
	themeSec:AddButtonRow({
		{ Text = "Save Theme", Callback = function()
			local n = cleanName(nameInput.Value)
			if n == "" then Library:Notify({ Title = "Theme", Text = "Enter a theme name" }) return end
			for _, t in ipairs(Builtin) do
				if t.Name:lower() == n:lower() then
					Library:Notify({ Title = "Theme", Text = "That name is built in" })
					return
				end
			end
			Library.CurrentTheme.Name = n
			Library.CustomThemes[n] = copySpec(Library.CurrentTheme)
			Library._themeItems()
			Library:_touch()
			Library:Notify({ Title = "Theme", Text = "Saved " .. n })
		end },
		{ Text = "Delete Theme", Callback = function()
			local n = themeDD.Value
			if not Library.CustomThemes[n] then
				Library:Notify({ Title = "Theme", Text = "Select a custom theme to delete" })
				return
			end
			Library.CustomThemes[n] = nil
			Library.CurrentTheme.Name = "Custom"
			Library._themeItems()
			Library:_touch()
			Library:Notify({ Title = "Theme", Text = "Deleted " .. n })
		end },
	})

	refreshList()
	return function()
		refreshList()
		local s = Config:LoadSettings()
		Config.Autosave = s.autosave == true
		Library.Options.__cfg_autosave:SetValue(Config.Autosave, true)
	end
end

Library._buildBuiltin = function(W)
	local function has(name)
		for _, t in ipairs(W.Tabs) do if t.Name == name then return true end end
		return false
	end
	if not has("Players") then buildPlayers(W) end
	local init = has("Config") and function() end or buildConfig(W)
	task.defer(function()
		if Library._unloaded then return end
		Config:LoadAutoload()
		init()
	end)
end

KL.Refresh()
env.InteriumUI = Library
return Library

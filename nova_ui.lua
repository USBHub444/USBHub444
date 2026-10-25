--[[
	N O V A   U I   L I B R A R Y   (Wind-UI inspired)
	-------------------------------------------------------------
	- Logo ตัวหนังสือ Dot-Matrix (วาดด้วย Frame ล้วน ไม่ใช้ตัวอักษรพิเศษ)
	- ปุ่มควบคุมหน้าต่างซ้ายบน 5 สไตล์: Mac (แดง/เหลือง/เขียว), Neon, Windows, Minimal, Capsule
	    แดง = ปิด/ลบ UI | เหลือง = ย่อ | เขียว = ขยายพอดีขึ้นนิดหน่อย
	  (เครื่องหมาย X / - / + ทั้งหมดวาดด้วย Frame หมุนเป็นเส้น ไม่ใช้ตัวอักษร)
	- ธีมสำเร็จรูป 7 แบบ + Custom RGB + พรีวิวสดของ UI
	- Components: Window, Tab(+Icon), Section/Card, Button, Toggle, Slider, Keybind,
	  Dropdown (ค้นหา + Multi-select), Textbox, ColorPicker, Label, Notification

	วิธีใช้: คัดลอกทั้งไฟล์ไปรันได้เลย (ตัวอย่างอยู่ท้ายไฟล์)
	ถ้าจะใช้เป็น ModuleScript ให้ตัดส่วน "EXAMPLE USAGE" ออก แล้ว return Library
]]

local Library = (function()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

local RGB = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

local Library = { Flags = {}, Windows = {}, _records = {}, _callbacks = {}, _notifyCount = 0 }

----------------------------------------------------------------------
-- THEMES
----------------------------------------------------------------------
Library.Themes = {
	["Dark"] = {
		Background = RGB(13, 13, 17), Sidebar = RGB(17, 17, 22), Card = RGB(22, 22, 29), Element = RGB(30, 30, 39),
		Accent = RGB(124, 92, 255), Accent2 = RGB(76, 175, 255), Text = RGB(242, 242, 250), SubText = RGB(145, 145, 165), Outline = RGB(44, 44, 58),
	},
	["Modern Navy"] = {
		Background = RGB(10, 18, 34), Sidebar = RGB(13, 23, 42), Card = RGB(17, 29, 52), Element = RGB(24, 40, 70),
		Accent = RGB(56, 152, 255), Accent2 = RGB(0, 224, 214), Text = RGB(232, 242, 255), SubText = RGB(128, 150, 185), Outline = RGB(36, 56, 92),
	},
	["Neon"] = {
		Background = RGB(8, 6, 16), Sidebar = RGB(12, 9, 24), Card = RGB(18, 13, 34), Element = RGB(27, 20, 50),
		Accent = RGB(255, 0, 170), Accent2 = RGB(0, 255, 225), Text = RGB(250, 240, 255), SubText = RGB(170, 140, 200), Outline = RGB(70, 30, 100),
	},
	["Midnight Purple"] = {
		Background = RGB(15, 10, 26), Sidebar = RGB(19, 13, 33), Card = RGB(26, 18, 45), Element = RGB(36, 26, 62),
		Accent = RGB(168, 85, 247), Accent2 = RGB(236, 72, 153), Text = RGB(245, 238, 255), SubText = RGB(160, 142, 190), Outline = RGB(62, 44, 98),
	},
	["Sunset"] = {
		Background = RGB(20, 12, 14), Sidebar = RGB(25, 15, 17), Card = RGB(32, 19, 21), Element = RGB(44, 27, 29),
		Accent = RGB(255, 107, 53), Accent2 = RGB(255, 196, 61), Text = RGB(255, 244, 238), SubText = RGB(190, 150, 140), Outline = RGB(76, 46, 42),
	},
	["Emerald"] = {
		Background = RGB(8, 17, 15), Sidebar = RGB(11, 22, 19), Card = RGB(15, 30, 26), Element = RGB(22, 43, 37),
		Accent = RGB(34, 211, 140), Accent2 = RGB(16, 185, 220), Text = RGB(232, 252, 244), SubText = RGB(130, 175, 158), Outline = RGB(34, 70, 58),
	},
	["Light"] = {
		Background = RGB(242, 243, 247), Sidebar = RGB(235, 237, 243), Card = RGB(255, 255, 255), Element = RGB(238, 240, 246),
		Accent = RGB(88, 101, 242), Accent2 = RGB(0, 170, 255), Text = RGB(24, 26, 36), SubText = RGB(110, 116, 135), Outline = RGB(214, 218, 230),
	},
}
Library.ThemeOrder = { "Dark", "Modern Navy", "Neon", "Midnight Purple", "Sunset", "Emerald", "Light" }
Library.Theme = {}
for k, v in pairs(Library.Themes.Dark) do Library.Theme[k] = v end
Library.CurrentTheme = "Dark"
local T = Library.Theme

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function tween(inst, time, props, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function apply(inst, props, animate, time, style, dir)
	if animate then return tween(inst, time or 0.2, props, style, dir) end
	for k, v in pairs(props) do inst[k] = v end
end

local PLAIN = { Frame = true, TextButton = true, TextLabel = true, TextBox = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true }
local function new(class, props, children)
	local inst = Instance.new(class)
	if PLAIN[class] then inst.BorderSizePixel = 0 end
	if class == "TextButton" or class == "ImageButton" then inst.AutoButtonColor = false end
	if class == "TextButton" or class == "TextLabel" or class == "TextBox" then inst.Text = "" end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

local function bind(inst, prop, key)
	local rec = { inst = inst, prop = prop, key = key }
	table.insert(Library._records, rec)
	inst[prop] = T[key]
	inst.Destroying:Connect(function() rec.dead = true end)
	return inst
end

local function onTheme(owner, fn)
	local rec = { fn = fn }
	table.insert(Library._callbacks, rec)
	owner.Destroying:Connect(function() rec.dead = true end)
	pcall(fn)
	return rec
end

function Library:_applyTheme(instant)
	local alive = {}
	for _, r in ipairs(self._records) do
		if not r.dead then
			table.insert(alive, r)
			local c = T[r.key]
			if instant then r.inst[r.prop] = c else tween(r.inst, 0.3, { [r.prop] = c }) end
		end
	end
	self._records = alive
	local cbs = {}
	for _, r in ipairs(self._callbacks) do
		if not r.dead then
			table.insert(cbs, r)
			local ok, err = pcall(r.fn)
			if not ok then warn("[NOVA] theme callback:", err) end
		end
	end
	self._callbacks = cbs
end

function Library:SetTheme(t, instant)
	if type(t) == "string" then
		local p = self.Themes[t]
		if not p then return end
		self.CurrentTheme = t
		for k, v in pairs(p) do T[k] = v end
	elseif type(t) == "table" then
		self.CurrentTheme = "Custom"
		for k, v in pairs(t) do T[k] = v end
	end
	self:_applyTheme(instant)
end

function Library:SetThemeColor(key, color)
	if T[key] == nil then return end
	T[key] = color
	self.CurrentTheme = "Custom"
	self:_applyTheme(true)
end

local function corner(parent, r)
	return new("UICorner", { CornerRadius = (r >= 99) and UDim.new(1, 0) or UDim.new(0, r), Parent = parent })
end

local function stroke(parent, key, thickness, transparency)
	local s = new("UIStroke", { Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
	bind(s, "Color", key or "Outline")
	return s
end

local function padding(parent, l, t, r, b)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b), Parent = parent })
end

local function label(parent, text, key, extra)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text or "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromScale(1, 1),
	})
	for k, v in pairs(extra or {}) do l[k] = v end
	l.Parent = parent
	if key then bind(l, "TextColor3", key) end
	return l
end

local function lighten(c, a) return c:Lerp(WHITE, a) end
local function norm(o) if type(o) == "string" then return { Name = o } end return o or {} end
local function fire(cb, ...)
	if not cb then return end
	local ok, err = pcall(cb, ...)
	if not ok then warn("[NOVA] callback error:", err) end
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function getGuiParent()
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then return hui end
	local core = game:GetService("CoreGui")
	local ok2 = pcall(function() local f = Instance.new("Folder"); f.Parent = core; f:Destroy() end)
	if ok2 then return core end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function ripple(parent, x, y)
	local rel = Vector2.new(x, y) - parent.AbsolutePosition
	local size = math.max(parent.AbsoluteSize.X, 60) * 2.4
	local c = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(rel.X, rel.Y), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 0.75, ZIndex = 2, Parent = parent })
	corner(c, 99)
	bind(c, "BackgroundColor3", "Accent")
	tween(c, 0.55, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 })
	Debris:AddItem(c, 0.6)
end

local function hoverable(f, hit)
	hit.MouseEnter:Connect(function() tween(f, 0.15, { BackgroundColor3 = lighten(T.Element, 0.05) }) end)
	hit.MouseLeave:Connect(function() tween(f, 0.15, { BackgroundColor3 = T.Element }) end)
end

----------------------------------------------------------------------
-- DOT-MATRIX FONT (5x7)
----------------------------------------------------------------------
local FONT = {
	A = "01110,10001,10001,11111,10001,10001,10001", B = "11110,10001,10001,11110,10001,10001,11110",
	C = "01110,10001,10000,10000,10000,10001,01110", D = "11110,10001,10001,10001,10001,10001,11110",
	E = "11111,10000,10000,11110,10000,10000,11111", F = "11111,10000,10000,11110,10000,10000,10000",
	G = "01110,10001,10000,10111,10001,10001,01111", H = "10001,10001,10001,11111,10001,10001,10001",
	I = "01110,00100,00100,00100,00100,00100,01110", J = "00111,00010,00010,00010,00010,10010,01100",
	K = "10001,10010,10100,11000,10100,10010,10001", L = "10000,10000,10000,10000,10000,10000,11111",
	M = "10001,11011,10101,10101,10001,10001,10001", N = "10001,11001,10101,10011,10001,10001,10001",
	O = "01110,10001,10001,10001,10001,10001,01110", P = "11110,10001,10001,11110,10000,10000,10000",
	Q = "01110,10001,10001,10001,10101,10010,01101", R = "11110,10001,10001,11110,10100,10010,10001",
	S = "01111,10000,10000,01110,00001,00001,11110", T = "11111,00100,00100,00100,00100,00100,00100",
	U = "10001,10001,10001,10001,10001,10001,01110", V = "10001,10001,10001,10001,10001,01010,00100",
	W = "10001,10001,10001,10101,10101,11011,10001", X = "10001,10001,01010,00100,01010,10001,10001",
	Y = "10001,10001,01010,00100,00100,00100,00100", Z = "11111,00001,00010,00100,01000,10000,11111",
	["0"] = "01110,10001,10011,10101,11001,10001,01110", ["1"] = "00100,01100,00100,00100,00100,00100,01110",
	["2"] = "01110,10001,00001,00010,00100,01000,11111", ["3"] = "11110,00001,00001,01110,00001,00001,11110",
	["4"] = "00010,00110,01010,10010,11111,00010,00010", ["5"] = "11111,10000,11110,00001,00001,10001,01110",
	["6"] = "00110,01000,10000,11110,10001,10001,01110", ["7"] = "11111,00001,00010,00100,01000,01000,01000",
	["8"] = "01110,10001,10001,01110,10001,10001,01110", ["9"] = "01110,10001,10001,01111,00001,00010,01100",
	["-"] = "00000,00000,00000,11111,00000,00000,00000", ["."] = "00000,00000,00000,00000,00000,01100,01100",
}

local function buildDotText(parent, text, dot, gap)
	local pitch = dot + gap
	local holder = new("Frame", { BackgroundTransparency = 1, Parent = parent })
	local dots, x = {}, 0
	for i = 1, #text do
		local ch = text:sub(i, i):upper()
		local g = FONT[ch]
		if g then
			local rows = string.split(g, ",")
			for r = 1, 7 do
				for c = 1, 5 do
					if rows[r]:sub(c, c) == "1" then
						local d = new("Frame", { Size = UDim2.fromOffset(dot, dot), Position = UDim2.fromOffset(x + (c - 1) * pitch, (r - 1) * pitch), Parent = holder })
						corner(d, 99)
						bind(d, "BackgroundColor3", "Accent")
						table.insert(dots, { inst = d, col = (x / pitch) + c })
					end
				end
			end
		end
		x = x + 6 * pitch
	end
	holder.Size = UDim2.fromOffset(math.max(x - pitch, 1), 7 * pitch - gap)
	return holder, dots
end

----------------------------------------------------------------------
-- DRAWN GLYPHS (X / - / + / square) : Frames only, no text characters
----------------------------------------------------------------------
local function makeGlyph(kind, parent, size, key)
	local parts = {}
	local function bar(w, h, rot, dx, dy)
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, dx or 0, 0.5, dy or 0), Size = UDim2.fromOffset(w, h), Rotation = rot or 0, Parent = parent })
		corner(f, 99)
		if key then bind(f, "BackgroundColor3", key) end
		table.insert(parts, f)
	end
	if kind == "cross" then
		bar(size * 1.4, 2, 45); bar(size * 1.4, 2, -45)
	elseif kind == "minus" then
		bar(size, 2)
	elseif kind == "plus" then
		bar(size, 2); bar(2, size)
	elseif kind == "square" then
		bar(size, 2, 0, 0, -size / 2 + 1); bar(size, 2, 0, 0, size / 2 - 1)
		bar(2, size, 0, -size / 2 + 1, 0); bar(2, size, 0, size / 2 - 1, 0)
	end
	local g = {}
	function g.setColor(c) for _, p in ipairs(parts) do p.BackgroundColor3 = c end end
	function g.tween(props) for _, p in ipairs(parts) do tween(p, 0.15, props) end end
	function g.setTransparency(t) for _, p in ipairs(parts) do p.BackgroundTransparency = t end end
	return g
end

local function makeChevron(parent, key)
	local holder = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = parent })
	for _, d in ipairs({ { -2, 45 }, { 2, -45 } }) do
		local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, d[1], 0.5, 0), Size = UDim2.fromOffset(7, 2), Rotation = d[2], Parent = holder })
		corner(b, 99)
		bind(b, "BackgroundColor3", key or "SubText")
	end
	return holder
end

local function makeIcon(parent, icon)
	local parts = {}
	local function add(inst, prop) table.insert(parts, { inst, prop }); return inst end
	local function box(x, y, w, h, r)
		local f = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Parent = parent })
		corner(f, r or 0)
		add(f, "BackgroundColor3")
		return f
	end
	local isImage = type(icon) == "number" or (type(icon) == "string" and icon:find("rbxasset") ~= nil)
	if isImage then
		local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = type(icon) == "number" and ("rbxassetid://" .. icon) or icon, Parent = parent })
		add(img, "ImageColor3")
	elseif icon == "grid" then
		box(0, 0, 7, 7, 2); box(9, 0, 7, 7, 2); box(0, 9, 7, 7, 2); box(9, 9, 7, 7, 2)
	elseif icon == "ring" then
		local r = new("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Parent = parent })
		corner(r, 99)
		add(new("UIStroke", { Thickness = 2, Parent = r }), "Color")
		box(5, 5, 6, 6, 99)
	elseif icon == "bars" then
		box(0, 2, 16, 2, 1); box(0, 7, 11, 2, 1); box(0, 12, 14, 2, 1)
	elseif icon == "diamond" then
		box(3, 3, 10, 10, 2).Rotation = 45
	elseif icon == "user" then
		box(5, 0, 6, 6, 99); box(1, 8, 14, 8, 4)
	elseif icon == "eye" then
		local e = new("Frame", { Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(16, 10), BackgroundTransparency = 1, Parent = parent })
		corner(e, 99)
		add(new("UIStroke", { Thickness = 2, Parent = e }), "Color")
		box(5, 5, 6, 6, 99)
	else
		box(4, 4, 8, 8, 99)
	end
	return function(color, animate)
		for _, p in ipairs(parts) do
			if animate then tween(p[1], 0.2, { [p[2]] = color }) else p[1][p[2]] = color end
		end
	end
end

----------------------------------------------------------------------
-- NOTIFICATIONS
----------------------------------------------------------------------
function Library:_notifyHolder()
	if self._notifyGui and self._notifyGui.Parent then return self._notifyHolder end
	local gui = new("ScreenGui", { Name = "NovaNotify", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000 })
	gui.Parent = getGuiParent()
	local holder = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 310, 1, -32), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), Parent = holder })
	self._notifyGui, self._notifyHolder = gui, holder
	return holder
end

function Library:Notify(o)
	o = type(o) == "string" and { Content = o } or (o or {})
	local holder = self:_notifyHolder()
	local kinds = { Success = RGB(60, 220, 130), Warning = RGB(255, 190, 60), Error = RGB(255, 85, 95) }
	local col = kinds[o.Type or ""] or T.Accent
	local duration = o.Duration or 4
	self._notifyCount = self._notifyCount + 1

	local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 68), BackgroundTransparency = 1, LayoutOrder = self._notifyCount, Parent = holder })
	local card = new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.new(1, 340, 0, 0), ClipsDescendants = true, Parent = wrap })
	bind(card, "BackgroundColor3", "Card"); corner(card, 10)
	new("UIStroke", { Color = col, Thickness = 1, Transparency = 0.45, Parent = card })
	local stripe = new("Frame", { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(0, 3, 1, -28), BackgroundColor3 = col, Parent = card })
	corner(stripe, 99)
	label(card, o.Title or "Notification", "Text", { Font = Enum.Font.GothamBold, TextSize = 13, Position = UDim2.fromOffset(24, 8), Size = UDim2.new(1, -36, 0, 18) })
	label(card, o.Content or "", "SubText", { Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(24, 27), Size = UDim2.new(1, -36, 0, 30) })
	local bar = new("Frame", { Position = UDim2.new(0, 10, 1, -5), Size = UDim2.new(1, -20, 0, 2), BackgroundColor3 = col, BackgroundTransparency = 0.2, Parent = card })
	corner(bar, 99)

	tween(card, 0.4, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
	tween(bar, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
	task.delay(duration, function()
		if not card.Parent then return end
		tween(card, 0.3, { Position = UDim2.new(1, 340, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.32)
		wrap:Destroy()
	end)
end

----------------------------------------------------------------------
-- CLASSES
----------------------------------------------------------------------
local Window, Tab, Section = {}, {}, {}
Window.__index, Tab.__index, Section.__index = Window, Tab, Section

local CONTROL_W = { Mac = 58, Neon = 58, Minimal = 58, Windows = 108, Capsule = 92 }
local RED, YEL, GRN = RGB(255, 95, 86), RGB(255, 189, 46), RGB(39, 201, 63)
Library.ControlStyles = { "Mac", "Neon", "Windows", "Minimal", "Capsule" }

function Window:_connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self._conns, c)
	return c
end

function Library:CreateWindow(o)
	o = o or {}
	local self = setmetatable({}, Window)
	self.Library = Library
	self.Tabs, self._conns = {}, {}
	self.ToggleKey = o.ToggleKey or Enum.KeyCode.RightShift
	self.ControlStyle = o.ControlStyle or "Mac"
	self.ControlPosition = o.ControlPosition or "Left"
	self.LogoText = o.Logo or o.Title or "NOVA"
	self.LogoAnimated = o.LogoAnimated ~= false
	self.OnClose = o.OnClose
	if o.Theme then Library:SetTheme(o.Theme, true) end

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local bs = o.Size or UDim2.fromOffset(660, 440)
	self.BaseSize = UDim2.fromOffset(math.min(bs.X.Offset, vp.X - 24), math.min(bs.Y.Offset, vp.Y - 24))

	local gui = new("ScreenGui", { Name = "NovaUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 500 })
	gui.Parent = getGuiParent()
	self.Gui = gui

	local main = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = self.BaseSize, ClipsDescendants = true, Parent = gui })
	bind(main, "BackgroundColor3", "Background"); corner(main, 12)
	self.Main = main

	-- glow stroke (animated gradient)
	local mainStroke = new("UIStroke", { Thickness = 1.5, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = main })
	local grad = new("UIGradient", { Parent = mainStroke })
	onTheme(main, function()
		grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, T.Accent), ColorSequenceKeypoint.new(0.5, T.Accent2), ColorSequenceKeypoint.new(1, T.Accent) })
	end)

	-- top bar
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = main })
	self.TopBar = top
	local div = new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Parent = top })
	bind(div, "BackgroundColor3", "Outline")

	-- body
	local body = new("Frame", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), BackgroundTransparency = 1, Parent = main })
	self.Body = body
	local sidebar = new("Frame", { Size = UDim2.new(0, 150, 1, 0), BackgroundTransparency = 1, Parent = body })
	local vdiv = new("Frame", { Position = UDim2.fromOffset(150, 0), Size = UDim2.new(0, 1, 1, 0), Parent = body })
	bind(vdiv, "BackgroundColor3", "Outline")

	local tabList = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = sidebar })
	padding(tabList, 10, 0, 10, 0)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })
	self.TabList = tabList

	-- sidebar footer (player card)
	local foot = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 40), Parent = sidebar })
	bind(foot, "BackgroundColor3", "Element"); corner(foot, 10); stroke(foot, "Outline")
	local av = new("ImageLabel", { Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(26, 26), Parent = foot })
	bind(av, "BackgroundColor3", "Accent"); corner(av, 99)
	label(foot, LocalPlayer and LocalPlayer.DisplayName or "Player", "Text", { Font = Enum.Font.GothamBold, TextSize = 12, Position = UDim2.fromOffset(40, 4), Size = UDim2.new(1, -46, 0, 18) })
	label(foot, "online", "SubText", { Font = Enum.Font.Gotham, TextSize = 10, Position = UDim2.fromOffset(40, 21), Size = UDim2.new(1, -46, 0, 14) })
	task.spawn(function()
		if not LocalPlayer then return end
		local ok, img = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
		if ok and av.Parent then av.Image = img end
	end)

	local content = new("Frame", { Position = UDim2.fromOffset(151, 0), Size = UDim2.new(1, -151, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = body })
	self.Pages = content

	self:_buildLogo()
	self:_buildControls()

	-- drag window
	local dragging, dragStart, startPos
	self:_connect(top.InputBegan, function(input)
		if isPress(input) then
			dragging, dragStart, startPos = true, input.Position, main.Position
		end
	end)
	self:_connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	self:_connect(UserInputService.InputEnded, function(input)
		if isPress(input) then dragging = false end
	end)

	-- toggle key
	self:_connect(UserInputService.InputBegan, function(input, gp)
		if not gp and input.KeyCode == self.ToggleKey then self:Toggle() end
	end)

	-- animation loop (glow rotation + logo shimmer)
	self:_connect(RunService.Heartbeat, function()
		local t = os.clock()
		grad.Rotation = (t * 45) % 360
		if self.LogoAnimated and self._logoDots then
			for _, d in ipairs(self._logoDots) do
				d.inst.BackgroundTransparency = 0.28 + 0.28 * math.sin(t * 3 - d.col * 0.45)
			end
		end
	end)

	-- open animation
	local target = self.BaseSize
	main.Size = UDim2.fromOffset(target.X.Offset * 0.92, target.Y.Offset * 0.92)
	tween(main, 0.35, { Size = target }, Enum.EasingStyle.Back)

	table.insert(Library.Windows, self)
	return self
end

function Window:_buildLogo()
	if self._logo then self._logo:Destroy() end
	local holder, dots = buildDotText(self.TopBar, self.LogoText, 3, 1)
	holder.AnchorPoint = Vector2.new(0, 0.5)
	self._logo, self._logoDots = holder, dots
	self:_layoutTop()
end

function Window:_layoutTop()
	if not self._logo then return end
	local x = 16
	if self.ControlPosition == "Left" then x = 14 + (CONTROL_W[self.ControlStyle] or 58) + 18 end
	self._logo.Position = UDim2.new(0, x, 0.5, 0)
end

function Window:SetLogo(text)
	self.LogoText = text ~= "" and text or "NOVA"
	self:_buildLogo()
end

function Window:SetLogoAnimated(v)
	self.LogoAnimated = v
	if not v and self._logoDots then
		for _, d in ipairs(self._logoDots) do d.inst.BackgroundTransparency = 0 end
	end
end

function Window:SetControlStyle(style)
	if not CONTROL_W[style] then return end
	self.ControlStyle = style
	self:_buildControls()
end

function Window:SetControlPosition(pos)
	self.ControlPosition = (pos == "Right") and "Right" or "Left"
	self:_buildControls()
end

function Window:_buildControls()
	if self._controls then self._controls:Destroy() end
	local style, pos = self.ControlStyle, self.ControlPosition
	local W = CONTROL_W[style] or 58
	local right = (pos == "Right")
	local inset = (style == "Windows") and 8 or 14
	local holder = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(W, 46),
		AnchorPoint = Vector2.new(right and 1 or 0, 0), Position = UDim2.new(right and 1 or 0, right and -inset or inset, 0, 0), Parent = self.TopBar,
	})
	self._controls = holder
	local actions = {
		close = function() self:Destroy() end,
		min = function() self:SetMinimized(not self.Minimized) end,
		zoom = function() self:SetZoomed(not self.Zoomed) end,
	}

	if style == "Mac" or style == "Neon" or style == "Minimal" then
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		local specs = { { "close", RED, "cross" }, { "min", YEL, "minus" }, { "zoom", GRN, "plus" } }
		for i, s in ipairs(specs) do
			local b = new("TextButton", { Size = UDim2.fromOffset(14, 14), LayoutOrder = i, BackgroundColor3 = s[2], Parent = holder })
			corner(b, 99)
			if style == "Minimal" then
				b.BackgroundTransparency = 1
				new("UIStroke", { Color = s[2], Thickness = 1.5, Parent = b })
			elseif style == "Neon" then
				new("UIStroke", { Color = s[2], Thickness = 3, Transparency = 0.7, Parent = b })
			end
			local g = makeGlyph(s[3], b, 6)
			g.setColor(style == "Minimal" and s[2] or RGB(70, 20, 20))
			g.setTransparency(1)
			b.MouseEnter:Connect(function()
				g.tween({ BackgroundTransparency = 0 })
				if style == "Minimal" then tween(b, 0.15, { BackgroundTransparency = 0.8 }) end
				tween(b, 0.15, { Size = UDim2.fromOffset(16, 16) })
			end)
			b.MouseLeave:Connect(function()
				g.tween({ BackgroundTransparency = 1 })
				if style == "Minimal" then tween(b, 0.15, { BackgroundTransparency = 1 }) end
				tween(b, 0.15, { Size = UDim2.fromOffset(14, 14) })
			end)
			b.Activated:Connect(actions[s[1]])
		end
	elseif style == "Windows" then
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		local specs = { { "min", "minus", 10 }, { "zoom", "square", 10 }, { "close", "cross", 8 } }
		for i, s in ipairs(specs) do
			local b = new("TextButton", { Size = UDim2.fromOffset(34, 28), LayoutOrder = i, BackgroundTransparency = 1, Parent = holder })
			corner(b, 8)
			local g = makeGlyph(s[2], b, s[3], "SubText")
			b.MouseEnter:Connect(function()
				if s[1] == "close" then
					tween(b, 0.15, { BackgroundColor3 = RED, BackgroundTransparency = 0 }); g.tween({ BackgroundColor3 = WHITE })
				else
					tween(b, 0.15, { BackgroundColor3 = T.Element, BackgroundTransparency = 0 }); g.tween({ BackgroundColor3 = T.Text })
				end
			end)
			b.MouseLeave:Connect(function()
				tween(b, 0.15, { BackgroundTransparency = 1 }); g.tween({ BackgroundColor3 = T.SubText })
			end)
			b.Activated:Connect(actions[s[1]])
		end
	else -- Capsule
		local pill = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 28), Parent = holder })
		bind(pill, "BackgroundColor3", "Element"); corner(pill, 99); stroke(pill, "Outline")
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = pill })
		local specs = { { "close", "cross", RED, 7 }, { "min", "minus", YEL, 8 }, { "zoom", "plus", GRN, 8 } }
		for i, s in ipairs(specs) do
			local b = new("TextButton", { Size = UDim2.fromOffset(28, 22), LayoutOrder = i, BackgroundTransparency = 1, BackgroundColor3 = s[3], Parent = pill })
			corner(b, 99)
			local g = makeGlyph(s[2], b, s[4], "SubText")
			b.MouseEnter:Connect(function() tween(b, 0.15, { BackgroundTransparency = 0 }); g.tween({ BackgroundColor3 = WHITE }) end)
			b.MouseLeave:Connect(function() tween(b, 0.15, { BackgroundTransparency = 1 }); g.tween({ BackgroundColor3 = T.SubText }) end)
			b.Activated:Connect(actions[s[1]])
		end
	end
	self:_layoutTop()
end

function Window:_targetSize()
	if self.Zoomed then
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		return UDim2.fromOffset(math.min(self.BaseSize.X.Offset * 1.15, vp.X - 12), math.min(self.BaseSize.Y.Offset * 1.15, vp.Y - 12))
	end
	return self.BaseSize
end

function Window:SetMinimized(v)
	if self.Minimized == v then return end
	self.Minimized = v
	local s = self.Main.Size
	if v then
		tween(self.Main, 0.28, { Size = UDim2.fromOffset(s.X.Offset, 46) }, Enum.EasingStyle.Quint)
		task.delay(0.28, function()
			if self.Minimized and self.Body then self.Body.Visible = false end
		end)
	else
		self.Body.Visible = true
		tween(self.Main, 0.3, { Size = self:_targetSize() }, Enum.EasingStyle.Quint)
	end
end

function Window:SetZoomed(v)
	self.Zoomed = v and true or false
	if self.Minimized then return end
	tween(self.Main, 0.3, { Size = self:_targetSize() }, Enum.EasingStyle.Quint)
end

function Window:Toggle(v)
	if v == nil then v = not self.Gui.Enabled end
	self.Gui.Enabled = v
end

function Window:SetToggleKey(key) self.ToggleKey = key end
function Window:Notify(o) Library:Notify(o) end

function Window:Destroy()
	for _, c in ipairs(self._conns) do c:Disconnect() end
	self._conns = {}
	for i, w in ipairs(Library.Windows) do
		if w == self then table.remove(Library.Windows, i) break end
	end
	fire(self.OnClose)
	if self.Gui then self.Gui:Destroy() end
end

function Library:Unload()
	for i = #self.Windows, 1, -1 do self.Windows[i]:Destroy() end
	if self._notifyGui then self._notifyGui:Destroy() end
end

----------------------------------------------------------------------
-- TAB
----------------------------------------------------------------------
function Window:CreateTab(o)
	o = norm(o)
	local tab = setmetatable({ Window = self, Name = o.Name or "Tab" }, Tab)
	local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = #self.Tabs + 1, Parent = self.TabList })
	bind(btn, "BackgroundColor3", "Accent"); corner(btn, 8)
	local ind = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 0), Parent = btn })
	bind(ind, "BackgroundColor3", "Accent"); corner(ind, 99)
	local iconBox = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Parent = btn })
	local setIcon = makeIcon(iconBox, o.Icon)
	local text = label(btn, tab.Name, nil, { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -46, 1, 0) })

	local page = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = self.Pages })
	bind(page, "ScrollBarImageColor3", "Accent")
	padding(page, 12, 12, 14, 12)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
	tab.Page, tab.Button = page, btn

	function tab:_refresh(animate)
		local active = self.Window.ActiveTab == self
		apply(text, { TextColor3 = active and T.Text or T.SubText }, animate, 0.2)
		setIcon(active and T.Accent or T.SubText, animate)
		apply(ind, { Size = UDim2.fromOffset(3, active and 18 or 0) }, animate, 0.25, Enum.EasingStyle.Back)
		apply(btn, { BackgroundTransparency = active and 0.88 or 1 }, animate, 0.2)
	end
	btn.MouseEnter:Connect(function() if self.ActiveTab ~= tab then tween(btn, 0.15, { BackgroundTransparency = 0.94 }) end end)
	btn.MouseLeave:Connect(function() if self.ActiveTab ~= tab then tween(btn, 0.15, { BackgroundTransparency = 1 }) end end)
	btn.Activated:Connect(function() tab:Select() end)
	onTheme(btn, function() tab:_refresh(false) end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then tab:Select() end
	return tab
end

function Tab:Select()
	local W = self.Window
	W.ActiveTab = self
	for _, t in ipairs(W.Tabs) do
		t.Page.Visible = (t == self)
		t:_refresh(true)
	end
	self.Page.Position = UDim2.fromOffset(0, 10)
	tween(self.Page, 0.25, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
end

----------------------------------------------------------------------
-- SECTION (CARD)
----------------------------------------------------------------------
function Tab:CreateSection(o)
	o = norm(o)
	local sec = setmetatable({ Window = self.Window, Tab = self }, Section)
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = #self.Page:GetChildren(), Parent = self.Page })
	bind(card, "BackgroundColor3", "Card"); corner(card, 12)
	local st = new("UIStroke", { Thickness = 1.2, Color = WHITE, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	local sg = new("UIGradient", { Rotation = 35, Parent = st })
	onTheme(card, function()
		sg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, T.Accent), ColorSequenceKeypoint.new(0.45, T.Outline), ColorSequenceKeypoint.new(1, T.Accent2) })
	end)
	padding(card, 12, 10, 12, 12)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })

	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
	local pill = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 14), Parent = head })
	bind(pill, "BackgroundColor3", "Accent"); corner(pill, 99)
	label(head, o.Name or "Section", "Text", { Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -30, 1, 0) })
	local chev = makeChevron(head, "SubText")
	chev.Position = UDim2.new(1, -2, 0.5, 0)

	local contentF = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = card })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = contentF })
	sec.Content, sec.Card = contentF, card

	local open = true
	head.Activated:Connect(function()
		open = not open
		contentF.Visible = open
		tween(chev, 0.2, { Rotation = open and 0 or -90 })
	end)
	return sec
end

-- base row: returns frame, title label, base height
function Section:_row(o, rightW, extraH)
	local hasDesc = o.Description ~= nil
	local baseH = hasDesc and 50 or 36
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, baseH + (extraH or 0)), ClipsDescendants = true, Parent = self.Content })
	bind(f, "BackgroundColor3", "Element"); corner(f, 8); stroke(f, "Outline")
	local w = -((rightW or 0) + 28)
	local title = label(f, o.Name or "Element", "Text", { Position = UDim2.fromOffset(14, hasDesc and 8 or 0), Size = UDim2.new(1, w, 0, hasDesc and 18 or 36) })
	if hasDesc then
		label(f, o.Description, "SubText", { Font = Enum.Font.Gotham, TextSize = 11, Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, w, 0, 14) })
	end
	return f, title, baseH
end

local function setFlag(o, v) if o.Flag then Library.Flags[o.Flag] = v end end

function Section:AddLabel(text)
	local l = label(self.Content, text or "", "SubText", { Font = Enum.Font.Gotham, TextSize = 12, Size = UDim2.new(1, 0, 0, 22), TextWrapped = true })
	local obj = {}
	function obj:Set(t) l.Text = t end
	return obj
end

function Section:AddDivider()
	local d = new("Frame", { Size = UDim2.new(1, 0, 0, 1), Parent = self.Content })
	bind(d, "BackgroundColor3", "Outline")
end

----------------------------------------------------------------------
-- BUTTON
----------------------------------------------------------------------
function Section:AddButton(o)
	o = norm(o)
	local f = self:_row(o, 30)
	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = f })
	local ring = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Parent = f })
	corner(ring, 99)
	local rs = new("UIStroke", { Thickness = 2, Parent = ring })
	bind(rs, "Color", "Accent")
	local rd = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4), Parent = ring })
	corner(rd, 99); bind(rd, "BackgroundColor3", "Accent")
	hoverable(f, hit)
	hit.InputBegan:Connect(function(input)
		if isPress(input) then ripple(f, input.Position.X, input.Position.Y) end
	end)
	hit.Activated:Connect(function()
		ring.Size = UDim2.fromOffset(20, 20)
		tween(ring, 0.35, { Size = UDim2.fromOffset(14, 14) }, Enum.EasingStyle.Back)
		fire(o.Callback)
	end)
	return {}
end

----------------------------------------------------------------------
-- TOGGLE
----------------------------------------------------------------------
function Section:AddToggle(o)
	o = norm(o)
	local f = self:_row(o, 48)
	local block = (o.Style == "Block")
	local track = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(44, 22), Parent = f })
	bind(track, "BackgroundColor3", "Background"); corner(track, block and 6 or 99)
	local ts = new("UIStroke", { Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = track })
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, Parent = track })
	corner(fill, block and 6 or 99)
	local grad = new("UIGradient", { Parent = fill })
	local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = WHITE, ZIndex = 3, Parent = track })
	corner(knob, block and 4 or 99)
	local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, ZIndex = 4, Parent = knob })
	corner(dot, block and 2 or 99); bind(dot, "BackgroundColor3", "Accent")

	local state = (o.Default == true)
	local obj = {}
	local function render(animate)
		grad.Color = ColorSequence.new(T.Accent, T.Accent2)
		apply(fill, { Size = UDim2.new(state and 1 or 0, 0, 1, 0) }, animate, 0.25)
		apply(knob, { Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, animate, 0.3, Enum.EasingStyle.Back)
		apply(dot, { BackgroundTransparency = state and 0 or 1 }, animate, 0.2)
		apply(ts, { Color = state and T.Accent or T.Outline }, animate, 0.2)
	end
	onTheme(f, function() render(false) end)
	setFlag(o, state)

	function obj:Set(v, silent)
		state = v and true or false
		render(true); setFlag(o, state)
		if not silent then fire(o.Callback, state) end
	end
	function obj:Get() return state end

	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = f })
	hoverable(f, hit)
	hit.Activated:Connect(function() obj:Set(not state) end)
	if state then fire(o.Callback, state) end
	return obj
end

----------------------------------------------------------------------
-- SLIDER
----------------------------------------------------------------------
function Section:AddSlider(o)
	o = norm(o)
	local f, _, baseH = self:_row(o, 70, 18)
	local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
	local suffix = o.Suffix or ""
	local decimals = tostring(inc):match("%.(%d+)")

	local box = new("TextBox", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(58, 20), Font = Enum.Font.GothamBold, TextSize = 12, ClearTextOnFocus = false, Parent = f })
	bind(box, "BackgroundColor3", "Background"); bind(box, "TextColor3", "Accent"); corner(box, 6); stroke(box, "Outline")

	local track = new("Frame", { Position = UDim2.new(0, 14, 0, baseH + 2), Size = UDim2.new(1, -28, 0, 6), Parent = f })
	bind(track, "BackgroundColor3", "Background"); corner(track, 99)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, Parent = track })
	corner(fill, 99)
	local grad = new("UIGradient", { Parent = fill })
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, ZIndex = 3, Parent = track })
	corner(knob, 99)
	local ks = new("UIStroke", { Thickness = 2, Parent = knob })
	bind(ks, "Color", "Accent")
	onTheme(f, function() grad.Color = ColorSequence.new(T.Accent, T.Accent2) end)

	local value = min
	local obj = {}
	local function setValue(v, silent)
		v = math.clamp(math.floor(v / inc + 0.5) * inc, min, max)
		if decimals then v = tonumber(string.format("%." .. #decimals .. "f", v)) end
		value = v
		local a = (max > min) and (v - min) / (max - min) or 0
		tween(fill, 0.08, { Size = UDim2.new(a, 0, 1, 0) })
		tween(knob, 0.08, { Position = UDim2.new(a, 0, 0.5, 0) })
		box.Text = tostring(v) .. suffix
		setFlag(o, v)
		if not silent then fire(o.Callback, v) end
	end
	function obj:Set(v, silent) setValue(tonumber(v) or min, silent) end
	function obj:Get() return value end

	local hit = new("TextButton", { Position = UDim2.new(0, 14, 0, baseH - 4), Size = UDim2.new(1, -28, 0, 22), BackgroundTransparency = 1, ZIndex = 5, Parent = f })
	local dragging = false
	local function fromX(x)
		setValue(min + (max - min) * math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1))
	end
	hit.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			fromX(input.Position.X)
			tween(knob, 0.1, { Size = UDim2.fromOffset(18, 18) })
		end
	end)
	self.Window:_connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then fromX(input.Position.X) end
	end)
	self.Window:_connect(UserInputService.InputEnded, function(input)
		if dragging and isPress(input) then
			dragging = false
			tween(knob, 0.15, { Size = UDim2.fromOffset(14, 14) })
		end
	end)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text:match("[%-%d%.]+"))
		setValue(n or value)
	end)

	setValue(o.Default or min, true)
	if o.Default then fire(o.Callback, value) end
	return obj
end

----------------------------------------------------------------------
-- KEYBIND
----------------------------------------------------------------------
function Section:AddKeybind(o)
	o = norm(o)
	local f = self:_row(o, 108)
	local key = o.Default
	local mode = o.Mode or "Press" -- Press | Toggle | Hold
	local listening, state = false, false

	local btn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(94, 22), Font = Enum.Font.GothamBold, TextSize = 11, Parent = f })
	bind(btn, "BackgroundColor3", "Background"); bind(btn, "TextColor3", "Text"); corner(btn, 6)
	local bst = stroke(btn, "Outline")
	local function show()
		btn.Text = listening and "..." or (key and key.Name or "None")
		bst.Color = listening and T.Accent or T.Outline
	end
	show()
	onTheme(f, show)
	setFlag(o, key)

	local obj = {}
	function obj:Set(k, silent) key = k; show(); setFlag(o, key); if not silent then fire(o.ChangedCallback, key) end end
	function obj:Get() return key end

	btn.Activated:Connect(function() listening = true; show() end)

	local function matches(input)
		if not key then return false end
		if key.EnumType == Enum.KeyCode then return input.KeyCode == key end
		return input.UserInputType == key
	end
	self.Window:_connect(UserInputService.InputBegan, function(input, gp)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				if input.KeyCode == Enum.KeyCode.Backspace then obj:Set(nil)
				elseif input.KeyCode == Enum.KeyCode.Escape then show()
				else obj:Set(input.KeyCode) end
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
				listening = false
				obj:Set(input.UserInputType)
			end
			return
		end
		if gp or not matches(input) then return end
		if mode == "Toggle" then state = not state; fire(o.Callback, state)
		elseif mode == "Hold" then fire(o.Callback, true)
		else fire(o.Callback) end
	end)
	self.Window:_connect(UserInputService.InputEnded, function(input)
		if mode == "Hold" and matches(input) then fire(o.Callback, false) end
	end)
	return obj
end

----------------------------------------------------------------------
-- DROPDOWN (search + multi select)
----------------------------------------------------------------------
function Section:AddDropdown(o)
	o = norm(o)
	local multi = (o.Multi == true)
	local options = o.Options or {}
	local selected, order = {}, {}
	local hasDesc = o.Description ~= nil

	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true, Parent = self.Content })
	bind(f, "BackgroundColor3", "Element"); corner(f, 8); stroke(f, "Outline")
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })

	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, hasDesc and 50 or 36), BackgroundTransparency = 1, LayoutOrder = 1, Parent = f })
	label(head, o.Name or "Dropdown", "Text", { Position = UDim2.fromOffset(14, hasDesc and 8 or 0), Size = UDim2.new(0.5, -14, 0, hasDesc and 18 or 36) })
	if hasDesc then label(head, o.Description, "SubText", { Font = Enum.Font.Gotham, TextSize = 11, Position = UDim2.fromOffset(14, 27), Size = UDim2.new(0.5, -14, 0, 14) }) end
	local valueLbl = label(head, "", "Accent", { Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -36, 0, 0), Size = UDim2.new(0.5, -40, 1, 0) })
	local chev = makeChevron(head, "SubText")
	hoverable(f, head)

	local panel = new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false, ClipsDescendants = true, LayoutOrder = 2, Parent = f })
	local search = new("TextBox", { Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 28), PlaceholderText = "Search...", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	bind(search, "BackgroundColor3", "Background"); bind(search, "TextColor3", "Text"); bind(search, "PlaceholderColor3", "SubText")
	corner(search, 6); padding(search, 10, 0, 10, 0); stroke(search, "Outline")
	local scroll = new("ScrollingFrame", { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 0, 0), BackgroundTransparency = 1, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel })
	bind(scroll, "ScrollBarImageColor3", "Accent")
	new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	if o.Search == false then search.Visible = false end

	local rows, open = {}, false
	local obj = {}

	local function currentValue()
		if multi then
			local out = {}
			for _, n in ipairs(options) do if selected[tostring(n)] then table.insert(out, n) end end
			return out
		end
		for _, n in ipairs(options) do if selected[tostring(n)] then return n end end
		return nil
	end
	local function updateText()
		local v = currentValue()
		if multi then
			valueLbl.Text = (#v == 0) and "None" or (#v <= 2 and table.concat(v, ", ") or (#v .. " selected"))
		else
			valueLbl.Text = v and tostring(v) or "None"
		end
	end
	local function visuals()
		for name, r in pairs(rows) do
			local on = selected[name] == true
			r.btn.BackgroundTransparency = on and 0.85 or 1
			r.lbl.TextColor3 = on and T.Accent or T.Text
			r.dot.BackgroundTransparency = on and 0 or 1
			r.stroke.Color = on and T.Accent or T.Outline
		end
		updateText()
	end
	onTheme(f, visuals)

	local function panelHeight()
		local n = 0
		for _, r in pairs(rows) do if r.btn.Visible then n = n + 1 end end
		local sh = math.min(n * 31, 150)
		scroll.Size = UDim2.new(1, -20, 0, sh)
		local top = (o.Search == false) and 4 or 36
		scroll.Position = UDim2.fromOffset(10, top)
		return top + sh + 10
	end
	local function resize()
		if open then tween(panel, 0.2, { Size = UDim2.new(1, 0, 0, panelHeight()) }) end
	end

	local function fireChange()
		local v = currentValue()
		setFlag(o, v)
		fire(o.Callback, v)
	end

	local function rebuild()
		for _, r in pairs(rows) do r.btn:Destroy() end
		rows = {}
		for i, n in ipairs(options) do
			local name = tostring(n)
			local btn = new("TextButton", { Size = UDim2.new(1, -4, 0, 28), BackgroundTransparency = 1, LayoutOrder = i, Parent = scroll })
			bind(btn, "BackgroundColor3", "Accent"); corner(btn, 6)
			local lbl = label(btn, name, nil, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -40, 1, 0) })
			local ring = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = btn })
			corner(ring, multi and 3 or 99)
			local rs = new("UIStroke", { Thickness = 1.5, Parent = ring })
			local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, Parent = ring })
			corner(dot, multi and 1 or 99); bind(dot, "BackgroundColor3", "Accent")
			rows[name] = { btn = btn, lbl = lbl, dot = dot, stroke = rs }
			btn.MouseEnter:Connect(function() if not selected[name] then tween(btn, 0.12, { BackgroundTransparency = 0.93 }) end end)
			btn.MouseLeave:Connect(function() if not selected[name] then tween(btn, 0.12, { BackgroundTransparency = 1 }) end end)
			btn.Activated:Connect(function()
				if multi then
					selected[name] = (not selected[name]) or nil
				else
					selected = { [name] = true }
				end
				visuals(); fireChange()
				if not multi then
					open = false
					tween(chev, 0.2, { Rotation = 0 })
					tween(panel, 0.2, { Size = UDim2.new(1, 0, 0, 0) })
					task.delay(0.2, function() if not open then panel.Visible = false end end)
				end
			end)
		end
		visuals(); resize()
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = search.Text:lower()
		for name, r in pairs(rows) do r.btn.Visible = (q == "") or (name:lower():find(q, 1, true) ~= nil) end
		resize()
	end)

	head.Activated:Connect(function()
		open = not open
		tween(chev, 0.2, { Rotation = open and 180 or 0 })
		if open then
			panel.Visible = true
			tween(panel, 0.22, { Size = UDim2.new(1, 0, 0, panelHeight()) }, Enum.EasingStyle.Quint)
		else
			tween(panel, 0.2, { Size = UDim2.new(1, 0, 0, 0) })
			task.delay(0.2, function() if not open then panel.Visible = false end end)
		end
	end)

	function obj:Get() return currentValue() end
	function obj:Set(v, silent)
		selected = {}
		if multi then
			for _, n in ipairs(type(v) == "table" and v or {}) do selected[tostring(n)] = true end
		elseif v ~= nil then
			selected[tostring(v)] = true
		end
		visuals()
		setFlag(o, currentValue())
		if not silent then fire(o.Callback, currentValue()) end
	end
	function obj:Refresh(newOptions, keep)
		options = newOptions or {}
		if not keep then selected = {} else
			local keepSet = {}
			for _, n in ipairs(options) do if selected[tostring(n)] then keepSet[tostring(n)] = true end end
			selected = keepSet
		end
		rebuild()
	end

	if multi then
		for _, n in ipairs(type(o.Default) == "table" and o.Default or {}) do selected[tostring(n)] = true end
	elseif o.Default ~= nil then
		selected[tostring(o.Default)] = true
	end
	rebuild()
	setFlag(o, currentValue())
	return obj
end

----------------------------------------------------------------------
-- TEXTBOX
----------------------------------------------------------------------
function Section:AddTextbox(o)
	o = norm(o)
	local f = self:_row(o, 160)
	local box = new("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(146, 24), Text = o.Default or "", PlaceholderText = o.Placeholder or "Type here...", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	bind(box, "BackgroundColor3", "Background"); bind(box, "TextColor3", "Text"); bind(box, "PlaceholderColor3", "SubText")
	corner(box, 6); padding(box, 8, 0, 8, 0)
	local bs = stroke(box, "Outline")
	box.Focused:Connect(function() tween(bs, 0.15, { Color = T.Accent }) end)
	local obj = {}
	box.FocusLost:Connect(function(enter)
		tween(bs, 0.15, { Color = T.Outline })
		local v = box.Text
		if o.Numeric then
			local n = tonumber(v)
			if not n then box.Text = ""; return end
			v = n
		end
		setFlag(o, v)
		if enter or o.CallbackOnLostFocus ~= false then fire(o.Callback, v) end
	end)
	function obj:Set(v) box.Text = tostring(v) end
	function obj:Get() return box.Text end
	setFlag(o, box.Text)
	return obj
end

----------------------------------------------------------------------
-- COLOR PICKER
----------------------------------------------------------------------
local function toHex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function Section:AddColorPicker(o)
	o = norm(o)
	local default = o.Default or WHITE
	local h, s, v = default:ToHSV()
	local color = default
	local hasDesc = o.Description ~= nil

	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true, Parent = self.Content })
	bind(f, "BackgroundColor3", "Element"); corner(f, 8); stroke(f, "Outline")
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })

	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, hasDesc and 50 or 36), BackgroundTransparency = 1, LayoutOrder = 1, Parent = f })
	label(head, o.Name or "Color", "Text", { Position = UDim2.fromOffset(14, hasDesc and 8 or 0), Size = UDim2.new(1, -80, 0, hasDesc and 18 or 36) })
	if hasDesc then label(head, o.Description, "SubText", { Font = Enum.Font.Gotham, TextSize = 11, Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, -80, 0, 14) }) end
	local swatch = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(34, 18), BackgroundColor3 = color, Parent = head })
	corner(swatch, 6)
	new("UIStroke", { Color = WHITE, Transparency = 0.7, Thickness = 1.5, Parent = swatch })
	hoverable(f, head)

	local panel = new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false, ClipsDescendants = true, LayoutOrder = 2, Parent = f })

	local sv = new("Frame", { Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(180, 120), BackgroundColor3 = WHITE, Parent = panel })
	corner(sv, 6)
	local satLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = sv })
	corner(satLayer, 6)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = satLayer })
	local valLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
	corner(valLayer, 6)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = valLayer })
	local cursor = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3, Parent = sv })
	corner(cursor, 99)
	new("UIStroke", { Color = WHITE, Thickness = 2, Parent = cursor })

	local hue = new("Frame", { Position = UDim2.fromOffset(206, 6), Size = UDim2.fromOffset(16, 120), BackgroundColor3 = WHITE, Parent = panel })
	corner(hue, 6)
	local kps = {}
	for i = 0, 6 do table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))) end
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(kps), Parent = hue })
	local hcur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 6, 0, 5), BackgroundColor3 = WHITE, ZIndex = 3, Parent = hue })
	corner(hcur, 2)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5, Parent = hcur })

	local preview = new("Frame", { Position = UDim2.fromOffset(234, 6), Size = UDim2.new(1, -248, 0, 50), BackgroundColor3 = color, Parent = panel })
	corner(preview, 8); stroke(preview, "Outline")
	local hex = new("TextBox", { Position = UDim2.fromOffset(234, 62), Size = UDim2.new(1, -248, 0, 26), ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextSize = 12, Parent = panel })
	bind(hex, "BackgroundColor3", "Background"); bind(hex, "TextColor3", "Text"); corner(hex, 6); stroke(hex, "Outline")
	local rgbLbl = label(panel, "", "SubText", { Font = Enum.Font.Gotham, TextSize = 11, Position = UDim2.fromOffset(234, 94), Size = UDim2.new(1, -248, 0, 18) })

	local obj = {}
	local function render()
		color = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = color
		preview.BackgroundColor3 = color
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		cursor.Position = UDim2.fromScale(s, 1 - v)
		hcur.Position = UDim2.fromScale(0.5, h)
		hex.Text = toHex(color)
		rgbLbl.Text = string.format("RGB  %d, %d, %d", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	end
	local function commit(silent)
		render()
		setFlag(o, color)
		if not silent then fire(o.Callback, color) end
	end
	function obj:Set(c, silent) h, s, v = c:ToHSV(); commit(silent) end
	function obj:Get() return color end

	local mode
	local function handle(pos)
		if mode == "sv" then
			s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		elseif mode == "hue" then
			h = math.clamp((pos.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 0.999)
		end
		commit(false)
	end
	local svHit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = sv })
	local hueHit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = hue })
	svHit.InputBegan:Connect(function(i) if isPress(i) then mode = "sv"; handle(i.Position) end end)
	hueHit.InputBegan:Connect(function(i) if isPress(i) then mode = "hue"; handle(i.Position) end end)
	self.Window:_connect(UserInputService.InputChanged, function(i) if mode and isMove(i) then handle(i.Position) end end)
	self.Window:_connect(UserInputService.InputEnded, function(i) if isPress(i) then mode = nil end end)

	hex.FocusLost:Connect(function()
		local t = hex.Text:gsub("#", ""):gsub("%s", "")
		if #t == 6 and tonumber(t, 16) then
			obj:Set(RGB(tonumber(t:sub(1, 2), 16), tonumber(t:sub(3, 4), 16), tonumber(t:sub(5, 6), 16)))
		else
			render()
		end
	end)

	local open = false
	head.Activated:Connect(function()
		open = not open
		if open then
			panel.Visible = true
			tween(panel, 0.22, { Size = UDim2.new(1, 0, 0, 134) }, Enum.EasingStyle.Quint)
		else
			tween(panel, 0.2, { Size = UDim2.new(1, 0, 0, 0) })
			task.delay(0.2, function() if not open then panel.Visible = false end end)
		end
	end)

	commit(true)
	setFlag(o, color)
	return obj
end

----------------------------------------------------------------------
-- SETTINGS TAB (themes, live preview, custom RGB, window options)
----------------------------------------------------------------------
function Window:CreateSettingsTab(o)
	o = o or {}
	local Lib = Library
	local tab = self:CreateTab({ Name = o.Name or "Settings", Icon = "ring" })

	-- Theme presets gallery (thumbnails)
	local gal = tab:CreateSection("Theme Presets")
	gal:AddLabel("Click a preset to apply it instantly.")
	local grid = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gal.Content })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(112, 82), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local cards = {}
	local pickers = {}
	for i, name in ipairs(Lib.ThemeOrder) do
		local p = Lib.Themes[name]
		local cell = new("TextButton", { BackgroundColor3 = p.Background, LayoutOrder = i, Parent = grid })
		corner(cell, 8)
		local cs = new("UIStroke", { Thickness = 1.5, Color = p.Outline, Parent = cell })
		for k = 0, 2 do
			local d = new("Frame", { Position = UDim2.fromOffset(8, 10 + k * 10), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = (k == 0) and p.Accent or p.Outline, Parent = cell })
			corner(d, 99)
		end
		local c = new("Frame", { Position = UDim2.fromOffset(24, 8), Size = UDim2.fromOffset(80, 42), BackgroundColor3 = p.Card, Parent = cell })
		corner(c, 5)
		new("UIStroke", { Color = p.Outline, Parent = c })
		local e1 = new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(46, 8), BackgroundColor3 = p.Element, Parent = c }); corner(e1, 3)
		local e2 = new("Frame", { Position = UDim2.fromOffset(6, 20), Size = UDim2.fromOffset(28, 8), BackgroundColor3 = p.Element, Parent = c }); corner(e2, 3)
		local tg = new("Frame", { Position = UDim2.fromOffset(52, 20), Size = UDim2.fromOffset(20, 9), BackgroundColor3 = p.Accent, Parent = c }); corner(tg, 99)
		local bar = new("Frame", { Position = UDim2.fromOffset(6, 33), Size = UDim2.fromOffset(60, 3), BackgroundColor3 = p.Accent2, Parent = c }); corner(bar, 99)
		label(cell, name, nil, { Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = p.Text, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 20) })
		cards[name] = cs
		cell.Activated:Connect(function()
			Lib:SetTheme(name)
			for key, pk in pairs(pickers) do pk:Set(T[key], true) end
			Lib:Notify({ Title = "Theme applied", Content = name, Type = "Success", Duration = 2 })
		end)
	end
	onTheme(grid, function()
		for name, st in pairs(cards) do
			st.Color = (Lib.CurrentTheme == name) and T.Accent or Lib.Themes[name].Outline
		end
	end)

	-- Live preview (everything bound to the live theme)
	local pv = tab:CreateSection("Live Preview")
	local mock = new("Frame", { Size = UDim2.new(1, 0, 0, 150), Parent = pv.Content })
	bind(mock, "BackgroundColor3", "Background"); corner(mock, 10); stroke(mock, "Accent")
	for i, col in ipairs({ RED, YEL, GRN }) do
		local d = new("Frame", { Position = UDim2.fromOffset(10 + (i - 1) * 14, 10), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = col, Parent = mock })
		corner(d, 99)
	end
	local ml = new("Frame", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 1), Parent = mock }); bind(ml, "BackgroundColor3", "Outline")
	local sb = new("Frame", { Position = UDim2.fromOffset(10, 40), Size = UDim2.fromOffset(60, 100), BackgroundTransparency = 1, Parent = mock })
	for i = 0, 2 do
		local t = new("Frame", { Position = UDim2.fromOffset(0, i * 26), Size = UDim2.new(1, 0, 0, 20), Parent = sb })
		corner(t, 5)
		if i == 0 then bind(t, "BackgroundColor3", "Accent"); t.BackgroundTransparency = 0.7 else bind(t, "BackgroundColor3", "Element") end
	end
	local mc = new("Frame", { Position = UDim2.fromOffset(82, 40), Size = UDim2.new(1, -92, 0, 100), Parent = mock })
	bind(mc, "BackgroundColor3", "Card"); corner(mc, 8); stroke(mc, "Outline")
	local r1 = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 22), Parent = mc }); bind(r1, "BackgroundColor3", "Element"); corner(r1, 6)
	local tg = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(30, 14), Parent = r1 }); bind(tg, "BackgroundColor3", "Accent"); corner(tg, 99)
	local kn = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = WHITE, Parent = tg }); corner(kn, 99)
	label(r1, "Toggle", "Text", { TextSize = 11, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.5, 0, 1, 0) })
	local r2 = new("Frame", { Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 0, 26), Parent = mc }); bind(r2, "BackgroundColor3", "Element"); corner(r2, 6)
	label(r2, "Slider", "Text", { TextSize = 11, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.5, 0, 0, 16) })
	local tr = new("Frame", { Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 0, 4), Parent = r2 }); bind(tr, "BackgroundColor3", "Background"); corner(tr, 99)
	local fl = new("Frame", { Size = UDim2.fromScale(0.62, 1), Parent = tr }); bind(fl, "BackgroundColor3", "Accent"); corner(fl, 99)
	local r3 = new("Frame", { Position = UDim2.fromOffset(8, 68), Size = UDim2.new(1, -16, 0, 22), Parent = mc }); bind(r3, "BackgroundColor3", "Accent"); corner(r3, 6)
	label(r3, "Button", nil, { TextSize = 11, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold })

	-- Custom RGB
	local cu = tab:CreateSection("Custom RGB")
	local keys = {
		{ "Accent", "Accent Color" }, { "Accent2", "Accent Color 2 (gradient)" }, { "Background", "Background" }, { "Sidebar", "Sidebar" },
		{ "Card", "Card" }, { "Element", "Element" }, { "Text", "Text" }, { "SubText", "Sub Text" }, { "Outline", "Outline" },
	}
	for _, k in ipairs(keys) do
		pickers[k[1]] = cu:AddColorPicker({
			Name = k[2], Default = T[k[1]],
			Callback = function(c)
				Lib._suppress = true
				T[k[1]] = c
				Lib.CurrentTheme = "Custom"
				Lib:_applyTheme(true)
				Lib._suppress = false
			end,
		})
	end

	-- Window options
	local wo = tab:CreateSection("Window")
	wo:AddDropdown({ Name = "Control Buttons Style", Description = "Mac / Neon / Windows / Minimal / Capsule", Options = Lib.ControlStyles, Default = self.ControlStyle, Search = false,
		Callback = function(v) if v then self:SetControlStyle(v) end end })
	wo:AddDropdown({ Name = "Control Buttons Position", Options = { "Left", "Right" }, Default = self.ControlPosition, Search = false,
		Callback = function(v) if v then self:SetControlPosition(v) end end })
	wo:AddKeybind({ Name = "Toggle UI Key", Description = "Press the key to hide / show the window", Default = self.ToggleKey,
		ChangedCallback = function(k) if k and k.EnumType == Enum.KeyCode then self:SetToggleKey(k) end end })
	wo:AddTextbox({ Name = "Logo Text", Default = self.LogoText, Placeholder = "A-Z 0-9", Callback = function(t) self:SetLogo(t) end })
	wo:AddToggle({ Name = "Animated Logo", Default = self.LogoAnimated, Callback = function(v) self:SetLogoAnimated(v) end })
	wo:AddButton({ Name = "Test Notification", Callback = function()
		Lib:Notify({ Title = "Hello from NOVA", Content = "This is how notifications look with the current theme.", Duration = 3 })
	end })

	return tab
end

return Library
end)()

--====================================================================
-- EXAMPLE USAGE   (ตัวอย่างการใช้งานครบทุกองค์ประกอบ)
--====================================================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Window = Library:CreateWindow({
	Logo = "NOVA",                       -- ตัวหนังสือ Dot-Matrix มุมบน
	Theme = "Dark",                      -- Dark | Modern Navy | Neon | Midnight Purple | Sunset | Emerald | Light
	ControlStyle = "Mac",                -- Mac | Neon | Windows | Minimal | Capsule
	ControlPosition = "Left",            -- Left | Right
	ToggleKey = Enum.KeyCode.RightShift, -- ซ่อน/แสดง UI
	Size = UDim2.fromOffset(660, 440),
})

----- Tab: Main -----
local Main = Window:CreateTab({ Name = "Main", Icon = "grid" })

local Player = Main:CreateSection("Player")

Player:AddToggle({
	Name = "God Mode Demo", Description = "Pill style toggle", Default = false, Flag = "demo_toggle",
	Callback = function(on) Library:Notify({ Title = "Toggle", Content = "State: " .. tostring(on), Type = on and "Success" or "Warning", Duration = 2 }) end,
})

Player:AddToggle({ Name = "Block Style Toggle", Style = "Block", Default = true, Callback = function(on) print("block toggle", on) end })

Player:AddSlider({
	Name = "WalkSpeed", Min = 16, Max = 200, Default = 16, Increment = 1, Suffix = "", Flag = "walkspeed",
	Callback = function(v)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = v end
	end,
})

Player:AddSlider({
	Name = "JumpPower", Min = 50, Max = 300, Default = 50, Increment = 5,
	Callback = function(v)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.UseJumpPower = true; hum.JumpPower = v end
	end,
})

Player:AddKeybind({
	Name = "Quick Action Key", Description = "Click then press any key (Backspace = clear)", Default = Enum.KeyCode.F, Mode = "Press",
	Callback = function() Library:Notify({ Title = "Keybind", Content = "You pressed the key!", Duration = 2 }) end,
})

Player:AddButton({
	Name = "Reset Character", Description = "Button with ripple effect",
	Callback = function()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = 0 end
	end,
})

local Pick = Main:CreateSection("Pickers")

-- รายชื่อผู้เล่น (ค้นหาได้) + อัปเดตอัตโนมัติ
local function playerNames()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do table.insert(t, p.Name) end
	return t
end
local PlayerDrop = Pick:AddDropdown({
	Name = "Select Player", Description = "Searchable list", Options = playerNames(), Default = LocalPlayer.Name,
	Callback = function(name) print("Selected player:", name) end,
})
Players.PlayerAdded:Connect(function() PlayerDrop:Refresh(playerNames(), true) end)
Players.PlayerRemoving:Connect(function() task.defer(function() PlayerDrop:Refresh(playerNames(), true) end) end)

Pick:AddDropdown({
	Name = "Multi Select", Multi = true, Options = { "Apple", "Banana", "Cherry", "Durian", "Mango", "Lychee", "Papaya", "Guava" }, Default = { "Mango" },
	Callback = function(list) print("Selected:", table.concat(list, ", ")) end,
})

Pick:AddTextbox({
	Name = "Custom Message", Placeholder = "Type something...", Default = "",
	Callback = function(text) Library:Notify({ Title = "Textbox", Content = "You typed: " .. text, Duration = 3 }) end,
})

Pick:AddColorPicker({
	Name = "ESP Color", Default = Color3.fromRGB(255, 80, 120),
	Callback = function(c) print("Color:", c) end,
})

----- Tab: About -----
local About = Window:CreateTab({ Name = "About", Icon = "user" })
local Info = About:CreateSection("NOVA UI")
Info:AddLabel("Wind-UI inspired library. Drag the top bar to move the window.")
Info:AddLabel("Red = close | Yellow = minimize | Green = zoom (slightly larger).")
Info:AddButton({ Name = "Show all notification types", Callback = function()
	Library:Notify({ Title = "Info", Content = "Default accent notification.", Duration = 3 })
	Library:Notify({ Title = "Success", Content = "Everything worked.", Type = "Success", Duration = 3.5 })
	Library:Notify({ Title = "Warning", Content = "Be careful with this.", Type = "Warning", Duration = 4 })
	Library:Notify({ Title = "Error", Content = "Something went wrong.", Type = "Error", Duration = 4.5 })
end })

----- Tab: Settings (themes + live preview + custom RGB + window options) -----
Window:CreateSettingsTab()

Library:Notify({ Title = "NOVA UI", Content = "Loaded. Press RightShift to hide / show.", Type = "Success", Duration = 4 })

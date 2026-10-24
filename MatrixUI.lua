--[[
	MatrixUI  -  Roblox UI Library (Lua / Luau)
	------------------------------------------------------------------
	วิธีใช้แบบเร็ว:
	  1) วางไฟล์นี้ทั้งไฟล์ใน LocalScript (เช่น StarterPlayer > StarterPlayerScripts)
	     แล้วกด Play ตัวอย่างท้ายไฟล์จะรันทันที
	  2) หรือวางเป็น ModuleScript ชื่อ "MatrixUI" ใน ReplicatedStorage
	     แล้วตั้ง RUN_EXAMPLE = false ด้านล่าง จากนั้นเรียก
	         local Library = require(game.ReplicatedStorage.MatrixUI)

	สิ่งที่มีในไลบรารี:
	  Window (ลากได้ / ย่อ / ปิด / คีย์เปิดปิด) | Tab + Icon + Indicator
	  Section (Card) | Label | Button | Toggle | Slider | Dropdown
	  Textbox | Keybind | ColorPicker | Color Preview | Notify
	  Settings tab สำเร็จรูป (Dark / Modern Navy / Neon / Custom RGB)

	หมายเหตุ: ไม่ใช้ตัวอักษรพิเศษในปุ่มใดๆ ปุ่ม X, ย่อ, ลูกศร วาดด้วย Frame ทั้งหมด
]]

local RUN_EXAMPLE = true -- ตั้งเป็น false ถ้านำไปใช้เป็น ModuleScript

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local GUI_NAME = "MatrixUILibrary"
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Library = {
	Flags = {},
	ToggleKey = Enum.KeyCode.RightShift,
	SpinEnabled = true,
	SpinSpeed = 80,
	Transparency = 0,
}

----------------------------------------------------------------
-- ธีม
----------------------------------------------------------------
Library.Themes = {
	["Dark"] = {
		Background = rgb(18, 18, 22), Sidebar = rgb(24, 24, 30), Element = rgb(33, 33, 42), Stroke = rgb(55, 55, 68),
		Text = rgb(240, 243, 250), SubText = rgb(150, 158, 175), Accent = rgb(138, 92, 246), Accent2 = rgb(0, 200, 255),
	},
	["Modern Navy"] = {
		Background = rgb(12, 20, 38), Sidebar = rgb(16, 27, 50), Element = rgb(23, 38, 66), Stroke = rgb(42, 64, 104),
		Text = rgb(235, 242, 255), SubText = rgb(140, 160, 195), Accent = rgb(56, 160, 255), Accent2 = rgb(99, 102, 241),
	},
	["Neon"] = {
		Background = rgb(8, 8, 14), Sidebar = rgb(12, 12, 20), Element = rgb(20, 20, 33), Stroke = rgb(46, 46, 72),
		Text = rgb(240, 255, 250), SubText = rgb(140, 170, 165), Accent = rgb(0, 255, 170), Accent2 = rgb(255, 0, 200),
	},
}
Library.ThemeOrder = { "Dark", "Modern Navy", "Neon", "Custom RGB" }
Library.ThemeName = "Dark"

local Theme = {}
local bindings, rings, bars, listeners, conns = {}, {}, {}, {}, {}

local function lum(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function derive(bg)
	local light = lum(bg) > 0.55
	local t = light and BLACK or WHITE
	return {
		Background = bg,
		Sidebar = bg:Lerp(t, 0.06),
		Element = bg:Lerp(t, 0.11),
		Stroke = bg:Lerp(t, 0.24),
		Text = light and rgb(25, 35, 55) or rgb(240, 243, 250),
		SubText = light and rgb(95, 110, 135) or rgb(150, 158, 175),
	}
end

----------------------------------------------------------------
-- ตัวช่วย
----------------------------------------------------------------
local function create(class, props)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	inst.Parent = parent
	return inst
end

local function corner(inst, r)
	return create("UICorner", { CornerRadius = UDim.new(0, r), Parent = inst })
end

local function tween(inst, props, t)
	local tw = TweenService:Create(inst, TweenInfo.new(t or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function safe(fn, ...)
	if type(fn) == "function" then
		local ok, err = pcall(fn, ...)
		if not ok then warn("[MatrixUI] " .. tostring(err)) end
	end
end

local function track(conn)
	conns[#conns + 1] = conn
	return conn
end

local function bind(inst, prop, key)
	bindings[#bindings + 1] = { inst, prop, key }
	inst[prop] = Theme[key]
	return inst
end

local function applyBindings(animate)
	for i = #bindings, 1, -1 do
		local b = bindings[i]
		if not b[1]:IsDescendantOf(game) then
			table.remove(bindings, i)
		elseif animate then
			tween(b[1], { [b[2]] = Theme[b[3]] }, 0.25)
		else
			b[1][b[2]] = Theme[b[3]]
		end
	end
end

local function ringSequence()
	local base, a, b = Theme.Stroke, Theme.Accent, Theme.Accent2
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(0.15, a),
		ColorSequenceKeypoint.new(0.3, b),
		ColorSequenceKeypoint.new(0.5, base),
		ColorSequenceKeypoint.new(0.65, a),
		ColorSequenceKeypoint.new(0.8, b),
		ColorSequenceKeypoint.new(1, base),
	})
end

local function refreshGradients()
	local ring = ringSequence()
	for _, g in ipairs(rings) do
		if g.Parent then g.Color = ring end
	end
	local bar = ColorSequence.new(Theme.Accent, Theme.Accent2)
	for _, g in ipairs(bars) do
		if g.Parent then g.Color = bar end
	end
end

local function fire(source)
	for _, fn in ipairs(listeners) do
		pcall(fn, source)
	end
end

local function commit(instant, source)
	Theme.OnAccent = lum(Theme.Accent) > 0.6 and rgb(20, 24, 32) or WHITE
	applyBindings(not instant)
	refreshGradients()
	fire(source)
end

local function text(parent, props, key)
	props.BackgroundTransparency = 1
	props.Parent = parent
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextSize = props.TextSize or 13
	local l = create("TextLabel", props)
	bind(l, "TextColor3", key or "Text")
	return l
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function dragInput(handle, fn, scroller)
	local dragging = false
	track(handle.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			if scroller then scroller.ScrollingEnabled = false end
			fn(input.Position)
		end
	end))
	track(UIS.InputChanged:Connect(function(input)
		if dragging and isMove(input) then fn(input.Position) end
	end))
	track(UIS.InputEnded:Connect(function(input)
		if dragging and isPress(input) then
			dragging = false
			if scroller then scroller.ScrollingEnabled = true end
		end
	end))
end

local function makeDraggable(handle, target)
	local state = { moved = false }
	local dragging, dragStart, startPos = false, nil, nil
	track(handle.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging, state.moved = true, false
			dragStart, startPos = input.Position, target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end))
	track(UIS.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local d = input.Position - dragStart
			if math.abs(d.X) + math.abs(d.Y) > 4 then state.moved = true end
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	return state
end

local function getGuiParent()
	local ok, ui = pcall(function() return gethui and gethui() end)
	if ok and typeof(ui) == "Instance" then return ui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function rgbText(c)
	return string.format("%d, %d, %d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function parseColor(s)
	s = s:gsub("%s", "")
	local h = s:match("^#?(%x%x%x%x%x%x)$")
	if h then
		return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
	end
	local r, g, b = s:match("^(%d+),(%d+),(%d+)$")
	if r then
		return Color3.fromRGB(math.clamp(tonumber(r), 0, 255), math.clamp(tonumber(g), 0, 255), math.clamp(tonumber(b), 0, 255))
	end
	return nil
end

-- เริ่มต้นด้วยธีม Dark
for k, v in pairs(Library.Themes["Dark"]) do Theme[k] = v end
Theme.OnAccent = WHITE

----------------------------------------------------------------
-- ฟอนต์ Dot-matrix 5x7 (ใช้วาดโลโก้ด้วยจุดเล็กๆ)
----------------------------------------------------------------
local GLYPH_SRC = {
	A = "01110/10001/10001/11111/10001/10001/10001", B = "11110/10001/10001/11110/10001/10001/11110",
	C = "01110/10001/10000/10000/10000/10001/01110", D = "11110/10001/10001/10001/10001/10001/11110",
	E = "11111/10000/10000/11110/10000/10000/11111", F = "11111/10000/10000/11110/10000/10000/10000",
	G = "01110/10001/10000/10111/10001/10001/01111", H = "10001/10001/10001/11111/10001/10001/10001",
	I = "01110/00100/00100/00100/00100/00100/01110", J = "00111/00010/00010/00010/00010/10010/01100",
	K = "10001/10010/10100/11000/10100/10010/10001", L = "10000/10000/10000/10000/10000/10000/11111",
	M = "10001/11011/10101/10101/10001/10001/10001", N = "10001/11001/10101/10011/10001/10001/10001",
	O = "01110/10001/10001/10001/10001/10001/01110", P = "11110/10001/10001/11110/10000/10000/10000",
	Q = "01110/10001/10001/10001/10101/10010/01101", R = "11110/10001/10001/11110/10100/10010/10001",
	S = "01111/10000/10000/01110/00001/00001/11110", T = "11111/00100/00100/00100/00100/00100/00100",
	U = "10001/10001/10001/10001/10001/10001/01110", V = "10001/10001/10001/10001/10001/01010/00100",
	W = "10001/10001/10001/10101/10101/11011/10001", X = "10001/10001/01010/00100/01010/10001/10001",
	Y = "10001/10001/01010/00100/00100/00100/00100", Z = "11111/00001/00010/00100/01000/10000/11111",
	["0"] = "01110/10001/10011/10101/11001/10001/01110", ["1"] = "00100/01100/00100/00100/00100/00100/01110",
	["2"] = "01110/10001/00001/00010/00100/01000/11111", ["3"] = "11110/00001/00001/01110/00001/00001/11110",
	["4"] = "00010/00110/01010/10010/11111/00010/00010", ["5"] = "11111/10000/11110/00001/00001/10001/01110",
	["6"] = "00110/01000/10000/11110/10001/10001/01110", ["7"] = "11111/00001/00010/00100/01000/01000/01000",
	["8"] = "01110/10001/10001/01110/10001/10001/01110", ["9"] = "01110/10001/10001/01111/00001/00010/01100",
	["-"] = "00000/00000/00000/11111/00000/00000/00000", ["."] = "00000/00000/00000/00000/00000/01100/01100",
}
local GLYPHS = {}
for ch, src in pairs(GLYPH_SRC) do GLYPHS[ch] = string.split(src, "/") end

local function dotText(parent, str, pitch, position)
	str = string.upper(str)
	local dot = math.max(pitch - 1, 1)
	local holder = create("Frame", {
		BackgroundTransparency = 1, Position = position,
		Size = UDim2.fromOffset(#str * 6 * pitch, 7 * pitch), Parent = parent,
	})
	for i = 1, #str do
		local g = GLYPHS[str:sub(i, i)]
		if g then
			for row = 1, 7 do
				for col = 1, 5 do
					local lit = g[row]:sub(col, col) == "1"
					local d = create("Frame", {
						Size = UDim2.fromOffset(dot, dot), BorderSizePixel = 0,
						Position = UDim2.fromOffset(((i - 1) * 6 + col - 1) * pitch, (row - 1) * pitch),
						BackgroundTransparency = lit and 0 or 0.65, Parent = holder,
					})
					corner(d, dot / 2)
					bind(d, "BackgroundColor3", lit and "Accent" or "Stroke")
				end
			end
		end
	end
	return holder
end

----------------------------------------------------------------
-- API ธีม
----------------------------------------------------------------
function Library:SetTheme(name)
	if name == "Custom RGB" then
		Library.ThemeName = name
		fire("theme")
		return true
	end
	local p = Library.Themes[name]
	if not p then return false end
	Library.ThemeName = name
	for k, v in pairs(p) do Theme[k] = v end
	commit(false, "theme")
	return true
end

-- key: "Background" | "Accent" | "Accent2" | "Text" | "SubText" ...
function Library:SetColor(key, color)
	Library.ThemeName = "Custom RGB"
	if key == "Background" then
		for k, v in pairs(derive(color)) do Theme[k] = v end
	else
		Theme[key] = color
	end
	commit(true, key)
end

function Library:GetTheme()
	return Theme
end

----------------------------------------------------------------
-- Notification
----------------------------------------------------------------
local notifyOrder = 0
function Library:Notify(o)
	local holder = Library.NotifyHolder
	if not holder then return end
	o = o or {}
	local dur = o.Duration or 4
	notifyOrder = notifyOrder + 1
	local n = create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 62), BorderSizePixel = 0, GroupTransparency = 1,
		LayoutOrder = notifyOrder, Parent = holder,
	})
	bind(n, "BackgroundColor3", "Background")
	corner(n, 10)
	local st = create("UIStroke", { Thickness = 1.6, Parent = n })
	bind(st, "Color", "Accent")
	text(n, { Text = o.Title or "Notification", Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -24, 0, 18) }, "Text")
	text(n, { Text = o.Text or "", TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -24, 0, 30) }, "SubText")
	local prog = create("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), BorderSizePixel = 0, Parent = n })
	bind(prog, "BackgroundColor3", "Accent")
	tween(n, { GroupTransparency = 0 }, 0.25)
	tween(prog, { Size = UDim2.new(0, 0, 0, 3) }, dur)
	task.delay(dur, function()
		if n.Parent then
			tween(n, { GroupTransparency = 1 }, 0.3)
			task.wait(0.32)
			n:Destroy()
		end
	end)
end

function Library:Destroy()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
	table.clear(bindings)
	table.clear(rings)
	table.clear(bars)
	table.clear(listeners)
	if Library.Gui then Library.Gui:Destroy() end
	Library.Gui, Library.NotifyHolder, Library.Window = nil, nil, nil
end

----------------------------------------------------------------
-- Section (การ์ด) และองค์ประกอบ
----------------------------------------------------------------
local Section = {}
Section.__index = Section

local function row(sec, h)
	sec._n = sec._n + 1
	local f = create("Frame", { Size = UDim2.new(1, 0, 0, h), BorderSizePixel = 0, LayoutOrder = sec._n, Parent = sec.Card })
	bind(f, "BackgroundColor3", "Element")
	corner(f, 7)
	return f
end

local function rowHeight(o)
	return o.Description and 48 or 36
end

local function title(f, o, rightPad)
	local d = o.Description ~= nil
	local n = text(f, {
		Text = o.Name or "Element", Font = Enum.Font.GothamBold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 12, 0, d and 6 or 0), Size = UDim2.new(1, -(rightPad + 12), 0, d and 18 or 36),
	}, "Text")
	if d then
		text(f, {
			Text = o.Description, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 12, 0, 25), Size = UDim2.new(1, -(rightPad + 12), 0, 16),
		}, "SubText")
	end
	return n
end

function Section:AddLabel(str)
	self._n = self._n + 1
	local l = text(self.Card, {
		Text = str, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = self._n,
	}, "SubText")
	local obj = {}
	function obj:Set(t) l.Text = t end
	return obj
end

function Section:AddButton(o)
	local f = row(self, rowHeight(o))
	local nameLbl = title(f, o, 30)
	local tag = create("Frame", { Size = UDim2.fromOffset(3, 16), Position = UDim2.new(1, -14, 0.5, -8), BorderSizePixel = 0, Parent = f })
	bind(tag, "BackgroundColor3", "Accent")
	corner(tag, 2)
	local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = f })
	bind(flash, "BackgroundColor3", "Accent")
	corner(flash, 7)
	local b = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f })
	b.MouseEnter:Connect(function() tween(flash, { BackgroundTransparency = 0.88 }, 0.15) end)
	b.MouseLeave:Connect(function() tween(flash, { BackgroundTransparency = 1 }, 0.15) end)
	b.MouseButton1Click:Connect(function()
		flash.BackgroundTransparency = 0.6
		tween(flash, { BackgroundTransparency = 0.88 }, 0.3)
		safe(o.Callback)
	end)
	local obj = {}
	function obj:SetText(t) nameLbl.Text = t end
	return obj
end

function Section:AddToggle(o)
	local state = o.Default == true
	local f = row(self, rowHeight(o))
	title(f, o, 60)
	local trackF = create("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10), BorderSizePixel = 0, Parent = f })
	bind(trackF, "BackgroundColor3", "Stroke")
	corner(trackF, 10)
	local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = state and 0 or 1, BorderSizePixel = 0, Parent = trackF })
	bind(fill, "BackgroundColor3", "Accent")
	corner(fill, 10)
	local knob = create("Frame", { Size = UDim2.fromOffset(14, 14), Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = trackF })
	corner(knob, 7)
	local hit = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f })
	if o.Flag then Library.Flags[o.Flag] = state end
	local obj = {}
	function obj:Set(v, silent)
		state = v and true or false
		tween(fill, { BackgroundTransparency = state and 0 or 1 }, 0.18)
		tween(knob, { Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) }, 0.18)
		if o.Flag then Library.Flags[o.Flag] = state end
		if not silent then safe(o.Callback, state) end
	end
	function obj:Get() return state end
	hit.MouseButton1Click:Connect(function() obj:Set(not state) end)
	return obj
end

function Section:AddSlider(o)
	local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
	local value = math.clamp(o.Default or min, min, max)
	local f = row(self, 54)
	text(f, { Text = o.Name or "Slider", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(0.6, 0, 0, 18) }, "Text")
	local vl = text(f, { TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.6, 0, 0, 6), Size = UDim2.new(0.4, -12, 0, 18) }, "Accent")
	local bar = create("Frame", { Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 6), BorderSizePixel = 0, Parent = f })
	bind(bar, "BackgroundColor3", "Stroke")
	corner(bar, 3)
	local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, Parent = bar })
	bind(fill, "BackgroundColor3", "Accent")
	corner(fill, 3)
	local knob = create("Frame", { Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = bar })
	corner(knob, 7)
	local ks = create("UIStroke", { Thickness = 2, Parent = knob })
	bind(ks, "Color", "Accent")
	local hit = create("TextButton", { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", Parent = f })
	local obj = {}
	local function setValue(x, silent)
		x = math.clamp(math.floor((x - min) / inc + 0.5) * inc + min, min, max)
		x = tonumber(string.format("%.4f", x))
		value = x
		local a = (max == min) and 0 or (x - min) / (max - min)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, -7, 0.5, -7)
		vl.Text = tostring(x) .. (o.Suffix or "")
		if o.Flag then Library.Flags[o.Flag] = x end
		if not silent then safe(o.Callback, x) end
	end
	function obj:Set(x, silent) setValue(x, silent) end
	function obj:Get() return value end
	setValue(value, true)
	dragInput(hit, function(pos)
		local a = math.clamp((pos.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		setValue(min + (max - min) * a)
	end, self.Page)
	return obj
end

function Section:AddDropdown(o)
	local options = o.Options or {}
	local current = o.Default
	local open = false
	local f = row(self, 36)
	f.ClipsDescendants = true
	local head = create("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "", Parent = f })
	text(head, { Text = o.Name or "Dropdown", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.5, -12, 1, 0) }, "Text")
	local val = text(head, { Text = current ~= nil and tostring(current) or "Select...", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -32, 1, 0) }, "Accent")
	local mark = create("Frame", { Size = UDim2.fromOffset(7, 7), Position = UDim2.new(1, -20, 0.5, -3), Rotation = 45, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = head })
	bind(mark, "BackgroundColor3", "Accent")
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -16, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = f,
	})
	bind(list, "ScrollBarImageColor3", "Accent")
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local entries = {}
	local function listHeight()
		local n = math.min(#options, 5)
		return n * 26 + math.max(n - 1, 0) * 4
	end
	local function resize()
		tween(f, { Size = UDim2.new(1, 0, 0, open and (42 + listHeight() + 8) or 36) }, 0.2)
		tween(list, { Size = UDim2.new(1, -16, 0, listHeight()) }, 0.2)
		tween(mark, { BackgroundTransparency = open and 0 or 0.5 }, 0.2)
	end
	local function paint()
		for _, e in ipairs(entries) do
			e.btn.TextColor3 = (e.opt == current) and Theme.Accent or Theme.Text
		end
	end
	listeners[#listeners + 1] = paint
	local obj = {}
	local function choose(opt, silent)
		current = opt
		val.Text = tostring(opt)
		paint()
		open = false
		resize()
		if o.Flag then Library.Flags[o.Flag] = opt end
		if not silent then safe(o.Callback, opt) end
	end
	local function rebuild()
		for _, e in ipairs(entries) do e.btn:Destroy() end
		table.clear(entries)
		for i, opt in ipairs(options) do
			local b = create("TextButton", {
				Size = UDim2.new(1, -6, 0, 26), BorderSizePixel = 0, Text = tostring(opt), Font = Enum.Font.GothamMedium,
				TextSize = 12, AutoButtonColor = false, LayoutOrder = i, Parent = list,
			})
			bind(b, "BackgroundColor3", "Background")
			corner(b, 5)
			b.MouseButton1Click:Connect(function() choose(opt) end)
			entries[#entries + 1] = { opt = opt, btn = b }
		end
		paint()
	end
	rebuild()
	head.MouseButton1Click:Connect(function()
		open = not open
		resize()
	end)
	function obj:Set(v, silent) choose(v, silent) end
	function obj:Get() return current end
	function obj:Refresh(newOptions, keep)
		options = newOptions or {}
		if not keep then current = nil val.Text = "Select..." end
		rebuild()
		if open then resize() end
	end
	if o.Flag and current ~= nil then Library.Flags[o.Flag] = current end
	return obj
end

function Section:AddTextbox(o)
	local f = row(self, rowHeight(o))
	title(f, o, 176)
	local box = create("TextBox", {
		Size = UDim2.fromOffset(160, 26), Position = UDim2.new(1, -172, 0.5, -13), BorderSizePixel = 0,
		Text = o.Default or "", PlaceholderText = o.Placeholder or "Type here...", ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium, TextSize = 12, Parent = f,
	})
	bind(box, "BackgroundColor3", "Background")
	bind(box, "TextColor3", "Text")
	bind(box, "PlaceholderColor3", "SubText")
	corner(box, 5)
	local st = create("UIStroke", { Thickness = 1, Parent = box })
	bind(st, "Color", "Stroke")
	box.FocusLost:Connect(function(enter)
		if o.Flag then Library.Flags[o.Flag] = box.Text end
		safe(o.Callback, box.Text, enter)
	end)
	local obj = {}
	function obj:Set(t) box.Text = t end
	function obj:Get() return box.Text end
	return obj
end

function Section:AddKeybind(o)
	local key = o.Default or Enum.KeyCode.F
	local listening = false
	local f = row(self, rowHeight(o))
	title(f, o, 110)
	local btn = create("TextButton", {
		Size = UDim2.fromOffset(90, 24), Position = UDim2.new(1, -102, 0.5, -12), BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextSize = 12, Text = key.Name, AutoButtonColor = false, Parent = f,
	})
	bind(btn, "BackgroundColor3", "Background")
	bind(btn, "TextColor3", "Accent")
	corner(btn, 5)
	local st = create("UIStroke", { Thickness = 1, Parent = btn })
	bind(st, "Color", "Stroke")
	btn.MouseButton1Click:Connect(function()
		listening = true
		btn.Text = "..."
	end)
	track(UIS.InputBegan:Connect(function(input, gp)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				if input.KeyCode ~= Enum.KeyCode.Escape then
					key = input.KeyCode
					if o.Flag then Library.Flags[o.Flag] = key end
					safe(o.Changed, key)
				end
				btn.Text = key.Name
			end
		elseif not gp and input.KeyCode == key then
			safe(o.Callback, key)
		end
	end))
	if o.Flag then Library.Flags[o.Flag] = key end
	local obj = {}
	function obj:Get() return key end
	function obj:Set(k) key = k btn.Text = k.Name end
	return obj
end

function Section:AddColorPicker(o)
	local color = o.Default or rgb(0, 170, 255)
	local h, s, v = color:ToHSV()
	local open = false
	local f = row(self, 36)
	f.ClipsDescendants = true
	local head = create("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "", Parent = f })
	text(head, { Text = o.Name or "Color", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -170, 1, 0) }, "Text")
	local info = text(head, { TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -158, 0, 0), Size = UDim2.fromOffset(100, 36) }, "SubText")
	local swatch = create("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10), BorderSizePixel = 0, Parent = head })
	corner(swatch, 5)
	local sst = create("UIStroke", { Thickness = 1.5, Parent = swatch })
	bind(sst, "Color", "Stroke")

	local sv = create("Frame", { Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -52, 0, 110), BorderSizePixel = 0, Parent = f })
	corner(sv, 4)
	local whiteF = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = sv })
	corner(whiteF, 4)
	create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = whiteF })
	local blackF = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = sv })
	corner(blackF, 4)
	create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackF })
	local cursor = create("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = sv })
	corner(cursor, 5)
	create("UIStroke", { Thickness = 2, Color = WHITE, Parent = cursor })

	local hueBar = create("Frame", { Position = UDim2.new(1, -32, 0, 44), Size = UDim2.fromOffset(22, 110), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = f })
	corner(hueBar, 4)
	local kps = {}
	for i = 0, 6 do
		kps[#kps + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i % 6) / 6, 1, 1))
	end
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(kps), Parent = hueBar })
	local hueMark = create("Frame", { Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = hueBar })
	create("UIStroke", { Thickness = 1, Color = BLACK, Parent = hueMark })

	local obj = {}
	local function update(silent)
		color = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		swatch.BackgroundColor3 = color
		cursor.Position = UDim2.new(s, -5, 1 - v, -5)
		hueMark.Position = UDim2.new(0, -2, h, -2)
		info.Text = hex(color) .. "  " .. rgbText(color)
		if o.Flag then Library.Flags[o.Flag] = color end
		if not silent then safe(o.Callback, color) end
	end
	function obj:Set(c, silent)
		h, s, v = c:ToHSV()
		update(silent)
	end
	function obj:Get() return color end
	update(true)
	dragInput(sv, function(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		update()
	end, self.Page)
	dragInput(hueBar, function(pos)
		h = math.clamp((pos.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 0.999)
		update()
	end, self.Page)
	head.MouseButton1Click:Connect(function()
		open = not open
		tween(f, { Size = UDim2.new(1, 0, 0, open and 164 or 36) }, 0.22)
	end)
	return obj
end

-- กล่องพรีวิวสี: หน้าต่างจำลอง + ชิปสีพร้อมรหัส Hex แบบเรียลไทม์
function Section:AddColorPreview()
	local f = row(self, 132)
	local scene = create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 72), BorderSizePixel = 0, ClipsDescendants = true, Parent = f })
	bind(scene, "BackgroundColor3", "Background")
	corner(scene, 8)
	local st = create("UIStroke", { Thickness = 2, Color = WHITE, Parent = scene })
	rings[#rings + 1] = create("UIGradient", { Color = ringSequence(), Parent = st })
	local sb = create("Frame", { Size = UDim2.new(0, 56, 1, 0), BorderSizePixel = 0, Parent = scene })
	bind(sb, "BackgroundColor3", "Sidebar")
	for i = 1, 3 do
		local r = create("Frame", { Position = UDim2.fromOffset(6, 8 + (i - 1) * 20), Size = UDim2.new(1, -12, 0, 14), BorderSizePixel = 0, Parent = sb })
		bind(r, "BackgroundColor3", i == 1 and "Accent" or "Element")
		corner(r, 4)
	end
	text(scene, { Text = "Preview", Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(68, 6), Size = UDim2.fromOffset(120, 16) }, "Text")
	local line = create("Frame", { Position = UDim2.fromOffset(56, 28), Size = UDim2.new(1, -56, 0, 2), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = scene })
	bars[#bars + 1] = create("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Parent = line })
	local btn = create("Frame", { Position = UDim2.fromOffset(68, 40), Size = UDim2.fromOffset(80, 22), BorderSizePixel = 0, Parent = scene })
	bind(btn, "BackgroundColor3", "Accent")
	corner(btn, 5)
	text(btn, { Text = "Button", Font = Enum.Font.GothamBold, TextSize = 11, Size = UDim2.fromScale(1, 1) }, "OnAccent")
	local tg = create("Frame", { Position = UDim2.fromOffset(160, 41), Size = UDim2.fromOffset(34, 18), BorderSizePixel = 0, Parent = scene })
	bind(tg, "BackgroundColor3", "Accent")
	corner(tg, 9)
	local kn = create("Frame", { Position = UDim2.fromOffset(18, 3), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = tg })
	corner(kn, 6)

	local chipRow = create("Frame", { Position = UDim2.fromOffset(8, 88), Size = UDim2.new(1, -16, 0, 36), BackgroundTransparency = 1, Parent = f })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chipRow })
	local chips = {}
	for i, k in ipairs({ "Background", "Accent", "Accent2" }) do
		local chip = create("Frame", { Size = UDim2.new(1 / 3, -4, 1, 0), BorderSizePixel = 0, LayoutOrder = i, Parent = chipRow })
		bind(chip, "BackgroundColor3", k)
		corner(chip, 6)
		local cs = create("UIStroke", { Thickness = 1, Parent = chip })
		bind(cs, "Color", "Stroke")
		local lbl = create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 11, Parent = chip })
		chips[#chips + 1] = { key = k, label = lbl }
	end
	local function refresh()
		for _, c in ipairs(chips) do
			local col = Theme[c.key]
			c.label.Text = c.key .. "\n" .. hex(col)
			c.label.TextColor3 = lum(col) > 0.6 and rgb(20, 24, 32) or WHITE
		end
	end
	refresh()
	listeners[#listeners + 1] = refresh
end

----------------------------------------------------------------
-- Tab
----------------------------------------------------------------
local TabMeta = {}
TabMeta.__index = TabMeta

function TabMeta:AddSection(name)
	self._n = self._n + 1
	local card = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = self._n, Parent = self.Page })
	bind(card, "BackgroundColor3", "Sidebar")
	corner(card, 10)
	local st = create("UIStroke", { Thickness = 1.5, Transparency = 0.45, Parent = card })
	bind(st, "Color", "Accent")
	create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = card })
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	local head = create("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 0, Parent = card })
	local bar = create("Frame", { Size = UDim2.fromOffset(3, 14), Position = UDim2.new(0, 0, 0.5, -7), BorderSizePixel = 0, Parent = head })
	bind(bar, "BackgroundColor3", "Accent")
	corner(bar, 2)
	text(head, { Text = name or "Section", Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 1, 0) }, "Text")
	return setmetatable({ Card = card, Page = self.Page, _n = 0 }, Section)
end

----------------------------------------------------------------
-- Window
----------------------------------------------------------------
function Library:CreateWindow(cfg)
	cfg = cfg or {}
	Library:Destroy()
	local parent = getGuiParent()
	local old = parent:FindFirstChild(GUI_NAME)
	if old then old:Destroy() end
	if cfg.Theme then Library:SetTheme(cfg.Theme) end
	if cfg.ToggleKey then Library.ToggleKey = cfg.ToggleKey end

	local Window = { Tabs = {} }
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local W = math.min(cfg.Size and cfg.Size.X or 660, vp.X - 20)
	local H = math.min(cfg.Size and cfg.Size.Y or 440, vp.Y - 20)
	local sideW = W < 540 and 140 or 190
	local HEAD_H = 54

	local gui = create("ScreenGui", { Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Parent = parent })
	Library.Gui, Library.Window = gui, Window
	Window.Gui = gui

	local main = create("Frame", {
		Name = "Main", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
		BorderSizePixel = 0, Active = true, ClipsDescendants = true, Parent = gui,
	})
	bind(main, "BackgroundColor3", "Background")
	corner(main, 12)
	local ring = create("UIStroke", { Thickness = 2.5, Color = WHITE, Parent = main })
	rings[#rings + 1] = create("UIGradient", { Color = ringSequence(), Parent = ring })

	-- Sidebar
	local side = create("Frame", { Name = "Sidebar", Size = UDim2.new(0, sideW, 1, 0), BorderSizePixel = 0, Parent = main })
	bind(side, "BackgroundColor3", "Sidebar")
	corner(side, 12)
	local sideFill = create("Frame", { Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0), BorderSizePixel = 0, Parent = side })
	bind(sideFill, "BackgroundColor3", "Sidebar")
	local sideLine = create("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0, Parent = side })
	bind(sideLine, "BackgroundColor3", "Stroke")

	-- โลโก้ Dot-matrix (ซ้ายบนสุด)
	local logoText = cfg.Logo or "MATRIX"
	local pitch = math.clamp(math.floor((sideW - 28) / (#logoText * 6)), 2, 4)
	local logoF = create("Frame", { Size = UDim2.new(1, 0, 0, HEAD_H + 8), BackgroundTransparency = 1, Parent = side })
	dotText(logoF, logoText, pitch, UDim2.fromOffset(14, math.floor((HEAD_H + 8 - 7 * pitch) / 2)))
	local logoLine = create("Frame", { Size = UDim2.new(1, -24, 0, 2), Position = UDim2.fromOffset(12, HEAD_H + 8), BorderSizePixel = 0, Parent = side })
	bind(logoLine, "BackgroundColor3", "Stroke")

	local tabList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, HEAD_H + 16), Size = UDim2.new(1, 0, 1, -(HEAD_H + 76)), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = side,
	})
	bind(tabList, "ScrollBarImageColor3", "Accent")
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = tabList })

	-- โปรไฟล์ผู้เล่น (ล่างซ้าย)
	local pf = create("Frame", { Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58), BorderSizePixel = 0, Parent = side })
	bind(pf, "BackgroundColor3", "Element")
	corner(pf, 8)
	local pfs = create("UIStroke", { Thickness = 1.5, Color = WHITE, Parent = pf })
	rings[#rings + 1] = create("UIGradient", { Color = ringSequence(), Parent = pfs })
	local avatar = create("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 8, 0.5, -17), BackgroundTransparency = 1, Parent = pf })
	corner(avatar, 17)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and avatar.Parent then avatar.Image = img end
	end)
	text(pf, { Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(48, 8), Size = UDim2.new(1, -54, 0, 16) }, "Text")
	text(pf, { Text = "@" .. LocalPlayer.Name, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(48, 26), Size = UDim2.new(1, -54, 0, 14) }, "SubText")

	-- Header
	local header = create("Frame", { Position = UDim2.fromOffset(sideW, 0), Size = UDim2.new(1, -sideW, 0, HEAD_H), BackgroundTransparency = 1, Parent = main })
	local headTitle = text(header, { Text = cfg.Title or "MatrixUI", Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 9), Size = UDim2.new(1, -110, 0, 20) }, "Text")
	local headSub = text(header, { Text = cfg.SubTitle or "", Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -110, 0, 14) }, "SubText")
	local divider = create("Frame", { Position = UDim2.fromOffset(sideW, HEAD_H), Size = UDim2.new(1, -sideW, 0, 2), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = main })
	bars[#bars + 1] = create("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Parent = divider })

	makeDraggable(header, main)
	makeDraggable(logoF, main)

	-- ปุ่มควบคุมหน้าต่างมุมขวาบน (ย่อ / ปิด) วาดด้วย Frame ไม่ใช้ตัวอักษร
	local ctrl = create("Frame", { Size = UDim2.fromOffset(60, 26), Position = UDim2.new(1, -72, 0, 14), BackgroundTransparency = 1, Parent = header })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = ctrl })
	local function ctrlButton(order)
		local b = create("TextButton", { Size = UDim2.fromOffset(26, 26), BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = order, Parent = ctrl })
		bind(b, "BackgroundColor3", "Element")
		corner(b, 7)
		local st = create("UIStroke", { Thickness = 1, Parent = b })
		bind(st, "Color", "Stroke")
		return b
	end
	local function strokeBar(parent, w, rot)
		local l = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, 2), Rotation = rot, BorderSizePixel = 0, Parent = parent })
		bind(l, "BackgroundColor3", "Text")
		corner(l, 1)
		return l
	end
	local minB = ctrlButton(1)
	strokeBar(minB, 10, 0)
	local closeB = ctrlButton(2)
	strokeBar(closeB, 13, 45)
	strokeBar(closeB, 13, -45)
	minB.MouseEnter:Connect(function() tween(minB, { BackgroundColor3 = Theme.Stroke }, 0.15) end)
	minB.MouseLeave:Connect(function() tween(minB, { BackgroundColor3 = Theme.Element }, 0.15) end)
	closeB.MouseEnter:Connect(function() tween(closeB, { BackgroundColor3 = rgb(220, 60, 70) }, 0.15) end)
	closeB.MouseLeave:Connect(function() tween(closeB, { BackgroundColor3 = Theme.Element }, 0.15) end)

	local minimized = false
	minB.MouseButton1Click:Connect(function()
		minimized = not minimized
		tween(main, { Size = UDim2.fromOffset(W, minimized and (HEAD_H + 2) or H) }, 0.25)
	end)
	closeB.MouseButton1Click:Connect(function()
		safe(cfg.OnClose)
		Library:Destroy()
	end)

	local pages = create("Frame", { Position = UDim2.fromOffset(sideW, HEAD_H + 2), Size = UDim2.new(1, -sideW, 1, -(HEAD_H + 2)), BackgroundTransparency = 1, ClipsDescendants = true, Parent = main })

	-- Notification holder (มุมขวาล่าง)
	local nh = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 270, 1, -32), BackgroundTransparency = 1, Parent = gui })
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = nh })
	Library.NotifyHolder = nh

	-- ปุ่มลอยสำหรับมือถือ (เปิด/ปิด UI)
	if cfg.ToggleButton == true or (cfg.ToggleButton == nil and UIS.TouchEnabled and not UIS.KeyboardEnabled) then
		local fb = create("TextButton", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 14, 0.5, -22), BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = gui })
		bind(fb, "BackgroundColor3", "Accent")
		corner(fb, 22)
		for i = 0, 2 do
			local l = create("Frame", { Position = UDim2.fromOffset(12, 14 + i * 7), Size = UDim2.fromOffset(20, 2), BorderSizePixel = 0, Parent = fb })
			bind(l, "BackgroundColor3", "OnAccent")
		end
		local st = makeDraggable(fb, fb)
		fb.MouseButton1Click:Connect(function()
			if not st.moved then main.Visible = not main.Visible end
		end)
	end

	track(UIS.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == Library.ToggleKey then main.Visible = not main.Visible end
	end))

	-- ลูปหลัก: หมุนขอบเรืองแสง
	track(RunService.Heartbeat:Connect(function(dt)
		if Library.SpinEnabled then
			for _, g in ipairs(rings) do
				g.Rotation = (g.Rotation + dt * Library.SpinSpeed) % 360
			end
		end
	end))

	function Window:SetTransparency(x)
		Library.Transparency = x
		main.BackgroundTransparency = x
		side.BackgroundTransparency = x
		sideFill.BackgroundTransparency = x
	end
	function Window:Toggle() main.Visible = not main.Visible end
	function Window:SetToggleKey(k) Library.ToggleKey = k end
	function Window:Notify(o) Library:Notify(o) end
	function Window:Destroy() Library:Destroy() end

	-- Tab
	local function refreshTabs()
		for _, t in ipairs(Window.Tabs) do
			if t.IconImage then
				t.IconImage.ImageColor3 = t.Active and Theme.Accent or Theme.SubText
			end
		end
	end
	listeners[#listeners + 1] = refreshTabs

	local function selectTab(t)
		for _, x in ipairs(Window.Tabs) do
			local on = (x == t)
			x.Active = on
			x.Page.Visible = on
			x.Indicator.Visible = on
			tween(x.Button, { BackgroundTransparency = on and 0 or 0.65 }, 0.15)
		end
		headTitle.Text = t.Name
		headSub.Text = (t.Sub and t.Sub ~= "") and t.Sub or (cfg.SubTitle or "")
		refreshTabs()
	end

	function Window:AddTab(info)
		info = info or {}
		local Tab = setmetatable({ _n = 0, Name = info.Name or "Tab", Sub = info.Sub, Active = false }, TabMeta)
		local idx = #Window.Tabs + 1

		local btn = create("TextButton", { Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0, Text = "", AutoButtonColor = false, BackgroundTransparency = 0.65, LayoutOrder = idx, Parent = tabList })
		bind(btn, "BackgroundColor3", "Element")
		corner(btn, 8)
		local ind = create("Frame", { Size = UDim2.fromOffset(3, 20), Position = UDim2.new(0, 0, 0.5, -10), BorderSizePixel = 0, Visible = false, Parent = btn })
		bind(ind, "BackgroundColor3", "Accent")
		corner(ind, 2)
		if info.Icon then
			Tab.IconImage = create("ImageLabel", { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, 12, 0.5, -10), BackgroundTransparency = 1, Image = info.Icon, Parent = btn })
		else
			Tab.IconImage = create("ImageLabel", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 18, 0.5, -4), BackgroundTransparency = 1, Image = "", Parent = btn })
			Tab.IconImage.BackgroundTransparency = 0
			corner(Tab.IconImage, 4)
			bind(Tab.IconImage, "BackgroundColor3", "Accent")
			Tab.IconImage = nil
		end
		local tx = 42
		text(btn, { Text = Tab.Name, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(tx, 0), Size = UDim2.new(1, -(tx + 6), 1, 0) }, "Text")

		local page = create("ScrollingFrame", {
			Name = Tab.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = pages,
		})
		bind(page, "ScrollBarImageColor3", "Accent")
		create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
		create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14), Parent = page })

		Tab.Button, Tab.Page, Tab.Indicator = btn, page, ind
		Window.Tabs[idx] = Tab
		btn.MouseButton1Click:Connect(function() selectTab(Tab) end)
		if idx == 1 then selectTab(Tab) end
		return Tab
	end

	-- Settings tab สำเร็จรูป
	function Window:AddSettingsTab(info)
		info = info or {}
		local tab = Window:AddTab({ Name = info.Name or "Settings", Sub = info.Sub or "UI customization", Icon = info.Icon })

		local s1 = tab:AddSection("Theme")
		local themeDd = s1:AddDropdown({
			Name = "UI Theme", Options = Library.ThemeOrder, Default = Library.ThemeName,
			Callback = function(v) Library:SetTheme(v) end,
		})

		local s2 = tab:AddSection("Color Preview")
		s2:AddColorPreview()

		local s3 = tab:AddSection("Custom RGB")
		local pickers = {}
		for _, def in ipairs({ { "Background", "Background Color" }, { "Accent", "Accent Color" }, { "Accent2", "Accent 2 Color" } }) do
			local key = def[1]
			pickers[key] = s3:AddColorPicker({ Name = def[2], Default = Theme[key], Callback = function(c) Library:SetColor(key, c) end })
		end
		s3:AddTextbox({
			Name = "Accent (R,G,B or #HEX)", Placeholder = "255,120,0",
			Callback = function(t)
				local c = parseColor(t)
				if c then
					Library:SetColor("Accent", c)
				else
					Library:Notify({ Title = "Invalid color", Text = "Use 255,120,0 or #FF7800" })
				end
			end,
		})
		listeners[#listeners + 1] = function(source)
			themeDd:Set(Library.ThemeName, true)
			for key, p in pairs(pickers) do
				if source ~= key then p:Set(Theme[key], true) end
			end
		end

		local s4 = tab:AddSection("Interface")
		s4:AddSlider({ Name = "Window Transparency", Min = 0, Max = 60, Default = math.floor(Library.Transparency * 100), Suffix = "%", Callback = function(v) Window:SetTransparency(v / 100) end })
		s4:AddToggle({ Name = "Animated Glow Border", Default = Library.SpinEnabled, Callback = function(v) Library.SpinEnabled = v end })
		s4:AddSlider({ Name = "Glow Spin Speed", Min = 10, Max = 300, Increment = 5, Default = Library.SpinSpeed, Callback = function(v) Library.SpinSpeed = v end })
		s4:AddKeybind({ Name = "Toggle UI Key", Default = Library.ToggleKey, Changed = function(k) Library.ToggleKey = k end })
		s4:AddButton({ Name = "Destroy UI", Description = "Close and remove the whole interface", Callback = function() Library:Destroy() end })
		return tab
	end

	Window:SetTransparency(Library.Transparency)
	commit(true, "init")
	return Window
end

----------------------------------------------------------------
-- ตัวอย่างการใช้งาน (ครบทุกองค์ประกอบ)
----------------------------------------------------------------
if RUN_EXAMPLE then
	local Window = Library:CreateWindow({
		Title = "MatrixUI Demo",
		SubTitle = "Roblox UI Library",
		Logo = "MATRIX",                 -- ข้อความโลโก้แบบ Dot-matrix (A-Z, 0-9)
		Theme = "Modern Navy",           -- Dark / Modern Navy / Neon
		ToggleKey = Enum.KeyCode.RightShift,
		-- Size = Vector2.new(660, 440),
	})

	-- Tab 1
	local Main = Window:AddTab({ Name = "Main", Sub = "Player controls" })
	local sPlayer = Main:AddSection("Player")

	sPlayer:AddLabel("ตัวอย่างการปรับค่าตัวละคร")

	sPlayer:AddSlider({
		Name = "WalkSpeed", Min = 16, Max = 100, Default = 16, Flag = "WalkSpeed",
		Callback = function(v)
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = v end
		end,
	})
	sPlayer:AddSlider({
		Name = "JumpPower", Min = 50, Max = 200, Default = 50, Flag = "JumpPower",
		Callback = function(v)
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.UseJumpPower = true
				hum.JumpPower = v
			end
		end,
	})
	sPlayer:AddToggle({ Name = "Toggle Example", Description = "สวิตช์เปิด-ปิด", Default = false, Flag = "DemoToggle", Callback = function(v) print("Toggle:", v) end })
	sPlayer:AddButton({
		Name = "Button Example", Description = "กดเพื่อแสดงแจ้งเตือน",
		Callback = function() Library:Notify({ Title = "Success", Text = "You pressed the button", Duration = 4 }) end,
	})

	local sInput = Main:AddSection("Inputs")
	sInput:AddDropdown({ Name = "Dropdown", Options = { "Option A", "Option B", "Option C" }, Default = "Option A", Flag = "DemoDropdown", Callback = function(v) print("Dropdown:", v) end })
	sInput:AddTextbox({ Name = "Textbox", Placeholder = "Type and press Enter", Callback = function(t, enter) print("Text:", t, enter) end })
	sInput:AddKeybind({ Name = "Keybind", Default = Enum.KeyCode.F, Callback = function(k) print("Pressed:", k.Name) end, Changed = function(k) print("Rebound to:", k.Name) end })
	sInput:AddColorPicker({ Name = "ColorPicker", Default = Color3.fromRGB(255, 120, 0), Flag = "DemoColor", Callback = function(c) print("Color:", c) end })

	-- Tab 2
	local Misc = Window:AddTab({ Name = "Misc", Sub = "Other tools" })
	local sMisc = Misc:AddSection("Notifications")
	sMisc:AddButton({ Name = "Short notification", Callback = function() Library:Notify({ Title = "Info", Text = "Short message", Duration = 2 }) end })
	sMisc:AddButton({ Name = "Long notification", Callback = function() Library:Notify({ Title = "Info", Text = "This one stays on screen longer.", Duration = 8 }) end })
	sMisc:AddButton({ Name = "Print Flags", Callback = function()
		for k, v in pairs(Library.Flags) do print(k, v) end
	end })

	-- Settings (ปรับสี UI แบบเรียลไทม์)
	Window:AddSettingsTab({ Name = "Settings" })

	Library:Notify({ Title = "MatrixUI", Text = "Loaded. Press RightShift to hide or show.", Duration = 5 })
end

return Library

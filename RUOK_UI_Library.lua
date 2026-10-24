--[[
	RUOK UI Library
	ธีมฟ้านม + ขอบเรืองแสงหมุน (สไตล์เดียวกับของคุณ) ครบชุด:
	  Window / Tab / Section / Label / Button / Toggle / Slider / Dropdown
	  Textbox / Keybind / ColorPicker / Notify
	  + หมวด Settings อัตโนมัติ: พรีวิวสดๆ, แกลเลอรีธีมสี, ปรับสีเอง, Rainbow,
	    ความโปร่งใส, ความเร็วขอบหมุน, ปุ่มเปิด/ปิด UI, บันทึก/รีเซ็ตธีม

	ส่วนล่างสุดเป็นตัวอย่างการใช้งาน ลบทิ้งได้
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local NAME = "RUOKUILibrary"
local FILE = "RUOKHub_theme.json"
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)

local Library = {
	Flags = {},
	ToggleKey = Enum.KeyCode.RightShift,
	SpinEnabled = true,
	SpinSpeed = 90,
	Rainbow = false,
	Transparency = 0,
	ThemeName = "Sky Milk",
}

----------------------------------------------------------------
-- ธีมสำเร็จรูป (เพิ่มเองได้: table.insert(Library.Presets, {...}))
----------------------------------------------------------------
local Presets = {
	{ Name = "Sky Milk", Main = Color3.fromRGB(205, 225, 245), Accent = Color3.fromRGB(0, 140, 240), Accent2 = Color3.fromRGB(0, 210, 255) },
	{ Name = "Midnight", Main = Color3.fromRGB(15, 23, 42), Accent = Color3.fromRGB(56, 189, 248), Accent2 = Color3.fromRGB(99, 102, 241) },
	{ Name = "Dark Violet", Main = Color3.fromRGB(28, 30, 38), Accent = Color3.fromRGB(139, 92, 246), Accent2 = Color3.fromRGB(0, 200, 255) },
	{ Name = "Rose", Main = Color3.fromRGB(255, 230, 236), Accent = Color3.fromRGB(244, 63, 94), Accent2 = Color3.fromRGB(251, 146, 60) },
	{ Name = "Mint", Main = Color3.fromRGB(215, 245, 232), Accent = Color3.fromRGB(16, 185, 129), Accent2 = Color3.fromRGB(6, 182, 212) },
	{ Name = "Sunset", Main = Color3.fromRGB(255, 236, 214), Accent = Color3.fromRGB(249, 115, 22), Accent2 = Color3.fromRGB(236, 72, 153) },
	{ Name = "Lavender", Main = Color3.fromRGB(232, 224, 250), Accent = Color3.fromRGB(139, 92, 246), Accent2 = Color3.fromRGB(217, 70, 239) },
	{ Name = "Crimson", Main = Color3.fromRGB(24, 18, 20), Accent = Color3.fromRGB(239, 68, 68), Accent2 = Color3.fromRGB(249, 115, 22) },
	{ Name = "Forest", Main = Color3.fromRGB(20, 32, 26), Accent = Color3.fromRGB(74, 222, 128), Accent2 = Color3.fromRGB(163, 230, 53) },
	{ Name = "Neon", Main = Color3.fromRGB(10, 10, 16), Accent = Color3.fromRGB(0, 255, 170), Accent2 = Color3.fromRGB(255, 0, 200) },
	{ Name = "Gold", Main = Color3.fromRGB(30, 26, 18), Accent = Color3.fromRGB(250, 204, 21), Accent2 = Color3.fromRGB(245, 158, 11) },
	{ Name = "Mono", Main = Color3.fromRGB(240, 240, 240), Accent = Color3.fromRGB(40, 40, 40), Accent2 = Color3.fromRGB(130, 130, 130) },
}
Library.Presets = Presets

----------------------------------------------------------------
-- สถานะภายใน
----------------------------------------------------------------
local Theme = {}
local bindings = {}       -- {instance, property, themeKey}
local spinners = {}       -- UIGradient ของขอบเรืองแสง (หมุน)
local bars = {}           -- UIGradient แถบสี Accent -> Accent2
local conns = {}          -- connection ทั้งหมด (ไว้ล้างตอนปิด)
local themeListeners = {} -- ฟังก์ชันที่เรียกเมื่อธีมเปลี่ยน

local function lum(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function buildTheme(main, accent, accent2)
	local light = lum(main) > 0.55
	return {
		Main = main,
		Side = light and main:Lerp(BLACK, 0.07) or main:Lerp(WHITE, 0.05),
		Element = light and main:Lerp(BLACK, 0.12) or main:Lerp(WHITE, 0.09),
		Stroke = light and main:Lerp(BLACK, 0.25) or main:Lerp(WHITE, 0.22),
		Text = light and Color3.fromRGB(30, 45, 65) or Color3.fromRGB(240, 244, 252),
		Sub = light and Color3.fromRGB(85, 105, 128) or Color3.fromRGB(150, 160, 180),
		Accent = accent,
		Accent2 = accent2,
		OnAccent = lum(accent) > 0.62 and Color3.fromRGB(20, 24, 32) or WHITE,
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
		if not ok then warn("[RUOK UI] " .. tostring(err)) end
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

local function applyBindings(animate, onlyKey)
	for i = #bindings, 1, -1 do
		local b = bindings[i]
		local inst, prop, key = b[1], b[2], b[3]
		if not inst:IsDescendantOf(game) then
			table.remove(bindings, i)
		elseif not onlyKey or key == onlyKey then
			if animate then
				TweenService:Create(inst, TweenInfo.new(0.3), { [prop] = Theme[key] }):Play()
			else
				inst[prop] = Theme[key]
			end
		end
	end
end

local function ringSequence()
	local base, a, b = Theme.Stroke, Theme.Accent, Theme.Accent2
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(0.15, a),
		ColorSequenceKeypoint.new(0.25, b),
		ColorSequenceKeypoint.new(0.4, base),
		ColorSequenceKeypoint.new(0.6, base),
		ColorSequenceKeypoint.new(0.65, a),
		ColorSequenceKeypoint.new(0.75, b),
		ColorSequenceKeypoint.new(0.9, base),
		ColorSequenceKeypoint.new(1, base),
	})
end

local function refreshGradients()
	local ring = ringSequence()
	for _, g in ipairs(spinners) do
		if g.Parent then g.Color = ring end
	end
	local bar = ColorSequence.new(Theme.Accent, Theme.Accent2)
	for _, g in ipairs(bars) do
		if g.Parent then g.Color = bar end
	end
end

local function fireListeners(source)
	for _, fn in ipairs(themeListeners) do
		pcall(fn, source)
	end
end

-- เปลี่ยนทั้งธีม (พื้นหลัง + สีหลัก + สีรอง)
local function setColors(main, a, b, instant, source)
	for k, v in pairs(buildTheme(main, a, b)) do Theme[k] = v end
	applyBindings(not instant)
	refreshGradients()
	fireListeners(source)
end

-- เปลี่ยนเฉพาะสี Accent (เร็ว ใช้กับ Rainbow / ตัวเลือกสี)
local function setAccent(a, b)
	Theme.Accent, Theme.Accent2 = a, b
	Theme.OnAccent = lum(a) > 0.62 and Color3.fromRGB(20, 24, 32) or WHITE
	applyBindings(false, "Accent")
	applyBindings(false, "OnAccent")
	refreshGradients()
end

local function textLabel(parent, props, key)
	props.BackgroundTransparency = 1
	props.Parent = parent
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextSize = props.TextSize or 13
	local l = create("TextLabel", props)
	bind(l, "TextColor3", key or "Text")
	return l
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- ลากเพื่อปรับค่า (สไลเดอร์, ตัวเลือกสี)
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

-- ลากหน้าต่าง
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
	local ok2 = pcall(function() return CoreGui.Name end)
	if ok2 then return CoreGui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function hexStr(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function c2t(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function t2c(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- ธีมเริ่มต้น
do
	local p = Presets[1]
	for k, v in pairs(buildTheme(p.Main, p.Accent, p.Accent2)) do Theme[k] = v end
end

----------------------------------------------------------------
-- API ธีม
----------------------------------------------------------------
function Library:SetTheme(name)
	for _, p in ipairs(Presets) do
		if p.Name == name then
			Library.ThemeName = name
			setColors(p.Main, p.Accent, p.Accent2, false)
			return true
		end
	end
	return false
end

function Library:SetColors(main, accent, accent2)
	Library.ThemeName = "Custom"
	setColors(main, accent, accent2, false)
end

function Library:SaveConfig()
	if not writefile then return false end
	return (pcall(function()
		writefile(FILE, HttpService:JSONEncode({
			Main = c2t(Theme.Main), Accent = c2t(Theme.Accent), Accent2 = c2t(Theme.Accent2),
			Transparency = Library.Transparency, Spin = Library.SpinEnabled,
			SpinSpeed = Library.SpinSpeed, Theme = Library.ThemeName,
		}))
	end))
end

function Library:LoadConfig()
	if not (isfile and readfile) then return false end
	local ok, data = pcall(function()
		if isfile(FILE) then return HttpService:JSONDecode(readfile(FILE)) end
	end)
	if ok and type(data) == "table" and data.Main and data.Accent and data.Accent2 then
		Library.ThemeName = data.Theme or "Custom"
		Library.Transparency = data.Transparency or 0
		if data.Spin ~= nil then Library.SpinEnabled = data.Spin end
		Library.SpinSpeed = data.SpinSpeed or Library.SpinSpeed
		setColors(t2c(data.Main), t2c(data.Accent), t2c(data.Accent2), true)
		return true
	end
	return false
end

function Library:Destroy()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
	table.clear(bindings)
	table.clear(spinners)
	table.clear(bars)
	table.clear(themeListeners)
	if Library.Gui then Library.Gui:Destroy() end
	Library.Gui, Library.NotifyHolder, Library.Window = nil, nil, nil
end

----------------------------------------------------------------
-- แจ้งเตือน
----------------------------------------------------------------
local notifyOrder = 0
function Library:Notify(o)
	if not Library.NotifyHolder then return end
	o = o or {}
	local dur = o.Duration or 4
	notifyOrder = notifyOrder + 1
	local n = create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 60), BorderSizePixel = 0, GroupTransparency = 1,
		LayoutOrder = notifyOrder, Parent = Library.NotifyHolder,
	})
	bind(n, "BackgroundColor3", "Main")
	corner(n, 8)
	local st = create("UIStroke", { Thickness = 1.6, Parent = n })
	bind(st, "Color", "Accent")
	textLabel(n, { Text = o.Title or "แจ้งเตือน", Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -24, 0, 18) }, "Text")
	textLabel(n, { Text = o.Text or "", TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -24, 0, 28) }, "Sub")
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

----------------------------------------------------------------
-- องค์ประกอบ (เมธอดของ Tab)
----------------------------------------------------------------
local TabMeta = {}
TabMeta.__index = TabMeta

local function nextOrder(tab)
	tab._order = tab._order + 1
	return tab._order
end

local function elementHeight(o)
	return o.Description and 52 or 38
end

local function newElement(tab, height)
	local f = create("Frame", { Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, LayoutOrder = nextOrder(tab), Parent = tab.Page })
	bind(f, "BackgroundColor3", "Element")
	corner(f, 6)
	return f
end

local function makeTitle(f, o, rightPad)
	local hasDesc = o.Description ~= nil
	local n = textLabel(f, {
		Text = o.Name or "Element", Font = Enum.Font.GothamBold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 12, 0, hasDesc and 7 or 0), Size = UDim2.new(1, -(rightPad + 12), 0, hasDesc and 18 or 38),
	}, "Text")
	if hasDesc then
		textLabel(f, {
			Text = o.Description, Font = Enum.Font.Gotham, TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -(rightPad + 12), 0, 16),
		}, "Sub")
	end
	return n
end

function TabMeta:AddSection(name)
	local f = create("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = nextOrder(self), Parent = self.Page })
	local bar = create("Frame", { Size = UDim2.new(0, 3, 0, 14), Position = UDim2.new(0, 0, 0.5, -7), BorderSizePixel = 0, Parent = f })
	bind(bar, "BackgroundColor3", "Accent")
	corner(bar, 2)
	textLabel(f, { Text = name, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -10, 1, 0) }, "Text")
end

function TabMeta:AddLabel(text)
	local l = textLabel(self.Page, {
		Text = text, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = nextOrder(self),
	}, "Sub")
	local obj = {}
	function obj:Set(t) l.Text = t end
	return obj
end

function TabMeta:AddButton(o)
	local f = newElement(self, elementHeight(o))
	makeTitle(f, o, 36)
	textLabel(f, { Text = "›", Font = Enum.Font.GothamBold, TextSize = 22, Position = UDim2.new(1, -30, 0, 0), Size = UDim2.new(0, 20, 1, 0) }, "Accent")
	local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = f })
	bind(flash, "BackgroundColor3", "Accent")
	corner(flash, 6)
	local b = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f })
	b.MouseButton1Click:Connect(function()
		flash.BackgroundTransparency = 0.65
		tween(flash, { BackgroundTransparency = 1 }, 0.35)
		safe(o.Callback)
	end)
end

function TabMeta:AddToggle(o)
	local state = o.Default == true
	local f = newElement(self, elementHeight(o))
	makeTitle(f, o, 60)
	local track_ = create("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10), BorderSizePixel = 0, Parent = f })
	bind(track_, "BackgroundColor3", "Stroke")
	corner(track_, 10)
	local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = state and 0 or 1, BorderSizePixel = 0, Parent = track_ })
	bind(fill, "BackgroundColor3", "Accent")
	corner(fill, 10)
	local knob = create("Frame", { Size = UDim2.fromOffset(14, 14), Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = track_ })
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

function TabMeta:AddSlider(o)
	local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
	local value = math.clamp(o.Default or min, min, max)
	local f = newElement(self, 54)
	textLabel(f, { Text = o.Name or "Slider", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(0.6, 0, 0, 18) }, "Text")
	local vl = textLabel(f, { TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.6, 0, 0, 6), Size = UDim2.new(0.4, -12, 0, 18) }, "Accent")
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

function TabMeta:AddDropdown(o)
	local options = o.Options or {}
	local current = o.Default
	local open = false
	local f = newElement(self, 38)
	f.ClipsDescendants = true
	local head = create("TextButton", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Text = "", Parent = f })
	textLabel(head, { Text = o.Name or "Dropdown", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.5, -12, 1, 0) }, "Text")
	local val = textLabel(head, { Text = current ~= nil and tostring(current) or "เลือก...", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -34, 1, 0) }, "Accent")
	local arrow = textLabel(head, { Text = "▼", TextSize = 10, Position = UDim2.new(1, -28, 0, 0), Size = UDim2.fromOffset(20, 38) }, "Sub")
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 44), Size = UDim2.new(1, -16, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = f,
	})
	bind(list, "ScrollBarImageColor3", "Accent")
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local entries = {}
	local function listHeight()
		local n = math.min(#options, 5)
		return n * 30 + math.max(n - 1, 0) * 4
	end
	local function resize()
		tween(f, { Size = UDim2.new(1, 0, 0, open and (44 + listHeight() + 8) or 38) }, 0.2)
		tween(list, { Size = UDim2.new(1, -16, 0, listHeight()) }, 0.2)
		tween(arrow, { Rotation = open and 180 or 0 }, 0.2)
	end
	local function paint()
		for _, e in ipairs(entries) do
			e.btn.TextColor3 = (e.opt == current) and Theme.Accent or Theme.Text
		end
	end
	table.insert(themeListeners, paint)

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
				Size = UDim2.new(1, -6, 0, 30), BorderSizePixel = 0, Text = tostring(opt), Font = Enum.Font.GothamMedium,
				TextSize = 12, AutoButtonColor = false, LayoutOrder = i, Parent = list,
			})
			bind(b, "BackgroundColor3", "Side")
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
		if not keep then current = nil val.Text = "เลือก..." end
		rebuild()
		if open then resize() end
	end
	if o.Flag and current ~= nil then Library.Flags[o.Flag] = current end
	return obj
end

function TabMeta:AddTextbox(o)
	local f = newElement(self, elementHeight(o))
	makeTitle(f, o, 180)
	local box = create("TextBox", {
		Size = UDim2.fromOffset(160, 26), Position = UDim2.new(1, -172, 0.5, -13), BorderSizePixel = 0,
		Text = o.Default or "", PlaceholderText = o.Placeholder or "พิมพ์ที่นี่...", ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium, TextSize = 12, Parent = f,
	})
	bind(box, "BackgroundColor3", "Side")
	bind(box, "TextColor3", "Text")
	bind(box, "PlaceholderColor3", "Sub")
	corner(box, 5)
	box.FocusLost:Connect(function(enter)
		if o.Flag then Library.Flags[o.Flag] = box.Text end
		safe(o.Callback, box.Text, enter)
	end)
	local obj = {}
	function obj:Set(t) box.Text = t end
	function obj:Get() return box.Text end
	return obj
end

function TabMeta:AddKeybind(o)
	local key = o.Default or Enum.KeyCode.F
	local listening = false
	local f = newElement(self, elementHeight(o))
	makeTitle(f, o, 110)
	local btn = create("TextButton", {
		Size = UDim2.fromOffset(90, 24), Position = UDim2.new(1, -102, 0.5, -12), BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextSize = 12, Text = key.Name, AutoButtonColor = false, Parent = f,
	})
	bind(btn, "BackgroundColor3", "Side")
	bind(btn, "TextColor3", "Accent")
	corner(btn, 5)
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
					safe(o.Changed, key)
				end
				btn.Text = key.Name
			end
		elseif not gp and input.KeyCode == key then
			safe(o.Callback, key)
		end
	end))
	local obj = {}
	function obj:Get() return key end
	function obj:Set(k) key = k btn.Text = k.Name end
	return obj
end

function TabMeta:AddColorPicker(o)
	local color = o.Default or Color3.fromRGB(0, 170, 255)
	local h, s, v = color:ToHSV()
	local open = false
	local f = newElement(self, 38)
	f.ClipsDescendants = true
	local head = create("TextButton", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Text = "", Parent = f })
	textLabel(head, { Text = o.Name or "Color", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -150, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }, "Text")
	local hex = textLabel(head, { TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -132, 0, 0), Size = UDim2.fromOffset(74, 38) }, "Sub")
	local swatch = create("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10), BorderSizePixel = 0, Parent = head })
	corner(swatch, 5)
	local sst = create("UIStroke", { Thickness = 1.5, Parent = swatch })
	bind(sst, "Color", "Stroke")

	-- กล่อง Saturation/Value
	local sv = create("Frame", { Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -52, 0, 110), BorderSizePixel = 0, Parent = f })
	corner(sv, 4)
	local white = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = sv })
	corner(white, 4)
	create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local blackF = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = sv })
	corner(blackF, 4)
	create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackF })
	local cursor = create("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = sv })
	corner(cursor, 5)
	create("UIStroke", { Thickness = 2, Color = WHITE, Parent = cursor })

	-- แถบ Hue
	local hueBar = create("Frame", { Position = UDim2.new(1, -32, 0, 46), Size = UDim2.fromOffset(22, 110), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = f })
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
		hex.Text = hexStr(color)
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
		h = math.clamp((pos.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
		update()
	end, self.Page)
	head.MouseButton1Click:Connect(function()
		open = not open
		tween(f, { Size = UDim2.new(1, 0, 0, open and 166 or 38) }, 0.22)
	end)
	return obj
end

-- พรีวิวหน้าต่างจำลอง (เปลี่ยนสีตามธีมแบบสด)
function TabMeta:AddPreview()
	local f = newElement(self, 132)
	local scene = create("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), BorderSizePixel = 0, ClipsDescendants = true, Parent = f })
	bind(scene, "BackgroundColor3", "Main")
	corner(scene, 8)
	local st = create("UIStroke", { Thickness = 2, Color = WHITE, Parent = scene })
	local g = create("UIGradient", { Color = ringSequence(), Parent = st })
	spinners[#spinners + 1] = g

	local sbar = create("Frame", { Size = UDim2.new(0, 90, 1, 0), BorderSizePixel = 0, Parent = scene })
	bind(sbar, "BackgroundColor3", "Side")
	for i = 1, 4 do
		local r = create("Frame", { Position = UDim2.fromOffset(7, 10 + (i - 1) * 22), Size = UDim2.new(1, -14, 0, 16), BorderSizePixel = 0, Parent = sbar })
		bind(r, "BackgroundColor3", i == 1 and "Accent" or "Element")
		corner(r, 4)
	end
	textLabel(scene, { Text = "RUOK Hub", Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(104, 8), Size = UDim2.fromOffset(150, 16) }, "Text")
	textLabel(scene, { Text = "ตัวอย่างสีที่เลือก", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(104, 24), Size = UDim2.fromOffset(150, 14) }, "Sub")
	local line = create("Frame", { Position = UDim2.fromOffset(90, 42), Size = UDim2.new(1, -90, 0, 2), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = scene })
	bars[#bars + 1] = create("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Parent = line })

	local btn = create("Frame", { Position = UDim2.fromOffset(104, 56), Size = UDim2.fromOffset(100, 22), BorderSizePixel = 0, Parent = scene })
	bind(btn, "BackgroundColor3", "Accent")
	corner(btn, 5)
	textLabel(btn, { Text = "Button", Font = Enum.Font.GothamBold, TextSize = 12, Size = UDim2.fromScale(1, 1) }, "OnAccent")
	local tg = create("Frame", { Position = UDim2.fromOffset(216, 57), Size = UDim2.fromOffset(40, 20), BorderSizePixel = 0, Parent = scene })
	bind(tg, "BackgroundColor3", "Accent")
	corner(tg, 10)
	local kn = create("Frame", { Position = UDim2.fromOffset(23, 3), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = tg })
	corner(kn, 7)
	local sl = create("Frame", { Position = UDim2.fromOffset(104, 92), Size = UDim2.fromOffset(150, 6), BorderSizePixel = 0, Parent = scene })
	bind(sl, "BackgroundColor3", "Stroke")
	corner(sl, 3)
	local sf = create("Frame", { Size = UDim2.new(0.6, 0, 1, 0), BorderSizePixel = 0, Parent = sl })
	bind(sf, "BackgroundColor3", "Accent")
	corner(sf, 3)
end

-- แกลเลอรีธีม: การ์ดแสดงภาพสีจริง กดแล้วเปลี่ยนทั้ง UI ทันที
function TabMeta:AddThemeGallery()
	local holder = create("Frame", { Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1, LayoutOrder = nextOrder(self), Parent = self.Page })
	local grid = create("UIGridLayout", { CellSize = UDim2.fromOffset(142, 74), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		holder.Size = UDim2.new(1, 0, 0, grid.AbsoluteContentSize.Y)
	end)
	local cards = {}
	local obj = {}
	function obj:Refresh()
		for _, c in ipairs(cards) do
			local sel = (c.name == Library.ThemeName)
			c.stroke.Color = sel and Theme.Accent or c.idle
			c.stroke.Thickness = sel and 3 or 1.5
			c.check.Visible = sel
		end
	end
	for i, p in ipairs(Presets) do
		local t = buildTheme(p.Main, p.Accent, p.Accent2)
		local card = create("TextButton", { BackgroundColor3 = p.Main, BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = i, ClipsDescendants = true, Parent = holder })
		corner(card, 8)
		local stroke = create("UIStroke", { Thickness = 1.5, Color = t.Stroke, Parent = card })
		local strip = create("Frame", { Size = UDim2.new(0, 40, 1, 0), BackgroundColor3 = t.Side, BorderSizePixel = 0, Parent = card })
		for k = 0, 2 do
			local r = create("Frame", { Position = UDim2.fromOffset(6, 10 + k * 14), Size = UDim2.fromOffset(28, 8), BackgroundColor3 = k == 0 and p.Accent or t.Element, BorderSizePixel = 0, Parent = strip })
			corner(r, 3)
		end
		local top = create("Frame", { Position = UDim2.fromOffset(48, 10), Size = UDim2.new(1, -58, 0, 6), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = card })
		corner(top, 3)
		create("UIGradient", { Color = ColorSequence.new(p.Accent, p.Accent2), Parent = top })
		local dot = create("Frame", { Position = UDim2.fromOffset(48, 24), Size = UDim2.fromOffset(38, 12), BackgroundColor3 = p.Accent, BorderSizePixel = 0, Parent = card })
		corner(dot, 4)
		local dot2 = create("Frame", { Position = UDim2.fromOffset(90, 24), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = p.Accent2, BorderSizePixel = 0, Parent = card })
		corner(dot2, 6)
		create("TextLabel", { BackgroundTransparency = 1, Text = p.Name, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = t.Text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(48, 46), Size = UDim2.new(1, -54, 0, 18), Parent = card })
		local check = create("TextLabel", { BackgroundTransparency = 1, Text = "✓", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = p.Accent, Position = UDim2.new(1, -24, 0, 2), Size = UDim2.fromOffset(20, 20), Visible = false, Parent = card })
		cards[#cards + 1] = { name = p.Name, stroke = stroke, check = check, idle = t.Stroke }
		card.MouseButton1Click:Connect(function()
			Library.ThemeName = p.Name
			setColors(p.Main, p.Accent, p.Accent2, false)
			obj:Refresh()
		end)
	end
	obj:Refresh()
	table.insert(themeListeners, function() obj:Refresh() end)
	return obj
end

----------------------------------------------------------------
-- สร้างหน้าต่างหลัก
----------------------------------------------------------------
function Library:CreateWindow(cfg)
	cfg = cfg or {}
	Library:Destroy()
	local parent = getGuiParent()
	local old = parent:FindFirstChild(NAME)
	if old then old:Destroy() end
	if cfg.AutoLoad ~= false then Library:LoadConfig() end

	local Window = { Tabs = {} }
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local W = math.min(cfg.Size and cfg.Size.X or 720, vp.X - 20)
	local H = math.min(cfg.Size and cfg.Size.Y or 485, vp.Y - 20)
	local sideW = W < 560 and 150 or 210
	local HEAD_H = 52
	local curW = W

	local gui = create("ScreenGui", { Name = NAME, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Parent = parent })
	Library.Gui, Library.Window = gui, Window
	Window.Gui = gui

	local main = create("Frame", {
		Name = "Main", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
		BorderSizePixel = 0, Active = true, ClipsDescendants = true, Parent = gui,
	})
	bind(main, "BackgroundColor3", "Main")
	corner(main, 8)
	local ring = create("UIStroke", { Thickness = 2.5, Color = WHITE, Parent = main })
	spinners[#spinners + 1] = create("UIGradient", { Color = ringSequence(), Parent = ring })

	-- แถบด้านซ้าย
	local side = create("Frame", { Name = "Sidebar", Size = UDim2.new(0, sideW, 1, 0), BorderSizePixel = 0, Parent = main })
	bind(side, "BackgroundColor3", "Side")
	local sideLine = create("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0, Parent = side })
	bind(sideLine, "BackgroundColor3", "Stroke")

	local logoF = create("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Parent = side })
	if cfg.Logo then
		create("ImageLabel", { Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1, Image = cfg.Logo, ScaleType = Enum.ScaleType.Fit, Parent = logoF })
	else
		textLabel(logoF, { Text = cfg.Title or "RUOK Hub", Font = Enum.Font.GothamBold, TextSize = 20, Size = UDim2.fromScale(1, 1) }, "Accent")
	end
	local logoLine = create("Frame", { Size = UDim2.new(1, -24, 0, 2), Position = UDim2.fromOffset(12, 64), BorderSizePixel = 0, Parent = side })
	bind(logoLine, "BackgroundColor3", "Stroke")

	local tabList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -136), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = side,
	})
	bind(tabList, "ScrollBarImageColor3", "Accent")
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = tabList })

	-- โปรไฟล์ผู้เล่น (ล่างซ้าย)
	local pf = create("Frame", { Size = UDim2.new(1, -16, 0, 52), Position = UDim2.new(0, 8, 1, -60), BorderSizePixel = 0, Parent = side })
	bind(pf, "BackgroundColor3", "Element")
	corner(pf, 6)
	local pfs = create("UIStroke", { Thickness = 1.5, Color = WHITE, Parent = pf })
	spinners[#spinners + 1] = create("UIGradient", { Color = ringSequence(), Parent = pfs })
	local avatar = create("ImageLabel", { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(0, 8, 0.5, -18), BackgroundTransparency = 1, Parent = pf })
	corner(avatar, 18)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and avatar.Parent then avatar.Image = img end
	end)
	textLabel(pf, { Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -58, 0, 18) }, "Text")
	textLabel(pf, { Text = "@" .. LocalPlayer.Name, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -58, 0, 14) }, "Sub")

	-- ส่วนหัว
	local header = create("Frame", { Position = UDim2.fromOffset(sideW, 0), Size = UDim2.new(1, -sideW, 0, HEAD_H), BackgroundTransparency = 1, Parent = main })
	local headTitle = textLabel(header, { Text = cfg.Title or "RUOK Hub", Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -100, 0, 20) }, "Text")
	local headSub = textLabel(header, { Text = cfg.SubTitle or "", Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -100, 0, 14) }, "Sub")

	local divider = create("Frame", { Position = UDim2.fromOffset(sideW, HEAD_H), Size = UDim2.new(1, -sideW, 0, 2), BackgroundColor3 = WHITE, BorderSizePixel = 0, ClipsDescendants = true, Parent = main })
	bars[#bars + 1] = create("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Parent = divider })
	local glow = create("Frame", { Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(-0.3, 0, 0, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = divider })
	create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) }), Parent = glow })

	makeDraggable(header, main)
	makeDraggable(logoF, main)

	-- ปุ่มควบคุมหน้าต่าง (แดง/เหลือง/เขียว)
	local ctrl = create("Frame", { Size = UDim2.fromOffset(60, 14), Position = UDim2.new(1, -72, 0, 19), BackgroundTransparency = 1, Parent = header })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = ctrl })
	local function dot(color, order)
		local b = create("TextButton", { Size = UDim2.fromOffset(14, 14), BackgroundColor3 = color, Text = "", AutoButtonColor = false, LayoutOrder = order, Parent = ctrl })
		corner(b, 7)
		return b
	end
	local red, yellow, green = dot(Color3.fromRGB(255, 95, 86), 1), dot(Color3.fromRGB(255, 189, 46), 2), dot(Color3.fromRGB(39, 201, 63), 3)

	red.MouseButton1Click:Connect(function()
		tween(main, { BackgroundTransparency = 1 }, 0.2)
		task.wait(0.2)
		Library:Destroy()
	end)
	local minimized = false
	yellow.MouseButton1Click:Connect(function()
		minimized = not minimized
		tween(main, { Size = UDim2.fromOffset(curW, minimized and HEAD_H or H) }, 0.25)
	end)
	local wide = false
	green.MouseButton1Click:Connect(function()
		wide = not wide
		curW = math.min(W + (wide and 120 or 0), vp.X - 20)
		tween(main, { Size = UDim2.fromOffset(curW, minimized and HEAD_H or H) }, 0.3)
	end)

	-- พื้นที่เนื้อหา
	local pages = create("Frame", { Position = UDim2.fromOffset(sideW, HEAD_H + 2), Size = UDim2.new(1, -sideW, 1, -(HEAD_H + 2)), BackgroundTransparency = 1, ClipsDescendants = true, Parent = main })

	-- กล่องแจ้งเตือน
	local nh = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 270, 1, -32), BackgroundTransparency = 1, Parent = gui })
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = nh })
	Library.NotifyHolder = nh

	local tabSound
	if cfg.TabSound then
		tabSound = create("Sound", { SoundId = cfg.TabSound, Volume = 1, Parent = gui })
	end

	-- ปุ่มลอยเปิด/ปิด UI (สำหรับมือถือ)
	if cfg.ToggleButton == true or (cfg.ToggleButton == nil and UIS.TouchEnabled) then
		local fb = create("TextButton", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 14, 0.5, -22), BorderSizePixel = 0, Text = "☰", Font = Enum.Font.GothamBold, TextSize = 20, AutoButtonColor = false, Parent = gui })
		bind(fb, "BackgroundColor3", "Accent")
		bind(fb, "TextColor3", "OnAccent")
		corner(fb, 22)
		local st = makeDraggable(fb, fb)
		fb.MouseButton1Click:Connect(function()
			if not st.moved then main.Visible = not main.Visible end
		end)
	end

	track(UIS.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == Library.ToggleKey then main.Visible = not main.Visible end
	end))

	-- ลูปหลัก: ขอบหมุน / เส้นเรืองแสง / Rainbow
	local glowPos = -0.3
	track(RunService.Heartbeat:Connect(function(dt)
		if Library.SpinEnabled then
			for _, g in ipairs(spinners) do
				g.Rotation = (g.Rotation + dt * Library.SpinSpeed) % 360
			end
		end
		glowPos = glowPos + dt * 0.6
		if glowPos > 1.2 then glowPos = -0.3 end
		glow.Position = UDim2.new(glowPos, 0, 0, 0)
		if Library.Rainbow then
			local hue = (os.clock() * 0.08) % 1
			setAccent(Color3.fromHSV(hue, 0.75, 1), Color3.fromHSV((hue + 0.15) % 1, 0.75, 1))
		end
	end))

	function Window:SetTransparency(x)
		Library.Transparency = x
		main.BackgroundTransparency = x
		side.BackgroundTransparency = x
	end
	function Window:Toggle() main.Visible = not main.Visible end
	function Window:Destroy() Library:Destroy() end

	-- เพิ่มแท็บ
	local function selectTab(t)
		for _, x in ipairs(Window.Tabs) do
			local on = (x == t)
			x.Page.Visible = on
			x.Indicator.Visible = on
			tween(x.Button, { BackgroundTransparency = on and 0 or 0.6 }, 0.15)
		end
		headTitle.Text = t.Name
		headSub.Text = (t.Sub and t.Sub ~= "") and t.Sub or (cfg.SubTitle or "")
		if tabSound then pcall(function() tabSound:Play() end) end
	end

	function Window:AddTab(info)
		info = info or {}
		local Tab = setmetatable({ _order = 0, Name = info.Name or "Tab", Sub = info.Sub }, TabMeta)
		local idx = #Window.Tabs + 1

		local btn = create("TextButton", { Size = UDim2.new(1, 0, 0, 42), BorderSizePixel = 0, Text = "", AutoButtonColor = false, BackgroundTransparency = 0.6, LayoutOrder = idx, ClipsDescendants = true, Parent = tabList })
		bind(btn, "BackgroundColor3", "Element")
		corner(btn, 6)
		local ind = create("Frame", { Size = UDim2.new(0, 3, 0, 22), Position = UDim2.new(0, 0, 0.5, -11), BorderSizePixel = 0, Visible = false, Parent = btn })
		bind(ind, "BackgroundColor3", "Accent")
		corner(ind, 2)
		local tx = 12
		if info.Icon then
			create("ImageLabel", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 10, 0.5, -12), BackgroundTransparency = 1, Image = info.Icon, Parent = btn })
			tx = 42
		end
		textLabel(btn, { Text = Tab.Name, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(tx, 4), Size = UDim2.new(1, -(tx + 6), 0, 18) }, "Text")
		textLabel(btn, { Text = info.Sub or "", Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(tx, 22), Size = UDim2.new(1, -(tx + 6), 0, 14) }, "Sub")

		local page = create("ScrollingFrame", {
			Name = Tab.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = pages,
		})
		bind(page, "ScrollBarImageColor3", "Accent")
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
		create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = page })

		Tab.Button, Tab.Page, Tab.Indicator = btn, page, ind
		Window.Tabs[idx] = Tab
		btn.MouseButton1Click:Connect(function() selectTab(Tab) end)
		if idx == 1 then selectTab(Tab) end
		return Tab
	end

	-- หมวด Settings สำเร็จรูป
	function Window:AddSettingsTab(info)
		info = info or {}
		local tab = Window:AddTab({ Name = info.Name or "Settings", Sub = info.Sub or "ปรับแต่ง UI", Icon = info.Icon })

		tab:AddSection("ตัวอย่างสด (Live Preview)")
		tab:AddPreview()

		tab:AddSection("ธีมสำเร็จรูป — กดเพื่อเปลี่ยนสีทั้ง UI ทันที")
		local gallery = tab:AddThemeGallery()

		tab:AddSection("ปรับสีเอง")
		local mainPick, accPick, acc2Pick
		mainPick = tab:AddColorPicker({ Name = "สีพื้นหลัง (Main)", Default = Theme.Main, Callback = function(c)
			Library.ThemeName = "Custom"
			setColors(c, Theme.Accent, Theme.Accent2, true, "picker")
			gallery:Refresh()
		end })
		accPick = tab:AddColorPicker({ Name = "สีหลัก (Accent)", Default = Theme.Accent, Callback = function(c)
			Library.ThemeName = "Custom"
			setAccent(c, Theme.Accent2)
			gallery:Refresh()
		end })
		acc2Pick = tab:AddColorPicker({ Name = "สีรอง (Accent 2)", Default = Theme.Accent2, Callback = function(c)
			Library.ThemeName = "Custom"
			setAccent(Theme.Accent, c)
			gallery:Refresh()
		end })
		table.insert(themeListeners, function(source)
			if source ~= "picker" then
				mainPick:Set(Theme.Main, true)
				accPick:Set(Theme.Accent, true)
				acc2Pick:Set(Theme.Accent2, true)
			end
		end)

		tab:AddSection("ปรับแต่ง UI")
		tab:AddSlider({ Name = "ความโปร่งใสหน้าต่าง", Min = 0, Max = 60, Default = math.floor(Library.Transparency * 100), Suffix = "%", Callback = function(v)
			Window:SetTransparency(v / 100)
		end })
		tab:AddToggle({ Name = "ขอบเรืองแสงหมุน", Default = Library.SpinEnabled, Callback = function(v) Library.SpinEnabled = v end })
		tab:AddSlider({ Name = "ความเร็วขอบหมุน", Min = 10, Max = 300, Default = Library.SpinSpeed, Increment = 5, Callback = function(v) Library.SpinSpeed = v end })
		tab:AddToggle({ Name = "สีรุ้ง (Rainbow Accent)", Description = "สีหลักไล่สีอัตโนมัติ", Default = Library.Rainbow, Callback = function(v)
			Library.Rainbow = v
			if not v then
				Library.ThemeName = "Custom"
				gallery:Refresh()
			end
		end })
		tab:AddKeybind({ Name = "ปุ่มเปิด/ปิด UI", Default = Library.ToggleKey, Changed = function(k) Library.ToggleKey = k end })

		tab:AddSection("ระบบ")
		tab:AddButton({ Name = "บันทึกธีม", Description = "เก็บสีและการตั้งค่าไว้ใช้ครั้งหน้า", Callback = function()
			local ok = Library:SaveConfig()
			Library:Notify({ Title = ok and "บันทึกแล้ว" or "บันทึกไม่ได้", Text = ok and "ธีมจะถูกโหลดอัตโนมัติครั้งหน้า" or "executor ของคุณไม่รองรับ writefile" })
		end })
		tab:AddButton({ Name = "รีเซ็ตธีม", Callback = function()
			Library.Rainbow = false
			Library:SetTheme(Presets[1].Name)
			Library:Notify({ Title = "รีเซ็ตแล้ว", Text = "กลับเป็นธีม " .. Presets[1].Name })
		end })
		tab:AddButton({ Name = "ปิด UI (Destroy)", Callback = function() Library:Destroy() end })
		return tab
	end

	Window:SetTransparency(Library.Transparency)
	return Window
end

----------------------------------------------------------------
-- ตัวอย่างการใช้งาน (ลบส่วนนี้ได้)
----------------------------------------------------------------
local Window = Library:CreateWindow({
	Title = "RUOK Hub",
	SubTitle = "ruok By พอส",
	-- Logo = "rbxassetid://0",      -- ใส่รูปโลโก้ได้
	-- TabSound = "rbxassetid://78902420378646",
})

local Info = Window:AddTab({ Name = "INFO", Sub = "ข้อมูล" })
Info:AddSection("เกี่ยวกับ")
Info:AddLabel("RUOK UI Library — ธีมฟ้านม ปรับสีได้ในหมวด Settings")

local Main = Window:AddTab({ Name = "Main", Sub = "หน้าหลัก" })
Main:AddSection("ตัวอย่างองค์ประกอบ")
Main:AddButton({ Name = "ปุ่มทดสอบ", Description = "กดแล้วมีแจ้งเตือน", Callback = function()
	Library:Notify({ Title = "สำเร็จ", Text = "กดปุ่มแล้ว!" })
end })
Main:AddToggle({ Name = "สวิตช์ทดสอบ", Flag = "demoToggle", Callback = function(v) print("Toggle:", v) end })
Main:AddSlider({ Name = "สไลเดอร์", Min = 0, Max = 100, Default = 50, Flag = "demoSlider", Callback = function(v) print("Slider:", v) end })
Main:AddDropdown({ Name = "เลือกโหมด", Options = { "โหมด A", "โหมด B", "โหมด C" }, Default = "โหมด A", Callback = function(v) print("Dropdown:", v) end })
Main:AddTextbox({ Name = "ข้อความ", Placeholder = "พิมพ์แล้วกด Enter", Callback = function(t) print("Text:", t) end })
Main:AddKeybind({ Name = "คีย์ลัด", Default = Enum.KeyCode.F, Callback = function() print("Keybind pressed") end })
Main:AddColorPicker({ Name = "เลือกสี", Default = Color3.fromRGB(255, 120, 0), Callback = function(c) print("Color:", c) end })

Window:AddTab({ Name = "Combat", Sub = "ทดสอบ" })
Window:AddTab({ Name = "Visuals", Sub = "ทดสอบ" })
Window:AddTab({ Name = "Teleport", Sub = "ทดสอบ" })

Window:AddSettingsTab({ Name = "Settings", Sub = "ปรับเเต่ง UI" })

Library:Notify({ Title = "RUOK Hub", Text = "โหลดสำเร็จ — ไปที่ Settings เพื่อปรับสี UI", Duration = 5 })

return Library

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local function getGuiParent()
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then return hui end
	return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
end

local Config = {
	Esp = false,
	MaxEspStuds = 500,
	AimActive = false,
	TeamCheck = true,
	Part = "Head",
	Smooth = 1,
	ShowAimBtn = false,
	ShowTpBtn = false,
	ShowNearestTpBtn = false,
	NearestTpMode = "Hepsi",
	SelectedTpPlayer = nil,
	NoRecoil = false,
	KillAura = false,
	AuraRange = 18,
	TriggerBot = false,
	AutoSwing = false,
	SwingDelay = 0.14,
	ShowAuraBtn = false,
	ShowTrigBtn = false,
	NoLag = false,
	UltraPotato = false
}

local espList = {}
local uiSetters = {}
local cachedTargets = {}
local potatoCleanedParts = setmetatable({}, { __mode = "k" })
local tpDropdownRef = nil
local lastScanTime = 0
local lastSwingTime = 0
local lastTriggerTime = 0
local lastOptTime = 0
local prevCamLook = nil
local isSyncingUI = false

local function syncModeUI()
	if isSyncingUI then return end
	isSyncingUI = true
	for _, fn in ipairs(uiSetters) do
		pcall(fn)
	end
	task.defer(function()
		isSyncingUI = false
	end)
end

local function isTeammate(plr)
	if not Config.TeamCheck or not plr then return false end
	local ok, sameTeam = pcall(function()
		if LocalPlayer.Team and plr.Team then
			return LocalPlayer.Team == plr.Team
		end
		if LocalPlayer.TeamColor and plr.TeamColor and LocalPlayer.TeamColor ~= BrickColor.White() then
			return LocalPlayer.TeamColor == plr.TeamColor
		end
		return false
	end)
	return ok and sameTeam or false
end

local function getPlayerNamesList()
	local names = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			table.insert(names, plr.Name)
		end
	end
	if #names == 0 then
		table.insert(names, "Oyuncu Yok")
	end
	return names
end

local function refreshTpDropdown()
	if tpDropdownRef then
		pcall(function()
			tpDropdownRef:Refresh(getPlayerNamesList(), true)
		end)
	end
end

local function teleportToPart(targetPart)
	local myChar = LocalPlayer.Character
	local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Head"))
	if targetPart and myRoot then
		pcall(function()
			myRoot.CFrame = targetPart.CFrame * CFrame.new(0, 0, 3)
		end)
	end
end

local function teleportToPlayerName(playerName)
	if not playerName or playerName == "Oyuncu Yok" then return end
	local targetPlr = Players:FindFirstChild(playerName)
	local tChar = targetPlr and targetPlr.Character
	local tPart = tChar and (tChar:FindFirstChild("HumanoidRootPart") or tChar:FindFirstChild("Head"))
	teleportToPart(tPart)
end

local function teleportToNearestTarget()
	local myChar = LocalPlayer.Character
	local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Head"))
	if not myRoot then return end

	local nearestPart = nil
	local nearestDist = math.huge

	for _, t in ipairs(cachedTargets) do
		if t and t.part and t.part:IsA("BasePart") and t.part.Parent and t.model and t.model.Parent and t.model ~= myChar then
			local allowByMode = true
			if Config.NearestTpMode == "Oyuncular" then
				allowByMode = (t.isPlayer == true)
			elseif Config.NearestTpMode == "Bot" then
				allowByMode = (t.isPlayer == false)
			end

			if allowByMode and not (t.isPlayer and isTeammate(t.player)) then
				local dist = (t.part.Position - myRoot.Position).Magnitude
				if dist > 1 and dist < nearestDist then
					nearestDist = dist
					nearestPart = t.part
				end
			end
		end
	end

	if not nearestPart then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and not isTeammate(plr) then
				local char = plr.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local part = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
				if hum and hum.Health > 0 and part and part:IsA("BasePart") and part.Parent then
					local dist = (part.Position - myRoot.Position).Magnitude
					if dist > 1 and dist < nearestDist then
						nearestDist = dist
						nearestPart = part
					end
				end
			end
		end
	end

	if nearestPart then
		teleportToPart(nearestPart)
	end
end

Players.PlayerAdded:Connect(function()
	task.wait(0.2)
	refreshTpDropdown()
end)

Players.PlayerRemoving:Connect(function()
	task.wait(0.2)
	refreshTpDropdown()
end)
local function applyNoLag()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
			pcall(function()
				obj.Enabled = false
			end)
		elseif obj:IsA("Explosion") then
			pcall(function()
				obj.Visible = false
			end)
		end
	end
end

local function applyUltraPotato()
	applyNoLag()

	pcall(function()
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 1e6
		Lighting.Brightness = 0
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
		for _, eff in ipairs(Lighting:GetChildren()) do
			if eff:IsA("PostEffect") or eff:IsA("Atmosphere") then
				eff.Enabled = false
			end
		end
	end)

	pcall(function()
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			terrain.WaterWaveSize = 0
			terrain.WaterWaveSpeed = 0
			terrain.WaterReflectance = 0
			terrain.WaterTransparency = 1
		end
	end)

	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)

	local processed = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if processed >= 250 then break end
		if not potatoCleanedParts[obj] then
			potatoCleanedParts[obj] = true
			processed = processed + 1

			if obj:IsA("BasePart") then
				pcall(function()
					obj.Material = Enum.Material.SmoothPlastic
					obj.CastShadow = false
					if obj:IsA("MeshPart") then
						obj.TextureID = ""
					end
				end)
			elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
				pcall(function()
					obj:Destroy()
				end)
			end
		end
	end
end

local function clearEsp()
	for id, bb in pairs(espList) do
		if bb then pcall(function() bb:Destroy() end) end
		espList[id] = nil
	end
end

local function getEsp(id, part, title)
	local bb = espList[id]
	if bb and bb.Adornee == part and bb.Parent then return bb end
	if bb then pcall(function() bb:Destroy() end) end

	bb = Instance.new("BillboardGui")
	bb.Adornee = part
	bb.Size = UDim2.new(0, 100, 0, 42)
	bb.StudsOffset = Vector3.new(0, 2.2, 0)
	bb.AlwaysOnTop = true
	pcall(function() bb.Parent = getGuiParent() end)

	local box = Instance.new("Frame")
	box.Size = UDim2.new(0, 16, 0, 16)
	box.Position = UDim2.new(0.5, -8, 0.5, 4)
	box.BackgroundTransparency = 1
	box.Parent = bb

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 50, 50)
	stroke.Thickness = 1.5
	stroke.Parent = box

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Lbl"
	lbl.Size = UDim2.new(1, 0, 0, 15)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0.2
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 10
	lbl.Text = title
	lbl.Parent = bb

	espList[id] = bb
	return bb
end

local Screen = Instance.new("ScreenGui")
Screen.ResetOnSpawn = false
Screen.IgnoreGuiInset = true
Screen.DisplayOrder = 999999
pcall(function() Screen.Parent = getGuiParent() end)

local function makeFlagKey(labelText, pos, activeColor, getter, setter, onChange)
	local btn = Instance.new("TextButton")
	btn.Name = labelText
	btn.Size = UDim2.new(0, 76, 0, 40)
	btn.Position = pos
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	btn.Active = true
	btn.Draggable = true
	btn.Visible = false
	btn.Parent = Screen
	pcall(function()
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke", btn)
		stroke.Color = activeColor
		stroke.Thickness = 1.5
	end)

	local function refresh()
		local on = getter()
		btn.Text = labelText .. ": " .. (on and "ON" or "OFF")
		btn.BackgroundColor3 = on and activeColor or Color3.fromRGB(25, 25, 30)
	end

	btn.MouseButton1Click:Connect(function()
		local nextVal = not getter()
		setter(nextVal)
		if onChange then onChange(nextVal) end
		refresh()
		syncModeUI()
	end)

	table.insert(uiSetters, refresh)
	return btn, refresh
end

local AimBtn = makeFlagKey("AIM", UDim2.new(0.86, 0, 0.55, 0), Color3.fromRGB(45, 200, 110), function() return Config.AimActive end, function(v) Config.AimActive = v end)
local AuraBtn = makeFlagKey("AURA", UDim2.new(0.68, 0, 0.65, 0), Color3.fromRGB(240, 140, 35), function() return Config.KillAura end, function(v) Config.KillAura = v end)
local TrigBtn = makeFlagKey("TRIG", UDim2.new(0.77, 0, 0.65, 0), Color3.fromRGB(185, 80, 255), function() return Config.TriggerBot end, function(v) Config.TriggerBot = v end)

local TpBtn = Instance.new("TextButton")
TpBtn.Name = "TP"
TpBtn.Size = UDim2.new(0, 76, 0, 40)
TpBtn.Position = UDim2.new(0.86, 0, 0.65, 0)
TpBtn.TextColor3 = Color3.new(1, 1, 1)
TpBtn.Font = Enum.Font.GothamBold
TpBtn.TextSize = 10
TpBtn.Text = "TP"
TpBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 240)
TpBtn.Active = true
TpBtn.Draggable = true
TpBtn.Visible = false
TpBtn.Parent = Screen
pcall(function()
	Instance.new("UICorner", TpBtn).CornerRadius = UDim.new(0, 8)
	local tpStroke = Instance.new("UIStroke", TpBtn)
	tpStroke.Color = Color3.fromRGB(110, 190, 255)
	tpStroke.Thickness = 1.5
end)
TpBtn.MouseButton1Click:Connect(function()
	teleportToPlayerName(Config.SelectedTpPlayer)
end)

local NearestTpBtn = Instance.new("TextButton")
NearestTpBtn.Name = "E-TP"
NearestTpBtn.Size = UDim2.new(0, 76, 0, 40)
NearestTpBtn.Position = UDim2.new(0.86, 0, 0.75, 0)
NearestTpBtn.TextColor3 = Color3.new(1, 1, 1)
NearestTpBtn.Font = Enum.Font.GothamBold
NearestTpBtn.TextSize = 10
NearestTpBtn.Text = "E-TP"
NearestTpBtn.BackgroundColor3 = Color3.fromRGB(20, 175, 165)
NearestTpBtn.Active = true
NearestTpBtn.Draggable = true
NearestTpBtn.Visible = false
NearestTpBtn.Parent = Screen
pcall(function()
	Instance.new("UICorner", NearestTpBtn).CornerRadius = UDim.new(0, 8)
	local eTpStroke = Instance.new("UIStroke", NearestTpBtn)
	eTpStroke.Color = Color3.fromRGB(110, 240, 225)
	eTpStroke.Thickness = 1.5
end)
NearestTpBtn.MouseButton1Click:Connect(function()
	teleportToNearestTarget()
end)
local function isValidPart(part, model)
	return part ~= nil
		and part:IsA("BasePart")
		and part.Parent ~= nil
		and model ~= nil
		and model.Parent ~= nil
end

local function getAimPart(char)
	if not char then return nil end
	local chosen = char:FindFirstChild(Config.Part)
	if chosen and chosen:IsA("BasePart") then
		return chosen
	end
	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

local function getCandidateParts(model)
	local parts = {}
	if not model then return parts end
	local preferred = getAimPart(model)
	if isValidPart(preferred, model) then
		table.insert(parts, preferred)
	end
	for _, name in ipairs({
		"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso",
		"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
		"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
		"Left Arm", "Right Arm", "Left Leg", "Right Leg"
	}) do
		local p = model:FindFirstChild(name)
		if isValidPart(p, model) and p ~= preferred then
			table.insert(parts, p)
		end
	end
	if #parts == 0 then
		for _, d in ipairs(model:GetDescendants()) do
			if isValidPart(d, model) then
				table.insert(parts, d)
				break
			end
		end
	end
	return parts
end

local function isGlassOrPassable(instance)
	if not instance or not instance:IsA("BasePart") then return true end
	if instance.Material == Enum.Material.Glass then
		return true
	end
	local lowerName = string.lower(instance.Name)
	if string.find(lowerName, "glass", 1, true) or string.find(lowerName, "cam", 1, true) or string.find(lowerName, "window", 1, true) then
		if instance.Transparency >= 0.25 then
			return true
		end
	end
	return false
end

local function findVisiblePart(cam, target)
	if not target or not isValidPart(target.part, target.model) then
		return nil
	end
	local origin = cam.CFrame.Position
	local candidates = getCandidateParts(target.model)

	for _, part in ipairs(candidates) do
		local toPart = part.Position - origin
		local dist = toPart.Magnitude
		if dist > 0.5 and dist <= 900 then
			local excludeList = {}
			if LocalPlayer.Character then
				table.insert(excludeList, LocalPlayer.Character)
			end
			local blocked = false
			local dirUnit = toPart.Unit

			for _ = 1, 6 do
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = excludeList
				params.IgnoreWater = true

				local hit = workspace:Raycast(origin, dirUnit * (dist + 1), params)
				if not hit or not hit.Instance then
					return part
				end
				if hit.Instance:IsDescendantOf(target.model) then
					return part
				end
				if isGlassOrPassable(hit.Instance) then
					table.insert(excludeList, hit.Instance)
				else
					blocked = true
					break
				end
			end

			if not blocked then
				return part
			end
		end
	end

	return nil
end

local function scanTargets()
	local myChar = LocalPlayer.Character
	local list = {}
	local added = {}

	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if plr ~= LocalPlayer and char and char.Parent then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local part = getAimPart(char)
			if hum and hum.Health > 0 and isValidPart(part, char) then
				added[char] = true
				table.insert(list, {
					id = "plr_" .. tostring(plr.UserId),
					name = plr.DisplayName,
					model = char,
					part = part,
					isPlayer = true,
					player = plr
				})
			end
		end
	end

	local npcCount = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if npcCount >= 60 then break end
		if obj:IsA("Model") and obj ~= myChar and not added[obj] and not Players:GetPlayerFromCharacter(obj) then
			local hum = obj:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local part = getAimPart(obj)
				if isValidPart(part, obj) then
					added[obj] = true
					npcCount = npcCount + 1
					table.insert(list, {
						id = "npc_" .. tostring(obj:GetDebugId()),
						name = "[BOT] " .. obj.Name,
						model = obj,
						part = part,
						isPlayer = false,
						player = nil
					})
				end
			end
		end
	end

	return list
end

local function lockCam(part)
	local cam = workspace.CurrentCamera
	if not cam or not part or not part:IsA("BasePart") or not part.Parent then
		return
	end
	local targetPos = part.Position
	local camPos = cam.CFrame.Position
	if (targetPos - camPos).Magnitude <= 0.5 then
		return
	end
	pcall(function()
		if cam.CameraType == Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Custom
		end
		local goal = CFrame.lookAt(camPos, targetPos)
		cam.CFrame = Config.Smooth >= 0.99 and goal or cam.CFrame:Lerp(goal, Config.Smooth)
	end)
end

local function activateEquippedTool()
	local char = LocalPlayer.Character
	if not char then return end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool and tool.Parent == char then
		pcall(function()
			tool:Activate()
		end)
	end
end

local function applyNoRecoil(cam, activeAimPart)
	if not Config.NoRecoil or not cam or activeAimPart then
		prevCamLook = cam and cam.CFrame.LookVector or nil
		return
	end

	local currentLook = cam.CFrame.LookVector
	if prevCamLook then
		local dy = currentLook.Y - prevCamLook.Y
		if dy > 0.012 then
			local correctedLook = Vector3.new(currentLook.X, prevCamLook.Y + dy * 0.25, currentLook.Z).Unit
			local pos = cam.CFrame.Position
			cam.CFrame = CFrame.new(pos, pos + correctedLook)
			currentLook = cam.CFrame.LookVector
		end
	end
	prevCamLook = currentLook
end

local function isTargetUnderCenter(cam, targets)
	local origin = cam.CFrame.Position
	local dir = cam.CFrame.LookVector * 500
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if LocalPlayer.Character then
		params.FilterDescendantsInstances = {LocalPlayer.Character}
	end
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, dir, params)
	if not result or not result.Instance then
		return false
	end

	for _, t in ipairs(targets) do
		if not (t.isPlayer and isTeammate(t.player)) and result.Instance:IsDescendantOf(t.model) then
			return true
		end
	end
	return false
end

local function loadRayfieldSafe()
	local urls = {
		"https://sirius.menu/rayfield",
		"https://raw.githubusercontent.com/shlexware/Rayfield/main/source"
	}
	for _, url in ipairs(urls) do
		local okCode, code = pcall(function()
			return game:HttpGet(url)
		end)
		if okCode and type(code) == "string" and #code > 100 then
			local okFn, fn = pcall(loadstring, code)
			if okFn and type(fn) == "function" then
				local okLib, lib = pcall(fn)
				if okLib and type(lib) == "table" and lib.CreateWindow then
					return lib
				end
			end
		end
	end
	return nil
end

local function buildFallbackMenu()
	local parent = getGuiParent()
	if not parent then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "MobileFallbackMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999998
	gui.Parent = parent

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 86, 0, 34)
	toggleBtn.Position = UDim2.new(0.03, 0, 0.25, 0)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	toggleBtn.TextColor3 = Color3.new(1, 1, 1)
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 11
	toggleBtn.Text = "MENU"
	toggleBtn.Active = true
	toggleBtn.Draggable = true
	toggleBtn.Parent = gui
	pcall(function() Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8) end)

	local panel = Instance.new("ScrollingFrame")
	panel.Size = UDim2.new(0, 230, 0, 290)
	panel.Position = UDim2.new(0.14, 0, 0.22, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 4
	panel.CanvasSize = UDim2.new(0, 0, 0, 680)
	panel.Active = true
	panel.Draggable = true
	panel.Visible = true
	panel.Parent = gui
	pcall(function() Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10) end)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = panel

	toggleBtn.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)

	local function addToggle(text, getter, setter, onChange)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 30)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 10
		b.Parent = panel
		pcall(function() Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6) end)

		local function refresh()
			local on = getter()
			b.Text = text .. ": " .. (on and "AÇIK" or "KAPALI")
			b.BackgroundColor3 = on and Color3.fromRGB(45, 165, 95) or Color3.fromRGB(42, 42, 50)
		end

		b.MouseButton1Click:Connect(function()
			local nv = not getter()
			setter(nv)
			if onChange then onChange(nv) end
			refresh()
			syncModeUI()
		end)

		table.insert(uiSetters, refresh)
		refresh()
	end

	local function addAction(text, fn)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 30)
		b.BackgroundColor3 = Color3.fromRGB(45, 110, 195)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 10
		b.Text = text
		b.Parent = panel
		pcall(function() Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6) end)
		b.MouseButton1Click:Connect(fn)
	end

	addToggle("ESP", function() return Config.Esp end, function(v) Config.Esp = v end, function(v) if not v then clearEsp() end end)
	addToggle("Aimbot (Açıkta)", function() return Config.AimActive end, function(v) Config.AimActive = v end)
	addToggle("Takım Kontrolü", function() return Config.TeamCheck end, function(v) Config.TeamCheck = v end)
	addToggle("No Recoil", function() return Config.NoRecoil end, function(v) Config.NoRecoil = v end)
	addToggle("Kill Aura", function() return Config.KillAura end, function(v) Config.KillAura = v end)
	addToggle("Trigger Bot", function() return Config.TriggerBot end, function(v) Config.TriggerBot = v end)
	addToggle("Auto Swing", function() return Config.AutoSwing end, function(v) Config.AutoSwing = v end)
	addToggle("AIM Tuşu", function() return Config.ShowAimBtn end, function(v) Config.ShowAimBtn = v end)
	addToggle("TP Tuşu", function() return Config.ShowTpBtn end, function(v) Config.ShowTpBtn = v end)
	addToggle("E-TP Tuşu", function() return Config.ShowNearestTpBtn end, function(v) Config.ShowNearestTpBtn = v end)
	addToggle("AURA Tuşu", function() return Config.ShowAuraBtn end, function(v) Config.ShowAuraBtn = v end)
	addToggle("TRIG Tuşu", function() return Config.ShowTrigBtn end, function(v) Config.ShowTrigBtn = v end)
	addToggle("No Lag", function() return Config.NoLag end, function(v) Config.NoLag = v end, function(v) if v then applyNoLag() end end)
	addToggle("Ultra Patates", function() return Config.UltraPotato end, function(v) Config.UltraPotato = v end, function(v) if v then applyUltraPotato() end end)
	addAction("En Yakına Işınlan (E-TP)", teleportToNearestTarget)
	addAction("Hedef Parça Değiştir (" .. Config.Part .. ")", function()
		Config.Part = (Config.Part == "Head") and "HumanoidRootPart" or "Head"
	end)
	addAction("E-TP Modu Değiştir (" .. Config.NearestTpMode .. ")", function()
		if Config.NearestTpMode == "Hepsi" then
			Config.NearestTpMode = "Oyuncular"
		elseif Config.NearestTpMode == "Oyuncular" then
			Config.NearestTpMode = "Bot"
		else
			Config.NearestTpMode = "Hepsi"
		end
	end)
end
RunService.RenderStepped:Connect(function()
	pcall(function()
		AimBtn.Visible = Config.ShowAimBtn
		TpBtn.Visible = Config.ShowTpBtn
		NearestTpBtn.Visible = Config.ShowNearestTpBtn
		AuraBtn.Visible = Config.ShowAuraBtn
		TrigBtn.Visible = Config.ShowTrigBtn
	end)

	local cam = workspace.CurrentCamera
	local myRoot = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Head"))
	if not cam or not myRoot then return end

	local now = os.clock()
	if now - lastScanTime >= 0.25 then
		lastScanTime = now
		pcall(function()
			cachedTargets = scanTargets()
		end)
	end

	if now - lastOptTime >= 2.0 then
		lastOptTime = now
		pcall(function()
			if Config.UltraPotato then
				applyUltraPotato()
			elseif Config.NoLag then
				applyNoLag()
			end
		end)
	end

	local chosenPart = nil
	local bestStuds = math.huge
	local auraPart = nil
	local auraStuds = Config.AuraRange
	local seen = {}

	for _, t in ipairs(cachedTargets) do
		if isValidPart(t.part, t.model) then
			local studs = (t.part.Position - myRoot.Position).Magnitude
			local teammate = t.isPlayer and isTeammate(t.player)

			if Config.Esp and studs <= Config.MaxEspStuds then
				seen[t.id] = true
				pcall(function()
					local bb = getEsp(t.id, t.part, t.name)
					local lbl = bb and bb:FindFirstChild("Lbl")
					if lbl then
						local tag = teammate and " [TAKIM]" or ""
						lbl.Text = t.name .. tag .. " [" .. math.floor(studs) .. "s]"
					end
				end)
			end

			if Config.AimActive and not teammate and studs > 0.5 and studs < bestStuds then
				local visPart = findVisiblePart(cam, t)
				if visPart then
					bestStuds = studs
					chosenPart = visPart
				end
			end

			if Config.KillAura and not teammate and studs > 0.5 and studs <= auraStuds then
				auraStuds = studs
				auraPart = t.part
			end
		end
	end

	if not Config.Esp then
		if next(espList) then clearEsp() end
	else
		for id, bb in pairs(espList) do
			if not seen[id] then
				pcall(function() bb:Destroy() end)
				espList[id] = nil
			end
		end
	end

	if Config.AimActive and chosenPart then
		lockCam(chosenPart)
	end

	pcall(function()
		applyNoRecoil(cam, Config.AimActive and chosenPart or nil)
	end)

	pcall(function()
		if Config.KillAura and auraPart then
			local rootPos = myRoot.Position
			local lookGoal = CFrame.lookAt(rootPos, Vector3.new(auraPart.Position.X, rootPos.Y, auraPart.Position.Z))
			myRoot.CFrame = myRoot.CFrame:Lerp(lookGoal, 0.45)
			if now - lastSwingTime >= Config.SwingDelay then
				lastSwingTime = now
				activateEquippedTool()
			end
		elseif Config.AutoSwing and (now - lastSwingTime >= Config.SwingDelay) then
			lastSwingTime = now
			activateEquippedTool()
		end

		if Config.TriggerBot and (now - lastTriggerTime >= 0.08) then
			if isTargetUnderCenter(cam, cachedTargets) then
				lastTriggerTime = now
				activateEquippedTool()
			end
		end
	end)
end)

task.spawn(function()
	if not game:IsLoaded() then
		pcall(function() game.Loaded:Wait() end)
	end
	LocalPlayer:WaitForChild("PlayerGui", 5)
	task.wait(0.25)

	local Rayfield = loadRayfieldSafe()
	if not Rayfield then
		buildFallbackMenu()
		return
	end

	local Win = nil
	pcall(function()
		Win = Rayfield:CreateWindow({
			Name = "ESP & Aimbot",
			ConfigurationSaving = { Enabled = false },
			KeySystem = false
		})
	end)
	if not Win then
		buildFallbackMenu()
		return
	end

	local Main = Win:CreateTab("Ana", 4483362458)
	Main:CreateToggle({
		Name = "ESP",
		CurrentValue = false,
		Callback = function(v)
			Config.Esp = v
			if not v then clearEsp() end
		end
	})

	local tAim = Main:CreateToggle({
		Name = "Aimbot (Açıkta)",
		CurrentValue = false,
		Callback = function(v)
			if isSyncingUI then return end
			Config.AimActive = v
			syncModeUI()
		end
	})

	table.insert(uiSetters, function()
		pcall(function() tAim:Set(Config.AimActive) end)
	end)

	local Combat = Win:CreateTab("Savaş", 4483362458)
	Combat:CreateToggle({ Name = "No Recoil", CurrentValue = false, Callback = function(v) Config.NoRecoil = v end })
	Combat:CreateToggle({ Name = "Kill Aura", CurrentValue = false, Callback = function(v) Config.KillAura = v end })
	Combat:CreateSlider({ Name = "Kill Aura Menzili", Range = {5, 50}, Increment = 1, Suffix = "s", CurrentValue = 18, Callback = function(v) Config.AuraRange = v end })
	Combat:CreateToggle({ Name = "Trigger Bot", CurrentValue = false, Callback = function(v) Config.TriggerBot = v end })
	Combat:CreateToggle({ Name = "Auto Swing", CurrentValue = false, Callback = function(v) Config.AutoSwing = v end })
	Combat:CreateSlider({ Name = "Saldırı Hızı (Gecikme)", Range = {5, 60}, Increment = 5, Suffix = "ms x10", CurrentValue = 14, Callback = function(v) Config.SwingDelay = v / 100 end })

	local Keys = Win:CreateTab("Tuşlar", 4483362458)
	Keys:CreateToggle({ Name = "AIM Tuşunu Göster/Gizle", CurrentValue = false, Callback = function(v) Config.ShowAimBtn = v end })
	Keys:CreateToggle({ Name = "TP Tuşunu Göster/Gizle", CurrentValue = false, Callback = function(v) Config.ShowTpBtn = v end })
	Keys:CreateToggle({ Name = "E-TP Tuşunu Göster/Gizle", CurrentValue = false, Callback = function(v) Config.ShowNearestTpBtn = v end })
	Keys:CreateToggle({ Name = "AURA Tuşunu Göster/Gizle", CurrentValue = false, Callback = function(v) Config.ShowAuraBtn = v end })
	Keys:CreateToggle({ Name = "TRIG Tuşunu Göster/Gizle", CurrentValue = false, Callback = function(v) Config.ShowTrigBtn = v end })
	Keys:CreateSlider({ Name = "Kilit Hızı", Range = {5, 100}, Increment = 5, CurrentValue = 100, Callback = function(v) Config.Smooth = v / 100 end })

	local Extra = Win:CreateTab("Ekstra", 4483362458)
	Extra:CreateToggle({
		Name = "Takım Kontrolü (Team Check)",
		CurrentValue = true,
		Callback = function(v)
			Config.TeamCheck = v
		end
	})
	Extra:CreateDropdown({
		Name = "Hedef Parça",
		Options = {"Head", "HumanoidRootPart"},
		CurrentOption = {"Head"},
		MultipleOptions = false,
		Callback = function(opt)
			Config.Part = opt[1] or "Head"
		end
	})
	Extra:CreateDropdown({
		Name = "E-TP Hedef Türü",
		Options = {"Hepsi", "Oyuncular", "Bot"},
		CurrentOption = {"Hepsi"},
		MultipleOptions = false,
		Callback = function(opt)
			Config.NearestTpMode = opt and opt[1] or "Hepsi"
		end
	})
	Extra:CreateSlider({
		Name = "ESP Maksimum Mesafe",
		Range = {50, 2000},
		Increment = 50,
		Suffix = "s",
		CurrentValue = 500,
		Callback = function(v)
			Config.MaxEspStuds = v
		end
	})

	local initPlayers = getPlayerNamesList()
	Config.SelectedTpPlayer = initPlayers[1]

	tpDropdownRef = Extra:CreateDropdown({
		Name = "Oyuncu Seç",
		Options = initPlayers,
		CurrentOption = { initPlayers[1] },
		MultipleOptions = false,
		Callback = function(opt)
			Config.SelectedTpPlayer = opt and opt[1] or nil
		end
	})

	Extra:CreateButton({
		Name = "Teleport",
		Callback = function()
			teleportToPlayerName(Config.SelectedTpPlayer)
		end
	})

	Extra:CreateToggle({
		Name = "No Lag",
		CurrentValue = false,
		Callback = function(v)
			Config.NoLag = v
			if v then applyNoLag() end
		end
	})
	Extra:CreateToggle({
		Name = "Ultra Patates Modu",
		CurrentValue = false,
		Callback = function(v)
			Config.UltraPotato = v
			if v then applyUltraPotato() end
		end
	})
end)

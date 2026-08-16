local Repository = "https://raw.githubusercontent.com/longhazem/libba/main/"

local function GetLoadstringSource(Url)
	local function tryRequest(fn, args)
		if not fn then return nil end
		local ok, r = pcall(fn, args)
		if ok and r and r.Body and typeof(r.Body) == "string" then return r.Body end
	end
	local body = tryRequest(request, {Url=Url,Method="GET"})
		or tryRequest(http_request, {Url=Url,Method="GET"})
		or tryRequest(syn and syn.request, {Url=Url,Method="GET"})
		or tryRequest(fluxus and fluxus.request, {Url=Url,Method="GET"})
	if not body then
		local ok, r = pcall(function() return game:HttpGet(Url) end)
		if ok and typeof(r) == "string" then body = r
		elseif ok and typeof(r) == "Instance" then
			local iok, src = pcall(function() return r.Source end)
			if iok and typeof(src) == "string" then body = src end
		end
	end
	if not body then error("[TokaiHub] HTTP failed: " .. tostring(Url), 2) end
	if body:match("^429") or body:lower():match("rate limit") then
		warn("[TokaiHub] Rate limit — cho 10s roi thu lai")
		task.wait(10)
		return GetLoadstringSource(Url)
	end
	if body:match("^<!DOCTYPE") or body:match("^<html") then
		error("[TokaiHub] Server tra ve HTML — URL sai hoac repo loi", 2)
	end
	return body
end

local function PatchObsidianSource(Source)
	Source = Source:gsub("Instance%[key%] = value", [[if key ~= "NumSides" then pcall(function() Instance[key] = value end) end]])
	return Source
end

local function LoadRemote(Url)
	local Source = GetLoadstringSource(Url)
	if string.find(Url, "/source.lua", 1, true) then Source = PatchObsidianSource(Source) end
	local Chunk, LoadError = loadstring(Source)
	if not Chunk then error("loadstring failed for " .. tostring(Url) .. ": " .. tostring(LoadError), 2) end
	return Chunk()
end

local Library = LoadRemote(Repository .. "source.lua")
local ThemeManager = LoadRemote(Repository .. "addons/ThemeManager.lua")
local SaveManager = LoadRemote(Repository .. "addons/SaveManager.lua")

local Options = getgenv().Options or {}
local Toggles = getgenv().Toggles or {}

local MoonUI = { Scale = { Window = 1 } }
function MoonUI:SetTheme() end
function MoonUI:RefreshCurrentColor() end
function MoonUI:ConfigManager(Data) return Data or {} end
function MoonUI.newNotify()
	return { new = function(Data)
		local text = (Data and Data.Title) or "Tokaihub"
		if Data and (Data.Content or Data.Description) then text = text .. " — " .. (Data.Content or Data.Description) end
		pcall(function() Library:Notify(text, (Data and Data.Duration) or 5) end)
	end }
end

local function NormalizeUIString(Value, Fallback)
	if typeof(Value) == "EnumItem" then return Value.Name end
	if Value == nil then return Fallback end
	return tostring(Value)
end
local function NormalizeKey(Value, Fallback)
	if typeof(Value) == "EnumItem" then return Value.Name end
	if Value == nil then return Fallback or "None" end
	return tostring(Value)
end

local function WrapSection(Groupbox)
	local Section = {}
	function Section:AddToggle(Data)
		local Flag = NormalizeUIString(Data.Flag or Data.Name, "Toggle")
		local Toggle = Groupbox:AddToggle(Flag, { Text = NormalizeUIString(Data.Name or Flag, Flag), Default = Data.Default or false, Tooltip = Data.Tooltip })
		if Data.Callback then Toggle:OnChanged(Data.Callback) end
		return { Instance = Toggle, Link = { AddKeybind = function(_, KeyData)
			local KeyFlag = NormalizeUIString(KeyData.Flag or KeyData.Name or (Flag.."_Key"), Flag.."_Key")
			Toggle:AddKeyPicker(KeyFlag, { Default = NormalizeKey(KeyData.Default,"None"), Text = NormalizeUIString(KeyData.Name or "Keybind","Keybind"), Mode = NormalizeUIString(KeyData.Mode or "Toggle","Toggle"), NoUI = KeyData.NoUI or false, SyncToggleState = true })
			if KeyData.Callback and Options[KeyFlag] then Options[KeyFlag]:OnChanged(KeyData.Callback) end
			return Options[KeyFlag]
		end } }
	end
	function Section:AddSlider(Data)
		local Flag = NormalizeUIString(Data.Flag or Data.Name, "Slider")
		local Slider = Groupbox:AddSlider(Flag, { Text = NormalizeUIString(Data.Name or Flag, Flag), Default = Data.Default or Data.Min or 0, Min = Data.Min or 0, Max = Data.Max or 100, Rounding = Data.Rounding or 0, Suffix = Data.Suffix, Compact = Data.Compact or false })
		if Data.Callback then Slider:OnChanged(Data.Callback) end
		return Slider
	end
	function Section:AddDropdown(Data)
		local Flag = NormalizeUIString(Data.Flag or Data.Name, "Dropdown")
		local Dropdown = Groupbox:AddDropdown(Flag, { Text = NormalizeUIString(Data.Name or Flag, Flag), Values = Data.Values or {}, Default = Data.Default, Multi = Data.Multi or false, Tooltip = Data.Tooltip })
		if Data.Callback then Dropdown:OnChanged(Data.Callback) end
		return Dropdown
	end
	function Section:AddColorPicker(Data)
		local Flag = NormalizeUIString(Data.Flag or Data.Name, "ColorPicker")
		local Label = Groupbox:AddLabel(NormalizeUIString(Data.Name or Flag, Flag))
		Label:AddColorPicker(Flag, { Default = Data.Default or Color3.new(1,1,1) })
		if Data.Callback and Options[Flag] then Options[Flag]:OnChanged(Data.Callback) end
		return Options[Flag]
	end
	function Section:AddKeybind(Data)
		local Flag = NormalizeUIString(Data.Flag or Data.Name, "Keybind")
		local Label = Groupbox:AddLabel(NormalizeUIString(Data.Name or Flag, Flag))
		Label:AddKeyPicker(Flag, { Default = NormalizeKey(Data.Default,"None"), Text = NormalizeUIString(Data.Name or Flag, Flag), NoUI = Data.NoUI or false, Mode = NormalizeUIString(Data.Mode or "Toggle","Toggle") })
		if Data.Callback and Options[Flag] then Options[Flag]:OnChanged(Data.Callback) end
		return Options[Flag]
	end
	function Section:AddButton(Data)
		return Groupbox:AddButton(Data.Name or Data.Text or "Button", Data.Callback or Data.Func or function() end)
	end
	function Section:AddInput(Data)
		local Flag = NormalizeUIString(Data.Flag or Data.Name, "Input")
		local Input = Groupbox:AddInput(Flag, {
			Text = NormalizeUIString(Data.Name or Flag, Flag),
			Default = Data.Default or "",
			NumericOnly = Data.NumericOnly or false,
			Placeholder = Data.Placeholder or "",
			Tooltip = Data.Tooltip,
		})
		if Data.Callback then Input:OnChanged(Data.Callback) end
		return Input
	end
	return Section
end

local function WrapTab(Tab)
	return { DrawSection = function(_, Data)
		local Name = Data.Name or "Section"
		local Position = string.lower(Data.Position or "left")
		if Position == "right" then return WrapSection(Tab:AddRightGroupbox(Name))
		else return WrapSection(Tab:AddLeftGroupbox(Name)) end
	end }
end

function MoonUI.new(Data)
	local Window = Library:CreateWindow({ Title = "Tokaihub", Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })
	local SettingsTab
	local Wrapped = {
		Raw = Window,
		DrawTab = function(_, TabData)
			local Name = TabData.Name or "Tab"
			local Tab = Window:AddTab(Name)
			if Name == "Settings" or Name == "System" then SettingsTab = Tab end
			return WrapTab(Tab)
		end,
		DrawConfig = function(_, ConfigData)
			SettingsTab = SettingsTab or Window:AddTab("Settings")
			ThemeManager:SetLibrary(Library); SaveManager:SetLibrary(Library)
			SaveManager:IgnoreThemeSettings(); SaveManager:SetIgnoreIndexes({"MenuKeybind"})
			ThemeManager:SetFolder("Tokaihub"); SaveManager:SetFolder("Tokaihub/specific-game")
			if SaveManager.SetSubFolder then SaveManager:SetSubFolder("specific-place") end
			SaveManager:BuildConfigSection(SettingsTab); ThemeManager:ApplyToTab(SettingsTab)
			SaveManager:LoadAutoloadConfig()
			return { Init = function() end }
		end,
		SetMenuKey = function(_, Key) task.defer(function() Library.ToggleKeybind = getgenv().Options and getgenv().Options.MenuKeybind end) end,
		Unload = function() Library:Unload() end,
	}
	return Wrapped
end

-- Singleton cleanup
local scriptId = tick()
getgenv().Moon_ScriptId = scriptId
if getgenv().Moon_Connections then
	for _, conn in pairs(getgenv().Moon_Connections) do if conn then pcall(function() conn:Disconnect() end) end end
end
getgenv().Moon_Connections = {}

-- Localize
local Vector3_new = Vector3.new; local Vector2_new = Vector2.new; local CFrame_new = CFrame.new
local Color3_new = Color3.new; local Color3_fromHSV = Color3.fromHSV
local RaycastParams_new = RaycastParams.new
local math_floor = math.floor; local math_clamp = math.clamp; local math_abs = math.abs
local pairs = pairs; local ipairs = ipairs; local type = type; local tick = tick
local os_clock = os.clock; local string_format = string.format; local rawget = rawget
local pcall = pcall; local tostring = tostring; local getgenv = getgenv
local getgc = getgc; local filtergc = filtergc
local Drawing = Drawing; local Drawing_new = Drawing and Drawing.new

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Ballistic solver
local SolveLead = function(origin, target, targetVelocity, projectileSpeed, gravity)
	local displacement = target - origin
	local vSq = projectileSpeed * projectileSpeed
	local g = gravity
	local x = Vector3_new(displacement.X, 0, displacement.Z).Magnitude
	local y = displacement.Y
	local time = x / projectileSpeed
	local predictedTarget = target + (targetVelocity * time)
	displacement = predictedTarget - origin
	x = Vector3_new(displacement.X, 0, displacement.Z).Magnitude
	y = displacement.Y
	local root = vSq * vSq - g * (g * x * x + 2 * y * vSq)
	if root < 0 then return predictedTarget + Vector3_new(0, 0.5 * g * time * time, 0), time end
	local rootSqrt = math.sqrt(root)
	local theta = math.atan((vSq - rootSqrt) / (g * x))
	local vx = projectileSpeed * math.cos(theta)
	local vy = projectileSpeed * math.sin(theta)
	if vx <= 0 then return predictedTarget, time end
	local realTime = x / vx
	local drop = 0.5 * g * realTime * realTime
	return predictedTarget + Vector3_new(0, drop, 0), realTime
end

local WeaponManager = { Equipped = nil, Logic = {}, Visuals = {}, LastScan = 0, ScanCooldown = 1.0, Connection = nil }
local ESPElements = {}; local CurrentFrameId = 0; local ESPEnabled = false
local ActorManager = { Enemies = {}, Teammates = {}, Vehicles = {}, _lastMapUpdate = 0, _lastListUpdate = 0, _lastTargetUpdate = 0, Initialized = false, SelectedTarget = nil, SelectedActor = nil }

local SetupHooks, EnableSpeedController, GetSecureContainer, DetectMapType
local SecureESPContainer = nil; local RefreshFirearmControllers

local InventoryService, ReplicatorService, ClientService, WorldService, BulletService
local CharacterController, ControllerService, FirearmInventoryClass, ActorClass, Recoiler, EffectsService
local CalibersTable, VehicleService, FirearmInventory, EnvironmentService, CharacterCamera, TurretController

local Config = {
	ShowPlayers = true, ShowZombies = true, ShowNPCs = true, ShowSquadMembers = false,
	ShowVehicles = false, VehicleColor = Color3_new(0,1,1), VehicleHealthColor = Color3_new(0,1,0), IgnoreLocalVehicle = true,
	UseBoxESP = true, SimpleESP = false, UseHighlight = false, UseTracers = false,
	ShowNames = true, ShowDistance = true, ShowHealth = true, ShowWeaponInfo = true, BoxStyle = "Full",
	ShowVehicleBox = true, VehicleBoxStyle = "Full", ShowVehicleName = true, ShowVehicleHealth = true, VehicleHealthBarSide = "Bottom",
	TextScale = 1.20, DynamicTextScaling = true, MaxDistance = 2000,
	NoRecoil = false, NoSpread = false, UnlockFiremodes = false, CustomRPM = false, RPMValue = 800,
	SilentAim = false, SilentAimFOV = 100, SilentAimHitChance = 100, SilentAimTargetPart = "Head",
	RageMode = false, Rage_LookAt = false, Rage_FOV = 360, Rage_Range = 500, Rage_TargetPart = "Head",
	ShowFOV = false, Prediction = false, BulletDrop = false, ShowPrediction = false,
	PredictionColor = Color3.fromRGB(255,0,0), SmartTargetSwitch = false,
	InfStamina = false,
	AutoReload = false,
	Character_Fly = false, Character_FlySpeed = 50, Character_WalkSpeedEnabled = false, Character_WalkSpeed = 16,
	Character_SprintSpeedEnabled = false, Character_SprintSpeed = 25,
	TurretUnlockFiremodes = false, TurretNoRecoil = false, TurretNoSpread = false,
	AlwaysDay = false, NoFog = false, ThermalVision = false, NightVision = false,
	BoxColor = nil, HealthBarColor = nil,
	PlayerColor = Color3_new(1,0.65,0), TeammateColor = Color3_new(0,1,0), ZombieColor = Color3_new(1,0,0),
	NPCColor = Color3_new(1,1,0), SquadColor = Color3_new(0,1,0), TracerColor = Color3_new(1,1,1),
	ZombieColors = { [1]=Color3_new(0.58,0.29,0), [2]=Color3_new(1,1,0), [3]=Color3_new(1,0,0), [4]=Color3_new(0.58,0,1) },
	BoxScale = 1.0, HealthBarSide = "Left", UseHealthGradient = true,
	AutoDetectMap = true, CurrentMapType = "Unknown", CurrentMapName = "Unknown",
	FPS_NoRain = false, FPS_NoEffects = false, FPS_NoShells = false, FPS_NoLensFlare = false, FPS_LowQuality = false,
	VehicleFly_Enabled = false, VehicleFly_Speed = 100,
	VehicleFly_ToggleKey = Enum.KeyCode.X, VehicleFly_UpKey = Enum.KeyCode.E, VehicleFly_DownKey = Enum.KeyCode.Q
}

-- Vehicle Fly System
local VehicleFly = { HooksApplied = false }

local function ApplyVehicleFly(vehicle, dt, originalUpdate)
	if not Config.VehicleFly_Enabled or not vehicle.Controlling then return originalUpdate(vehicle, dt) end
	if not Camera then return originalUpdate(vehicle, dt) end
	local moveDir = Vector3_new()
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
	if UserInputService:IsKeyDown(Config.VehicleFly_UpKey) then moveDir = moveDir + Vector3_new(0,1,0) end
	if UserInputService:IsKeyDown(Config.VehicleFly_DownKey) then moveDir = moveDir - Vector3_new(0,1,0) end
	if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end
	local currentCF = vehicle.CFrame or (vehicle.Hitbox and vehicle.Hitbox.CFrame) or CFrame_new()
	local newPos = currentCF.Position + (moveDir * Config.VehicleFly_Speed * dt)
	local newCF = CFrame.lookAt(newPos, newPos + Camera.CFrame.LookVector)
	vehicle.CFrame = newCF
	if vehicle.Hitbox then vehicle.Hitbox.CFrame = newCF end
	pcall(function()
		if ControllerService and ControllerService.Controller then
			local ctrl = ControllerService.Controller
			if ctrl._vehicle == vehicle and ctrl._solver and ctrl._solver.SetState then
				ctrl._solver:SetState(newCF, Vector3_new(), Vector3_new(), vehicle.ComponentReplicates)
			end
		end
	end)
	pcall(function()
		if ReplicatorService and ReplicatorService.LocalActor then
			ReplicatorService.LocalActor.SimulatedPosition = newCF.Position
		end
	end)
	return newCF, vehicle.Hitbox, {}
end

function VehicleFly.HookVehicles()
	if VehicleFly.HooksApplied then return end
	for _, tbl in pairs(getgc(true)) do
		if type(tbl) == "table" and rawget(tbl, "Update") and not tbl._FlyHooked then
			if rawget(tbl, "SetRPM") or rawget(tbl, "_updateLightModes") then
				local old = tbl.Update
				tbl.Update = function(self, dt) return ApplyVehicleFly(self, dt, old) end
				tbl._FlyHooked = true
			end
		end
	end
	VehicleFly.HooksApplied = true
end

function VehicleFly.Toggle()
	Config.VehicleFly_Enabled = not Config.VehicleFly_Enabled
	print("[Vehicle Fly]", Config.VehicleFly_Enabled and "ENABLED" or "DISABLED")
end

local Places = {
	["Menu"]={16173503753,2916899287}, ["CM_Mission1"]={83829699029749,4843465225},
	["OW_Ronograd"]={95595459346841,3701546109}, ["OW_Blank"]={0,5899968224},
	["HQ_Seychelles"]={139188553486454,14014688944}, ["PVP_Coast"]={99240342190508,5480112241},
	["PVP_Favela"]={123576346999506,5468388011}, ["PVP_NYC"]={71499109870653,3826587512},
	["PVP_Tokyo"]={125537938344868,4524359706}, ["PVP_Office"]={113296614204646,5289429734},
	["PVP_Blank"]={0,10938546013}, ["ZMP_NYC"]={84460047957624,4747446334},
	["ZME_NYC"]={84460047957624,4747446334}
}

local gcCache = nil; local lastScan = 0; local lastCollections = nil

local function BulkScan()
	local now = tick()
	if gcCache and (now - lastScan) < 10 then
		return { ReplicatorService = ReplicatorService, BulletService = BulletService }, lastCollections
	end
	local startTime = os_clock()
	local success, res = pcall(function() return filtergc("table") end)
	if not success then success, res = pcall(function() return getgc(true) end) end
	if not success or type(res) ~= "table" then return end
	gcCache = res; lastScan = now
	local found = {}
	local collections = { FirearmInventoryClass={}, FirearmInventoryReplicator={}, FirearmInventory={}, TurretController={} }
	local count = 0
	for _, obj in pairs(res) do
		count = count + 1
		if count % 8000 == 0 then task.wait() end
		if type(obj) == "table" then
			if not found.ReplicatorService and rawget(obj,"Actors") and rawget(obj,"LocalActor") then found.ReplicatorService=obj
			elseif not found.BulletService and rawget(obj,"_multithreadSend") then found.BulletService=obj
			elseif not found.WorldService and rawget(obj,"InactiveWorld") then found.WorldService=obj
			elseif not found.ClientService and rawget(obj,"Clients") and rawget(obj,"LocalClient") then found.ClientService=obj
			elseif not found.VehicleService and rawget(obj,"Vehicles") and rawget(obj,"Changed") then found.VehicleService=obj
			elseif not found.EnvironmentService and rawget(obj,"RainDensity") and (rawget(obj,"_lights") or rawget(obj,"_clouds")) then found.EnvironmentService=obj
			elseif not found.InventoryService and rawget(obj,"Inventories") and (rawget(obj,"_hasRadio") or rawget(obj,"_droppedItems")) then found.InventoryService=obj
			elseif not found.CalibersTable and rawget(obj,"shotgun_12gauge_00buck") then found.CalibersTable=obj
			elseif not found.EffectsService and rawget(obj,"BulletLand") and rawget(obj,"BulletFired") then found.EffectsService=obj
			elseif not found.Network and rawget(obj,"FireServer") and rawget(obj,"_events") then found.Network=obj
			elseif rawget(obj,"SetCFrame") and rawget(obj,"SetVehicleGoal") then
				if rawget(obj,"__index")==obj or not rawget(obj,"Parent") then found.CharacterController=obj end
			elseif rawget(obj,"Equip") and rawget(obj,"Unequip") and rawget(obj,"Discharge") then found.FirearmInventoryClass=obj
			elseif rawget(obj,"Impulse") and rawget(obj,"TimeSkip") and rawget(obj,"GetCameraAdjustment") then found.Recoiler=obj
			elseif rawget(obj,"Update") and rawget(obj,"_updateLOD") then found.ActorClass=obj
			elseif rawget(obj,"Update") and rawget(obj,"Render") and rawget(obj,"Watch") then found.CharacterCamera=obj
			elseif rawget(obj,"_discharge") and rawget(obj,"Discharge") then found.TurretController=obj
			elseif rawget(obj,"_firearm") and rawget(obj,"_actor") then table.insert(collections.FirearmInventoryReplicator,obj)
			elseif rawget(obj,"_firearm") and rawget(obj,"_bulletsShot") then table.insert(collections.FirearmInventory,obj)
			elseif rawget(obj,"_turret") and rawget(obj,"_config") then table.insert(collections.TurretController,obj)
			end
		end
	end
	local function logService(name,obj) if obj then print(string_format("[BulkScan] Found %s",name)) return obj end end
	ReplicatorService = logService("ReplicatorService",found.ReplicatorService) or ReplicatorService
	BulletService = logService("BulletService",found.BulletService) or BulletService
	WorldService = logService("WorldService",found.WorldService) or WorldService
	ClientService = logService("ClientService",found.ClientService) or ClientService
	VehicleService = logService("VehicleService",found.VehicleService) or VehicleService
	EnvironmentService = logService("EnvironmentService",found.EnvironmentService) or EnvironmentService
	InventoryService = logService("InventoryService",found.InventoryService) or InventoryService
	CalibersTable = logService("CalibersTable",found.CalibersTable) or CalibersTable
	EffectsService = logService("EffectsService",found.EffectsService) or EffectsService
	CharacterController = logService("CharacterController",found.CharacterController) or CharacterController
	FirearmInventoryClass = logService("FirearmInventoryClass",found.FirearmInventoryClass) or FirearmInventoryClass
	Recoiler = logService("Recoiler",found.Recoiler) or Recoiler
	ActorClass = logService("ActorClass",found.ActorClass) or ActorClass
	TurretController = logService("TurretController",found.TurretController) or TurretController
	CharacterCamera = logService("CharacterCamera",found.CharacterCamera) or (shared.Engine and shared.Engine.CharacterCamera)
	FirearmInventory = collections.FirearmInventory; lastCollections = collections
	print(string_format("[BulkScan] Memory scan took: %.1fms",(os_clock()-startTime)*1000))
	return found, collections
end

local function FindService(serviceName)
	if not ReplicatorService then BulkScan() end
	if serviceName=="ReplicatorService" then return ReplicatorService
	elseif serviceName=="BulletService" then return BulletService
	elseif serviceName=="CharacterController" then return CharacterController
	elseif serviceName=="InventoryService" then return InventoryService end
	return nil
end

function GetMuzzlePosition()
	if WeaponManager.Equipped then
		local handler = WeaponManager.Equipped
		if handler._originalMuzzle then
			local success,cf = pcall(handler._originalMuzzle,handler)
			if success and cf then return cf.Position end
		elseif handler.GetMuzzleCFrame then
			local success,cf = pcall(handler.GetMuzzleCFrame,handler)
			if success and cf then return cf.Position end
		end
	end
	return Camera.CFrame.Position
end

function GetSecureContainer()
	if SecureESPContainer and SecureESPContainer.Parent then return SecureESPContainer end
	local function TryCreate(parent)
		local success,result = pcall(function()
			local f = parent:FindFirstChild("ESP_Cache")
			if not f then
				f = Instance.new("ScreenGui"); f.Name = "ESP_Cache"; f.ResetOnSpawn = false
				if (parent.Name=="CoreGui" or parent.Name=="RobloxGui") and type(syn)=="table" and syn.protect_gui then
					pcall(function() syn.protect_gui(f) end)
				end
				f.Parent = parent
			end
			return f
		end)
		if success and result then return result end; return nil
	end
	local s,hui = pcall(function() return gethui() end)
	if s and hui then local f=TryCreate(hui); if f then SecureESPContainer=f; return f end end
	local s2,core = pcall(function() return game:GetService("CoreGui") end)
	if s2 and core then local f=TryCreate(core); if f then SecureESPContainer=f; return f end end
	if LocalPlayer then
		local pGui = LocalPlayer:FindFirstChild("PlayerGui")
		if pGui then local f=TryCreate(pGui); if f then SecureESPContainer=f; return f end end
	end
	return nil
end

local AllControllersCache = { Visuals={}, Logic={} }

RefreshFirearmControllers = function(silent)
	if tick()-WeaponManager.LastScan < 0.2 then return end
	WeaponManager.LastScan = tick()
	local _,collections = BulkScan()
	if not collections then return end
	WeaponManager.Visuals = collections.FirearmInventoryReplicator
	WeaponManager.Logic = collections.FirearmInventory
	for _,t in ipairs(collections.TurretController) do table.insert(WeaponManager.Visuals,t) end
	if ReplicatorService and ReplicatorService.LocalActor then
		local myActor = ReplicatorService.LocalActor
		if myActor.Turret and type(myActor.Turret)=="table" and myActor.Turret._config then
			table.insert(WeaponManager.Visuals,myActor.Turret)
		end
	end
	AllControllersCache.Visuals = WeaponManager.Visuals
	AllControllersCache.Logic = WeaponManager.Logic
	FirearmInventory = WeaponManager.Logic
	if InventoryService and InventoryService.Equipped then
		WeaponManager.Equipped = InventoryService.Equipped.Handler
	end
end

local function GetEntityType(actor)
	if actor.Zombie==true then return "Zombie" end
	if actor.Owner and Players:GetPlayerByUserId(actor.Owner.UserId) then return "Player" end
	if actor.Owner or actor.OwnerName then return "NPC" end
	return "Unknown"
end


local function GetBulletDamage(caliber, distance, part)
	if not caliber or not caliber.Damage or not caliber.Dropoff then return 25 end
	local dmgTable = caliber.Damage[part or "Torso"] or caliber.Damage["Torso"] or {0}
	local dropoff = caliber.Dropoff
	local index = 1
	for i, d in ipairs(dropoff) do
		if distance <= d then
			index = i
			break
		end
		index = i
	end
	return dmgTable[index] or 0
end
local function IsTeammate(actor,cachedLocalSquad)
	if actor.Zombie==true then return false end
	local ownerPlayer = actor.Owner and Players:GetPlayerByUserId(actor.Owner.UserId)
	local isRealPlayer = ownerPlayer~=nil
	if isRealPlayer and (Config.CurrentMapName=="OW_Ronograd" or Config.CurrentMapName=="ZME_NYC") then return true end
	if isRealPlayer and ownerPlayer.Team and LocalPlayer.Team and ownerPlayer.Team==LocalPlayer.Team then return true end
	if isRealPlayer and cachedLocalSquad and cachedLocalSquad~="" then
		if ClientService and ClientService.Clients and ClientService.Clients[ownerPlayer] then
			return ClientService.Clients[ownerPlayer].Squad==cachedLocalSquad
		end
	end
	return false
end

local function GetSectorKey(position,sectorSize)
	return math.floor(position.X/sectorSize).."_"..math.floor(position.Z/sectorSize)
end

local function GetNearbySectors(playerSectorKey,sectorSize)
	local sectors={}
	local px,pz = playerSectorKey:match("(-?%d+)_(-?%d+)")
	if not px or not pz then return sectors end
	px,pz = tonumber(px),tonumber(pz)
	for dx=-1,1 do for dz=-1,1 do table.insert(sectors,(px+dx).."_"..(pz+dz)) end end
	return sectors
end

function ActorManager:Update(dt)
	if not ReplicatorService or not ReplicatorService.Actors then return end
	local now = tick()
	if not self._sectors then
		self._sectors={}; self._sectorSize=512; self._playerSector=nil; self._targetQueue={}; self._lastSectorUpdate=0
	end
	if not self._lastMapUpdate or (now-self._lastMapUpdate>10) then
		Config.CurrentMapType=DetectMapType(); self._lastMapUpdate=now
	end
	if not self._lastListUpdate or (now-self._lastListUpdate>0.5) then
		table.clear(self.Enemies); table.clear(self.Teammates); table.clear(self.Vehicles); table.clear(self._sectors)
		local localSquad=nil
		if ClientService and ClientService.LocalClient then localSquad=ClientService.LocalClient.Squad end
		for _,actor in pairs(ReplicatorService.Actors) do
			if not actor or not actor.Alive or not actor.Character then continue end
			if actor.Owner==LocalPlayer then continue end
			actor._entityType=GetEntityType(actor); actor._isTeammate=IsTeammate(actor,localSquad)
			if actor._isTeammate then
				table.insert(self.Teammates,actor)
			else
				table.insert(self.Enemies,actor)
				local actorPos=actor.Position or (actor.Character and actor.Character.PrimaryPart and actor.Character.PrimaryPart.Position)
				if actorPos then
					local sk=GetSectorKey(actorPos,self._sectorSize)
					if not self._sectors[sk] then self._sectors[sk]={} end
					table.insert(self._sectors[sk],actor)
				end
			end
		end
		if VehicleService and VehicleService.Vehicles then
			for _,veh in pairs(VehicleService.Vehicles) do table.insert(self.Vehicles,veh) end
		end
		self._playerSector=GetSectorKey(Camera.CFrame.Position,self._sectorSize)
		self._lastListUpdate=now; self.Initialized=true
	end
	if self.Initialized and (not self._lastTargetUpdate or (now-self._lastTargetUpdate>0.05)) then
		if GetCombatTarget then
			if Config.SilentAim or Config.ShowPrediction then
				local target,actor=GetCombatTarget("SilentAim")
				self.SelectedTarget_SA=target; self.SelectedActor_SA=actor
			else self.SelectedTarget_SA=nil; self.SelectedActor_SA=nil end
		end
		self._lastTargetUpdate=now
	end
	if self.Initialized and Config.RageMode and GetCombatTarget then
		local updateInterval=0.016
		if not self._lastRageUpdate or (now-self._lastRageUpdate>updateInterval) then
			local currentTarget=self.SelectedTarget_RB; local currentActor=self.SelectedActor_RB; local shouldRescan=true
			if currentTarget and currentTarget.Parent and currentActor and currentActor.Alive then
				local dist=currentActor.LOD_Distance
				if not dist or dist<=0 then
					local char=currentActor.Character
					if char and char.PrimaryPart then dist=(char.PrimaryPart.Position-Camera.CFrame.Position).Magnitude end
				end
				if dist and dist<(Config.Rage_Range*1.2) then shouldRescan=false end
			end
			if shouldRescan then
				local target,actor=GetCombatTarget("Rage")
				if target~=self.SelectedTarget_RB then
					if actor and self._rageBurst and self._rageBurst[actor.UID] then self._rageBurst[actor.UID].shots=0 end
				end
				self.SelectedTarget_RB=target; self.SelectedActor_RB=actor
			end
			self._lastRageUpdate=now
		end
	elseif not Config.RageMode then
		self.SelectedTarget_RB=nil; self.SelectedActor_RB=nil
	end
end

-- Wallcheck
local VisCache={}; local VisRayParams=RaycastParams.new()
VisRayParams.FilterType=Enum.RaycastFilterType.Exclude; VisRayParams.IgnoreWater=true
local LastVisCacheCleanup=0; local VisFilterTable=table.create(16)

local function IsIgnored(part)
	if not part then return false end
	if part.Material==Enum.Material.Glass then return true end
	if part.Name=="Glass" or part.Name=="Window" then return true end
	if part.Transparency>0.5 then return true end
	if CollectionService:HasTag(part,"GlassShatter") then return true end
	if CollectionService:HasTag(part,"Door") then return true end
	if CollectionService:HasTag(part,"Prefab") then
		local attr=part:GetAttribute("Prefab")
		if attr=="Glass" or attr=="Door" then return true end
	end
	if part.Parent and (part.Parent.Name=="Doors" or part.Parent.Name=="Glass") then return true end
	return false
end

local function IsVisible(targetActor,targetPart,origin,isPriority)
	if not targetPart or not targetPart.Parent then return false end
	local now=tick(); local uid=targetActor.UID
	if now-LastVisCacheCleanup>2 then
		for k,v in pairs(VisCache) do if now-v.last>5 then VisCache[k]=nil end end
		LastVisCacheCleanup=now
	end
	if not isPriority then
		if VisCache[uid] and (now-VisCache[uid].last<0.05) then return VisCache[uid].result end
	end
	if not isPriority then
		if getgenv().RaycastBudget<=0 then return false end
		getgenv().RaycastBudget=getgenv().RaycastBudget-1
	end
	local character=targetPart.Parent
	local originPos=origin or Camera.CFrame.Position
	local direction=(targetPart.Position-originPos)
	local dist=direction.Magnitude
	if not targetActor.ViewportOnScreen and (dist>100) then
		VisCache[uid]={result=false,last=now}; return false
	end
	table.clear(VisFilterTable); table.insert(VisFilterTable,Camera)
	if LocalPlayer.Character then table.insert(VisFilterTable,LocalPlayer.Character) end
	table.insert(VisFilterTable,character)
	if ReplicatorService and ReplicatorService.LocalActor then
		local myActor=ReplicatorService.LocalActor
		if myActor.Seat and myActor.Seat.Model then table.insert(VisFilterTable,myActor.Seat.Model) end
	end
	VisRayParams.FilterDescendantsInstances=VisFilterTable
	local isVisible=false
	local result=Workspace:Raycast(originPos,direction,VisRayParams)
	if not result then isVisible=true
	elseif result.Instance:IsDescendantOf(character) then isVisible=true
	else
		local penetrations=0; local dirUnit=direction.Unit
		while penetrations<2 do
			if not result then isVisible=true; break end
			local hitPart=result.Instance
			if hitPart:IsDescendantOf(character) then isVisible=true; break end
			if IsIgnored(hitPart) then
				table.insert(VisFilterTable,hitPart)
				VisRayParams.FilterDescendantsInstances=VisFilterTable
				penetrations=penetrations+1
				result=Workspace:Raycast(result.Position+(dirUnit*0.1),direction-(result.Position-originPos),VisRayParams)
			else isVisible=false; break end
		end
	end
	VisCache[uid]={result=isVisible,last=now}; return isVisible
end

GetCombatTarget = function(mode)
	getgenv().RaycastBudget=(mode=="Rage") and 20 or 12
	local cfg=Config
	local targetPartName=(mode=="Rage") and cfg.Rage_TargetPart or cfg.SilentAimTargetPart or "Head"
	local useFOV=(mode=="SilentAim")
	local fovLimit=cfg.SilentAimFOV; local fovLimitSq=fovLimit*fovLimit
	local maxDistance=(mode=="Rage") and cfg.Rage_Range or cfg.MaxDistance or 2000
	local checkOrigin=Camera.CFrame.Position
	local muzzle=GetMuzzlePosition(); if muzzle then checkOrigin=muzzle end
	if not ActorManager.Enemies or #ActorManager.Enemies==0 then return nil,nil end
	if mode=="Rage" and ActorManager.SelectedActor_RB then
		local activeActor=ActorManager.SelectedActor_RB
		if activeActor.Alive and activeActor.Character then
			local dist=activeActor.LOD_Distance
			if not dist or dist<=0 then dist=(activeActor.Position-checkOrigin).Magnitude end
			if dist<=maxDistance then
				local targetPart=activeActor.Parts and activeActor.Parts[targetPartName]
				if targetPart and IsVisible(activeActor,targetPart,checkOrigin,true) then return targetPart,activeActor end
			end
		end
		ActorManager.SelectedActor_RB=nil; ActorManager.SelectedTarget_RB=nil
	end
	local candidates=getgenv()._targetCandidates or table.create(64)
	table.clear(candidates); getgenv()._targetCandidates=candidates
	local now=tick(); local ignoredTargets=ActorManager._ignoredTargets
	local mouseX,mouseY
	if useFOV then local sc=Camera.ViewportSize/2; mouseX,mouseY=sc.X,sc.Y end
	local enemyList
	if mode=="Rage" and ActorManager._sectors and ActorManager._playerSector then
		enemyList={}
		local nearbySectors=GetNearbySectors(ActorManager._playerSector,ActorManager._sectorSize)
		for _,sectorKey in ipairs(nearbySectors) do
			local sectorEnemies=ActorManager._sectors[sectorKey]
			if sectorEnemies then for _,actor in ipairs(sectorEnemies) do table.insert(enemyList,actor) end end
		end
		if #enemyList==0 then enemyList=ActorManager.Enemies end
	else enemyList=ActorManager.Enemies end
	for _,actor in pairs(enemyList) do
		if not actor.Alive then continue end
		if ignoredTargets then
			local ignoreUntil=ignoredTargets[actor.UID]
			if ignoreUntil then
				if now<ignoreUntil then continue else ignoredTargets[actor.UID]=nil end
			end
		end
		local char=actor.Character; if not char then continue end
		local dist=actor.LOD_Distance
		if not dist or dist<=0 then
			local root=char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
			if not root then continue end
			local delta=root.Position-checkOrigin
			dist=math.sqrt(delta.X*delta.X+delta.Y*delta.Y+delta.Z*delta.Z)
		end
		if dist>maxDistance then continue end
		local score=dist
		if useFOV then
			if not actor.ViewportOnScreen and dist>50 then continue end
			local root=char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
			if not root then continue end
			local pos,onScreen=Camera:WorldToViewportPoint(root.Position)
			if not onScreen then continue end
			local dx=pos.X-mouseX; local dy=pos.Y-mouseY
			local screenDistSq=(dx*dx)+(dy*dy)
			if screenDistSq>fovLimitSq then continue end
			score=screenDistSq
		end
		table.insert(candidates,{actor=actor,score=score,char=char,dist=dist})
	end
	if #candidates==0 then return nil,nil end
	table.sort(candidates,function(a,b) return a.score<b.score end)
	for i=1,#candidates do
		local candle=candidates[i]; local actor=candle.actor; local char=candle.char
		local part=char:FindFirstChild(targetPartName)
		if not part then part=char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") end
		if part and part.Parent then
			if IsVisible(actor,part,checkOrigin) then return part,actor end
			if getgenv().RaycastBudget<=0 then break end
		end
	end
	return nil,nil
end

local function HookController(controller)
	if type(controller)~="table" then return end
	if controller._hookedMuzzle then return end
	if rawget(controller,"_turret") or rawget(controller,"_config") then return end
	if controller.GetMuzzleCFrame then
		controller._originalMuzzle=controller.GetMuzzleCFrame
		controller.GetMuzzleCFrame=function(self,...)
			local muzzleCF,v2,v3=controller._originalMuzzle(self,...)
			local isVehicleWeapon=false
			if self._actor and not self._actor.IsLocalPlayer and ReplicatorService and ReplicatorService.LocalActor and ReplicatorService.LocalActor.Character then
				local hum=ReplicatorService.LocalActor.Character:FindFirstChild("male")
				if hum and hum.SeatPart and hum.SeatPart.Parent==self._actor then isVehicleWeapon=true end
			end
			local isYours=false
			if self._actor and self._actor.IsLocalPlayer then isYours=true end
			if not isYours and isVehicleWeapon then isYours=true end
			local combatTarget=ActorManager.SelectedTarget_RB or ActorManager.SelectedTarget_SA
			local targetActor=ActorManager.SelectedActor_RB or ActorManager.SelectedActor_SA
			if (Config.SilentAim or Config.RageMode) and combatTarget and targetActor then
				local targetPos=combatTarget.Position; local gravity=32.2; local muzzle_velocity=2000
				if self._firearm and self._firearm.Tune then
					local caliberName=self._firearm.Tune.Caliber; local barrelLen=self._firearm.Tune.Barrel
					if BulletService and BulletService.GetInfo then
						local success,vel=pcall(function() return BulletService:GetInfo(caliberName,barrelLen) end)
						if success and vel then muzzle_velocity=vel end
					end
				end
				local targetVelocity=Vector3_new(0,0,0)
				if targetActor._oldDirection then targetVelocity=targetActor._oldDirection*60
				elseif combatTarget.Parent and combatTarget.Parent.PrimaryPart then
					targetVelocity=combatTarget.Parent.PrimaryPart.AssemblyLinearVelocity or Vector3_new(0,0,0)
				end
				local aimPos,travelTime=SolveLead(muzzleCF.Position,targetPos,targetVelocity,muzzle_velocity,gravity)
				local zeroAngle=0; local actor=self._actor
				if actor and actor.ADS and actor.ViewModel and actor.ViewModel.Zero then
					local zeroData=actor.ViewModel.Zero; local zeroDist=zeroData
					if type(zeroData)=="table" then zeroDist=zeroData[4] end
					if zeroDist then
						local v177=zeroDist*gravity/(muzzle_velocity^2)
						zeroAngle=math.asin(math.clamp(v177,-1,1))*0.5
					end
				end
				muzzleCF=CFrame_new(muzzleCF.Position,aimPos)*CFrame.Angles(-zeroAngle,0,0)
			end
			return muzzleCF,v2,v3
		end
		controller._hookedMuzzle=true
	elseif controller._discharge then
		controller._originalDischarge=controller._discharge
		controller._discharge=function(self,active)
			self._firing=active; local r=controller._originalDischarge(self,active)
			if active and (Config.SilentAim or Config.RageMode) and (math.random(1,100)<=Config.SilentAimHitChance) then
				local targetHead=ActorManager.SelectedTarget_RB or ActorManager.SelectedTarget_SA
				local targetActor=ActorManager.SelectedActor_RB or ActorManager.SelectedActor_SA
				if targetHead and targetHead.Parent then
					local muzzlePos=Camera.CFrame.Position
					if self._actor and self._actor.Character then
						local tool=self._actor.Character:FindFirstChild("HumanoidRootPart")
						if tool then muzzlePos=tool.Position end
					end
					local targetPos=targetHead.Position; local direction=(targetPos-muzzlePos).Unit
					if self._actor and self._actor.IsLocalPlayer and ReplicatorService and ReplicatorService.LocalActor and ReplicatorService.LocalActor.Character then
						local root=ReplicatorService.LocalActor.Character.PrimaryPart
						if root then
							local yaw=math.atan2(direction.X,direction.Z)
							ReplicatorService.LocalActor.Orientation=yaw
							ReplicatorService.LocalActor.GoalOrientation=yaw
							root.CFrame=CFrame.new(root.Position,root.Position+direction)
						end
					end
				end
			end
			return r
		end
	end
end

local FOVCircle=Drawing.new("Circle")
FOVCircle.Thickness=1
pcall(function() FOVCircle.NumSides=60 end)
FOVCircle.Radius=Config.SilentAimFOV
FOVCircle.Filled=false; FOVCircle.Visible=false; FOVCircle.Color=Color3.fromRGB(255,255,255)

getgenv().VelocityCache={}
getgenv().PredictionDot=Drawing.new("Circle")
getgenv().PredictionDot.Thickness=1; getgenv().PredictionDot.NumSides=10
getgenv().PredictionDot.Radius=2; getgenv().PredictionDot.Filled=true
getgenv().PredictionDot.Visible=false; getgenv().PredictionDot.Color=Config.PredictionColor

local WeaponInfoText=Drawing.new("Text")
WeaponInfoText.Size=18; WeaponInfoText.Center=false; WeaponInfoText.Outline=true
WeaponInfoText.Color=Color3.fromRGB(0,255,255)
WeaponInfoText.Position=Vector2.new(50,Camera.ViewportSize.Y-100)
WeaponInfoText.Visible=false; WeaponInfoText.Font=2

local SpeedControllerConnection=nil
function EnableSpeedController()
	if SpeedControllerConnection then return end
	SpeedControllerConnection=RunService.Heartbeat:Connect(function()
		local actor=nil
		if ReplicatorService and ReplicatorService.LocalActor then actor=ReplicatorService.LocalActor
		elseif ControllerService and ControllerService.Controller and ControllerService.Controller._localActor then
			actor=ControllerService.Controller._localActor
		end
		if not actor then return end
		local walkEnabled=Config.Character_WalkSpeedEnabled; local sprintEnabled=Config.Character_SprintSpeedEnabled
		if not walkEnabled and not sprintEnabled then
			if actor.SpeedPenalty then actor.SpeedPenalty=nil end; return
		end
		local controller=ControllerService and ControllerService.Controller
		local isSprinting=controller and controller.IsSprinting
		local multiplier=1
		if sprintEnabled and isSprinting then multiplier=(Config.Character_SprintSpeed or 25)/16.8
		elseif walkEnabled and not isSprinting then multiplier=(Config.Character_WalkSpeed or 16)/12 end
		actor.SpeedPenalty=multiplier
	end)
	table.insert(getgenv().Moon_Connections,SpeedControllerConnection)
end

local function ApplyGunMods(firearm,force)
	if not firearm or not firearm._firearm or not firearm._firearm.Tune then return end
	firearm._LastTuneTime=tick()
	local tune=firearm._firearm.Tune; local caliber=firearm._caliber; local override=firearm._firearm.OverrideTune
	if not tune._Originals then
		tune._Originals={
			Recoil_X=tune.Recoil_X,Recoil_Z=tune.Recoil_Z,Recoil_Camera=tune.Recoil_Camera,
			RecoilForce_Tap=tune.RecoilForce_Tap,RecoilForce_Impulse=tune.RecoilForce_Impulse,
			Recoil_Range=tune.Recoil_Range,Recoil_KickBack=tune.Recoil_KickBack,
			Barrel_Spread=tune.Barrel_Spread,Spread=tune.Spread,RPM=tune.RPM,Firemodes=tune.Firemodes,
			Bolt=tune.Bolt,Bolt_Action_Pause=tune.Bolt_Action_Pause,
			Hipfire_Spread=tune.Hipfire_Spread,Move_Spread=tune.Move_Spread,Jump_Spread=tune.Jump_Spread
		}
	end
	if caliber and not caliber._Originals then caliber._Originals={Spread=caliber.Spread,RecoilForce=caliber.RecoilForce} end
	if override and not override._Originals then
		override._Originals={Recoil_X=override.Recoil_X,Recoil_Z=override.Recoil_Z,Recoil_Camera=override.Recoil_Camera,
			RecoilForce_Tap=override.RecoilForce_Tap,RecoilForce_Impulse=override.RecoilForce_Impulse,
			Spread=override.Spread,RPM=override.RPM,Firemodes=override.Firemodes}
	end
	if Config.NoRecoil or Config.SilentAim then
		tune.Recoil_X=0;tune.Recoil_Y=0;tune.Recoil_Z=0;tune.Recoil_Camera=0
		tune.RecoilForce_Tap=0;tune.RecoilForce_Impulse=0
		tune.Recoil_Range=Vector2_new(0,0);tune.Recoil_KickBack=0
		tune.FocusRecoil_X=0;tune.FocusRecoil_Z=0;tune.FocusRecoil_Camera=0
		tune.Sway=0;tune.Sway_ADS=0
		if tune.Bolt then tune.Bolt=0 end
		if tune.Bolt_Action_Pause then tune.Bolt_Action_Pause=0 end
		if override then
			override.Recoil_X=0;override.Recoil_Y=0;override.Recoil_Z=0;override.Recoil_Camera=0
			override.RecoilForce_Tap=0;override.RecoilForce_Impulse=0;override.Sway=0;override.Sway_ADS=0
		end
		if caliber then caliber.RecoilForce=0 end
	else
		for k,v in pairs(tune._Originals) do if tune[k]~=nil then tune[k]=v end end
		if override and override._Originals then for k,v in pairs(override._Originals) do if override[k]~=nil then override[k]=v end end end
		if caliber and caliber._Originals then caliber.RecoilForce=caliber._Originals.RecoilForce end
	end
	if Config.NoSpread then
		tune.Barrel_Spread=0;tune.Spread=0;tune.MinSpread=0;tune.MaxSpread=0
		tune.Hipfire_Spread=0;tune.Move_Spread=0;tune.Jump_Spread=0
		if caliber then caliber.Spread=0 end
		if override then override.Spread=0;override.MinSpread=0;override.MaxSpread=0 end
	else
		tune.Barrel_Spread=tune._Originals.Barrel_Spread;tune.Spread=tune._Originals.Spread
		tune.MinSpread=tune._Originals.MinSpread or 0;tune.MaxSpread=tune._Originals.MaxSpread or 0
		tune.Hipfire_Spread=tune._Originals.Hipfire_Spread;tune.Move_Spread=tune._Originals.Move_Spread;tune.Jump_Spread=tune._Originals.Jump_Spread
		if caliber and caliber._Originals then caliber.Spread=caliber._Originals.Spread end
		if override and override._Originals then override.Spread=override._Originals.Spread end
	end
	if Config.CustomRPM and Config.RPMValue then
		tune.RPM=Config.RPMValue; if override then override.RPM=Config.RPMValue end
	else
		tune.RPM=tune._Originals.RPM
		if override and override._Originals then override.RPM=override._Originals.RPM end
	end
	if Config.UnlockFiremodes then
		local hasAuto=false
		if tune.Firemodes then
			for _,m in pairs(tune.Firemodes) do if m==2 then hasAuto=true end end
			if not hasAuto then table.insert(tune.Firemodes,2) end
		end
		if override and override.Firemodes then
			local hasAutoOverride=false
			for _,m in pairs(override.Firemodes) do if m==2 then hasAutoOverride=true end end
			if not hasAutoOverride then table.insert(override.Firemodes,2) end
		end
	end
end

local function SetupAggressiveHooks()
	local fc=FirearmInventoryClass
	if fc and type(fc)=="table" then
		if not fc._OriginalEquip then fc._OriginalEquip=fc.Equip end
		if fc._OriginalEquip then fc.Equip=function(self,...) ApplyGunMods(self,true); return fc._OriginalEquip(self,...) end end
	end
	local rc=Recoiler
	if rc and type(rc)=="table" then
		if not rc._OriginalImpulse then rc._OriginalImpulse=rc.Impulse end
		if rc._OriginalImpulse then rc.Impulse=function(self,...) if Config.NoRecoil then return end; return rc._OriginalImpulse(self,...) end end
		if rc.GetViewmodelAdjustment and not rc._OriginalVMAdjust then
			rc._OriginalVMAdjust=rc.GetViewmodelAdjustment
			rc.GetViewmodelAdjustment=function(self,...) if Config.NoRecoil then return CFrame_new() end; return rc._OriginalVMAdjust(self,...) end
		end
		if rc.GetCameraAdjustment and not rc._OriginalCamAdjust then
			rc._OriginalCamAdjust=rc.GetCameraAdjustment
			rc.GetCameraAdjustment=function(self,...) if Config.NoRecoil then return CFrame_new(),0 end; return rc._OriginalCamAdjust(self,...) end
		end
	end
	local cc=CharacterCamera or (shared.Engine and shared.Engine.CharacterCamera) or getgenv().CharacterCamera
	if not cc then
		for _,obj in pairs(getgc(true)) do
			if type(obj)=="table" and rawget(obj,"Update") and rawget(obj,"Render") and rawget(obj,"Watch") then cc=obj; break end
		end
	end
	if cc and cc.Update and not cc._originalUpdate then
		cc._originalUpdate=cc.Update
		cc.Update=function(self,...)
			local res=cc._originalUpdate(self,...)
			local localActor=(ReplicatorService and ReplicatorService.LocalActor) or (self and self._localActor)
			if Config.Spinbot and localActor and localActor.Alive then
				local speed=(Config.SpinbotSpeed or 10); local yaw=(tick()*speed)%(math.pi*2)
				localActor.Orientation=yaw; localActor.GoalOrientation=yaw; localActor.CameraX=yaw
			elseif Config.RageMode and Config.Rage_LookAt and ActorManager.SelectedTarget_RB then
				local targetPos=ActorManager.SelectedTarget_RB.Position
				local myPos=localActor and (localActor.Position or Vector3_new()) or Vector3_new()
				local lookDir=(Vector3_new(targetPos.X,myPos.Y,targetPos.Z)-myPos).Unit
				local yaw=math.atan2(lookDir.X,lookDir.Z)
				local pitch=math.atan2(targetPos.Y-myPos.Y,Vector2_new(lookDir.X,lookDir.Z).Magnitude)
				if localActor then
					localActor.Orientation=yaw; localActor.GoalOrientation=yaw; localActor.CameraX=yaw; localActor.CameraY=pitch
				end
			end
			return res
		end
	end
end

local function SetupActorHooks()
	local ac=ActorClass
	if not ac and ReplicatorService and ReplicatorService.Actors then
		for _,actor in pairs(ReplicatorService.Actors) do
			local mt=getmetatable(actor)
			if mt and mt.__index then ac=mt.__index; ActorClass=ac; break end
		end
	end
	if ac and ac.Update and not ac._originalUpdate then
		ac._originalUpdate=ac.Update
		ac.Update=function(self,...)
			local args={pcall(ac._originalUpdate,self,...)}
			if not args[1] then return end; return unpack(args,2)
		end
	end
end

local function SetupEnvironmentHooks()
	local es=EnvironmentService or FindService("EnvironmentService")
	if es then
		local mt=getmetatable(es)
		if mt and mt.Update then
			if not mt._originalUpdate then
				setreadonly(mt,false); mt._originalUpdate=mt.Update
				mt.Update=function(self,dt,...)
					local result=mt._originalUpdate(self,dt,...)
					local lighting=game:GetService("Lighting")
					if Config.AlwaysDay then lighting.ClockTime=12 end
					if Config.NoFog then
						lighting.FogEnd=100000; lighting.FogStart=0
						local atmosphere=self._atmosphere or lighting:FindFirstChildOfClass("Atmosphere")
						if atmosphere then atmosphere.Density=0;atmosphere.Haze=0;atmosphere.Glare=0;atmosphere.Offset=0 end
						local clouds=self._clouds or lighting:FindFirstChildOfClass("Clouds")
						if clouds then clouds.Cover=0;clouds.Density=0 end
					end
					return result
				end
				setreadonly(mt,true)
			end
		else
			if es.Update and not es._originalUpdate then
				es._originalUpdate=es.Update
				es.Update=function(self,dt,...)
					local result=es._originalUpdate(self,dt,...)
					local lighting=game:GetService("Lighting")
					if Config.AlwaysDay then lighting.ClockTime=12 end
					if Config.NoFog then
						lighting.FogEnd=100000
						local atm=lighting:FindFirstChildOfClass("Atmosphere")
						if atm then atm.Density=0;atm.Haze=0 end
						local clouds=lighting:FindFirstChildOfClass("Clouds")
						if clouds then clouds.Cover=0 end
					end
					return result
				end
			end
		end
	end
end

function SetupHooks()
	SetupAggressiveHooks(); SetupActorHooks(); SetupEnvironmentHooks()
	local TargetController=nil
	if CharacterController then
		if CharacterController.Update then TargetController=CharacterController
		else
			local meta=getmetatable(CharacterController); local index=meta and meta.__index
			if type(index)=="table" and index.Update then TargetController=index end
		end
	end
	if not TargetController and ControllerService and ControllerService.Controller then
		local ctrl=ControllerService.Controller
		if ctrl.Update then TargetController=ctrl
		else
			local meta=getmetatable(ctrl); local index=(meta and meta.__index) or meta
			if type(index)=="table" and index.Update then TargetController=index end
		end
	end
	if TargetController and TargetController.Update then
		EnableSpeedController()
		if not TargetController._originalUpdate then TargetController._originalUpdate=TargetController.Update end
		local OldUpdate=TargetController._originalUpdate
		TargetController.Update=function(self,viewInput,dt,...)
			-- Infinite Stamina
			if Config.InfStamina then
				pcall(function()
					self._exhaustStart = tick()
					self._exhausted = tick() + 1
				end)
			end

			if Config.Character_Fly then
				local localActor=(ReplicatorService and ReplicatorService.LocalActor) or (self and self._localActor)
				if not localActor or not localActor.Alive then return OldUpdate(self,viewInput,dt,...) end
				if Config.RageMode and Config.Rage_LookAt and ActorManager.SelectedTarget_RB then
					local targetPos=ActorManager.SelectedTarget_RB.Position; local myPos=self._position or Vector3_new()
					local lookDir=(Vector3_new(targetPos.X,myPos.Y,targetPos.Z)-myPos).Unit
					local yaw=math.atan2(lookDir.X,lookDir.Z)
					local pitch=math.atan2(targetPos.Y-myPos.Y,Vector2_new(lookDir.X,lookDir.Z).Magnitude)
					localActor.Orientation=yaw;localActor.GoalOrientation=yaw;localActor.CameraX=yaw;localActor.CameraY=pitch;self.Orientation=yaw
				end
				self.VelocityGravity=0; self.HeightState=0; self.IsGrounded=true
				local camCF=Camera.CFrame; local dir=Vector3_new(0,0,0)
				if viewInput and viewInput.Magnitude>0 then
					dir=dir+(camCF.LookVector*-viewInput.Y)+(camCF.RightVector*viewInput.X)
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir=dir+Vector3_new(0,1,0) end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir=dir-Vector3_new(0,1,0) end
				if dir.Magnitude>0 then
					local flySpeedVal=tonumber(Config.Character_FlySpeed) or 50
					local flySprint=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 2.5 or 1
					local deltaTime=type(dt)=="number" and dt or 0.016
					local nextPos=self._position+(dir.Unit*flySpeedVal*flySprint*deltaTime)
					self._position=nextPos; self._lastSafePosition=nextPos
					localActor.SimulatedPosition=nextPos; localActor.Grounded=true; localActor.Sprinting=false
					local _,yRot=Camera.CFrame:ToOrientation()
					localActor.CFrame=CFrame.new(nextPos)*CFrame.Angles(0,yRot,0); localActor.Orientation=yRot
				end
				return
			else
				if self._localActor then
					if self._localActor.Rappelling then self._localActor.Rappelling=false end
					if self.HeightState==nil then self.HeightState=0; self._localActor.HeightState=0 end
				end
				return OldUpdate(self,viewInput,dt,...)
			end
		end
	-- Hook _exhaust to block stamina drain
	if TargetController and not TargetController._originalExhaust then
		if type(TargetController._exhaust) == "function" then
			TargetController._originalExhaust = TargetController._exhaust
			TargetController._exhaust = function(self, ...)
				if Config.InfStamina then return true end
				return TargetController._originalExhaust(self, ...)
			end
		end
	end
	else
		warn("[ESP] Could not find CharacterController.Update to hook!")
	end
end

local function InitializeServices()
	local found,collections=BulkScan()
	if not found then return false end
	CalibersTable=found.CalibersTable
	RefreshFirearmControllers(true); SetupHooks()
	if BulletService then
		if not BulletService._originalDischarge then BulletService._originalDischarge=BulletService.Discharge end
		local lastUsedCaliber,lastUsedVelocity=nil,2000
		BulletService.Discharge=function(self,originCF,p49,p50,p51,p52,p53,p54,p55,p56,p57)
			local muzzlePos
			if (p51) and (Config.SilentAim or Config.RageMode) and (math.random(1,100)<=Config.SilentAimHitChance) then
				p57=false
				local targetHead=ActorManager.SelectedTarget_RB or ActorManager.SelectedTarget_SA
				local targetActor=ActorManager.SelectedActor_RB or ActorManager.SelectedActor_SA
				if targetHead then
					local targetPos=targetHead.Position; local muzzle_velocity=2000
					if p49==lastUsedCaliber then muzzle_velocity=lastUsedVelocity
					elseif p49 and BulletService.GetInfo then
						local vel=BulletService:GetInfo(p49,p50)
						if vel and vel>0 then muzzle_velocity=vel; lastUsedCaliber=p49; lastUsedVelocity=vel end
					end
					local targetVelocity=getgenv()._lastPredVel or Vector3_new(0,0,0); local gravity=32.2
					if originCF then muzzlePos=originCF.Position end
					if not muzzlePos and GetMuzzlePosition then muzzlePos=GetMuzzlePosition() end
					if muzzlePos and targetPos then
						local aimPos,_=SolveLead(muzzlePos,targetPos,targetVelocity,muzzle_velocity,gravity)
						getgenv().LastSilentAimUpdate=tick(); originCF=CFrame_new(muzzlePos,aimPos)
						if not ActorManager._lastRBLog or (tick()-ActorManager._lastRBLog>5) then
							print(string_format("[Ragebot] TARGET ACQUIRED: %s",targetActor.OwnerName or "NPC"))
							ActorManager._lastRBLog=tick()
						end
					end
				end
			end
			return BulletService._originalDischarge(self,originCF,p49,p50,p51,p52,p53,p54,p55,p56,p57)
		end
		getgenv()._BulletServiceHooked=true
	end
	if Recoiler then
		local rc=Recoiler
		if not rc._OriginalImpulse then
			rc._OriginalImpulse=rc.Impulse
			rc.Impulse=function(self,...) if Config.NoRecoil or Config.TurretNoRecoil then return end; return rc._OriginalImpulse(self,...) end
		end
		if not rc._OriginalGetCameraAdjustment then
			rc._OriginalGetCameraAdjustment=rc.GetCameraAdjustment
			rc.GetCameraAdjustment=function(self,...) if Config.NoRecoil or Config.TurretNoRecoil then return CFrame.new(),0 end; return rc._OriginalGetCameraAdjustment(self,...) end
		end
	end
	return true
end

local function UpdateCombat(frameId)
	local cfg=Config; local activeVelocity=2000
	local showWeaponInfo=cfg.ShowWeaponInfo
	local showPred=cfg.ShowPrediction or (cfg.SilentAim and cfg.Prediction)
	local activeTune
	local equippedController=WeaponManager.Equipped
	if InventoryService and not WeaponManager.Connection then
		local InterfaceStateChanged=InventoryService.OnInterfaceStateChanged
		if typeof(InterfaceStateChanged)=="RBXScriptSignal" then
			WeaponManager.Connection=InterfaceStateChanged:Connect(function()
				WeaponManager.Equipped=InventoryService.Equipped and InventoryService.Equipped.Handler
			end)
			table.insert(getgenv().Moon_Connections,WeaponManager.Connection)
		end
		WeaponManager.Equipped=InventoryService.Equipped and InventoryService.Equipped.Handler
	end
	equippedController=WeaponManager.Equipped or (InventoryService and InventoryService.Equipped and InventoryService.Equipped.Handler)
	local targetPart_RB=ActorManager.SelectedTarget_RB; local targetPart_SA=ActorManager.SelectedTarget_SA
	if equippedController then
		ApplyGunMods(equippedController,false)

		-- Auto Reload (global tick — không gán lên controller, không block manual R)
		if Config.AutoReload then
			local now_ar = tick()
			if (now_ar - (getgenv()._autoReloadTick or 0)) > 0.2 then
				getgenv()._autoReloadTick = now_ar
				-- Chỉ trigger khi mag = 0 VÀ không đang reload (manual hoặc auto)
				local magCapacity = equippedController._mag and (equippedController._mag.Capacity or 0) or 0
				local magEmpty = magCapacity == 0
				local isReloading = equippedController._reloading == true
				if magEmpty and not isReloading then
					pcall(function()
						-- Dùng _getMags trước (source gốc), không fallback Reload() để tránh conflict PC
						if equippedController._getMags and equippedController._reload then
							local mags = equippedController:_getMags()
							if mags and #mags > 0 then
								equippedController:_reload()
							end
						end
					end)
				end
			end
		end

		if (Config.SilentAim or Config.RageMode) and not equippedController._isHookedESP then
			HookController(equippedController); equippedController._isHookedESP=true
		end
		if Config.RageMode and ActorManager.SelectedTarget_RB then
			local targetActor=ActorManager.SelectedActor_RB
			if not targetActor or not targetActor.Alive then return end
			local uid=targetActor.UID; local weaponRPM=600
			if equippedController._firearm and equippedController._firearm.Tune then weaponRPM=equippedController._firearm.Tune.RPM or 600 end
			local magCount=equippedController._mag and equippedController._mag.Capacity or 0
			local inChamber=(equippedController._item and equippedController._item.MetaData and equippedController._item.MetaData.Chamber) and 1 or 0
			local totalAmmo=magCount+inChamber
			if totalAmmo<=0 then
				if equippedController.Reload and not equippedController._reloading then pcall(function() equippedController:Reload() end) end; return
			end
			local now=os.clock()
			local effectiveRPM=math.max(weaponRPM,Config.RageMode and 1200 or weaponRPM)
			local fireDelay=60/effectiveRPM
			ActorManager._rageLast=ActorManager._rageLast or {}
			local lastShot=ActorManager._rageLast[uid] or 0
			if now-lastShot>=fireDelay then
				ActorManager._rageLast[uid]=now
				ActorManager._ignoredTargets=ActorManager._ignoredTargets or {}
				ActorManager._ignoredTargets[uid]=now+1.0
				pcall(function() equippedController:Discharge() end)
				ActorManager.SelectedTarget_RB=nil; ActorManager.SelectedActor_RB=nil
			end
		elseif equippedController._firing and (Config.RageMode or Config.SilentAim) and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			local method=equippedController._discharge or equippedController.Discharge
			if method then pcall(method,equippedController,false) end
		end
	end
	if ReplicatorService and ReplicatorService.LocalActor then
		local myActor=ReplicatorService.LocalActor
		if myActor.Turret and type(myActor.Turret)=="table" then
			local tConfig=myActor.Turret._config
			if tConfig then
				if setreadonly then pcall(setreadonly,tConfig,false) end
				if make_writeable then pcall(make_writeable,tConfig) end
				if cfg.TurretNoRecoil then
					tConfig.Recoil=0;tConfig.Recoil_Base=Vector2.new(0,0);tConfig.Recoil_Range=Vector2.new(0,0)
					tConfig.Recoil_Camera=0;tConfig.Recoil_Kick=0;tConfig.Recoil_Smooth=0;tConfig.RPM_RecoilScale=0;tConfig.CameraShake=nil
				end
				if cfg.TurretNoSpread then
					tConfig.Spread=0;tConfig.Barrel_Spread=0;tConfig.MinSpread=0;tConfig.MaxSpread=0;tConfig.Recoil_Spread=0
					if CalibersTable and tConfig.Caliber then local cal=CalibersTable[tConfig.Caliber]; if cal then cal.Spread=0 end end
				end
				if cfg.TurretUnlockFiremodes and tConfig.Firemodes then
					local hasAuto=false
					for _,m in pairs(tConfig.Firemodes) do if m==0 or m==2 then hasAuto=true end end
					if not hasAuto then table.insert(tConfig.Firemodes,0) end
				end
			end
		end
	end
	if (frameId%10==0) and (cfg.TurretNoRecoil or cfg.TurretNoSpread or cfg.TurretUnlockFiremodes) then
		if AllControllersCache.Visuals then
			for _,controller in ipairs(AllControllersCache.Visuals) do
				if type(controller)~="table" or controller==equippedController then continue end
				if rawget(controller,"_turret")~=nil then
					local tConfig=controller._config
					if tConfig then
						if setreadonly then pcall(setreadonly,tConfig,false) end
						if cfg.TurretNoRecoil then tConfig.Recoil=0;tConfig.Recoil_Base=Vector2.new(0,0);tConfig.Recoil_Camera=0;tConfig.Recoil_Kick=0 end
						if cfg.TurretNoSpread then tConfig.Spread=0;tConfig.Barrel_Spread=0 end
						if cfg.TurretUnlockFiremodes and tConfig.Firemodes then
							local hasAuto=false
							for _,m in pairs(tConfig.Firemodes) do if m==0 then hasAuto=true end end
							if not hasAuto then table.insert(tConfig.Firemodes,0) end
						end
					end
				end
			end
		end
	end
	if (showWeaponInfo or showPred) and (frameId%5==0) then
		if type(equippedController)=="table" and equippedController._firearm then
			local firearm=equippedController._firearm; activeTune=firearm.Tune
			if activeTune then
				local velocity=0
				if BulletService and activeTune.Caliber then
					local success,v=pcall(function() return BulletService:GetInfo(activeTune.Caliber,activeTune.Barrel or 1) end)
					if success and v and v>0 then velocity=v end
				end
				if velocity==0 then velocity=activeTune.Velocity or (activeTune.MuzzleVelocity and activeTune.MuzzleVelocity.Value) or 2000 end
				activeVelocity=velocity
				if showWeaponInfo then
					local weaponName=firearm.Name or activeTune.Name or "Unknown"; local caliberName=""
					if CalibersTable and activeTune.Caliber and CalibersTable[activeTune.Caliber] then
						local cal=CalibersTable[activeTune.Caliber]
						if cal and cal.FamilyName then
							caliberName=cal.FamilyName
							if cal.VariantName and cal.VariantName~="" then caliberName=caliberName.." "..cal.VariantName end
						end
					end
					local velocityMS=math_floor(velocity*0.3048+0.5)
					local infoText=string_format("Weapon: %s\nCaliber: %s\nVelocity: %d m/s",weaponName,caliberName~="" and caliberName or "N/A",velocityMS)
					if WeaponInfoText.Text~=infoText then WeaponInfoText.Text=infoText end
					WeaponInfoText.Position=Vector2_new(50,Camera.ViewportSize.Y-120); WeaponInfoText.Visible=true
				else WeaponInfoText.Visible=false end
			else WeaponInfoText.Visible=false end
		else WeaponInfoText.Visible=false end
	end
	if Config.SilentAim and FirearmInventory and type(FirearmInventory)=="table" then
		for _,controller in pairs(FirearmInventory) do
			if type(controller)=="table" and controller._firearm and not controller._isHookedESP then
				HookController(controller); controller._isHookedESP=true
			end
		end
	end
	if (cfg.RageMode or cfg.Spinbot) and ReplicatorService and ReplicatorService.LocalActor then
		local myActor=ReplicatorService.LocalActor
		if myActor.Alive and myActor.Character then
			local root=myActor.Character:FindFirstChild("Root") or myActor.Character.PrimaryPart
			if root then
				local muzzlePos=GetMuzzlePosition() or Camera.CFrame.Position
				local targetPos=targetPart_RB and targetPart_RB.Position; local yaw,pitch
				if cfg.RageMode and cfg.Rage_LookAt and targetPart_RB then
					local direction=(targetPos-muzzlePos).Unit
					yaw=math.atan2(direction.X,direction.Z)
					pitch=math.atan2(targetPos.Y-muzzlePos.Y,Vector2_new(direction.X,direction.Z).Magnitude)
					root.CFrame=CFrame.new(root.Position,root.Position+Vector3_new(math.sin(yaw),0,math.cos(yaw)))
				elseif cfg.Spinbot then
					local speed=(Config.SpinbotSpeed or 20); yaw=(tick()*speed)%(math.pi*2); pitch=0
					root.CFrame=CFrame.new(root.Position)*CFrame.Angles(0,yaw,0)
				end
				if yaw then
					myActor.Orientation=yaw;myActor.GoalOrientation=yaw;myActor.CameraX=yaw;myActor.CameraY=pitch
					local controller=ControllerService and ControllerService.Controller
					if controller then controller.Orientation=yaw end
				end
			end
		end
	end
	if FOVCircle then
		pcall(function() FOVCircle.Radius=Config.SilentAimFOV end)
		local fovShow=Config.SilentAim and Config.ShowFOV
		pcall(function() FOVCircle.Visible=fovShow end)
		if fovShow then local sc=Camera.ViewportSize/2; pcall(function() FOVCircle.Position=Vector2.new(sc.X,sc.Y) end) end
	end
	local targetPart=targetPart_SA; local targetActor=ActorManager.SelectedActor_SA
	if targetPart then
		local rawVel=Vector3_new(0,0,0)
		if targetActor and targetActor._oldDirection then rawVel=targetActor._oldDirection*60
		elseif targetPart.Parent and targetPart.Parent.PrimaryPart then
			rawVel=targetPart.Parent.PrimaryPart.AssemblyLinearVelocity or Vector3_new(0,0,0)
		end
		if not getgenv()._lastPredVel then getgenv()._lastPredVel=rawVel
		else getgenv()._lastPredVel=getgenv()._lastPredVel:Lerp(rawVel,0.15) end
	end
	if getgenv().PredictionDot then
		local dot=getgenv().PredictionDot
		if Config.ShowPrediction and targetPart then
			local muzzlePos=GetMuzzlePosition() or Camera.CFrame.Position
			local targetPos=targetPart.Position; local targetVel=getgenv()._lastPredVel or Vector3_new(0,0,0)
			local gravity=32.2; local aimPos,_=SolveLead(muzzlePos,targetPos,targetVel,activeVelocity,gravity)
			local screenPos,onScreen=Camera:WorldToViewportPoint(aimPos)
			if onScreen then dot.Position=Vector2_new(screenPos.X,screenPos.Y); dot.Color=cfg.PredictionColor or Color3_fromHSV(0.33,1,1); dot.Visible=true
			else dot.Visible=false end
		else dot.Visible=false end
	end
end

local function GetEntityColor(actor,entityType,cachedLocalSquad)
	if entityType=="Player" then
		if IsTeammate(actor,cachedLocalSquad) then return Config.SquadColor or Config.TeammateColor or Color3_new(0,1,0) end
		return Config.PlayerColor or Color3_new(1,0.65,0)
	elseif entityType=="Zombie" then
		if actor.Health and type(actor.Health)=="table" and actor.Health.Ability then
			return Config.ZombieColors[actor.Health.Ability] or Config.ZombieColor or Color3_new(1,0,0)
		end
		return Config.ZombieColor or Color3_new(1,0,0)
	elseif entityType=="NPC" then return Config.NPCColor or Color3_new(1,1,0) end
	return Color3_new(1,1,1)
end

DetectMapType=function()
	local currentId=game.PlaceId
	for name,data in pairs(Places) do
		if data[1]==currentId or data[2]==currentId then
			Config.CurrentMapName=name
			if name:find("PVP_") then return "PVP" end
			if name:find("ZM") then return "Zombie" end
			if name:find("OW_") then return "OpenWorld" end
			if name:find("HQ_") or name:find("CM_") then return "Headquarters" end
			if name=="Menu" then return "Menu" end
		end
	end
	if not WorldService then return "Unknown" end
	local placeName=WorldService._world or ""; Config.CurrentMapName=placeName
	if placeName:find("PVP_") then return "PVP"
	elseif placeName:find("ZM") then return "Zombie"
	elseif placeName:find("OW_") or placeName=="Default" then return "OpenWorld"
	elseif placeName:find("HQ_") or placeName:find("CM_") then return "Headquarters"
	elseif placeName=="Menu" then return "Menu" end
	return "Unknown"
end

local function ShouldShowEntity(actor,entityType,cachedLocalSquad)
	if Config.AutoDetectMap then
		if Config.CurrentMapType=="PVP" and entityType=="Zombie" then return false end
	end
	if entityType=="Player" then
		if IsTeammate(actor,cachedLocalSquad) and not Config.ShowSquadMembers then return false end
		return Config.ShowPlayers
	elseif entityType=="Zombie" then return Config.ShowZombies
	elseif entityType=="NPC" then return Config.ShowNPCs end
	return false
end

local function CreateHighlight(actor,color)
	if not actor.Character then return nil end
	local highlight=Instance.new("Highlight")
	highlight.FillColor=color; highlight.FillTransparency=0.9; highlight.OutlineColor=color
	highlight.OutlineTransparency=0; pcall(function() highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop end)
	highlight.Parent=actor.Character; return highlight
end

local function CreateDrawingESP()
	local esp={BoxOutline=Drawing_new("Square"),Box=Drawing_new("Square"),HealthBarOutline=Drawing_new("Square"),HealthBar=Drawing_new("Square"),Name=Drawing_new("Text"),Distance=Drawing_new("Text")}
	esp.BoxOutline.Visible=false;esp.BoxOutline.Color=Color3.new(0,0,0);esp.BoxOutline.Thickness=3;esp.BoxOutline.Transparency=1;esp.BoxOutline.Filled=false;esp.BoxOutline.ZIndex=1
	esp.Box.Visible=false;esp.Box.Color=Color3.new(1,1,1);esp.Box.Thickness=1;esp.Box.Transparency=1;esp.Box.Filled=false;esp.Box.ZIndex=2
	esp.HealthBarOutline.Visible=false;esp.HealthBarOutline.Color=Color3.new(0,0,0);esp.HealthBarOutline.Thickness=1;esp.HealthBarOutline.Filled=true;esp.HealthBarOutline.Transparency=1;esp.HealthBarOutline.ZIndex=1
	esp.HealthBar.Visible=false;esp.HealthBar.Color=Color3.new(0,1,0);esp.HealthBar.Thickness=1;esp.HealthBar.Filled=true;esp.HealthBar.ZIndex=2
	esp.Name.Visible=false;esp.Name.Color=Color3.new(1,1,1);esp.Name.Size=13;esp.Name.Center=true;esp.Name.Outline=true;esp.Name.Font=2;esp.Name.ZIndex=3
	esp.Distance.Visible=false;esp.Distance.Color=Color3.new(1,1,1);esp.Distance.Size=12;esp.Distance.Center=true;esp.Distance.Outline=true;esp.Distance.Font=2;esp.Distance.ZIndex=3
	esp.Tracer=Drawing.new("Line");esp.Tracer.Visible=false;esp.Tracer.Color=Color3.new(1,1,1);esp.Tracer.Thickness=1;esp.Tracer.Transparency=1
	esp.Corners={}
	for i=1,8 do local line=Drawing.new("Line");line.Visible=false;line.Thickness=1;line.Color=Color3.new(1,1,1);table.insert(esp.Corners,line) end
	return esp
end

local function CreateSimpleESP(espData)
	local box=Instance.new("BoxHandleAdornment"); box.Name="ESPBox"; box.AlwaysOnTop=true; box.ZIndex=5; box.Transparency=0.6; box.Color3=espData.Color
	local container=GetSecureContainer(); if not container then return end
	box.Parent=container; espData.SimpleESP={Box=box,Container=container}
end

local function CreateESPForActor(actor,cachedLocalSquad)
	local entityType=GetEntityType(actor)
	if not ShouldShowEntity(actor,entityType,cachedLocalSquad) then return end
	local color=GetEntityColor(actor,entityType,cachedLocalSquad)
	local espData={Actor=actor,EntityType=entityType,Color=color}
	if Config.UseHighlight then espData.Highlight=CreateHighlight(actor,color) end
	espData.Drawing=CreateDrawingESP(); CreateSimpleESP(espData)
	ESPElements[actor.UID]=espData
end

local function SetAllVisible(drawings,espData,visible)
	if espData._visible==visible then return end
	espData._visible=visible
	local boxOn=visible and Config.UseBoxESP
	drawings.Box.Visible=boxOn; drawings.BoxOutline.Visible=boxOn
	drawings.Name.Visible=visible and Config.ShowNames; drawings.Distance.Visible=visible and Config.ShowDistance
	local healthOn=visible and Config.ShowHealth
	drawings.HealthBar.Visible=healthOn; drawings.HealthBarOutline.Visible=healthOn
	drawings.Tracer.Visible=visible and Config.UseTracers
	if espData.Highlight then espData.Highlight.Enabled=visible and Config.UseHighlight end
	if not visible then for _,line in ipairs(drawings.Corners) do line.Visible=false end end
end

local function RemoveESP(uid)
	local espData=ESPElements[uid]; if not espData then return end
	if espData.Highlight then pcall(function() espData.Highlight:Destroy() end) end
	if espData.SimpleESP then pcall(function() espData.SimpleESP.Box:Destroy() end) end
	if espData.Drawing then
		local d=espData.Drawing
		if d.Box then pcall(function() d.Box:Remove() end) end
		if d.BoxOutline then pcall(function() d.BoxOutline:Remove() end) end
		if d.Name then pcall(function() d.Name:Remove() end) end
		if d.Distance then pcall(function() d.Distance:Remove() end) end
		if d.HealthBar then pcall(function() d.HealthBar:Remove() end) end
		if d.HealthBarOutline then pcall(function() d.HealthBarOutline:Remove() end) end
		if d.Tracer then pcall(function() d.Tracer:Remove() end) end
		if d.Corners then for _,line in ipairs(d.Corners) do pcall(function() line:Remove() end) end end
	end
	ESPElements[uid]=nil
end

local function UpdateESPForActor(uid,espData,frameId,cachedCfg,localSquad)
	local actor=espData.Actor; local entityType=actor._entityType or "Unknown"
	espData.LastUpdate=frameId
	if not actor or not actor.Alive then RemoveESP(uid); return end
	if not ShouldShowEntity(actor,entityType,localSquad) then SetAllVisible(espData.Drawing,espData,false); return end
	-- Tính distance thực nếu LOD_Distance không có
	local distance = actor.LOD_Distance
	if not distance or distance <= 0 then
		local pos = actor.Position
		if not pos and actor.Character and actor.Character.PrimaryPart then
			pos = actor.Character.PrimaryPart.Position
		end
		if pos then
			distance = (Camera.CFrame.Position - pos).Magnitude
		else
			distance = 0
		end
	end
	if distance > cachedCfg.MaxDistance then
		SetAllVisible(espData.Drawing,espData,false)
		if espData.SimpleESP and espData.SimpleESP.Box then pcall(function() espData.SimpleESP.Box.Visible=false end) end
		return
	end
	if distance > 1500 and (frameId%2) ~= 0 then return end
	if cachedCfg.SimpleESP then
		SetAllVisible(espData.Drawing,espData,false)
		local sESP=espData.SimpleESP
		local isVisible=actor.ViewportOnScreen or actor.LOD_OnScreen or actor.OnScreen
		if not isVisible and actor.Position then local _,v=Camera:WorldToViewportPoint(actor.Position); isVisible=v end
		if distance<50 then isVisible=true end
		if isVisible then
			local char=actor.Character; local target=char and char:FindFirstChild("Head")
			if target then pcall(function() sESP.Box.Visible=true;sESP.Box.Adornee=target;sESP.Box.Size=target.Size;sESP.Box.Color3=espData.Color end) end
		else if sESP and sESP.Box then pcall(function() sESP.Box.Visible=false end) end end
		return
	end
	local drawings=espData.Drawing
	local worldPos = actor.Position
	if not worldPos then
		if actor.Character then
			local pp = actor.Character.PrimaryPart or actor.Character:FindFirstChild("Head")
			if pp then worldPos = pp.Position end
		end
	end
	if not worldPos then SetAllVisible(drawings,espData,false); return end
	local screen_point,onScreen=Camera:WorldToViewportPoint(worldPos)
	-- Chỉ dùng onScreen — reliable trên PC
	if not onScreen then SetAllVisible(drawings,espData,false); return end
	local screenPos=Vector2_new(screen_point.X,screen_point.Y)
	SetAllVisible(drawings,espData,true)
	if espData.Highlight then espData.Highlight.FillColor=espData.Color;espData.Highlight.OutlineColor=espData.Color end
	local height=6.5; local hState=actor.HeightState
	if hState==1 then height=4.5 elseif hState==2 then height=2.5 end
	local top_point=Camera:WorldToViewportPoint(worldPos+Vector3_new(0,height*0.5,0))
	local bottom_point=Camera:WorldToViewportPoint(worldPos-Vector3_new(0,height*0.5,0))
	local scale=cachedCfg.BoxScale or 1
	local boxHeight=math_abs(bottom_point.Y-top_point.Y)*scale; local boxWidth=boxHeight*0.6
	local boxPosition=Vector2_new(screenPos.X-boxWidth*0.5,screenPos.Y-boxHeight*0.5)
	local boxColor=cachedCfg.BoxColor or espData.Color
	if cachedCfg.UseBoxESP then
		if cachedCfg.BoxStyle=="Corner" then
			drawings.Box.Visible=false; drawings.BoxOutline.Visible=false
			local cornerLength=(boxWidth<boxHeight and boxWidth or boxHeight)*0.25
			local corners=drawings.Corners
			local bpX,bpY=boxPosition.X,boxPosition.Y; local rightX=bpX+boxWidth; local bottomY=bpY+boxHeight
			corners[1].From=boxPosition;corners[1].To=Vector2_new(bpX+cornerLength,bpY);corners[1].Color=boxColor;corners[1].Visible=true
			corners[2].From=boxPosition;corners[2].To=Vector2_new(bpX,bpY+cornerLength);corners[2].Color=boxColor;corners[2].Visible=true
			corners[3].From=Vector2_new(rightX,bpY);corners[3].To=Vector2_new(rightX-cornerLength,bpY);corners[3].Color=boxColor;corners[3].Visible=true
			corners[4].From=Vector2_new(rightX,bpY);corners[4].To=Vector2_new(rightX,bpY+cornerLength);corners[4].Color=boxColor;corners[4].Visible=true
			corners[5].From=Vector2_new(bpX,bottomY);corners[5].To=Vector2_new(bpX+cornerLength,bottomY);corners[5].Color=boxColor;corners[5].Visible=true
			corners[6].From=Vector2_new(bpX,bottomY);corners[6].To=Vector2_new(bpX,bottomY-cornerLength);corners[6].Color=boxColor;corners[6].Visible=true
			corners[7].From=Vector2_new(rightX,bottomY);corners[7].To=Vector2_new(rightX-cornerLength,bottomY);corners[7].Color=boxColor;corners[7].Visible=true
			corners[8].From=Vector2_new(rightX,bottomY);corners[8].To=Vector2_new(rightX,bottomY-cornerLength);corners[8].Color=boxColor;corners[8].Visible=true
		else
			local corners=drawings.Corners
			if corners[1].Visible then for _,line in ipairs(corners) do line.Visible=false end end
			drawings.BoxOutline.Size=Vector2_new(boxWidth,boxHeight);drawings.BoxOutline.Position=boxPosition;drawings.BoxOutline.Visible=true
			drawings.Box.Size=Vector2_new(boxWidth,boxHeight);drawings.Box.Position=boxPosition;drawings.Box.Color=boxColor;drawings.Box.Visible=true
		end
	else
		drawings.Box.Visible=false;drawings.BoxOutline.Visible=false
		local corners=drawings.Corners
		if corners[1].Visible then for _,line in ipairs(corners) do line.Visible=false end end
	end
	if cachedCfg.ShowNames then
		local displayName=actor.OwnerName
		if entityType=="Zombie" then
			local h=actor.Health
			if h and type(h)=="table" and h.Ability then
				local abilityNames={"Crippled","Slow","Normal","Sprinter"}
				displayName=abilityNames[h.Ability] or "Zombie"
			else displayName="Zombie" end
		elseif not displayName or displayName=="???" then displayName="AI" end
		local dynamicScale=cachedCfg.DynamicTextScaling and math_clamp(boxHeight*0.016,0.5,1.0) or 1.0
		local nameSize=13*cachedCfg.TextScale*dynamicScale
		drawings.Name.Text=displayName; drawings.Name.Position=Vector2_new(screenPos.X,boxPosition.Y-(nameSize+3))
		drawings.Name.Color=espData.Color; drawings.Name.Size=nameSize; drawings.Name.Visible=true
	else drawings.Name.Visible=false end
	if cachedCfg.ShowDistance then
		local dynamicScale=cachedCfg.DynamicTextScaling and math_clamp(boxHeight*0.016,0.5,1.0) or 1.0
		local distSize=12*cachedCfg.TextScale*dynamicScale
		drawings.Distance.Text=string_format("[%dm]",math_floor(distance*0.28)); drawings.Distance.Size=distSize
		local distY=boxPosition.Y+boxHeight+2
		if cachedCfg.HealthBarSide=="Bottom" then distY=distY+6 end
		drawings.Distance.Position=Vector2_new(screenPos.X,distY); drawings.Distance.Visible=true
	else drawings.Distance.Visible=false end
	if cachedCfg.ShowHealth and actor.Health then
		local healthPercent=1; local hp=actor.Health
		if type(hp)=="number" then healthPercent=math_clamp(hp*0.01,0,1) end
		local barColor=cachedCfg.HealthBarColor or Color3_new(0,1,0)
		if cachedCfg.UseHealthGradient then barColor=Color3_fromHSV(healthPercent*0.3,1,1) end
		local barSize,barPos,outlineSize,outlinePos; local hbSide=cachedCfg.HealthBarSide
		if hbSide=="Bottom" then
			local barW=boxWidth*healthPercent
			barSize=Vector2_new(barW,4);barPos=Vector2_new(boxPosition.X,boxPosition.Y+boxHeight+2)
			outlineSize=Vector2_new(boxWidth+2,6);outlinePos=Vector2_new(boxPosition.X-1,boxPosition.Y+boxHeight+1)
		elseif hbSide=="Right" then
			local barH=boxHeight*healthPercent
			barSize=Vector2_new(2,barH);barPos=Vector2_new(boxPosition.X+boxWidth+3,boxPosition.Y+(boxHeight-barH))
			outlineSize=Vector2_new(4,boxHeight+2);outlinePos=Vector2_new(boxPosition.X+boxWidth+2,boxPosition.Y-1)
		else
			local barH=boxHeight*healthPercent
			barSize=Vector2_new(2,barH);barPos=Vector2_new(boxPosition.X-5,boxPosition.Y+(boxHeight-barH))
			outlineSize=Vector2_new(4,boxHeight+2);outlinePos=Vector2_new(boxPosition.X-6,boxPosition.Y-1)
		end
		drawings.HealthBarOutline.Size=outlineSize;drawings.HealthBarOutline.Position=outlinePos;drawings.HealthBarOutline.Visible=true
		drawings.HealthBar.Size=barSize;drawings.HealthBar.Position=barPos;drawings.HealthBar.Color=barColor;drawings.HealthBar.Visible=true
	else drawings.HealthBar.Visible=false;drawings.HealthBarOutline.Visible=false end
	if cachedCfg.UseTracers then
		local viewport=Camera.ViewportSize
		drawings.Tracer.From=Vector2_new(viewport.X*0.5,viewport.Y)
		drawings.Tracer.To=Vector2_new(screenPos.X,boxPosition.Y+boxHeight)
		drawings.Tracer.Color=espData.Color; drawings.Tracer.Visible=true
	else drawings.Tracer.Visible=false end
end

local function UpdateESPForVehicle(uid,espData,vehicle,currentFrameId)
	local pos=nil
	if vehicle.Model.PrimaryPart then pos=vehicle.Model.PrimaryPart.Position else pos=vehicle.CFrame.Position end
	local dist=(Camera.CFrame.Position-pos).Magnitude
	if dist>Config.MaxDistance then
		espData.Drawing.Box.Visible=false;espData.Drawing.BoxOutline.Visible=false
		espData.Drawing.Name.Visible=false;espData.Drawing.Distance.Visible=false
		espData.Drawing.HealthBar.Visible=false;espData.Drawing.HealthBarOutline.Visible=false
		if espData.Drawing.Corners then for _,l in ipairs(espData.Drawing.Corners) do l.Visible=false end end; return
	end
	local screenPos,onScreen=Camera:WorldToViewportPoint(pos)
	if not onScreen then
		espData.Drawing.Box.Visible=false;espData.Drawing.BoxOutline.Visible=false
		espData.Drawing.Name.Visible=false;espData.Drawing.Distance.Visible=false
		espData.Drawing.HealthBar.Visible=false;espData.Drawing.HealthBarOutline.Visible=false
		if espData.Drawing.Corners then for _,l in ipairs(espData.Drawing.Corners) do l.Visible=false end end; return
	end
	espData.LastUpdate=currentFrameId
	local size=vehicle.Model:GetExtentsSize(); local height=size.Y; local width=math.max(size.X,size.Z)
	local boxSize=Vector2.new(1000/dist*width,1000/dist*height)*(Config.BoxScale or 1.0)
	local boxPos=Vector2.new(screenPos.X-boxSize.X/2,screenPos.Y-boxSize.Y/2)
	local boxHeight=boxSize.Y; local boxWidth=boxSize.X
	local drawings=espData.Drawing; local boxColor=Config.VehicleColor or Color3.new(0,1,1)
	if Config.ShowVehicleBox then
		drawings.BoxOutline.Color=Color3.new(0,0,0);drawings.BoxOutline.Transparency=1;drawings.BoxOutline.Thickness=1
		drawings.BoxOutline.Size=boxSize+Vector2.new(2,2);drawings.BoxOutline.Position=boxPos-Vector2.new(1,1);drawings.BoxOutline.ZIndex=0
		drawings.Box.Color=boxColor;drawings.Box.Transparency=1;drawings.Box.Thickness=1
		drawings.Box.Size=boxSize;drawings.Box.Position=boxPos;drawings.Box.ZIndex=5
		if Config.VehicleBoxStyle=="Corner" then
			drawings.Box.Visible=false;drawings.BoxOutline.Visible=false
			if drawings.Corners then
				local cornerLength=math.min(boxWidth,boxHeight)*0.25; local c=drawings.Corners
				c[1].From=Vector2.new(boxPos.X,boxPos.Y);c[1].To=Vector2.new(boxPos.X+cornerLength,boxPos.Y)
				c[2].From=Vector2.new(boxPos.X,boxPos.Y);c[2].To=Vector2.new(boxPos.X,boxPos.Y+cornerLength)
				c[3].From=Vector2.new(boxPos.X+boxWidth,boxPos.Y);c[3].To=Vector2.new(boxPos.X+boxWidth-cornerLength,boxPos.Y)
				c[4].From=Vector2.new(boxPos.X+boxWidth,boxPos.Y);c[4].To=Vector2.new(boxPos.X+boxWidth,boxPos.Y+cornerLength)
				c[5].From=Vector2.new(boxPos.X,boxPos.Y+boxHeight);c[5].To=Vector2.new(boxPos.X+cornerLength,boxPos.Y+boxHeight)
				c[6].From=Vector2.new(boxPos.X,boxPos.Y+boxHeight);c[6].To=Vector2.new(boxPos.X,boxPos.Y+boxHeight-cornerLength)
				c[7].From=Vector2.new(boxPos.X+boxWidth,boxPos.Y+boxHeight);c[7].To=Vector2.new(boxPos.X+boxWidth-cornerLength,boxPos.Y+boxHeight)
				c[8].From=Vector2.new(boxPos.X+boxWidth,boxPos.Y+boxHeight);c[8].To=Vector2.new(boxPos.X+boxWidth,boxPos.Y+boxHeight-cornerLength)
				for _,l in ipairs(c) do l.Color=boxColor;l.Transparency=1;l.Thickness=1;l.ZIndex=5;l.Visible=true end
			end
		else
			if drawings.Corners then for _,l in pairs(drawings.Corners) do l.Visible=false end end
			drawings.BoxOutline.Visible=true;drawings.Box.Visible=true
		end
	else
		drawings.Box.Visible=false;drawings.BoxOutline.Visible=false
		if drawings.Corners then for _,l in pairs(drawings.Corners) do l.Visible=false end end
	end
	if Config.ShowVehicleName then
		local dynamicScale=Config.DynamicTextScaling and math.clamp(boxHeight/60,0.5,1.0) or 1.0
		local nameSize=13*(Config.TextScale or 1)*dynamicScale
		local name=vehicle._vehicleName or (vehicle.Model and vehicle.Model.Name) or "Vehicle"
		drawings.Name.Text=name;drawings.Name.Size=nameSize
		drawings.Name.Position=Vector2.new(screenPos.X,boxPos.Y-(nameSize+3))
		drawings.Name.Color=boxColor;drawings.Name.ZIndex=3;drawings.Name.Outline=true;drawings.Name.Visible=true
	else drawings.Name.Visible=false end
	if Config.ShowDistance then
		local dynamicScale=Config.DynamicTextScaling and math.clamp(boxHeight/60,0.5,1.0) or 1.0
		local distSize=12*(Config.TextScale or 1)*dynamicScale
		local meters=math.floor(dist*0.28)
		drawings.Distance.Text=string.format("[%dm]",meters);drawings.Distance.Size=distSize
		drawings.Distance.Color=boxColor;drawings.Distance.ZIndex=3;drawings.Distance.Outline=true
		local distY=boxPos.Y+boxHeight+2
		if Config.ShowVehicleHealth and Config.VehicleHealthBarSide=="Bottom" then distY=distY+6 end
		drawings.Distance.Position=Vector2.new(screenPos.X,distY);drawings.Distance.Visible=true
	else drawings.Distance.Visible=false end
	if Config.ShowVehicleHealth and vehicle.Healths then
		local currentHp=0;local maxHp=0
		for _,v in pairs(vehicle.Healths) do if type(v)=="number" then currentHp=currentHp+v;maxHp=maxHp+100 end end
		if maxHp==0 then maxHp=100 end
		local hpPercent=math.clamp(currentHp/maxHp,0,1)
		local barColor=Config.VehicleHealthColor or Color3.new(0,1,0)
		if Config.UseHealthGradient then barColor=Color3.fromHSV(hpPercent*0.3,1,1) end
		local barSize,barPos,outlineSize,outlinePos
		if Config.VehicleHealthBarSide=="Bottom" then
			local barW=boxWidth*hpPercent
			barSize=Vector2.new(barW,4);barPos=Vector2.new(boxPos.X,boxPos.Y+boxHeight+2)
			outlineSize=Vector2.new(boxWidth+2,6);outlinePos=Vector2.new(boxPos.X-1,boxPos.Y+boxHeight+1)
		elseif Config.VehicleHealthBarSide=="Right" then
			local barH=boxHeight*hpPercent
			barSize=Vector2.new(2,barH);barPos=Vector2.new(boxPos.X+boxWidth+3,boxPos.Y+(boxHeight-barH))
			outlineSize=Vector2.new(4,boxHeight+2);outlinePos=Vector2.new(boxPos.X+boxWidth+2,boxPos.Y-1)
		else
			local barH=boxHeight*hpPercent
			barSize=Vector2.new(2,barH);barPos=Vector2.new(boxPos.X-5,boxPos.Y+(boxHeight-barH))
			outlineSize=Vector2.new(4,boxHeight+2);outlinePos=Vector2.new(boxPos.X-6,boxPos.Y-1)
		end
		drawings.HealthBarOutline.Size=outlineSize+Vector2.new(2,2);drawings.HealthBarOutline.Position=outlinePos-Vector2.new(1,1)
		drawings.HealthBarOutline.Color=Color3.new(0,0,0);drawings.HealthBarOutline.Transparency=1
		drawings.HealthBarOutline.Thickness=1;drawings.HealthBarOutline.ZIndex=0;drawings.HealthBarOutline.Visible=true
		drawings.HealthBar.Size=barSize;drawings.HealthBar.Position=barPos;drawings.HealthBar.Color=barColor
		drawings.HealthBar.Transparency=1;drawings.HealthBar.ZIndex=5;drawings.HealthBar.Visible=true
	else drawings.HealthBar.Visible=false;drawings.HealthBarOutline.Visible=false end
end

local function UpdateVehicles(frameId,cachedCfg)
	if not Config.ShowVehicles then return end
	if not ActorManager.Initialized then return end
	local localActor=ReplicatorService and ReplicatorService.LocalActor; local myVehUID=nil
	if localActor then
		if localActor.Seat then myVehUID=localActor.Seat.UID or (localActor.Seat.Model and localActor.Seat.Model.Name) end
		if not myVehUID and localActor.Turret and localActor.Turret._uid then
			if localActor.Turret._vehicle then myVehUID=localActor.Turret._vehicle.UID
			else myVehUID=localActor.Turret._uid:split("_")[1] end
		end
	end
	for _,actor in ipairs(ActorManager.Vehicles) do
		local uid="Veh_"..tostring(actor.UID); local espData=ESPElements[uid]
		local isLocal=(myVehUID==actor.UID)
		if Config.IgnoreLocalVehicle and isLocal then
			if espData and espData._visible~=false then
				local drawings=espData.Drawing
				drawings.Box.Visible=false;drawings.BoxOutline.Visible=false;drawings.Name.Visible=false
				drawings.Distance.Visible=false;drawings.HealthBar.Visible=false;drawings.HealthBarOutline.Visible=false
				if drawings.Corners then for _,l in ipairs(drawings.Corners) do l.Visible=false end end
				if espData.Highlight then espData.Highlight.Enabled=false end; espData._visible=false
			end
			continue
		end
		if not espData then
			espData={Drawing=CreateDrawingESP(),Type="Vehicle",LastUpdate=frameId,_visible=true}
			ESPElements[uid]=espData
		end
		espData._visible=true; UpdateESPForVehicle(actor.UID,espData,actor,frameId)
	end
end

local function UpdateESP()
	if not ESPEnabled then return end
	if not ReplicatorService then return end
	CurrentFrameId=CurrentFrameId+1
	local localSquad=ClientService and ClientService.LocalClient and ClientService.LocalClient.Squad
	local cachedCfg={
		MaxDistance=Config.MaxDistance or 1000, UseBoxESP=Config.UseBoxESP, BoxStyle=Config.BoxStyle,
		BoxScale=Config.BoxScale or 1, BoxColor=Config.BoxColor, ShowNames=Config.ShowNames,
		ShowDistance=Config.ShowDistance, ShowHealth=Config.ShowHealth, HealthBarSide=Config.HealthBarSide,
		HealthBarColor=Config.HealthBarColor, UseHealthGradient=Config.UseHealthGradient,
		UseTracers=Config.UseTracers, UseHighlight=Config.UseHighlight, SimpleESP=Config.SimpleESP,
		TextScale=(Config.TextScale or 1.2), DynamicTextScaling=true,
	}
	local function Process(list)
		for _,actor in ipairs(list) do
			local uid=actor.UID; if not uid then continue end
			if not ESPElements[uid] then CreateESPForActor(actor,localSquad) end
			local espData=ESPElements[uid]
			if espData then
				if (CurrentFrameId%30)==0 then espData.Color=GetEntityColor(actor,actor._entityType,localSquad) end
				UpdateESPForActor(uid,espData,CurrentFrameId,cachedCfg,localSquad)
			end
		end
	end
	if ActorManager.Initialized then Process(ActorManager.Enemies); Process(ActorManager.Teammates) end
	for uid,espData in pairs(ESPElements) do
		if espData.Type~="Vehicle" and espData.LastUpdate~=CurrentFrameId then RemoveESP(uid) end
	end
end

-- UI
local Notifier=MoonUI.newNotify()
local Window=MoonUI.new({ Name="Tokaihub", Keybind="LeftAlt", Scale=MoonUI.Scale.Window, TextSize=14 })
local _ConfigManager=MoonUI:ConfigManager({ Directory="Tokaihub", Config="Tokaihub" })
_ConfigManager.EnableNotify=true

-- Combat Tab
local CombatTab=Window:DrawTab({ Name="Combat", Icon="swords", Type="Double" })
local S_Rage=CombatTab:DrawSection({ Name="Ragebot", Position="right" })
S_Rage:AddToggle({ Name="Enabled", Flag="Rage_Enabled", Default=false, Callback=function(v) Config.RageMode=v end })
S_Rage:AddToggle({ Name="Look At Target", Flag="Rage_LookAt", Default=false, Callback=function(v) Config.Rage_LookAt=v end })
S_Rage:AddSlider({ Name="Rage Range", Flag="Rage_Range", Min=50, Max=10000, Default=500, Callback=function(v) Config.Rage_Range=v end })
S_Rage:AddDropdown({ Name="Target Part", Flag="Rage_TargetPart", Default="Head", Values={"Head","UpperTorso"}, Callback=function(v) Config.Rage_TargetPart=v end })
S_Rage:AddToggle({ Name="Auto Fire", Flag="Rage_AutoFire", Default=false, Callback=function(v) Config.Rage_AutoFire=v end })
S_Rage:AddToggle({ Name="Ammo Saver (Efficiency)", Flag="Rage_AmmoSaver", Default=false, Callback=function(v) Config.Rage_AmmoSaver=v end })
S_Rage:AddSlider({ Name="Extra Shots (Safety)", Flag="Rage_ExtraShots", Min=0, Max=5, Default=0, Callback=function(v) Config.Rage_ExtraShots=v end })

local S_GunMods=CombatTab:DrawSection({ Name="Gun Mods", Position="right" })
local S_SilentAim=CombatTab:DrawSection({ Name="Silent Aim", Position="left" })
S_SilentAim:AddToggle({ Name="Enabled", Flag="Combat_SilentAim", Default=false, Callback=function(v) Config.SilentAim=v end })
S_SilentAim:AddToggle({ Name="Show FOV", Flag="Combat_ShowFOV", Default=false, Callback=function(v) Config.ShowFOV=v end })
S_SilentAim:AddToggle({ Name="Show Weapon Info", Flag="Combat_ShowWeaponInfo", Default=true, Callback=function(v) Config.ShowWeaponInfo=v end })
S_SilentAim:AddSlider({ Name="FOV Radius", Min=10, Max=500, Default=100, Flag="Combat_SilentAimFOV", Callback=function(v) Config.SilentAimFOV=v end })
S_SilentAim:AddSlider({ Name="Hit Chance", Min=0, Max=100, Default=100, Flag="Combat_SilentAimChance", Callback=function(v) Config.SilentAimHitChance=v end })
S_SilentAim:AddDropdown({ Name="Target Part", Default="Head", Flag="Combat_SilentAimPart",
	Values={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"},
	Callback=function(v) Config.SilentAimTargetPart=v end })
S_SilentAim:AddToggle({ Name="Prediction", Flag="Combat_Prediction", Default=false, Callback=function(v) Config.Prediction=v end })
S_SilentAim:AddToggle({ Name="Bullet Drop", Flag="ESP_BulletDrop", Default=false, Callback=function(v) Config.BulletDrop=v end })

S_GunMods:AddToggle({
	Name = "Auto Reload",
	Flag = "Combat_AutoReload",
	Default = false,
	Callback = function(v)
		Config.AutoReload = v
	end
})
S_GunMods:AddToggle({ Name="No Recoil", Flag="Combat_NoRecoil", Default=false, Callback=function(v) Config.NoRecoil=v end })
S_GunMods:AddToggle({ Name="No Spread", Flag="Combat_NoSpread", Default=false, Callback=function(v) Config.NoSpread=v end })
S_GunMods:AddToggle({ Name="Unlock Firemodes", Flag="Combat_Firemodes", Default=false, Callback=function(v) Config.UnlockFiremodes=v end })
S_GunMods:AddToggle({ Name="Custom RPM", Flag="Combat_CustomRPM", Default=false, Callback=function(v) Config.CustomRPM=v end })
S_GunMods:AddSlider({ Name="RPM Value", Min=100, Max=10000, Default=800, Flag="Combat_RPMValue", Callback=function(v) Config.RPMValue=v end })

-- ESP Tab
local VisualsTab=Window:DrawTab({ Name="ESP", Icon="eye", Type="Double" })
local S_ESP=VisualsTab:DrawSection({ Name="ESP Settings", Position="left" })
S_ESP:AddToggle({ Name="Enable ESP", Flag="ESP_Enabled", Default=false, Callback=function(v)
	ESPEnabled=v; if not v then for uid in pairs(ESPElements) do RemoveESP(uid) end end end })
S_ESP:AddToggle({ Name="Simple ESP (Optimized)", Flag="ESP_Simple", Default=false, Callback=function(v)
	Config.SimpleESP=v; for uid in pairs(ESPElements) do RemoveESP(uid) end end })
S_ESP:AddToggle({ Name="Box ESP", Flag="ESP_Box", Default=true, Callback=function(v)
	Config.UseBoxESP=v; for uid in pairs(ESPElements) do RemoveESP(uid) end end })
S_ESP:AddToggle({ Name="Highlight ESP", Flag="ESP_Highlight", Default=false, Callback=function(v)
	Config.UseHighlight=v; for uid in pairs(ESPElements) do RemoveESP(uid) end end })
S_ESP:AddToggle({ Name="Tracers", Flag="ESP_Tracers", Default=false, Callback=function(v)
	Config.UseTracers=v; for uid in pairs(ESPElements) do RemoveESP(uid) end end })
S_ESP:AddToggle({ Name="Show Names", Flag="ESP_Names", Default=true, Callback=function(v) Config.ShowNames=v end })
S_ESP:AddToggle({ Name="Show Distance", Flag="ESP_Distance", Default=true, Callback=function(v) Config.ShowDistance=v end })
S_ESP:AddToggle({ Name="Show Health", Flag="ESP_Health", Default=true, Callback=function(v) Config.ShowHealth=v end })
S_ESP:AddToggle({ Name="Show Prediction", Flag="ESP_ShowPred", Default=false, Callback=function(v) Config.ShowPrediction=v end })
S_ESP:AddColorPicker({ Name="Prediction Color", Default=Config.PredictionColor, Flag="ESP_PredColor", Callback=function(v)
	Config.PredictionColor=v; local dot=getgenv().PredictionDot; if dot then dot.Color=v end end })
Config.TextScale=1.2
S_ESP:AddSlider({ Name="Max Distance (m)", Min=25, Max=10000, Default=1000, Flag="ESP_MaxDist", Callback=function(v)
	Config.MaxDistance=math.floor(v*3.57) end })

local S_Filters=VisualsTab:DrawSection({ Name="Entity Filters", Position="right" })
S_Filters:AddToggle({ Name="Show Players", Flag="ESP_Players", Default=true, Callback=function(v)
	Config.ShowPlayers=v; for uid in pairs(ESPElements) do RemoveESP(uid) end end })
S_Filters:AddToggle({ Name="Show Zombies", Flag="ESP_Zombies", Default=true, Callback=function(v)
	Config.ShowZombies=v; for uid in pairs(ESPElements) do RemoveESP(uid) end end })
S_Filters:AddToggle({ Name="Show NPCs", Flag="ESP_NPCs", Default=true, Callback=function(v)
	Config.ShowNPCs=v; for uid in pairs(ESPElements) do RemoveESP(uid) end end })
S_Filters:AddToggle({ Name="Show teammates", Flag="ESP_Squad", Default=false, Callback=function(v)
	Config.ShowSquadMembers=v; for uid in pairs(ESPElements) do RemoveESP(uid) end end })
S_Filters:AddButton({ Name="Clear All ESP", Callback=function() for uid in pairs(ESPElements) do RemoveESP(uid) end end })

local S_Colors=VisualsTab:DrawSection({ Name="Entity Colors", Position="right" })
S_Colors:AddColorPicker({ Name="Player (Enemy)", Flag="Color_Player", Default=Config.PlayerColor, Callback=function(v) Config.PlayerColor=v end })
S_Colors:AddColorPicker({ Name="Teammate (Squad)", Flag="Color_Squad", Default=Config.SquadColor, Callback=function(v) Config.SquadColor=v end })
S_Colors:AddColorPicker({ Name="NPC", Flag="Color_NPC", Default=Config.NPCColor, Callback=function(v) Config.NPCColor=v end })
S_Colors:AddColorPicker({ Name="Zombie: Crippled", Flag="Color_Z_Crippled", Default=Config.ZombieColors[1], Callback=function(v) Config.ZombieColors[1]=v end })
S_Colors:AddColorPicker({ Name="Zombie: Slow", Flag="Color_Z_Slow", Default=Config.ZombieColors[2], Callback=function(v) Config.ZombieColors[2]=v end })
S_Colors:AddColorPicker({ Name="Zombie: Normal", Flag="Color_Z_Normal", Default=Config.ZombieColors[3], Callback=function(v) Config.ZombieColors[3]=v end })
S_Colors:AddColorPicker({ Name="Zombie: Sprinter", Flag="Color_Z_Sprinter", Default=Config.ZombieColors[4], Callback=function(v) Config.ZombieColors[4]=v end })

local S_Layout=VisualsTab:DrawSection({ Name="Layout Settings", Position="left" })
Config.BoxScale=1.4
S_Layout:AddDropdown({ Name="Box Style", Values={"Full","Corner"}, Default="Full", Flag="ESP_BoxStyle", Callback=function(v) Config.BoxStyle=v end })
S_Layout:AddColorPicker({ Name="Box Color", Flag="ESP_BoxColorOverride", Default=Color3.fromRGB(255,255,255), Callback=function(v) Config.BoxColor=v end })
S_Layout:AddDropdown({ Name="Health Bar Position", Values={"Left","Right","Bottom"}, Default="Left", Flag="ESP_BarPos", Callback=function(v) Config.HealthBarSide=v end })
S_Layout:AddToggle({ Name="Health Gradient", Flag="ESP_BarGrad", Default=true, Callback=function(v) Config.UseHealthGradient=v end })
S_Layout:AddColorPicker({ Name="Health Color", Flag="ESP_BarColor", Default=Color3.fromRGB(0,255,0), Callback=function(v) Config.HealthBarColor=v end })

-- Character Tab
local CharacterTab=Window:DrawTab({ Name="Character", Icon="user", Type="Double" })
local S_Movement=CharacterTab:DrawSection({ Name="Movement", Position="left" })
local FlyToggle=S_Movement:AddToggle({ Name="Fly", Flag="Char_Fly", Default=false, Callback=function(v)
	Config.Character_Fly=v
	if not v and ControllerService and ControllerService.Controller then
		if ControllerService.Controller.SetCFrame then ControllerService.Controller:SetCFrame(nil) end
	end
end })
local FlyKey="V"
FlyToggle.Link:AddKeybind({ Name="Fly Key", Flag="Char_FlyKey", Default=FlyKey, Callback=function(v) FlyKey=v end })
game:GetService("UserInputService").InputBegan:Connect(function(input,gameProcessed)
	if gameProcessed then return end
	if FlyKey and FlyKey~="None" and (input.KeyCode.Name==FlyKey or input.KeyCode==FlyKey) then
		FlyToggle.Instance:SetValue(not FlyToggle.Instance:GetValue())
	end
end)
S_Movement:AddToggle({
	Name = "Infinite Stamina",
	Flag = "Char_InfStamina",
	Default = false,
	Callback = function(v)
		Config.InfStamina = v
	end
})
S_Movement:AddToggle({ Name="Spinbot", Flag="Char_Spinbot", Default=false, Callback=function(v) Config.Spinbot=v end })
S_Movement:AddSlider({ Name="Spin Speed", Min=1, Max=100, Default=20, Flag="Char_SpinSpeed", Callback=function(v) Config.SpinbotSpeed=v end })
S_Movement:AddSlider({ Name="Fly Speed", Min=10, Max=1000, Default=50, Flag="Char_FlySpeed", Callback=function(v) Config.Character_FlySpeed=v end })
S_Movement:AddToggle({ Name="Walk Speed", Flag="Char_WalkSpeedEnabled", Default=false, Callback=function(v) Config.Character_WalkSpeedEnabled=v end })
S_Movement:AddSlider({ Name="Walk Speed Value", Min=16, Max=100, Default=16, Flag="Char_WalkSpeed", Callback=function(v) Config.Character_WalkSpeed=v end })
S_Movement:AddToggle({ Name="Sprint Speed", Flag="Char_SprintSpeedEnabled", Default=false, Callback=function(v) Config.Character_SprintSpeedEnabled=v end })
S_Movement:AddSlider({ Name="Sprint Speed Value", Min=25, Max=100, Default=25, Flag="Char_SprintSpeed", Callback=function(v) Config.Character_SprintSpeed=v end })

local S_World=CharacterTab:DrawSection({ Name="World", Position="right" })
S_World:AddToggle({ Name="Thermal Vision", Flag="World_ThermalVision", Default=false, Callback=function(v)
	Config.ThermalVision=v; if EnvironmentService then EnvironmentService.FLIR=v end end })
local NVGColorCorrection=nil
local NVGColors={["Green"]=Color3.fromRGB(112,245,65),["Blue"]=Color3.fromRGB(165,233,255)}
local CurrentNVGColor="Green"
local function ApplyNVGEffect()
	if Config.NightVision and NVGColorCorrection then
		NVGColorCorrection.TintColor=NVGColors[CurrentNVGColor] or NVGColors["Green"]
		NVGColorCorrection.Brightness=0.15;NVGColorCorrection.Contrast=0.5;NVGColorCorrection.Saturation=-1;NVGColorCorrection.Enabled=true
	end
end
S_World:AddToggle({ Name="Night Vision", Flag="World_NightVision", Default=false, Callback=function(v)
	Config.NightVision=v
	if v then
		if not NVGColorCorrection then
			NVGColorCorrection=Instance.new("ColorCorrectionEffect"); NVGColorCorrection.Name="ESP_NightVision"
			NVGColorCorrection.Parent=game:GetService("Lighting")
		end
		ApplyNVGEffect()
	else if NVGColorCorrection then NVGColorCorrection.Enabled=false end end
end })
S_World:AddDropdown({ Name="NVG Color", Flag="World_NVGColor", Values={"Green","Blue"}, Default="Green", Callback=function(v)
	CurrentNVGColor=v; ApplyNVGEffect() end })

-- Vehicles Tab
local VehicleTab=Window:DrawTab({ Name="Vehicles", Icon="car", Type="Double" })
local S_VehVisuals=VehicleTab:DrawSection({ Name="Visuals", Position="right" })
local S_VehFly=VehicleTab:DrawSection({ Name="Vehicle Fly", Position="left" })
local VehFlyToggle=S_VehFly:AddToggle({ Name="Enable Fly", Flag="Veh_FlyEnabled", Default=false, Callback=function(v) Config.VehicleFly_Enabled=v end })
VehFlyToggle.Link:AddKeybind({ Name="Toggle Key", Flag="Veh_FlyKey", Default=Config.VehicleFly_ToggleKey, Callback=function(v) Config.VehicleFly_ToggleKey=v end })
S_VehFly:AddSlider({ Name="Fly Speed", Min=10, Max=500, Default=100, Flag="Veh_FlySpeed", Callback=function(v) Config.VehicleFly_Speed=v end })
local S_VehTurret=VehicleTab:DrawSection({ Name="Turret Mods", Position="left" })
S_VehTurret:AddToggle({ Name="Unlock Firemodes", Flag="Veh_UnlockFiremodes", Default=false, Callback=function(v) Config.TurretUnlockFiremodes=v end })
S_VehTurret:AddToggle({ Name="No Recoil", Flag="Veh_NoRecoil", Default=false, Callback=function(v) Config.TurretNoRecoil=v end })
S_VehTurret:AddToggle({ Name="No Spread", Flag="Veh_NoSpread", Default=false, Callback=function(v) Config.TurretNoSpread=v end })
S_VehVisuals:AddToggle({ Name="Enabled", Flag="ESP_Vehicles", Default=false, Callback=function(v) Config.ShowVehicles=v end })
S_VehVisuals:AddToggle({ Name="Ignore Local Vehicle", Flag="ESP_VehIgnoreLocal", Default=true, Callback=function(v) Config.IgnoreLocalVehicle=v end })
S_VehVisuals:AddToggle({ Name="Show Box", Flag="ESP_VehBox", Default=true, Callback=function(v) Config.ShowVehicleBox=v end })
S_VehVisuals:AddDropdown({ Name="Box Style", Values={"Full","Corner"}, Default="Full", Flag="ESP_VehBoxStyle", Callback=function(v) Config.VehicleBoxStyle=v end })
S_VehVisuals:AddColorPicker({ Name="Box Color", Flag="ESP_VehColor", Default=Config.VehicleColor, Callback=function(v) Config.VehicleColor=v end })
S_VehVisuals:AddToggle({ Name="Show Name", Flag="ESP_VehName", Default=true, Callback=function(v) Config.ShowVehicleName=v end })
S_VehVisuals:AddToggle({ Name="Show Health", Flag="ESP_VehHealth", Default=true, Callback=function(v) Config.ShowVehicleHealth=v end })
S_VehVisuals:AddDropdown({ Name="Health Bar Pos", Values={"Left","Right","Bottom"}, Default="Bottom", Flag="ESP_VehBarSide", Callback=function(v) Config.VehicleHealthBarSide=v end })
S_VehVisuals:AddColorPicker({ Name="Health Color", Flag="ESP_VehHealthColor", Default=Config.VehicleHealthColor, Callback=function(v) Config.VehicleHealthColor=v end })

-- Misc Tab
local MiscTab=Window:DrawTab({ Name="Misc", Icon="droplets", Type="Double" })
local S_Atmosphere=MiscTab:DrawSection({ Name="Atmosphere", Position="left" })
S_Atmosphere:AddToggle({ Name="Always Day", Flag="Misc_AlwaysDay", Default=false, Callback=function(v) Config.AlwaysDay=v end })
S_Atmosphere:AddToggle({ Name="No Fog", Flag="Misc_NoFog", Default=false, Callback=function(v) Config.NoFog=v end })

-- Settings Tab
local SettingsTab=Window:DrawTab({ Name="Settings", Icon="settings", Type="Double" })
local MenuGroup=SettingsTab:DrawSection({ Name="Menu", Position="left" })
MenuGroup:AddToggle({ Name="Open Keybind Menu", Flag="KeybindMenuOpen", Default=Library.KeybindFrame and Library.KeybindFrame.Visible or false, Callback=function(value)
	if Library.KeybindFrame then Library.KeybindFrame.Visible=value end end })
MenuGroup:AddToggle({ Name="Custom Cursor", Flag="ShowCustomCursor", Default=true, Callback=function(value) Library.ShowCustomCursor=value end })
MenuGroup:AddDropdown({
	Name = "Notification Side",
	Flag = "NotificationSide",
	Values = { "Left", "Right" },
	Default = "Right",
	Callback = function(value)
		if Library.SetNotifySide then
			Library:SetNotifySide(value)
		end
	end,
})
MenuGroup:AddDropdown({ Name="DPI Scale", Flag="DPIDropdown", Values={"50%","75%","100%","125%","150%","175%","200%"}, Default="100%", Callback=function(value)
	value=tostring(value):gsub("%%",""); local DPI=tonumber(value)
	if DPI and Library.SetDPIScale then Library:SetDPIScale(DPI) end end })
MenuGroup:AddSlider({ Name="Corner Radius", Flag="UICornerSlider", Default=Library.CornerRadius or 8, Min=0, Max=20, Rounding=0, Callback=function(value)
	if Window.Raw and Window.Raw.SetCornerRadius then Window.Raw:SetCornerRadius(value) end end })
MenuGroup:AddKeybind({ Name="Menu bind", Flag="MenuKeybind", Default="RightShift", NoUI=true, Callback=function()
	Library.ToggleKeybind=Options.MenuKeybind end })
MenuGroup:AddButton({ Name="Unload", Callback=function()
	pcall(function() Library:Unload() end); pcall(function() Window:Unload() end)
	if getgenv().Moon_Connections then
		for _,c in pairs(getgenv().Moon_Connections) do c:Disconnect() end
		getgenv().Moon_Connections={}
	end
	for uid in pairs(ESPElements) do RemoveESP(uid) end
end })

local ConfigUI=Window:DrawConfig({ Name="Configs", Icon="folder", Config=_ConfigManager })
ConfigUI:Init()

-- Main Loop
local frameCount=0
local espLoop=RunService.RenderStepped:Connect(function()
	frameCount=(frameCount+1)%60
	if ActorManager then
		ActorManager:Update()
		if ActorManager._rageBurst and frameCount%60==0 then
			for uid,data in pairs(ActorManager._rageBurst) do
				local lastActivity=data.lastShot or data.lastHealthUpdate or 0
				if tick()-lastActivity>10 then ActorManager._rageBurst[uid]=nil end
			end
		end
	end
	UpdateESP()
	if frameCount%2==0 then UpdateVehicles(frameCount,Config) end
	UpdateCombat(frameCount)
end)
table.insert(getgenv().Moon_Connections,espLoop)

-- Startup
Notifier.new({ Title="Tokaihub", Content="Tokaihub loaded successfully!", Duration=5 })

if Config.AutoDetectMap then Config.CurrentMapType=DetectMapType() end

task.spawn(function()
	task.wait(2.5)
	InitializeServices()
	task.wait(0.5)
	VehicleFly.HookVehicles()
	print("[Vehicle Fly] Ready! Press X to toggle")
end)

local flyKeybind=UserInputService.InputBegan:Connect(function(input,gameProcessed)
	if gameProcessed then return end
	if input.KeyCode==Config.VehicleFly_ToggleKey then VehicleFly.Toggle() end
end)
table.insert(getgenv().Moon_Connections,flyKeybind)

-- ==========================================
-- AUTO FARM SYSTEM
-- Teleport to enemy → shoot N shots → next enemy
-- ==========================================

local AutoFarm = {
	Enabled = false,
	ShotsPerTarget = 2,       -- viên bắn mỗi mục tiêu
	TeleportOffset = Vector3.new(0, 0, 3), -- offset phía sau target
	ShootDelay = 0.12,        -- delay giữa các viên (giây)
	SwitchDelay = 0.3,        -- delay trước khi switch target
	_running = false,
	_connection = nil,
	_currentTarget = nil,
	_shotsFired = 0,
	_lastShot = 0,
	_phase = "seek",          -- seek | shoot | switch
	_enemyIndex = 1,
}

-- Teleport LocalActor đến vị trí gần target
local function AutoFarm_Teleport(targetActor)
	local myActor = ReplicatorService and ReplicatorService.LocalActor
	if not myActor then return false end

	local targetPos = targetActor.Position
	if not targetPos then
		local char = targetActor.Character
		if char and char.PrimaryPart then
			targetPos = char.PrimaryPart.Position
		end
	end
	if not targetPos then return false end

	-- offset ra phía sau target dựa theo camera
	local camDir = Camera.CFrame.LookVector
	local offset = Vector3.new(
		AutoFarm.TeleportOffset.X,
		AutoFarm.TeleportOffset.Y,
		AutoFarm.TeleportOffset.Z
	)
	local newPos = targetPos + Vector3.new(0, 2, 0) + (camDir * -offset.Z)

	-- Set position via CharacterController
	pcall(function()
		myActor.SimulatedPosition = newPos
		myActor.CFrame = CFrame.new(newPos, targetPos)
		if ControllerService and ControllerService.Controller then
			ControllerService.Controller._position = newPos
			ControllerService.Controller._lastSafePosition = newPos
		end
	end)

	return true
end

-- Pick next valid enemy
local function AutoFarm_NextTarget()
	local enemies = ActorManager.Enemies
	if not enemies or #enemies == 0 then return nil end

	-- cycle qua list
	local startIdx = AutoFarm._enemyIndex
	local count = #enemies

	for i = 1, count do
		local idx = ((startIdx - 1 + i - 1) % count) + 1
		local actor = enemies[idx]
		if actor and actor.Alive and actor.Character then
			AutoFarm._enemyIndex = (idx % count) + 1
			return actor
		end
	end
	return nil
end

-- Main farm tick — chạy trên Heartbeat
local function AutoFarm_Tick()
	if not AutoFarm.Enabled then return end
	if not ActorManager.Initialized then return end

	local now = tick()
	local equippedController = WeaponManager.Equipped or
		(InventoryService and InventoryService.Equipped and InventoryService.Equipped.Handler)

	-- PHASE: SEEK — tìm và teleport đến target mới
	if AutoFarm._phase == "seek" then
		local target = AutoFarm_NextTarget()
		if not target then return end

		AutoFarm._currentTarget = target
		AutoFarm._shotsFired = 0

		-- Set ragebot target
		ActorManager.SelectedTarget_RB = target.Character and target.Character:FindFirstChild(Config.Rage_TargetPart or "Head")
		ActorManager.SelectedActor_RB = target

		-- Teleport
		AutoFarm_Teleport(target)

		AutoFarm._phase = "shoot"
		AutoFarm._lastShot = now
		return
	end

	-- PHASE: SHOOT — bắn N viên
	if AutoFarm._phase == "shoot" then
		local target = AutoFarm._currentTarget

		-- Validate target còn sống
		if not target or not target.Alive then
			AutoFarm._phase = "seek"
			return
		end

		-- Check delay giữa viên
		if (now - AutoFarm._lastShot) < AutoFarm.ShootDelay then return end

		-- Bắn
		if equippedController then
			-- Update target part mỗi viên (vì target có thể di chuyển)
			local char = target.Character
			if char then
				local part = char:FindFirstChild(Config.Rage_TargetPart or "Head")
					or char:FindFirstChild("UpperTorso")
				if part then
					ActorManager.SelectedTarget_RB = part
					ActorManager.SelectedActor_RB = target
				end
			end

			pcall(function() equippedController:Discharge() end)
			AutoFarm._shotsFired = AutoFarm._shotsFired + 1
			AutoFarm._lastShot = now
		end

		-- Đủ viên → chuyển phase
		if AutoFarm._shotsFired >= AutoFarm.ShotsPerTarget then
			AutoFarm._phase = "switch"
			AutoFarm._lastShot = now
		end
		return
	end

	-- PHASE: SWITCH — chờ rồi tìm target kế
	if AutoFarm._phase == "switch" then
		if (now - AutoFarm._lastShot) >= AutoFarm.SwitchDelay then
			AutoFarm._currentTarget = nil
			ActorManager.SelectedTarget_RB = nil
			ActorManager.SelectedActor_RB = nil
			AutoFarm._phase = "seek"
		end
		return
	end
end

-- Start / Stop
function AutoFarm.Start()
	if AutoFarm._running then return end
	AutoFarm._running = true
	AutoFarm._phase = "seek"
	AutoFarm._enemyIndex = 1

	AutoFarm._connection = RunService.Heartbeat:Connect(AutoFarm_Tick)
	table.insert(getgenv().Moon_Connections, AutoFarm._connection)
	print("[AutoFarm] Started")
end

function AutoFarm.Stop()
	AutoFarm._running = false
	AutoFarm._currentTarget = nil
	ActorManager.SelectedTarget_RB = nil
	ActorManager.SelectedActor_RB = nil
	AutoFarm._phase = "seek"

	if AutoFarm._connection then
		pcall(function() AutoFarm._connection:Disconnect() end)
		AutoFarm._connection = nil
	end
	print("[AutoFarm] Stopped")
end




-- ==========================================
-- VEHICLE MODS — Turret RPM + Auto Reload
-- ==========================================
local _TurretConfigModule = nil
local _TurretOriginals = {}
local _TurretMods = { CustomRPM=false, RPMValue=1000 }

local function _findModule(name)
	local rf = game:GetService("ReplicatedFirst")
	for _, flux in ipairs(rf:GetChildren()) do
		if flux.Name:find("Flux") then
			local services = flux:FindFirstChild("Services")
			if services then
				for _, s in ipairs(services:GetChildren()) do
					if s.Name:find(name) and s:IsA("ModuleScript") then return s end
				end
			end
		end
	end
	local function search(parent)
		if not parent then return end
		for _, child in ipairs(parent:GetChildren()) do
			if (child.Name:find(name,1,true) or child.Name:lower():find(name:lower(),1,true))
				and child:IsA("ModuleScript") then return child end
			local found = search(child)
			if found then return found end
		end
	end
	return search(rf) or search(game:GetService("ReplicatedStorage"))
end

local function _GetTurretConfig()
	if not _TurretConfigModule then
		local mod = _findModule("Turrets")
		if mod then
			local ok, result = pcall(require, mod)
			if ok and result then _TurretConfigModule = result end
		end
	end
	return _TurretConfigModule
end

local function ApplyTurretRPM()
	local configs = _GetTurretConfig()
	if not configs then return end
	for name, stats in pairs(configs) do
		if type(stats) == "table" and stats.RPM then
			if not _TurretOriginals[name] then _TurretOriginals[name] = stats.RPM end
			if _TurretMods.CustomRPM then
				stats.RPM = _TurretMods.RPMValue
			else
				stats.RPM = _TurretOriginals[name]
			end
		end
	end
end

local _autoReloadTick2 = 0
local function DoAutoReload_Veh()
	local now = tick()
	if now - _autoReloadTick2 < 0.2 then return end
	_autoReloadTick2 = now
	local weapon = WeaponManager.Equipped
		or (InventoryService and InventoryService.Equipped and InventoryService.Equipped.Handler)
	if not weapon then return end
	local magEmpty = (weapon._mag and (weapon._mag.Capacity or 0) == 0) or not weapon._mag
	if magEmpty and not weapon._reloading then
		pcall(function()
			if weapon._getMags and weapon._reload then
				local mags = weapon:_getMags()
				if mags and #mags > 0 then weapon:_reload() end
			elseif weapon.Reload then weapon:Reload() end
		end)
	end
end

local VehicleMods = { AutoReload=false, TurretCustomRPM=false, TurretRPMValue=1000 }
getgenv().VehicleMods = VehicleMods

local _vmHb = RunService.Heartbeat:Connect(function()
	if VehicleMods.AutoReload then DoAutoReload_Veh() end
	if VehicleMods.TurretCustomRPM then ApplyTurretRPM() end
end)
table.insert(getgenv().Moon_Connections, _vmHb)

S_VehTurret:AddToggle({ Name="Auto Reload", Flag="Veh_AutoReload", Default=false,
	Callback=function(v) VehicleMods.AutoReload=v end })
S_VehTurret:AddToggle({ Name="Turret Custom RPM", Flag="Veh_TurretCustomRPM", Default=false,
	Callback=function(v)
		VehicleMods.TurretCustomRPM=v; _TurretMods.CustomRPM=v
		if not v then _TurretOriginals={}; ApplyTurretRPM() end
	end })
S_VehTurret:AddSlider({ Name="Turret RPM", Flag="Veh_TurretRPMValue",
	Min=100, Max=10000, Default=1000, Rounding=0,
	Callback=function(v) VehicleMods.TurretRPMValue=v; _TurretMods.RPMValue=v end })
S_VehTurret:AddButton({ Name="Force Apply RPM",
	Callback=function()
		_TurretOriginals={}; _TurretConfigModule=nil; ApplyTurretRPM()
		Notifier.new({ Title="Turret RPM", Content="Applied ".._TurretMods.RPMValue.." RPM", Duration=3 })
	end })


-- ==========================================
-- BULLET TRACER v3 — Part Neon, chỉ local
-- ==========================================
local BulletTracer = {
	Enabled=false, Lifetime=3, Color=Color3.fromRGB(255,200,50),
	Transparency=0.3, Width=0.05, FadeOut=true, _parts={},
}
local function BT_SpawnPart(fromPos, toPos)
	local dist = (toPos-fromPos).Magnitude
	if dist < 0.5 then return end
	local part = Instance.new("Part")
	part.Name="BT"; part.Anchored=true; part.CanCollide=false
	part.CanTouch=false; part.CastShadow=false
	part.Size=Vector3.new(BulletTracer.Width, BulletTracer.Width, dist)
	part.CFrame=CFrame.new((fromPos+toPos)/2, toPos)
	part.Color=BulletTracer.Color; part.Transparency=BulletTracer.Transparency
	part.Material=Enum.Material.Neon
	pcall(function() part.Parent=Workspace end)
	table.insert(BulletTracer._parts, {part=part, born=tick()})
end
local function BT_Update()
	local now=tick(); local rem={}
	for i,t in ipairs(BulletTracer._parts) do
		if not t.part or not t.part.Parent then rem[#rem+1]=i; continue end
		local age=now-t.born
		if age>=BulletTracer.Lifetime then
			pcall(function() t.part:Destroy() end); rem[#rem+1]=i
		elseif BulletTracer.FadeOut then
			local a=age/BulletTracer.Lifetime
			pcall(function() t.part.Transparency=BulletTracer.Transparency+(1-BulletTracer.Transparency)*a end)
		end
	end
	for i=#rem,1,-1 do table.remove(BulletTracer._parts, rem[i]) end
end
local function BT_Hook()
	if not BulletService or BulletService._tracerHooked then return end
	local existing = BulletService.Discharge
	BulletService.Discharge = function(self, originCF, ...)
		local res = {pcall(existing, self, originCF, ...)}
		if BulletTracer.Enabled and originCF then
			local localMuzzle = GetMuzzlePosition()
			local mPos = originCF.Position
			if not localMuzzle or (mPos-localMuzzle).Magnitude <= 5 then
				local dir = originCF.LookVector
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				local fl = {Camera}
				if LocalPlayer.Character then fl[2]=LocalPlayer.Character end
				rp.FilterDescendantsInstances = fl
				local ray = Workspace:Raycast(mPos, dir*2000, rp)
				task.spawn(BT_SpawnPart, mPos, ray and ray.Position or mPos+dir*800)
			end
		end
		if res[1] then return table.unpack(res, 2) end
	end
	BulletService._tracerHooked = true
end
local _btHb = RunService.Heartbeat:Connect(function()
	if #BulletTracer._parts > 0 then BT_Update() end
end)
table.insert(getgenv().Moon_Connections, _btHb)
getgenv().BulletTracer = BulletTracer

local S_BT = MiscTab:DrawSection({ Name="Bullet Tracer", Position="right" })
S_BT:AddToggle({ Name="Enable Tracer", Flag="BT_Enabled", Default=false,
	Callback=function(v) BulletTracer.Enabled=v; if v then BT_Hook() end end })
S_BT:AddSlider({ Name="Lifetime (s)", Flag="BT_Lifetime", Min=1, Max=20, Default=3, Rounding=0,
	Callback=function(v) BulletTracer.Lifetime=v end })
S_BT:AddSlider({ Name="Transparency", Flag="BT_Transparency", Min=0, Max=100, Default=30, Rounding=0,
	Callback=function(v) BulletTracer.Transparency=v/100 end })
S_BT:AddSlider({ Name="Width (x0.01)", Flag="BT_Width", Min=1, Max=50, Default=5, Rounding=0,
	Callback=function(v) BulletTracer.Width=v/100 end })
S_BT:AddToggle({ Name="Fade Out", Flag="BT_FadeOut", Default=true,
	Callback=function(v) BulletTracer.FadeOut=v end })
S_BT:AddColorPicker({ Name="Tracer Color", Flag="BT_Color", Default=BulletTracer.Color,
	Callback=function(v)
		BulletTracer.Color=v
		for _,t in ipairs(BulletTracer._parts) do
			pcall(function() if t.part and t.part.Parent then t.part.Color=v end end)
		end
	end })

print("[VehicleMods + BulletTracer + FOV Screen-Center] Loaded")

-- ==========================================
-- AUTO REMOVE TREE
-- ==========================================
local _TreePrefixes = {"arb", "qradbiq", "oradbbig", "oragedbbig"}
local _AutoTree = { Enabled = false, _connection = nil }

local function _startsWith(str, prefix)
	return string.sub(str:lower(), 1, #prefix) == prefix
end

local function _DeleteTrees()
	local toDelete = {}
	local parentMark = {}
	for _, obj in pairs(Workspace:GetDescendants()) do
		local name = obj.Name:lower()
		local matched = false
		for _, p in ipairs(_TreePrefixes) do
			if _startsWith(name, p) then matched = true; break end
		end
		if matched then
			if obj:IsA("Model") or obj:IsA("Folder") then
				table.insert(toDelete, obj)
				parentMark[obj] = true
			else
				local parent = obj.Parent
				if parent and not parentMark[parent] then
					table.insert(toDelete, obj)
				end
			end
		end
	end
	for _, obj in pairs(toDelete) do
		if obj and obj.Parent then pcall(function() obj:Destroy() end) end
	end
end

local S_AutoTree = MiscTab:DrawSection({ Name="Auto Remove Tree", Position="left" })

S_AutoTree:AddToggle({
	Name = "Enable",
	Flag = "AT_Enabled",
	Default = false,
	Callback = function(v)
		_AutoTree.Enabled = v
		if v then
			if not _AutoTree._connection then
				_AutoTree._connection = RunService.Heartbeat:Connect(function()
					if _AutoTree.Enabled then _DeleteTrees() end
				end)
				table.insert(getgenv().Moon_Connections, _AutoTree._connection)
			end
		else
			if _AutoTree._connection then
				pcall(function() _AutoTree._connection:Disconnect() end)
				_AutoTree._connection = nil
			end
		end
	end
})

S_AutoTree:AddButton({
	Name = "Delete Once",
	Callback = function() _DeleteTrees() end
})

print("[AutoRemoveTree] Loaded")


-- ==========================================
-- HIT SOUND
-- Phát âm thanh khi bắn trúng enemy/NPC
-- Sound ID: 79887435989574
-- ==========================================
local HitSound = {
	Enabled = false,
	Volume = 0.5,
	_sound = nil,
}

-- Tạo Sound object trong LocalPlayer
local function HS_Init()
	if HitSound._sound and HitSound._sound.Parent then return end
	local s = Instance.new("Sound")
	s.Name = "HitSound"
	s.SoundId = "rbxassetid://79887435989574"
	s.Volume = HitSound.Volume
	s.RollOffMaxDistance = 0  -- không decay theo khoảng cách
	s.Parent = game:GetService("SoundService")
	HitSound._sound = s
end

local function HS_Play()
	if not HitSound.Enabled then return end
	if not HitSound._sound then HS_Init() end
	pcall(function()
		HitSound._sound.Volume = HitSound.Volume
		HitSound._sound:Play()
	end)
end

-- Hook BulletService.Discharge — detect khi đạn trúng enemy
local function HS_Hook()
	if not BulletService or BulletService._hitSoundHooked then return end

	local existing = BulletService.Discharge
	BulletService.Discharge = function(self, originCF, ...)
		local res = {pcall(existing, self, originCF, ...)}

		if HitSound.Enabled and originCF then
			-- Chỉ check khi là local player bắn
			local localMuzzle = GetMuzzlePosition()
			local mPos = originCF.Position
			if localMuzzle and (mPos - localMuzzle).Magnitude <= 5 then
				-- Raycast để tìm xem có trúng enemy không
				local dir = originCF.LookVector
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				local fl = {Camera}
				if LocalPlayer.Character then fl[2] = LocalPlayer.Character end
				rp.FilterDescendantsInstances = fl

				local ray = Workspace:Raycast(mPos, dir * 2000, rp)
				if ray and ray.Instance then
					-- Kiểm tra part có thuộc character của enemy không
					local hitPart = ray.Instance
					local hitModel = hitPart:FindFirstAncestorOfClass("Model")
					if hitModel then
						-- Check qua ActorManager enemies
						if ActorManager.Initialized then
							for _, actor in ipairs(ActorManager.Enemies) do
								if actor.Alive and actor.Character == hitModel then
									HS_Play()
									break
								end
							end
						end
					end
				end
			end
		end

		if res[1] then return table.unpack(res, 2) end
	end
	BulletService._hitSoundHooked = true
end

HS_Init()

-- UI — Misc tab
local S_HitSound = MiscTab:DrawSection({ Name="Hit Sound", Position="left" })

S_HitSound:AddToggle({
	Name = "Enable Hit Sound", Flag = "HS_Enabled", Default = false,
	Callback = function(v)
		HitSound.Enabled = v
		if v then HS_Hook() end
	end
})

S_HitSound:AddSlider({
	Name = "Volume", Flag = "HS_Volume",
	Min = 0, Max = 100, Default = 50, Rounding = 0,
	Callback = function(v)
		HitSound.Volume = v / 100
		if HitSound._sound then
			pcall(function() HitSound._sound.Volume = HitSound.Volume end)
		end
	end
})

S_HitSound:AddInput({
	Name = "Sound ID",
	Flag = "HS_SoundID",
	Default = "79887435989574",
	NumericOnly = true,
	Placeholder = "rbxassetid://...",
	Callback = function(v)
		local id = tostring(v):match("%d+")
		if id and #id > 0 then
			if HitSound._sound then
				pcall(function()
					HitSound._sound.SoundId = "rbxassetid://"..id
					HitSound._currentID = id
				end)
			end
		end
	end
})

S_HitSound:AddButton({
	Name = "Test Sound",
	Callback = function() HS_Play() end
})

getgenv().HitSound = HitSound
print("[HitSound] Loaded — ID: 79887435989574")

-- ==========================================
-- ANTI FALL DAMAGE
-- Tận dụng CharacterController — zero gravity khi đang rơi
-- ==========================================
local AntiFall = { Enabled = false }

local function AF_Hook()
	local TargetController = nil

	if CharacterController and CharacterController.Update then
		TargetController = CharacterController
	elseif ControllerService and ControllerService.Controller then
		local ctrl = ControllerService.Controller
		if ctrl.Update then TargetController = ctrl
		else
			local meta = getmetatable(ctrl)
			local index = meta and (meta.__index or meta)
			if type(index) == "table" and index.Update then TargetController = index end
		end
	end

	if not TargetController then
		-- Fallback: scan GC
		local ok, gc = pcall(function() return filtergc("table") end)
		if not ok then ok, gc = pcall(function() return getgc(true) end) end
		if ok and gc then
			for _, obj in pairs(gc) do
				if type(obj) == "table" and rawget(obj, "Update")
					and rawget(obj, "VelocityGravity") ~= nil then
					TargetController = obj; break
				end
			end
		end
	end

	if not TargetController then
		warn("[AntiFall] Controller not found — retry after 2s")
		task.delay(2, AF_Hook)
		return
	end

	-- Hook Update đã có sẵn (từ fly/speed controller)
	-- Thêm anti-fall logic vào đầu — không override hook cũ
	local existingUpdate = TargetController.Update
	if TargetController._antiFallHooked then return end

	TargetController.Update = function(self, viewInput, dt, ...)
		-- Chạy physics bình thường
		local result = {existingUpdate(self, viewInput, dt, ...)}

		if AntiFall.Enabled then
			-- HeightState = 7 (Falling) là trigger để server tính fall damage
			-- Giữ HeightState = 0 (Standing) → server không bao giờ biết mình đang rơi
			self.HeightState = 0
			self.IsGrounded = true
			if self._lastSafePosition and self._position then
				self._lastSafePosition = self._position
			end
			local myActor = ReplicatorService and ReplicatorService.LocalActor
			if myActor then
				myActor.Grounded = true
				myActor.HeightState = 0
			end
		end

		return table.unpack(result)
	end

	TargetController._antiFallHooked = true
	print("[AntiFall] Hooked successfully")
end

-- Hook sau khi services init xong
task.delay(3, AF_Hook)

-- Heartbeat riêng reset HeightState trên actor mỗi frame
local _antiFallHb = RunService.Heartbeat:Connect(function()
	if not AntiFall.Enabled then return end
	local myActor = ReplicatorService and ReplicatorService.LocalActor
	if not myActor then return end
	-- Reset HeightState = 0 (Standing) trực tiếp trên actor
	-- Server đọc field này để quyết định có tính fall damage không
	pcall(function()
		myActor.HeightState = 0
		myActor.Grounded = true
	end)
	-- Reset trên controller
	if ControllerService and ControllerService.Controller then
		local ctrl = ControllerService.Controller
		pcall(function()
			ctrl.HeightState = 0
			ctrl.IsGrounded = true
			if ctrl._position then
				ctrl._lastSafePosition = ctrl._position
			end
		end)
	end
end)
table.insert(getgenv().Moon_Connections, _antiFallHb)

getgenv().AntiFall = AntiFall

-- UI — Character tab
local S_AntiFall = CharacterTab:DrawSection({ Name="Anti Fall", Position="right" })

S_AntiFall:AddToggle({
	Name = "Enable Anti Fall",
	Flag = "AF_AntiFall",
	Default = false,
	Callback = function(v)
		AntiFall.Enabled = v
	end
})

print("[AntiFall] Loaded")



-- ==========================================
-- AURA KILL — Verified từ Flux_client.lua source
-- Cipher đúng 100%: netEncode verified = RSpy dump match
-- net:FireServer() = RemoteEvent:FireServer(netEncode(JSONEncode({_code,...}), _key))
-- ==========================================
local AuraKill = {
	Enabled = false,
	Range = 20,
	Interval = 0,
	BatchSize = 10,
	TargetPart = "Head",
	_net = nil,
	_remote = nil,
	_lastFire = 0,
	_connection = nil,
	_running = false,
}

-- Tìm network object: table có _code (UUID) + _key (array 5 nums) + _events
local function AK_FindNet()
	if AuraKill._net then return AuraKill._net end

	-- Method 1: shared.import("network") — đúng theo source
	if shared and type(shared.import) == "function" then
		local ok, net = pcall(function() return shared.import("network") end)
		if ok and net and rawget(net, "_key") and rawget(net, "_code") then
			AuraKill._net = net
			print("[AuraKill] Net via shared.import, code:", net._code:sub(1,8))
			return net
		end
	end

	-- Method 2: GC scan
	local gok, gc = pcall(function() return filtergc("table") end)
	if not gok then gok, gc = pcall(function() return getgc(true) end) end
	if gok and gc then
		for _, v in pairs(gc) do
			if type(v) ~= "table" then continue end
			local k  = rawget(v, "_key")
			local co = rawget(v, "_code")
			local ev = rawget(v, "_events")
			if type(k)=="table" and #k>=5
				and type(co)=="string" and co:match("^%x+%-%x+%-%x+%-%x+%-%x+$")
				and type(ev)=="table"
			then
				local allNums = true
				for _, n in ipairs(k) do if type(n)~="number" then allNums=false; break end end
				if allNums then
					AuraKill._net = v
					print("[AuraKill] Net via GC, code:", co:sub(1,8), "key[1]:", k[1])
					return v
				end
			end
		end
	end
	return nil
end

local function AK_GetRemote()
	if AuraKill._remote and AuraKill._remote.Parent then return AuraKill._remote end
	-- Source: v_u_11 = RemoteEvent (reliable channel)
	-- Path: ReplicatedStorage.Events.RemoteEvent
	local ev = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
	if ev then
		local re = ev:FindFirstChild("RemoteEvent")
		if re then AuraKill._remote=re; return re end
	end
	for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
		if v:IsA("RemoteEvent") then AuraKill._remote=v; return v end
	end
	return nil
end

-- netEncode đúng theo Flux_client.lua line 31-50
local function AK_NetEncode(jsonStr, key)
	local result = ""
	for i = 1, #jsonStr do
		local ki = i % 4  -- 0,1,2,3,0,1,2,3...
		local kval = key[ki + 1]  -- Lua 1-indexed: key[1..4]
		local nb = (string.byte(jsonStr, i) - 32 + kval) % 95 + 32
		result = result .. string.char(nb)
	end
	-- Padding: đúng theo source lines 43-50
	-- v25 = string.byte(p16) = first byte of jsonStr
	-- v27 = v25 - string.byte(tostring(v24))
	local firstByte = string.byte(jsonStr, 1)
	for v24 = 1, key[5] do
		local v26 = tostring(v24)
		local v27 = firstByte - string.byte(v26, 1)
		result = result .. string.char(v27)
	end
	return result
end

local function AK_Encrypt(data, net)
	local hs = game:GetService("HttpService")
	local ok, raw = pcall(function()
		return hs:JSONEncode(data)
	end)
	if not ok or not raw then return nil end
	return AK_NetEncode(raw, net._key)
end

-- Actor UID: UUID string
local function AK_GetUID(actor)
	for _, field in ipairs({"UID","_id","Id","UUID"}) do
		local v = rawget(actor, field)
		if type(v)=="string" and v:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then return v end
	end
	for k, v in pairs(actor) do
		if type(v)=="string" and v:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then return v end
	end
	return nil
end

local function AK_Fire(actor)
	local net = AK_FindNet()
	if not net then return false end
	local remote = AK_GetRemote()
	if not remote then return false end
	local char = actor.Character
	if not char then return false end
	local part = char:FindFirstChild(AuraKill.TargetPart)
		or char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char.PrimaryPart
	if not part then return false end
	local pos = part.Position
	local uid = AK_GetUID(actor)
	if not uid then return false end

	local n = math.random(1, 3)

	-- Slash: {_code, "InventoryAction", "Slash", n} → encrypt → RemoteEvent:FireServer
	local encSlash = AK_Encrypt({net._code, "InventoryAction", "Slash", n}, net)
	if encSlash then pcall(function() remote:FireServer(encSlash) end) end

	-- Impact sau delay
	-- Impact ngay lập tức — không delay
	local encImpact = AK_Encrypt(
		{net._code, "InventoryAction", "Impact", {pos.X, pos.Y, pos.Z}, uid, part.Name},
		net
	)
	if encImpact then pcall(function() remote:FireServer(encImpact) end) end

	return true
end

-- Fire up to ten nearest targets per heartbeat.
-- Each target still receives exactly two packets: Slash + Impact.
local function AK_Tick()
	if not AuraKill.Enabled then return end
	local now = tick()
	if now - AuraKill._lastFire < AuraKill.Interval then return end
	local myActor = ReplicatorService and ReplicatorService.LocalActor
	if not myActor then return end
	local myPos = myActor.Position or Camera.CFrame.Position
	local candidates = {}

	if ActorManager.Initialized then
		for _, actor in ipairs(ActorManager.Enemies) do
			if not actor or not actor.Alive or not actor.Character then continue end
			local aPos = actor.Position
			if not aPos and actor.Character.PrimaryPart then
				aPos = actor.Character.PrimaryPart.Position
			end
			if not aPos then continue end

			local d = (aPos - myPos).Magnitude
			if d <= AuraKill.Range then
				candidates[#candidates + 1] = {Actor = actor, Distance = d}
			end
		end
	end

	if #candidates == 0 then return end

	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)

	AuraKill._lastFire = now

	local count = math.min(AuraKill.BatchSize, #candidates)
	for i = 1, count do
		local target = candidates[i].Actor
		task.spawn(function()
			if not AK_Fire(target) then AuraKill._net = nil end
		end)
	end
end

function AuraKill.Start()
	if AuraKill._running then return end
	AuraKill._running = true
	task.spawn(AK_FindNet); task.spawn(AK_GetRemote)
	AuraKill._connection = RunService.Heartbeat:Connect(AK_Tick)
	table.insert(getgenv().Moon_Connections, AuraKill._connection)
	print("[AuraKill] Started")
end

function AuraKill.Stop()
	AuraKill._running = false
	if AuraKill._connection then
		pcall(function() AuraKill._connection:Disconnect() end)
		AuraKill._connection = nil
	end
end

getgenv().AuraKill = AuraKill

local S_AK = CombatTab:DrawSection({Name="Aura Kill", Position="left"})
S_AK:AddToggle({Name="Enable Aura Kill", Flag="AK_Enabled", Default=false,
	Callback=function(v) AuraKill.Enabled=v; if v then AuraKill.Start() else AuraKill.Stop() end end})
S_AK:AddSlider({Name="Range (studs)", Flag="AK_Range", Min=1, Max=10, Default=5, Rounding=0,
	Callback=function(v) AuraKill.Range=v end})
S_AK:AddSlider({Name="Attack Rate (ms)", Flag="AK_Interval", Min=0, Max=2000, Default=0, Rounding=0,
	Callback=function(v) AuraKill.Interval=v/1000 end})
S_AK:AddDropdown({Name="Target Part", Flag="AK_TargetPart", Default="Head",
	Values={"Head","UpperTorso","LowerTorso"},
	Callback=function(v) AuraKill.TargetPart=v end})
S_AK:AddButton({Name="Rescan Network",
	Callback=function()
		AuraKill._net=nil; AuraKill._remote=nil
		task.spawn(function()
			local net=AK_FindNet(); local re=AK_GetRemote()
			Notifier.new({Title="AuraKill",
				Content=net and re
					and "OK! code:"..net._code:sub(1,8).." key["..tostring(net._key[1]).."]"
					or "Fail",
				Duration=5})
		end)
	end})

print("[AuraKill] Loaded — Cipher verified vs RSpy dump")

-- ==========================================
pcall(function()
-- AUTO FARM
local AutoFarm = {Enabled=false, OffsetY=-2, _connection=nil, _running=false}

local function AF_GetTarget()
	local myActor = ReplicatorService and ReplicatorService.LocalActor
	if not myActor then return nil end
	local myPos = myActor.Position or Camera.CFrame.Position
	local best, bestDist = nil, math.huge
	if ActorManager.Initialized then
		for _, actor in ipairs(ActorManager.Enemies) do
			if actor and actor.Alive and actor.Character then
				local pos = actor.Position
				if not pos and actor.Character.PrimaryPart then
					pos = actor.Character.PrimaryPart.Position
				end
				if pos then
					local d = (pos - myPos).Magnitude
					if d < bestDist then bestDist = d; best = actor end
				end
			end
		end
	end
	return best
end

local function AF_TeleportTo(actor)
	local myActor = ReplicatorService and ReplicatorService.LocalActor
	if not myActor then return end
	local pos = actor.Position
	if not pos and actor.Character and actor.Character.PrimaryPart then
		pos = actor.Character.PrimaryPart.Position
	end
	if not pos then return end
	local targetPos = Vector3.new(pos.X, pos.Y + AutoFarm.OffsetY, pos.Z)
	pcall(function()
		if ControllerService and ControllerService.Controller then
			local ctrl = ControllerService.Controller
			ctrl._position = targetPos
			ctrl._lastSafePosition = targetPos
		end
		myActor.SimulatedPosition = targetPos
		myActor.CFrame = CFrame.new(targetPos)
	end)
end

local function AF_Tick()
	if not AutoFarm.Enabled then return end
	if not (getgenv().AuraKill and getgenv().AuraKill.Enabled) then
		Notifier.new({Title="Auto Farm", Content="Bật Aura Kill trước!", Duration=2})
		AutoFarm.Enabled = false
		return
	end
	local target = AF_GetTarget()
	if target then AF_TeleportTo(target) end
end

function AutoFarm.Start()
	if AutoFarm._running then return end
	if not (getgenv().AuraKill and getgenv().AuraKill.Enabled) then
		Notifier.new({Title="Auto Farm", Content="Bật Aura Kill trước!", Duration=3})
		return
	end
	AutoFarm._running = true
	AutoFarm._connection = RunService.Heartbeat:Connect(AF_Tick)
	table.insert(getgenv().Moon_Connections, AutoFarm._connection)
end

function AutoFarm.Stop()
	AutoFarm._running = false
	if AutoFarm._connection then
		pcall(function() AutoFarm._connection:Disconnect() end)
		AutoFarm._connection = nil
	end
end

getgenv().AutoFarm = AutoFarm

local S_AF = MiscTab:DrawSection({Name="Auto Farm", Position="left"})
S_AF:AddToggle({Name="Enable Auto Farm", Flag="AF_Enabled", Default=false,
	Callback=function(v) AutoFarm.Enabled=v; if v then AutoFarm.Start() else AutoFarm.Stop() end end})
S_AF:AddSlider({Name="Y Offset", Flag="AF_OffsetY", Min=-10, Max=0, Default=-2, Rounding=0,
	Callback=function(v) AutoFarm.OffsetY=v end})
print("[AutoFarm] Loaded")
end)

-- AUTO LOCKPICK v4
-- InputService._mounts["PickLock"] là callback thật
-- Tìm InputService instance → gọi _mounts["PickLock"](true) mỗi frame
pcall(function()

local AutoLockpick = {Enabled=false, _connection=nil}

local function ALP_FindInputService()
    -- InputService: table có _mounts, Binds, Connected, Overrides
    local ok, gc = pcall(function() return filtergc("table") end)
    if not ok then ok, gc = pcall(function() return getgc(true) end) end
    if not ok or not gc then return nil end
    for _, v in pairs(gc) do
        if type(v) == "table"
            and rawget(v, "_mounts") ~= nil
            and rawget(v, "Binds") ~= nil
            and rawget(v, "Connected") ~= nil
            and rawget(v, "Overrides") ~= nil
        then
            return v
        end
    end
    return nil
end

local _inputSvc = nil
local _lastScan = 0

local function ALP_Tick()
    if not AutoLockpick.Enabled then return end

    -- Rescan InputService mỗi 1s
    local now = tick()
    if not _inputSvc or (now - _lastScan > 1) then
        _lastScan = now
        _inputSvc = ALP_FindInputService()
    end
    if not _inputSvc then return end

    local mounts = rawget(_inputSvc, "_mounts")
    if not mounts then return end

    -- Gọi PickLock callback nếu đang active
    local pickFn = rawget(mounts, "PickLock")
    if pickFn and type(pickFn) == "function" then
        pcall(pickFn, true)
    end
end

function AutoLockpick.Start()
    if AutoLockpick._connection then return end
    AutoLockpick._connection = RunService.Heartbeat:Connect(ALP_Tick)
    table.insert(getgenv().Moon_Connections, AutoLockpick._connection)
    print("[AutoLockpick] Started")
end

function AutoLockpick.Stop()
    if AutoLockpick._connection then
        pcall(function() AutoLockpick._connection:Disconnect() end)
        AutoLockpick._connection = nil
    end
    _inputSvc = nil
end

getgenv().AutoLockpick = AutoLockpick

local S_ALP = MiscTab:DrawSection({Name="Auto Lockpick", Position="right"})
S_ALP:AddToggle({Name="Enable Auto Lockpick", Flag="ALP_Enabled", Default=false,
    Callback=function(v)
        AutoLockpick.Enabled = v
        if v then AutoLockpick.Start() else AutoLockpick.Stop() end
    end})
print("[AutoLockpick] Loaded")
end)

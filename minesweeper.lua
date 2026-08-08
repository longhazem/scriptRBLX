-- ============================================
-- Minesweeper Bot & ESP — libba UI Edition
-- ============================================

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
	if not body then error("[MineBot] HTTP failed: " .. tostring(Url), 2) end
	if body:match("^429") or body:lower():match("rate limit") then
		warn("[MineBot] Rate limit — chờ 10s")
		task.wait(10)
		return GetLoadstringSource(Url)
	end
	if body:match("^<!DOCTYPE") or body:match("^<html") then
		error("[MineBot] Server trả về HTML — URL sai", 2)
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

local Library      = LoadRemote(Repository .. "source.lua")
local ThemeManager = LoadRemote(Repository .. "addons/ThemeManager.lua")
local SaveManager  = LoadRemote(Repository .. "addons/SaveManager.lua")

local Options = getgenv().Options or {}
local Toggles = getgenv().Toggles or {}

-- ============================================
-- MoonUI shim
-- ============================================

local MoonUI = { Scale = { Window = 1 } }
function MoonUI:SetTheme() end
function MoonUI:RefreshCurrentColor() end
function MoonUI:ConfigManager(Data) return Data or {} end
function MoonUI.newNotify()
	return { new = function(Data)
		local text = (Data and Data.Title) or "MineBot"
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
	local Window = Library:CreateWindow({ Title = Data.Name or "MineBot", Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })
	local SettingsTab
	return {
		Raw = Window,
		DrawTab = function(_, TabData)
			local Name = TabData.Name or "Tab"
			local Tab = Window:AddTab(Name)
			if Name == "Settings" or Name == "System" then SettingsTab = Tab end
			return WrapTab(Tab)
		end,
		DrawConfig = function(_, ConfigData)
			SettingsTab = SettingsTab or Window:AddTab("Settings")
			ThemeManager:SetLibrary(Library)
			SaveManager:SetLibrary(Library)
			SaveManager:IgnoreThemeSettings()
			SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
			ThemeManager:SetFolder("MineBot")
			SaveManager:SetFolder("MineBot/configs")
			SaveManager:BuildConfigSection(SettingsTab)
			ThemeManager:ApplyToTab(SettingsTab)
			SaveManager:LoadAutoloadConfig()
			return { Init = function() end }
		end,
		SetMenuKey = function(_, Key)
			task.defer(function() Library.ToggleKeybind = getgenv().Options and getgenv().Options.MenuKeybind end)
		end,
		Unload = function() Library:Unload() end,
	}
end

-- ============================================
-- SERVICES
-- ============================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ============================================
-- STATE
-- ============================================

local autoFlagActive      = false
local autoWalkActive      = false
local espActive           = false
local infiniteJump        = false
local flying              = false
local flySpeed            = 50
local flyGyro, flyVelocity
local antiExplosionActive = false
local antiExplosionConn   = nil
local verticalInput       = 0

local customWalkSpeed    = 16
local customJumpPower    = 50
local flagDistance       = 15
local flagDelay          = 0.45
local espRefreshInterval = 0.2

local espSafeColor     = Color3.fromRGB(0, 0, 255)
local espBombColor     = Color3.fromRGB(255, 0, 0)
local espUncertainLow  = Color3.fromRGB(255, 215, 0)
local espUncertainMed  = Color3.fromRGB(255, 165, 0)
local espUncertainHigh = Color3.fromRGB(220, 20, 60)

local grid = {}
local W, H = 0, 0
local xToCol, zToRow = {}, {}
local localFlags   = {}
local deducedBombs = {}

-- ============================================
-- SECRET KEY SCANNER (no key system — scans game directly)
-- ============================================

local function getSecretKey()
	local salasana = workspace:FindFirstChild("Salasana")
	if salasana and salasana:IsA("ValueObject") and salasana.Value ~= 0 then
		return tostring(salasana.Value)
	end
	local function scanUpvaluesForKey(func, depth, maxDepth)
		depth = depth or 0; maxDepth = maxDepth or 3
		if depth > maxDepth then return nil end
		local ok, upvals = pcall(debug.getupvalues, func)
		if not ok or not upvals then return nil end
		for _, v in pairs(upvals) do
			if type(v) == "string" and (tonumber(v) ~= nil or #v > 10) then return v
			elseif type(v) == "number" then return tostring(v)
			elseif type(v) == "function" then
				local nested = scanUpvaluesForKey(v, depth+1, maxDepth)
				if nested then return nested end
			end
		end
		return nil
	end
	if getgc then
		for _, v in pairs(getgc(true)) do
			if type(v) == "function" then
				local ok, info = pcall(debug.info, v, "s")
				info = ok and info or ""
				if info:find("MouseControl") then
					local ok2, upvals = pcall(debug.getupvalues, v)
					if ok2 and upvals then
						local hasPlaceFlag, potentialKey = false, nil
						for _, uv in pairs(upvals) do
							if typeof(uv) == "Instance" and (uv.Name == "PlaceFlag" or uv.Name == "FlagEvents" or uv.Name == "ReplicatedStorage") then
								hasPlaceFlag = true
							elseif type(uv) == "string" and #uv >= 10 and tonumber(uv) ~= nil then
								potentialKey = uv
							elseif type(uv) == "number" and uv > 1000 then
								potentialKey = tostring(uv)
							end
						end
						if hasPlaceFlag and potentialKey then return potentialKey end
					end
				end
			end
		end
	end
	local function getConnectionsForEvent(event)
		local connections = {}
		local success, conns = pcall(getconnections, event)
		if success and conns then for _, conn in ipairs(conns) do table.insert(connections, conn) end end
		return connections
	end
	local mouse = player:GetMouse()
	local allEvents = { mouse.Button1Down, mouse.Button2Down, UserInputService.TouchTap, UserInputService.InputBegan, UserInputService.InputEnded }
	for _, event in ipairs(allEvents) do
		for _, conn in ipairs(getConnectionsForEvent(event)) do
			local func = conn.Function
			if func then local key = scanUpvaluesForKey(func); if key then return key end end
		end
	end
	return nil
end

-- ============================================
-- FLAG & BLOCK CHECKS
-- ============================================

local function hasServerFlag(part)
	if not part then return false end
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Model") then return true end
	end
	return false
end
local function checkFlagged(part) return localFlags[part] == true or deducedBombs[part] == true end
local function checkBlocked(part) return localFlags[part] == true or deducedBombs[part] == true or hasServerFlag(part) end

-- ============================================
-- ESP
-- ============================================

local espFolder = workspace:FindFirstChild("BotESPFolder")
if not espFolder then
	espFolder = Instance.new("Folder")
	espFolder.Name = "BotESPFolder"
	espFolder.Parent = workspace
end

local function clearESP() espFolder:ClearAllChildren() end

local function updateESP(safeTiles, borderProbabilities)
	clearESP()
	if not espActive then return end
	for part in pairs(deducedBombs) do
		if part and part.Parent then
			local box = Instance.new("SelectionBox")
			box.Adornee = part; box.Color3 = espBombColor
			box.LineThickness = 0.06; box.SurfaceColor3 = espBombColor
			box.SurfaceTransparency = 0.45; box.Parent = espFolder
		end
	end
	for _, cell in pairs(safeTiles) do
		if cell.part and cell.part.Parent then
			local box = Instance.new("SelectionBox")
			box.Adornee = cell.part; box.Color3 = espSafeColor
			box.LineThickness = 0.06; box.SurfaceColor3 = espSafeColor
			box.SurfaceTransparency = 0.45; box.Parent = espFolder
		end
	end
	for part, P in pairs(borderProbabilities) do
		if part and part.Parent then
			local color = espUncertainMed
			if P < 0.35 then color = espUncertainLow
			elseif P > 0.65 then color = espUncertainHigh end
			local box = Instance.new("SelectionBox")
			box.Adornee = part; box.Color3 = color
			box.LineThickness = 0.05; box.SurfaceColor3 = color
			box.SurfaceTransparency = 0.6; box.Parent = espFolder
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(0,100,0,40); bb.AlwaysOnTop = true
			bb.Adornee = part; bb.StudsOffset = Vector3.new(0,3,0)
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1,0,1,0); label.BackgroundTransparency = 1
			label.TextSize = 26; label.TextColor3 = color
			label.Font = Enum.Font.GothamBold; label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = Color3.fromRGB(0,0,0)
			label.Text = string.format("%.0f%%", P*100)
			label.Parent = bb; bb.Parent = espFolder
		end
	end
end

-- ============================================
-- GRID
-- ============================================

local function initGrid()
	grid = {}; xToCol = {}; zToRow = {}; localFlags = {}; deducedBombs = {}; clearESP()
	local flag = workspace:FindFirstChild("Flag")
	local partsFolder = flag and flag:FindFirstChild("Parts")
	local parts = partsFolder and partsFolder:GetChildren()
	if not parts then return end
	local xCoords, zCoords = {}, {}
	for _, p in ipairs(parts) do
		xCoords[math.floor(p.Position.X+0.5)] = true
		zCoords[math.floor(p.Position.Z+0.5)] = true
	end
	local sortedX, sortedZ = {}, {}
	for x in pairs(xCoords) do table.insert(sortedX, x) end
	for z in pairs(zCoords) do table.insert(sortedZ, z) end
	table.sort(sortedX); table.sort(sortedZ)
	for col, x in ipairs(sortedX) do xToCol[x] = col end
	for row, z in ipairs(sortedZ) do zToRow[z] = row end
	W = #sortedX; H = #sortedZ
	for col = 1, W do
		grid[col] = {}
		for row = 1, H do
			grid[col][row] = { part=nil, isOpened=false, isFlagged=false, isBlocked=false, value=0, col=col, row=row }
		end
	end
	for _, p in ipairs(parts) do
		local col = xToCol[math.floor(p.Position.X+0.5)]
		local row = zToRow[math.floor(p.Position.Z+0.5)]
		if col and row then grid[col][row].part = p end
	end
	for col = 1, W do
		for row = 1, H do
			local cell = grid[col][row]
			if cell.part and hasServerFlag(cell.part) then
				deducedBombs[cell.part] = true; cell.isFlagged = true; cell.isBlocked = true
			end
		end
	end
	print("[Grid] Mapped: " .. W .. "x" .. H)
end

local function checkGridValid()
	if W == 0 or H == 0 then return false end
	for col = 1, W do
		if not grid[col] then return false end
		for row = 1, H do
			local cell = grid[col][row]
			if not cell or not cell.part or not cell.part:IsDescendantOf(workspace) then return false end
		end
	end
	return true
end

-- ============================================
-- BOARD SCAN
-- ============================================

local function scanBoard()
	local state = {}
	for col = 1, W do
		state[col] = {}
		for row = 1, H do
			local cell = grid[col][row]
			local isOpened, value, isFlagged, isBlocked = false, 0, false, false
			if cell.part then
				isOpened = cell.part:FindFirstChild("NumberGui") ~= nil
				if isOpened then
					local label = cell.part.NumberGui:FindFirstChild("TextLabel")
					value = tonumber((label and label.Text) or "") or 0
				end
				isFlagged = checkFlagged(cell.part)
				isBlocked = checkBlocked(cell.part)
			end
			state[col][row] = { isOpened=isOpened, value=value, isFlagged=isFlagged, isBlocked=isBlocked }
		end
	end
	return state
end

-- ============================================
-- PATHFINDING
-- ============================================

local function getCurrentPlayerGrid()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil, nil end
	local nearestCol, nearestRow, minDist = nil, nil, math.huge
	for col = 1, W do
		for row = 1, H do
			local cell = grid[col][row]
			if cell.part then
				local dist = (cell.part.Position - root.Position).Magnitude
				if dist < minDist then minDist = dist; nearestCol = col; nearestRow = row end
			end
		end
	end
	return nearestCol, nearestRow
end

local function findPath(startCol, startRow, targetCol, targetRow)
	local queue = {{startCol, startRow, {}}}
	local visited = {}; visited[startCol.."_"..startRow] = true
	while #queue > 0 do
		local curr = table.remove(queue, 1)
		local c, r, path = curr[1], curr[2], curr[3]
		if c == targetCol and r == targetRow then return path end
		for _, dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
			local nc, nr = c+dir[1], r+dir[2]
			local key = nc.."_"..nr
			if nc >= 1 and nc <= W and nr >= 1 and nr <= H and not visited[key] then
				local neighbor = grid[nc][nr]
				if neighbor.isOpened or hasServerFlag(neighbor.part) or (nc==targetCol and nr==targetRow) then
					visited[key] = true
					local newPath = {}
					for _, p in ipairs(path) do table.insert(newPath, p) end
					table.insert(newPath, neighbor.part)
					table.insert(queue, {nc, nr, newPath})
				end
			end
		end
	end
	return nil
end

local function getConnectedComponent(startCol, startRow)
	local queue = {{startCol, startRow}}
	local visited = {}; visited[startCol.."_"..startRow] = true
	local component = {}
	while #queue > 0 do
		local curr = table.remove(queue, 1)
		local c, r = curr[1], curr[2]
		table.insert(component, grid[c][r])
		for _, dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
			local nc, nr = c+dir[1], r+dir[2]
			local key = nc.."_"..nr
			if nc >= 1 and nc <= W and nr >= 1 and nr <= H and not visited[key] then
				local neighbor = grid[nc][nr]
				if neighbor.isOpened or hasServerFlag(neighbor.part) then
					visited[key] = true; table.insert(queue, {nc, nr})
				end
			end
		end
	end
	return component
end

local function getLocalGuessCandidates(pCol, pRow)
	local component = getConnectedComponent(pCol, pRow)
	local candidates, seen = {}, {}
	local dirs8 = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}}
	for _, cell in ipairs(component) do
		for _, dir in ipairs(dirs8) do
			local nc, nr = cell.col+dir[1], cell.row+dir[2]
			if nc >= 1 and nc <= W and nr >= 1 and nr <= H then
				local neighbor = grid[nc][nr]
				if not neighbor.isOpened and not neighbor.isBlocked then
					local key = nc.."_"..nr
					if not seen[key] then seen[key] = true; table.insert(candidates, neighbor) end
				end
			end
		end
	end
	return candidates
end

-- ============================================
-- SOLVER
-- ============================================

local function solveEquations(safeTiles, borderProbabilities)
	local clues, borderMap, borderList = {}, {}, {}
	for col = 1, W do
		for row = 1, H do
			local cell = grid[col][row]
			if cell.isOpened and cell.value > 0 then
				local unopened, flaggedCount = {}, 0
				for dc = -1, 1 do
					for dr = -1, 1 do
						if not (dc==0 and dr==0) then
							local nc, nr = col+dc, row+dr
							if nc >= 1 and nc <= W and nr >= 1 and nr <= H then
								local nCell = grid[nc][nr]
								if nCell.isFlagged then flaggedCount = flaggedCount+1
								elseif not nCell.isOpened then table.insert(unopened, nCell) end
							end
						end
					end
				end
				if #unopened > 0 then
					table.insert(clues, { cell=cell, unopened=unopened, target=cell.value-flaggedCount })
					for _, nCell in ipairs(unopened) do
						if not borderMap[nCell] then borderMap[nCell]=true; table.insert(borderList, nCell) end
					end
				end
			end
		end
	end
	if #borderList == 0 then return end
	local components, visitedClues, visitedVars = {}, {}, {}
	for _, clue in ipairs(clues) do
		if not visitedClues[clue] then
			local compClues, compVars = {}, {}
			local queue = {clue}; visitedClues[clue] = true
			while #queue > 0 do
				local currClue = table.remove(queue, 1)
				table.insert(compClues, currClue)
				for _, nCell in ipairs(currClue.unopened) do
					if not visitedVars[nCell] then
						visitedVars[nCell] = true; table.insert(compVars, nCell)
						for _, otherClue in ipairs(clues) do
							if not visitedClues[otherClue] then
								local contains = false
								for _, c in ipairs(otherClue.unopened) do if c == nCell then contains=true; break end end
								if contains then visitedClues[otherClue]=true; table.insert(queue, otherClue) end
							end
						end
					end
				end
			end
			table.insert(components, { clues=compClues, vars=compVars })
		end
	end
	for _, comp in ipairs(components) do
		local vars, compClues = comp.vars, comp.clues
		if #vars <= 20 then
			local solutions, currentAssignment = {}, {}
			local function backtrack(varIndex)
				if varIndex > #vars then
					for _, clue in ipairs(compClues) do
						local sum = 0
						for _, nCell in ipairs(clue.unopened) do sum = sum + (currentAssignment[nCell] or 0) end
						if sum ~= clue.target then return end
					end
					local sol = {}
					for k, v in pairs(currentAssignment) do sol[k] = v end
					table.insert(solutions, sol); return
				end
				local currentVar = vars[varIndex]
				for _, clue in ipairs(compClues) do
					local sum, unassigned = 0, 0
					for _, nCell in ipairs(clue.unopened) do
						local assign = currentAssignment[nCell]
						if assign then sum = sum+assign else unassigned = unassigned+1 end
					end
					if sum > clue.target or sum+unassigned < clue.target then return end
				end
				currentAssignment[currentVar] = 0; backtrack(varIndex+1)
				currentAssignment[currentVar] = 1; backtrack(varIndex+1)
				currentAssignment[currentVar] = nil
			end
			backtrack(1)
			if #solutions > 0 then
				for _, var in ipairs(vars) do
					local bombCount = 0
					for _, sol in ipairs(solutions) do if sol[var]==1 then bombCount=bombCount+1 end end
					local P = bombCount / #solutions
					if P == 0 then safeTiles[var.col.."_"..var.row] = var
					elseif P == 1 then deducedBombs[var.part] = true
					else borderProbabilities[var.part] = P end
				end
			end
		end
	end
end

local function updateDeductions()
	local state1 = scanBoard(); task.wait(0.05); local state2 = scanBoard()
	local stable = true
	for col = 1, W do
		for row = 1, H do
			local c1, c2 = state1[col][row], state2[col][row]
			if c1.isOpened ~= c2.isOpened or c1.value ~= c2.value or c1.isFlagged ~= c2.isFlagged or c1.isBlocked ~= c2.isBlocked then
				stable = false; break
			end
		end
		if not stable then break end
	end
	if not stable then return false end
	for col = 1, W do
		for row = 1, H do
			local cell = grid[col][row]; local st = state1[col][row]
			cell.isOpened = st.isOpened; cell.value = st.value
			cell.isFlagged = st.isFlagged; cell.isBlocked = st.isBlocked
		end
	end
	local safeTiles, borderProbabilities, deducedNewBomb = {}, {}, false
	local totalUnopened, totalFlagged = {}, 0
	for col = 1, W do
		for row = 1, H do
			local cell = grid[col][row]
			if cell.part then
				if cell.isFlagged then totalFlagged = totalFlagged+1
				elseif not cell.isOpened then table.insert(totalUnopened, cell) end
			end
		end
	end
	local minesVal = ReplicatedStorage:FindFirstChild("Info") and
		ReplicatedStorage.Info:FindFirstChild("Mines") and
		ReplicatedStorage.Info.Mines.Value or 0
	local remainingMines = minesVal - totalFlagged
	if #totalUnopened > 0 then
		if #totalUnopened == remainingMines then
			for _, cell in ipairs(totalUnopened) do
				if not deducedBombs[cell.part] then
					deducedBombs[cell.part] = true; cell.isFlagged = true; cell.isBlocked = true; deducedNewBomb = true
				end
			end
		elseif remainingMines == 0 then
			for _, cell in ipairs(totalUnopened) do safeTiles[cell.col.."_"..cell.row] = cell end
		end
	end
	if not deducedNewBomb then
		solveEquations(safeTiles, borderProbabilities)
		for col = 1, W do
			for row = 1, H do
				local cell = grid[col][row]
				if cell.isOpened and cell.value > 0 then
					local flaggedNeighbors, unopenedNeighbors = 0, {}
					for dc = -1, 1 do
						for dr = -1, 1 do
							if not (dc==0 and dr==0) then
								local nc, nr = col+dc, row+dr
								if nc >= 1 and nc <= W and nr >= 1 and nr <= H then
									local nCell = grid[nc][nr]
									if nCell.isFlagged then flaggedNeighbors = flaggedNeighbors+1
									elseif not nCell.isOpened then table.insert(unopenedNeighbors, nCell) end
								end
							end
						end
					end
					if cell.value-flaggedNeighbors == #unopenedNeighbors and #unopenedNeighbors > 0 then
						for _, nCell in ipairs(unopenedNeighbors) do
							if not deducedBombs[nCell.part] then
								deducedBombs[nCell.part] = true; nCell.isFlagged = true; nCell.isBlocked = true; deducedNewBomb = true
							end
						end
					end
					if cell.value == flaggedNeighbors and #unopenedNeighbors > 0 then
						for _, nCell in ipairs(unopenedNeighbors) do
							if not nCell.isFlagged and not nCell.isOpened then safeTiles[nCell.col.."_"..nCell.row] = nCell end
						end
					end
				end
			end
		end
	end
	if espActive then updateESP(safeTiles, borderProbabilities) end
	return true, safeTiles, borderProbabilities, deducedNewBomb
end

-- ============================================
-- MOVEMENT
-- ============================================

local function walkTo(part)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	hum.WalkSpeed = customWalkSpeed
	local targetPos = Vector3.new(part.Position.X, root.Position.Y, part.Position.Z)
	hum:MoveTo(targetPos)
	local startT = os.clock()
	while (root.Position-targetPos).Magnitude > 1.0 and autoWalkActive do
		if os.clock()-startT > 3 then break end
		task.wait(); hum:MoveTo(targetPos)
	end
end

local function walkPath(path)
	for _, part in ipairs(path) do
		if not autoWalkActive then break end
		walkTo(part)
	end
end

-- ============================================
-- BOARD MANAGER LOOP
-- ============================================

task.spawn(function()
	while true do
		task.wait(espRefreshInterval)
		if autoWalkActive or autoFlagActive or espActive then
			local gameRunningVal = ReplicatedStorage:FindFirstChild("Info") and
				ReplicatedStorage.Info:FindFirstChild("GameRunning") and
				ReplicatedStorage.Info.GameRunning.Value
			if not gameRunningVal then
				localFlags = {}; deducedBombs = {}; clearESP(); task.wait(0.5); continue
			end
			if not checkGridValid() then initGrid(); task.wait(0.1); continue end
			local success, safeTiles, borderProbabilities, deducedNewBomb = updateDeductions()
			if not success then continue end
			if autoFlagActive then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local key = getSecretKey()
				if root and key then
					for part in pairs(deducedBombs) do
						if not hasServerFlag(part) then
							local dist = (part.Position-root.Position).Magnitude
							if dist < flagDistance then
								ReplicatedStorage.Events.FlagEvents.PlaceFlag:FireServer(part, key, true)
								localFlags[part] = true
								if flagDelay > 0 then task.wait(flagDelay) end
							end
						end
					end
				end
			end
			if autoWalkActive and not deducedNewBomb then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local pCol, pRow = getCurrentPlayerGrid()
				if root and pCol and pRow then
					local openedCount = 0
					for col = 1, W do for row = 1, H do if grid[col][row].isOpened then openedCount = openedCount+1 end end end
					if openedCount == 0 then
						local midCol = math.floor(W/2)+1; local midRow = math.floor(H/2)+1
						local targetPart = grid[midCol][midRow].part
						if targetPart then walkTo(targetPart); task.wait(0.3) end
					else
						local key = getSecretKey()
						if key then
							local targetCell, bestPath, minPathLen = nil, nil, math.huge
							for _, cell in pairs(safeTiles) do
								local path = findPath(pCol, pRow, cell.col, cell.row)
								if path and #path < minPathLen then minPathLen=#path; targetCell=cell; bestPath=path end
							end
							if bestPath and targetCell then
								walkPath(bestPath)
								local startWait = os.clock()
								while not targetCell.part:FindFirstChild("NumberGui") and os.clock()-startWait < 1.0 and autoWalkActive do task.wait(0.05) end
							else
								local bestGuessCell, minProb = nil, math.huge
								for part, P in pairs(borderProbabilities) do
									local col = xToCol[math.floor(part.Position.X+0.5)]
									local row = zToRow[math.floor(part.Position.Z+0.5)]
									if col and row and P < minProb then minProb=P; bestGuessCell=grid[col][row] end
								end
								if bestGuessCell then
									local path = findPath(pCol, pRow, bestGuessCell.col, bestGuessCell.row)
									if path then walkPath(path) else walkTo(bestGuessCell.part) end
									local startWait = os.clock()
									while not bestGuessCell.part:FindFirstChild("NumberGui") and os.clock()-startWait < 1.0 and autoWalkActive do task.wait(0.05) end
								else
									local candidates = getLocalGuessCandidates(pCol, pRow)
									if #candidates > 0 then
										local guessCell = candidates[math.random(1, #candidates)]
										local path = findPath(pCol, pRow, guessCell.col, guessCell.row)
										if path then walkPath(path) else walkTo(guessCell.part) end
										local startWait = os.clock()
										while not guessCell.part:FindFirstChild("NumberGui") and os.clock()-startWait < 1.0 and autoWalkActive do task.wait(0.05) end
									else
										autoWalkActive = false
										Library:Notify("Auto Walk stopped — no candidates.", 4)
									end
								end
							end
						end
					end
				end
			end
		else
			clearESP(); task.wait(0.2)
		end
	end
end)

-- ============================================
-- INFINITE JUMP
-- ============================================

UserInputService.JumpRequest:Connect(function()
	if infiniteJump then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

-- ============================================
-- ANTI-EXPLOSION
-- ============================================

local function applyAntiExplosion(char)
	if not char then return end
	local hum = char:WaitForChild("Humanoid", 3)
	if not hum then return end
	if antiExplosionConn then antiExplosionConn:Disconnect(); antiExplosionConn = nil end
	if not antiExplosionActive then return end
	antiExplosionConn = hum.StateChanged:Connect(function(old, new)
		if not antiExplosionActive then return end
		if new == Enum.HumanoidStateType.Dead then
			task.defer(function()
				if hum and hum.Parent then hum.Health = hum.MaxHealth; hum:ChangeState(Enum.HumanoidStateType.Running) end
			end)
		end
	end)
end

player.CharacterAdded:Connect(function(char)
	if antiExplosionActive then task.defer(function() applyAntiExplosion(char) end) end
end)

-- ============================================
-- FLY
-- ============================================

local function startFlying()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	if flyGyro then flyGyro:Destroy() end
	if flyVelocity then flyVelocity:Destroy() end
	flyGyro = Instance.new("BodyGyro")
	flyGyro.P = 9e4; flyGyro.maxTorque = Vector3.new(9e9,9e9,9e9)
	flyGyro.cframe = root.CFrame; flyGyro.Parent = root
	flyVelocity = Instance.new("BodyVelocity")
	flyVelocity.velocity = Vector3.new(0,0.1,0)
	flyVelocity.maxForce = Vector3.new(9e9,9e9,9e9)
	flyVelocity.Parent = root
	hum.PlatformStand = true
	task.spawn(function()
		while flying and player.Character and root and root.Parent and hum do
			local camera = workspace.CurrentCamera
			local joystickDir = hum.MoveDirection
			local moveDir = Vector3.zero
			if joystickDir.Magnitude > 0 then
				local look = camera.CFrame.LookVector
				local horizontalLook = Vector3.new(look.X,0,look.Z)
				if horizontalLook.Magnitude > 0.001 then horizontalLook = horizontalLook.Unit end
				local forwardDot = joystickDir:Dot(horizontalLook)
				moveDir = Vector3.new(joystickDir.X, forwardDot*look.Y, joystickDir.Z)
			else
				local look = camera.CFrame.LookVector
				local right = camera.CFrame.RightVector
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir+look end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir-look end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir-right end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir+right end
			end
			local vertical = verticalInput
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical = 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vertical = -1 end
			moveDir = moveDir + Vector3.new(0, vertical, 0)
			flyVelocity.velocity = moveDir.Magnitude > 0 and (moveDir.Unit * flySpeed) or Vector3.zero
			flyGyro.cframe = camera.CFrame
			task.wait()
		end
		if flyGyro then flyGyro:Destroy(); flyGyro = nil end
		if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
		if hum and hum.Parent then hum.PlatformStand = false end
	end)
end

local function stopFlying()
	if flyGyro then flyGyro:Destroy(); flyGyro = nil end
	if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
end

local function onCharacterAdded(char)
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then hum.UseJumpPower = true; hum.WalkSpeed = customWalkSpeed; hum.JumpPower = customJumpPower end
end
if player.Character then task.spawn(onCharacterAdded, player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

-- ============================================
-- DAY/NIGHT
-- ============================================

local Lighting        = game:GetService("Lighting")
local dayNightActive  = false
local dayNightConn    = nil
local dayNightMode    = "Day"
local lockedTime      = 14
local lightingHooked  = false
local originalNewindex = nil

local function applyLock(time) pcall(function() Lighting.ClockTime = time end) end

local function hookLightingNewindex()
	if lightingHooked then return end
	local ok = pcall(function()
		originalNewindex = hookmetamethod(Lighting, "__newindex", function(self, key, value)
			if dayNightActive and (key == "ClockTime" or key == "TimeOfDay") then
				if math.abs((type(value)=="number" and value or 0) - lockedTime) > 0.1 then return end
			end
			return originalNewindex(self, key, value)
		end)
	end)
	if ok then lightingHooked = true end
end

local function unhookLightingNewindex()
	if not lightingHooked then return end
	pcall(function() hookmetamethod(Lighting, "__newindex", originalNewindex) end)
	lightingHooked = false; originalNewindex = nil
end

local function setDayNight(mode)
	dayNightMode = mode
	if dayNightConn then dayNightConn:Disconnect(); dayNightConn = nil end
	if mode == "Day" then lockedTime = 14
	elseif mode == "Night" then lockedTime = 0 end
	applyLock(lockedTime)
	hookLightingNewindex()
	dayNightConn = RunService.Heartbeat:Connect(function()
		if not dayNightActive then return end
		if math.abs(Lighting.ClockTime - lockedTime) > 0.05 then
			rawset(Lighting, "ClockTime", lockedTime)
		end
	end)
end

-- ============================================
-- UI
-- ============================================

local Window = MoonUI.new({ Name = "Minesweeper Bot" })

-- TAB: AUTO BOT
local BotTab = Window:DrawTab({ Name = "Auto Bot", Icon = "bot", Type = "Double" })

local S_AutoWalk = BotTab:DrawSection({ Name = "Auto Walk", Position = "left" })
local AutoWalkToggle = S_AutoWalk:AddToggle({
	Name = "Auto Walk", Flag = "AutoWalk_Enabled", Default = false,
	Callback = function(v)
		autoWalkActive = v
		if v then initGrid(); Library:Notify("Auto Walk ON", 3) else Library:Notify("Auto Walk OFF", 3) end
	end
})
AutoWalkToggle.Link:AddKeybind({ Name = "Auto Walk Key", Flag = "AutoWalk_Key", Default = "L" })

local S_AutoFlag = BotTab:DrawSection({ Name = "Auto Flag", Position = "right" })
local AutoFlagToggle = S_AutoFlag:AddToggle({
	Name = "Auto Flag", Flag = "AutoFlag_Enabled", Default = false,
	Callback = function(v)
		autoFlagActive = v
		if v then initGrid(); Library:Notify("Auto Flag ON", 3) else Library:Notify("Auto Flag OFF", 3) end
	end
})
AutoFlagToggle.Link:AddKeybind({ Name = "Auto Flag Key", Flag = "AutoFlag_Key", Default = "P" })

local S_FlagSettings = BotTab:DrawSection({ Name = "Flag Settings", Position = "right" })
S_FlagSettings:AddSlider({ Name = "Flag Distance", Flag = "FlagDist", Min = 5, Max = 30, Default = 15, Suffix = " studs", Callback = function(v) flagDistance = v end })
S_FlagSettings:AddSlider({ Name = "Flag Delay", Flag = "FlagDelay", Min = 0, Max = 200, Default = 45, Rounding = 0, Suffix = "x0.01s", Callback = function(v) flagDelay = v * 0.01 end })

-- TAB: ESP
local EspTab = Window:DrawTab({ Name = "ESP", Icon = "eye", Type = "Double" })

local S_ESP = EspTab:DrawSection({ Name = "ESP Settings", Position = "left" })
local ESPToggle = S_ESP:AddToggle({
	Name = "ESP Active", Flag = "ESP_Active", Default = false,
	Callback = function(v)
		espActive = v
		if v then initGrid(); Library:Notify("ESP ON", 3) else clearESP(); Library:Notify("ESP OFF", 3) end
	end
})
ESPToggle.Link:AddKeybind({ Name = "ESP Key", Flag = "ESP_Key", Default = "M" })
S_ESP:AddSlider({ Name = "Refresh Interval", Flag = "ESP_Refresh", Min = 5, Max = 500, Default = 20, Suffix = "x0.01s", Callback = function(v) espRefreshInterval = v * 0.01 end })

local S_Colors = EspTab:DrawSection({ Name = "ESP Colors", Position = "right" })
S_Colors:AddColorPicker({ Name = "Safe Tile", Flag = "ESP_SafeColor", Default = espSafeColor, Callback = function(c) espSafeColor = c end })
S_Colors:AddColorPicker({ Name = "Bomb Tile", Flag = "ESP_BombColor", Default = espBombColor, Callback = function(c) espBombColor = c end })
S_Colors:AddColorPicker({ Name = "Low Risk", Flag = "ESP_LowColor", Default = espUncertainLow, Callback = function(c) espUncertainLow = c end })
S_Colors:AddColorPicker({ Name = "Med Risk", Flag = "ESP_MedColor", Default = espUncertainMed, Callback = function(c) espUncertainMed = c end })
S_Colors:AddColorPicker({ Name = "High Risk", Flag = "ESP_HighColor", Default = espUncertainHigh, Callback = function(c) espUncertainHigh = c end })

-- TAB: CHARACTER
local CharTab = Window:DrawTab({ Name = "Character", Icon = "user", Type = "Double" })

local S_Movement = CharTab:DrawSection({ Name = "Movement", Position = "left" })
S_Movement:AddSlider({ Name = "Walk Speed", Flag = "WalkSpeed", Min = 16, Max = 150, Default = 16, Callback = function(v)
	customWalkSpeed = v
	local char = player.Character; local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = v end
end })
S_Movement:AddSlider({ Name = "Jump Power", Flag = "JumpPower", Min = 50, Max = 300, Default = 50, Callback = function(v)
	customJumpPower = v
	local char = player.Character; local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.UseJumpPower = true; hum.JumpPower = v end
end })
S_Movement:AddToggle({ Name = "Infinite Jump", Flag = "InfJump", Default = false, Callback = function(v) infiniteJump = v end })

local S_Flight = CharTab:DrawSection({ Name = "Flight", Position = "right" })
local FlyToggle = S_Flight:AddToggle({
	Name = "Fly Mode", Flag = "Fly_Enabled", Default = false,
	Callback = function(v)
		flying = v
		if v then startFlying(); Library:Notify("Fly ON", 3)
		else stopFlying(); Library:Notify("Fly OFF", 3) end
	end
})
FlyToggle.Link:AddKeybind({ Name = "Fly Key", Flag = "Fly_Key", Default = "F" })
S_Flight:AddSlider({ Name = "Fly Speed", Flag = "FlySpeed", Min = 10, Max = 200, Default = 50, Callback = function(v) flySpeed = v end })

local S_Safety = CharTab:DrawSection({ Name = "Safety", Position = "right" })
S_Safety:AddToggle({ Name = "Anti-Explosion", Flag = "AntiExp", Default = false, Callback = function(v)
	antiExplosionActive = v
	if v then applyAntiExplosion(player.Character); Library:Notify("Anti-Explosion ON", 3)
	else if antiExplosionConn then antiExplosionConn:Disconnect(); antiExplosionConn = nil end; Library:Notify("Anti-Explosion OFF", 3) end
end })

-- TAB: MISC
local MiscTab = Window:DrawTab({ Name = "Misc", Icon = "droplets", Type = "Double" })

local S_DayNight = MiscTab:DrawSection({ Name = "Day / Night", Position = "left" })
S_DayNight:AddToggle({ Name = "Bật Điều Chỉnh Thời Gian", Flag = "DayNight_Active", Default = false,
	Callback = function(v)
		dayNightActive = v
		if v then setDayNight(dayNightMode); Library:Notify("Time Control ON — " .. dayNightMode, 3)
		else
			if dayNightConn then dayNightConn:Disconnect(); dayNightConn = nil end
			unhookLightingNewindex(); Library:Notify("Time Control OFF", 3)
		end
	end
})
S_DayNight:AddDropdown({ Name = "Chế Độ", Flag = "DayNight_Mode", Values = { "Day", "Night" }, Default = "Day",
	Callback = function(v)
		dayNightMode = v
		if dayNightActive then setDayNight(v); Library:Notify("Chế độ: " .. v, 3) end
	end
})

local S_Util = MiscTab:DrawSection({ Name = "Utilities", Position = "right" })
S_Util:AddButton({ Name = "Re-init Grid", Callback = function() initGrid(); Library:Notify("Grid re-initialized.", 3) end })
S_Util:AddButton({ Name = "Clear ESP", Callback = function() clearESP(); Library:Notify("ESP cleared.", 3) end })
S_Util:AddButton({ Name = "Reset All", Callback = function()
	autoWalkActive = false; autoFlagActive = false; espActive = false
	flying = false; infiniteJump = false; antiExplosionActive = false; dayNightActive = false
	if antiExplosionConn then antiExplosionConn:Disconnect(); antiExplosionConn = nil end
	if dayNightConn then dayNightConn:Disconnect(); dayNightConn = nil end
	unhookLightingNewindex(); stopFlying(); clearESP()
	local char = player.Character; local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = 16; hum.JumpPower = 50; hum.UseJumpPower = false; hum.PlatformStand = false end
	Library:Notify("All features reset.", 3)
end })

Window:DrawConfig({})
print("[MineBot] Loaded — no key system.")

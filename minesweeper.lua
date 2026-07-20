-- I could not obfuscate the code because it would lead to freezing the calculations so free code I guess.
print("test")
local identifierName = "Tokaihub"
if gethui():FindFirstChild(identifierName) then
	warn("perplexity: already executed")
elseif game.PlaceId == 7871169780 then
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")

	local executionTracker = Instance.new("BoolValue")
	executionTracker.Name = identifierName
	executionTracker.Value = true
	executionTracker.Parent = gethui()

	local flag = workspace:WaitForChild("Flag")
	local partsFolder = flag:WaitForChild("Parts")
	local infoFolder = ReplicatedStorage:WaitForChild("Info")
	local gameRunning = infoFolder:WaitForChild("GameRunning")
	local totalMinesValue = infoFolder:FindFirstChild("Mines")
	local flagsFolder = ReplicatedStorage:WaitForChild("Flags")

	local mainFolder = Instance.new("Folder")
	mainFolder.Name = HttpService:GenerateGUID(false)
	mainFolder.Parent = workspace

	local activeTiles = {}
	local colorConnections = {}
	local descConnections = {}
	local textConnections = {}
	local flagConnections = {}
	local neighborsCache = {}
	local tileGrid = {}
	local tileGridSize = nil
	local tileStates = {}
	local tileProbabilities = {}
	local partitionBestGuesses = {}
	local solvePending = false
	local SOLVE_COOLDOWN = 0.1
	local lastSolveTime = 0
	local highlightsEnabled = true
	local topLevelConnections = {}

	local COLOR_SAFE    = Color3.fromRGB(0, 255, 0)
	local COLOR_MINE    = Color3.fromRGB(255, 0, 0)
	local COLOR_BEST    = Color3.fromRGB(170, 0, 255)
	local COLOR_UNKNOWN = Color3.fromRGB(255, 255, 0)

	local flagNames = {}
	for _, subfolder in ipairs(flagsFolder:GetChildren()) do
		if subfolder:IsA("Folder") then
			for _, flagModel in ipairs(subfolder:GetChildren()) do
				flagNames[flagModel.Name] = true
			end
		end
	end

	local function tileHasFlag(tile)
		for _, child in ipairs(tile:GetChildren()) do
			if child:IsA("Model") and flagNames[child.Name] then
				return true
			end
		end
		return false
	end

	local function isGreen(tile)
		local r = math.round(tile.Color.R * 255)
		local g = math.round(tile.Color.G * 255)
		local b = math.round(tile.Color.B * 255)
		return (r == 117 and g == 205 and b == 100) or (r == 103 and g == 180 and b == 88)
	end

	local function isBeige(tile)
		local r = math.round(tile.Color.R * 255)
		local g = math.round(tile.Color.G * 255)
		local b = math.round(tile.Color.B * 255)
		return (r == 255 and g == 255 and b == 125) or (r == 230 and g == 230 and b == 113)
	end

	local function isGreenColor(c)
		local r = math.round(c.R * 255)
		local g = math.round(c.G * 255)
		local b = math.round(c.B * 255)
		return (r == 117 and g == 205 and b == 100) or (r == 103 and g == 180 and b == 88)
	end

	local function isBeigeColor(c)
		local r = math.round(c.R * 255)
		local g = math.round(c.G * 255)
		local b = math.round(c.B * 255)
		return (r == 255 and g == 255 and b == 125) or (r == 230 and g == 230 and b == 113)
	end

	local function getTileNumber(tile)
		local gui = tile:FindFirstChild("NumberGui")
		if gui then
			local label = gui:FindFirstChild("TextLabel")
			if label then
				return tonumber(label.Text) or 0
			end
		end
		return 0
	end

	local partPool = {}

	local function acquireVisualPart(tile, color)
		local visualPart
		if #partPool > 0 then
			visualPart = table.remove(partPool)
		else
			visualPart = Instance.new("Part")
			visualPart.Name = "PooledVisual"
			visualPart.CastShadow = false
			visualPart.Material = Enum.Material.Neon
			visualPart.CanCollide = false
			visualPart.CanQuery = false
			visualPart.Anchored = true
			local surfaceGui = Instance.new("SurfaceGui")
			surfaceGui.Name = "SurfaceGui"
			surfaceGui.Face = Enum.NormalId.Top
			surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			surfaceGui.PixelsPerStud = 25
			surfaceGui.Parent = visualPart
			local textLabel = Instance.new("TextLabel")
			textLabel.Name = "Label"
			textLabel.BackgroundTransparency = 1
			textLabel.BorderSizePixel = 0
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
			textLabel.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
			textLabel.TextColor3 = Color3.new(0, 0, 0)
			textLabel.TextSize = 100
			textLabel.TextStrokeTransparency = 1
			textLabel.TextXAlignment = Enum.TextXAlignment.Center
			textLabel.TextYAlignment = Enum.TextYAlignment.Center
			textLabel.Parent = surfaceGui
		end
		visualPart.Color = color
		visualPart.Transparency = 0.3
		visualPart.Size = tile.Size * 0.8
		visualPart.Position = tile.Position + Vector3.new(0, 1.5, 0)
		visualPart.Parent = mainFolder
		local gui = visualPart:FindFirstChild("SurfaceGui")
		local lbl = gui and gui:FindFirstChild("Label")
		if lbl then lbl.Text = ""; lbl.TextTransparency = 1 end
		return visualPart
	end

	local function releaseVisualPart(visualPart)
		if not visualPart then return end
		visualPart.Parent = nil
		table.insert(partPool, visualPart)
	end

	local function clearTiles()
		for _, visual in pairs(activeTiles) do
			releaseVisualPart(visual)
		end
		for _, conn in pairs(colorConnections) do conn:Disconnect() end
		for _, conn in pairs(descConnections) do conn:Disconnect() end
		for _, conn in pairs(textConnections) do conn:Disconnect() end
		for _, conns in pairs(flagConnections) do
			for _, conn in ipairs(conns) do conn:Disconnect() end
		end
		table.clear(activeTiles)
		table.clear(colorConnections)
		table.clear(descConnections)
		table.clear(textConnections)
		table.clear(flagConnections)
		table.clear(neighborsCache)
		table.clear(tileGrid)
		table.clear(tileStates)
		table.clear(tileProbabilities)
		table.clear(partitionBestGuesses)
	end

	local function updateFlagVisibility(tile)
		local visualPart = activeTiles[tile]
		if not visualPart then return end
		local hasFlag = tileHasFlag(tile)
		visualPart.Transparency = hasFlag and 1 or 0.3
		local gui = visualPart:FindFirstChildOfClass("SurfaceGui")
		if gui then
			local lbl = gui:FindFirstChild("Label")
			if lbl then lbl.TextTransparency = hasFlag and 1 or 0 end
		end
	end

	local function hookFlagEvents(tile)
		if flagConnections[tile] then return end
		local added = tile.ChildAdded:Connect(function(child)
			if child:IsA("Model") and flagNames[child.Name] then
				updateFlagVisibility(tile)
			end
		end)
		local removed = tile.ChildRemoved:Connect(function(child)
			if child:IsA("Model") and flagNames[child.Name] then
				updateFlagVisibility(tile)
			end
		end)
		flagConnections[tile] = { added, removed }
	end

	local function solveBoard()
		if not gameRunning.Value then
			clearTiles()
			return
		end

		local hasGlobalMines = totalMinesValue ~= nil
		local totalMines = hasGlobalMines and totalMinesValue.Value or math.huge

		local colorSnapshot = {}
		local numberSnapshot = {}
		local positionSnapshot = {}
		for tile in pairs(neighborsCache) do
			colorSnapshot[tile] = tile.Color
			numberSnapshot[tile] = getTileNumber(tile)
			positionSnapshot[tile] = tile.Position
		end

		table.clear(tileProbabilities)
		table.clear(partitionBestGuesses)

		for tile in pairs(neighborsCache) do
			if not isGreenColor(colorSnapshot[tile]) then
				tileStates[tile] = 0
			end
		end

		local changed = true
		local iterations = 0
		while changed and iterations < 128 do
			iterations = iterations + 1
			changed = false

			if not gameRunning.Value then clearTiles() return end

			for tile, neighbors in pairs(neighborsCache) do
				if isBeigeColor(colorSnapshot[tile]) then
					local number = numberSnapshot[tile]
					if number > 0 then
						local unknownNeighbors = {}
						local mineCount = 0
						for _, neighbor in ipairs(neighbors) do
							if isGreenColor(colorSnapshot[neighbor]) then
								local state = tileStates[neighbor] or 0
								if state == 2 then
									mineCount = mineCount + 1
								elseif state == 0 then
									table.insert(unknownNeighbors, neighbor)
								end
							end
						end
						local uCount = #unknownNeighbors
						if uCount > 0 then
							if number == mineCount + uCount then
								for _, n in ipairs(unknownNeighbors) do
									if tileStates[n] ~= 2 then
										tileStates[n] = 2
										changed = true
									end
								end
							elseif number == mineCount then
								for _, n in ipairs(unknownNeighbors) do
									if tileStates[n] ~= 1 then
										tileStates[n] = 1
										changed = true
									end
								end
							end
						end
					end
				end
			end

			local knownMines = 0
			local totalUnknownGreen = 0
			local unknownGreenList = {}
			for t in pairs(neighborsCache) do
				if isGreenColor(colorSnapshot[t]) then
					if tileStates[t] == 2 then
						knownMines = knownMines + 1
					elseif tileStates[t] == 0 then
						totalUnknownGreen = totalUnknownGreen + 1
						table.insert(unknownGreenList, t)
					end
				end
			end

			local globalRemainingMines = totalMines - knownMines
			if hasGlobalMines and totalUnknownGreen > 0 then
				if globalRemainingMines == 0 then
					for _, t in ipairs(unknownGreenList) do
						if tileStates[t] ~= 1 then tileStates[t] = 1; changed = true end
					end
				elseif globalRemainingMines == totalUnknownGreen then
					for _, t in ipairs(unknownGreenList) do
						if tileStates[t] ~= 2 then tileStates[t] = 2; changed = true end
					end
				end
			end

			if not changed then
				local frontierTiles = {}
				local tileToConstraints = {}
				local frontierUnknownSet = {}

				for tile, neighbors in pairs(neighborsCache) do
					if isBeigeColor(colorSnapshot[tile]) then
						local number = numberSnapshot[tile]
						if number > 0 then
							local unknowns = {}
							local mineCount = 0
							for _, neighbor in ipairs(neighbors) do
								if isGreenColor(colorSnapshot[neighbor]) then
									local state = tileStates[neighbor] or 0
									if state == 2 then
										mineCount = mineCount + 1
									elseif state == 0 then
										table.insert(unknowns, neighbor)
									end
								end
							end
							if #unknowns > 0 then
								local constraint = { unknowns = unknowns, remaining = number - mineCount }
								for _, u in ipairs(unknowns) do
									if not tileToConstraints[u] then
										tileToConstraints[u] = {}
										table.insert(frontierTiles, u)
										frontierUnknownSet[u] = true
									end
									table.insert(tileToConstraints[u], constraint)
								end
							end
						end
					end
				end

				local nonFrontierUnknowns = 0
				for _, t in ipairs(unknownGreenList) do
					if not frontierUnknownSet[t] then
						nonFrontierUnknowns = nonFrontierUnknowns + 1
					end
				end

				local visited = {}
				local partitions = {}
				for _, tile in ipairs(frontierTiles) do
					if not visited[tile] then
						local groupTiles = {}
						local groupConstraints = {}
						local cVisited = {}
						local queue = {tile}
						local qHead = 1
						visited[tile] = true
						while qHead <= #queue do
							local curr = queue[qHead]; qHead = qHead + 1
							table.insert(groupTiles, curr)
							for _, c in ipairs(tileToConstraints[curr]) do
								if not cVisited[c] then
									cVisited[c] = true
									table.insert(groupConstraints, c)
									for _, u in ipairs(c.unknowns) do
										if not visited[u] then
											visited[u] = true
											table.insert(queue, u)
										end
									end
								end
							end
						end
						table.insert(partitions, { tiles = groupTiles, constraints = groupConstraints })
					end
				end

				for _, part in ipairs(partitions) do
					if #part.tiles <= 14 then
						local validConfigs = 0
						local mineFreq = {}
						for _, t in ipairs(part.tiles) do mineFreq[t] = 0 end
						local assignment = {}
						local unknownsOutside = nonFrontierUnknowns + (#frontierTiles - #part.tiles)
						local noOutsideAbsorbers = (unknownsOutside == 0)
						local function backtrack(index, currentMines)
							if not gameRunning.Value then return end
							local remainingInPart = #part.tiles - index + 1
							if hasGlobalMines and (currentMines + remainingInPart + unknownsOutside < globalRemainingMines) then return end
							if index > #part.tiles then
								if hasGlobalMines and noOutsideAbsorbers and currentMines ~= globalRemainingMines then return end
								validConfigs = validConfigs + 1
								for _, t in ipairs(part.tiles) do
									if assignment[t] == 2 then mineFreq[t] = mineFreq[t] + 1 end
								end
								return
							end
							local tile = part.tiles[index]
							assignment[tile] = 1
							local canSafe = true
							for _, c in ipairs(tileToConstraints[tile] or {}) do
								local placed, unassigned = 0, 0
								for _, ct in ipairs(c.unknowns) do
									if assignment[ct] == 2 then placed = placed + 1
									elseif assignment[ct] == nil then unassigned = unassigned + 1 end
								end
								if placed + unassigned < c.remaining then canSafe = false; break end
							end
							if canSafe then backtrack(index + 1, currentMines) end
							local newMines = currentMines + 1
							if not hasGlobalMines or newMines <= globalRemainingMines then
								assignment[tile] = 2
								local canMine = true
								for _, c in ipairs(tileToConstraints[tile] or {}) do
									local placed = 0
									for _, ct in ipairs(c.unknowns) do
										if assignment[ct] == 2 then placed = placed + 1 end
									end
									if placed > c.remaining then canMine = false; break end
								end
								if canMine then backtrack(index + 1, newMines) end
							end
							assignment[tile] = nil
						end
						backtrack(1, 0)
						if validConfigs > 0 then
							local partBestTile = nil
							local partBestProb = math.huge
							for _, t in ipairs(part.tiles) do
								local p = mineFreq[t] / validConfigs
								if p == 1 and tileStates[t] ~= 2 then
									tileStates[t] = 2; changed = true
								elseif p == 0 and tileStates[t] ~= 1 then
									tileStates[t] = 1; changed = true
								else
									tileProbabilities[t] = p
									if p < partBestProb then
										partBestProb = p; partBestTile = t
									end
								end
							end
							if partBestTile then
								local cx, cy, cz = 0, 0, 0
								local count = #part.tiles
								for _, t in ipairs(part.tiles) do
									cx = cx + positionSnapshot[t].X
									cy = cy + positionSnapshot[t].Y
									cz = cz + positionSnapshot[t].Z
								end
								table.insert(partitionBestGuesses, {
									tile = partBestTile,
									prob = partBestProb,
									centroid = Vector3.new(cx / count, cy / count, cz / count)
								})
							end
						end
					else
						local cx, cy, cz = 0, 0, 0
						local count = #part.tiles
						for _, t in ipairs(part.tiles) do
							cx = cx + positionSnapshot[t].X
							cy = cy + positionSnapshot[t].Y
							cz = cz + positionSnapshot[t].Z
						end
						local centroid = Vector3.new(cx / count, cy / count, cz / count)
						local bestDist = math.huge
						local bestTile = part.tiles[1]
						for _, t in ipairs(part.tiles) do
							local d = (positionSnapshot[t] - centroid).Magnitude
							if d < bestDist then bestDist = d; bestTile = t end
						end
						table.insert(partitionBestGuesses, { tile = bestTile, prob = 0, centroid = centroid })
					end
				end

				local nonFrontierTiles = {}
				for _, t in ipairs(unknownGreenList) do
					if not frontierUnknownSet[t] then
						table.insert(nonFrontierTiles, t)
					end
				end

				local nonFrontierVisited = {}
				local nonFrontierPartitions = {}
				for _, tile in ipairs(nonFrontierTiles) do
					if not nonFrontierVisited[tile] then
						local group = {}
						local queue = {tile}
						local qHead = 1
						nonFrontierVisited[tile] = true
						while qHead <= #queue do
							local curr = queue[qHead]; qHead = qHead + 1
							table.insert(group, curr)
							for _, neighbor in ipairs(neighborsCache[curr] or {}) do
								if isGreenColor(colorSnapshot[neighbor]) and not frontierUnknownSet[neighbor] and not nonFrontierVisited[neighbor] then
									nonFrontierVisited[neighbor] = true
									table.insert(queue, neighbor)
								end
							end
						end
						table.insert(nonFrontierPartitions, group)
					end
				end

				for _, group in ipairs(nonFrontierPartitions) do
					local cx, cy, cz = 0, 0, 0
					for _, t in ipairs(group) do
						cx = cx + positionSnapshot[t].X
						cy = cy + positionSnapshot[t].Y
						cz = cz + positionSnapshot[t].Z
					end
					local centroid = Vector3.new(cx / #group, cy / #group, cz / #group)
					local bestDist = math.huge
					local bestTile = group[1]
					for _, t in ipairs(group) do
						local d = (t.Position - centroid).Magnitude
						if d < bestDist then bestDist = d; bestTile = t end
					end
					table.insert(partitionBestGuesses, { tile = bestTile, prob = 0, centroid = centroid })
				end
			end
		end

		if not gameRunning.Value then clearTiles() return end

		local guessSet = {}
		for _, entry in ipairs(partitionBestGuesses) do
			guessSet[entry.tile] = true
		end

		local visitedYellow = {}
		for tile, neighbors in pairs(neighborsCache) do
			local state = tileStates[tile] or 0
			if not visitedYellow[tile] and isGreen(tile) and state == 0 then
				local isEdge = false
				for _, neighbor in ipairs(neighbors) do
					if isBeige(neighbor) then isEdge = true; break end
				end
				if isEdge then
					local group = {}
					local hasGuess = false
					local queue = {tile}
					local qHead = 1
					visitedYellow[tile] = true
					while qHead <= #queue do
						local curr = queue[qHead]; qHead = qHead + 1
						table.insert(group, curr)
						if guessSet[curr] then hasGuess = true end
						for _, neighbor in ipairs(neighborsCache[curr]) do
							if not visitedYellow[neighbor] and isGreen(neighbor) and (tileStates[neighbor] or 0) == 0 then
								local neighborIsEdge = false
								for _, nn in ipairs(neighborsCache[neighbor]) do
									if isBeige(nn) then neighborIsEdge = true; break end
								end
								if neighborIsEdge then
									visitedYellow[neighbor] = true
									table.insert(queue, neighbor)
								end
							end
						end
					end
					if not hasGuess then
						local cx, cy, cz = 0, 0, 0
						for _, t in ipairs(group) do
							cx = cx + t.Position.X
							cy = cy + t.Position.Y
							cz = cz + t.Position.Z
						end
						local centroid = Vector3.new(cx / #group, cy / #group, cz / #group)
						local bestDist = math.huge
						local bestTile = group[1]
						for _, t in ipairs(group) do
							local d = (t.Position - centroid).Magnitude
							if d < bestDist then bestDist = d; bestTile = t end
						end
						guessSet[bestTile] = true
					end
				end
			end
		end

		for tile, neighbors in pairs(neighborsCache) do
			local isEdge = false
			local tileColor = colorSnapshot[tile]
			if tileColor and isGreenColor(tileColor) then
				for _, neighbor in ipairs(neighbors) do
					local nc = colorSnapshot[neighbor]
					if nc and isBeigeColor(nc) then isEdge = true; break end
				end
			end

			if isEdge then
				local state = tileStates[tile] or 0
				local targetColor
				if state == 1 then
					targetColor = COLOR_SAFE
				elseif state == 2 then
					targetColor = COLOR_MINE
				elseif guessSet[tile] then
					targetColor = COLOR_BEST
				else
					targetColor = COLOR_UNKNOWN
				end

				local visualPart = activeTiles[tile]
				if not visualPart then
					visualPart = acquireVisualPart(tile, targetColor)
					activeTiles[tile] = visualPart
				else
					visualPart.Color = targetColor
				end
				local gui = visualPart:FindFirstChild("SurfaceGui")
				local lbl = gui and gui:FindFirstChild("Label")
				if state == 1 then
					if lbl then lbl.Text = ""; lbl.TextTransparency = 1 end
					visualPart.Transparency = 0.3
					if flagConnections[tile] then
						for _, conn in ipairs(flagConnections[tile]) do conn:Disconnect() end
						flagConnections[tile] = nil
					end
				elseif state == 2 then
					hookFlagEvents(tile)
					local hasFlag = tileHasFlag(tile)
					visualPart.Transparency = hasFlag and 1 or 0.3
					if lbl then lbl.Text = "X"; lbl.TextTransparency = hasFlag and 1 or 0 end
				elseif guessSet[tile] then
					if lbl then lbl.Text = "?"; lbl.TextTransparency = 0 end
					visualPart.Transparency = 0.3
					if flagConnections[tile] then
						for _, conn in ipairs(flagConnections[tile]) do conn:Disconnect() end
						flagConnections[tile] = nil
					end
				else
					if lbl then lbl.Text = "?"; lbl.TextTransparency = 0 end
					visualPart.Transparency = 0.3
					if flagConnections[tile] then
						for _, conn in ipairs(flagConnections[tile]) do conn:Disconnect() end
						flagConnections[tile] = nil
					end
				end
			else
				if activeTiles[tile] then
					releaseVisualPart(activeTiles[tile])
					activeTiles[tile] = nil
				end
				if flagConnections[tile] then
					for _, conn in ipairs(flagConnections[tile]) do conn:Disconnect() end
					flagConnections[tile] = nil
				end
			end
		end
	end

	local function queueSolve()
		if solvePending then return end
		if not gameRunning.Value then clearTiles() return end
		solvePending = true
		local now = tick()
		local wait = math.max(0, SOLVE_COOLDOWN - (now - lastSolveTime))
		task.delay(wait, function()
			solvePending = false
			lastSolveTime = tick()
			solveBoard()
		end)
	end

	local function getTileGridKey(pos, tileWidth, tileDepth)
		local gx = math.round(pos.X / tileWidth)
		local gz = math.round(pos.Z / tileDepth)
		return gx, gz
	end

	local function registerTile(tile, skipEvaluation)
		if not tile:IsA("BasePart") then return end
		if neighborsCache[tile] then return end
		neighborsCache[tile] = {}
		tileStates[tile] = 0
		local tileWidth = tile.Size.X
		local tileDepth = tile.Size.Z
		if not tileGridSize then
			tileGridSize = { x = tileWidth, z = tileDepth }
		end
		local gx, gz = getTileGridKey(tile.Position, tileGridSize.x, tileGridSize.z)
		for dx = -1, 1 do
			for dz = -1, 1 do
				if dx ~= 0 or dz ~= 0 then
					local key = (gx + dx) .. "," .. (gz + dz)
					local otherTile = tileGrid[key]
					if otherTile and neighborsCache[otherTile] then
						table.insert(neighborsCache[tile], otherTile)
						table.insert(neighborsCache[otherTile], tile)
					end
				end
			end
		end
		tileGrid[gx .. "," .. gz] = tile
		colorConnections[tile] = tile:GetPropertyChangedSignal("Color"):Connect(queueSolve)
		local function hookDescendants(child)
			if child:IsA("TextLabel") then
				if not textConnections[child] then
					textConnections[child] = child:GetPropertyChangedSignal("Text"):Connect(queueSolve)
					queueSolve()
				end
			end
		end
		for _, desc in ipairs(tile:GetDescendants()) do
			hookDescendants(desc)
		end
		descConnections[tile] = tile.DescendantAdded:Connect(hookDescendants)
		if not skipEvaluation then
			queueSolve()
		end
	end

	local function unregisterTile(tile)
		if activeTiles[tile] then
			releaseVisualPart(activeTiles[tile])
			activeTiles[tile] = nil
		end
		if colorConnections[tile] then colorConnections[tile]:Disconnect(); colorConnections[tile] = nil end
		if descConnections[tile] then descConnections[tile]:Disconnect(); descConnections[tile] = nil end
		if flagConnections[tile] then
			for _, conn in ipairs(flagConnections[tile]) do conn:Disconnect() end
			flagConnections[tile] = nil
		end
		for _, desc in ipairs(tile:GetDescendants()) do
			if textConnections[desc] then
				textConnections[desc]:Disconnect()
				textConnections[desc] = nil
			end
		end
		if tileGridSize then
			local gx, gz = getTileGridKey(tile.Position, tileGridSize.x, tileGridSize.z)
			local key = gx .. "," .. gz
			if tileGrid[key] == tile then tileGrid[key] = nil end
		end
		if neighborsCache[tile] then
			for _, neighbor in ipairs(neighborsCache[tile]) do
				local nList = neighborsCache[neighbor]
				if nList then
					local index = table.find(nList, tile)
					if index then table.remove(nList, index) end
				end
			end
			neighborsCache[tile] = nil
		end
		tileStates[tile] = nil
		tileProbabilities[tile] = nil
	end

	local function setupAllTiles()
		table.clear(tileGrid)
		tileGridSize = nil
		for _, tile in ipairs(partsFolder:GetChildren()) do
			registerTile(tile, true)
		end
		queueSolve()
	end

	local isCleaningUp = false
	local function cleanupScript()
		if isCleaningUp then return end
		isCleaningUp = true
		clearTiles()
		for _, part in ipairs(partPool) do
			if part and part.Parent then part:Destroy() end
		end
		table.clear(partPool)
		if mainFolder and mainFolder.Parent then mainFolder:Destroy() end
		for _, conn in ipairs(topLevelConnections) do conn:Disconnect() end
		table.clear(topLevelConnections)
		if executionTracker and executionTracker.Parent then executionTracker:Destroy() end
	end

	table.insert(topLevelConnections, partsFolder.ChildAdded:Connect(function(child)
		registerTile(child, false)
	end))

	table.insert(topLevelConnections, partsFolder.ChildRemoved:Connect(unregisterTile))

	table.insert(topLevelConnections, gameRunning:GetPropertyChangedSignal("Value"):Connect(function()
		if gameRunning.Value then
			setupAllTiles()
		else
			clearTiles()
		end
	end))

	table.insert(topLevelConnections, executionTracker.Destroying:Connect(function()
		cleanupScript()
	end))

	if totalMinesValue then
		table.insert(topLevelConnections, totalMinesValue:GetPropertyChangedSignal("Value"):Connect(queueSolve))
	end

	table.insert(topLevelConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed then
			if input.KeyCode == Enum.KeyCode.Delete then
				cleanupScript()
			elseif input.KeyCode == Enum.KeyCode.H then
				highlightsEnabled = not highlightsEnabled
				if mainFolder then
					mainFolder.Parent = highlightsEnabled and workspace or nil
				end
			end
		end
	end))

	if gameRunning.Value then
		setupAllTiles()
	end
else
	warn("Tokaihub")
end

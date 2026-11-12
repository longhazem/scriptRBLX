local genv = getgenv()
if genv.MS2_STOP then pcall(genv.MS2_STOP) end

local Core = {}

local function neighbours(W, H, i)
    local out = {}
    local col = (i - 1) % W + 1
    local row = math.floor((i - 1) / W) + 1
    for dr = -1, 1 do
        for dc = -1, 1 do
            if dr ~= 0 or dc ~= 0 then
                local nc, nr = col + dc, row + dr
                if nc >= 1 and nc <= W and nr >= 1 and nr <= H then
                    out[#out + 1] = (nr - 1) * W + nc
                end
            end
        end
    end
    return out
end
Core.neighbours = neighbours

local function logFactorials(n)
    local lf = { [0] = 0 }
    local acc = 0
    for i = 1, n do
        acc = acc + math.log(i)
        lf[i] = acc
    end
    return lf
end

local function polyMul(a, b)
    local la, lb = #a, #b
    local out = {}
    for i = 1, la + lb - 1 do
        out[i] = 0
    end
    for i = 1, la do
        local ai = a[i]
        if ai ~= 0 then
            for j = 1, lb do
                out[i + j - 1] = out[i + j - 1] + ai * b[j]
            end
        end
    end
    return out
end

local function findRoot(parent, x)
    while parent[x] ~= x do
        parent[x] = parent[parent[x]]
        x = parent[x]
    end
    return x
end

local function buildModel(vars, cons)
    local n, m = #vars, #cons
    local localOf = {}
    for li = 1, n do
        localOf[vars[li]] = li
    end
    local cv, tgt, vc = {}, {}, {}
    for li = 1, n do
        vc[li] = {}
    end
    for ci = 1, m do
        local c = cons[ci]
        local list = {}
        for k = 1, #c.vars do
            local li = localOf[c.vars[k]]
            list[k] = li
            vc[li][#vc[li] + 1] = ci
        end
        cv[ci] = list
        tgt[ci] = c.target
    end
    local order, seen = {}, {}
    for start = 1, n do
        if not seen[start] then
            seen[start] = true
            local queue, head = { start }, 1
            while head <= #queue do
                local li = queue[head]
                head = head + 1
                order[#order + 1] = li
                for _, ci in ipairs(vc[li]) do
                    for _, lj in ipairs(cv[ci]) do
                        if not seen[lj] then
                            seen[lj] = true
                            queue[#queue + 1] = lj
                        end
                    end
                end
            end
        end
    end
    return { n = n, m = m, cv = cv, tgt = tgt, vc = vc, order = order }
end

local function enumerate(model, work)
    local n, m, cv, tgt, vc, order = model.n, model.m, model.cv, model.tgt, model.vc, model.order
    local sum, unas = {}, {}
    for ci = 1, m do
        sum[ci] = 0
        unas[ci] = #cv[ci]
    end
    local assign, cnt, cellK = {}, {}, {}
    for li = 1, n do
        cellK[li] = {}
    end
    local spent, overflow = 0, false

    local function dfs(pos, k)
        spent = spent + 1
        if spent > work then
            overflow = true
            return
        end
        if pos > n then
            spent = spent + n
            cnt[k + 1] = (cnt[k + 1] or 0) + 1
            for li = 1, n do
                if assign[li] == 1 then
                    local row = cellK[li]
                    row[k + 1] = (row[k + 1] or 0) + 1
                end
            end
            return
        end
        local li = order[pos]
        local list = vc[li]
        for val = 0, 1 do
            for _, ci in ipairs(list) do
                unas[ci] = unas[ci] - 1
                sum[ci] = sum[ci] + val
            end
            local ok = true
            for _, ci in ipairs(list) do
                if sum[ci] > tgt[ci] or sum[ci] + unas[ci] < tgt[ci] then
                    ok = false
                    break
                end
            end
            if ok then
                assign[li] = val
                dfs(pos + 1, k + val)
                assign[li] = nil
            end
            for _, ci in ipairs(list) do
                unas[ci] = unas[ci] + 1
                sum[ci] = sum[ci] - val
            end
            if overflow then
                return
            end
        end
    end

    dfs(1, 0)
    if overflow then
        return nil, spent
    end
    for k = 1, n + 1 do
        cnt[k] = cnt[k] or 0
    end
    for li = 1, n do
        for k = 1, n + 1 do
            cellK[li][k] = cellK[li][k] or 0
        end
    end
    return cnt, cellK, spent
end

local function probeFit(model, pinLi, pinVal, budget)
    local n, m, tgt, vc, order = model.n, model.m, model.tgt, model.vc, model.order
    local sum, unas = {}, {}
    for ci = 1, m do
        sum[ci] = 0
        unas[ci] = #model.cv[ci]
    end
    local spent, found, overflow = 0, false, false

    local function dfs(pos)
        spent = spent + 1
        if spent > budget then
            overflow = true
            return
        end
        if pos > n then
            found = true
            return
        end
        local li = order[pos]
        local list = vc[li]
        local lo, hi = 0, 1
        if li == pinLi then
            lo, hi = pinVal, pinVal
        end
        for val = lo, hi do
            for _, ci in ipairs(list) do
                unas[ci] = unas[ci] - 1
                sum[ci] = sum[ci] + val
            end
            local ok = true
            for _, ci in ipairs(list) do
                if sum[ci] > tgt[ci] or sum[ci] + unas[ci] < tgt[ci] then
                    ok = false
                    break
                end
            end
            if ok then
                dfs(pos + 1)
            end
            for _, ci in ipairs(list) do
                unas[ci] = unas[ci] + 1
                sum[ci] = sum[ci] - val
            end
            if found or overflow then
                return
            end
        end
    end

    dfs(1)
    if found then
        return true, spent
    end
    if overflow then
        return nil, spent
    end
    return false, spent
end

function Core.solve(W, H, st, opts)
    opts = opts or {}
    local N = W * H
    local open = st.open or {}
    local value = st.value or {}
    local flag = st.flag or {}
    local exists = {}
    for i = 1, N do
        exists[i] = (st.exists == nil) or (st.exists[i] == true)
    end
    local total = opts.totalMines
    local exactLimit = opts.exactLimit or 60
    local workLeft = opts.work or 400000
    local full = opts.mode ~= "basic"
    local clock0 = os.clock()
    local res = { safe = {}, mines = {}, probs = {}, guess = nil, guessP = nil, error = nil, stats = {} }

    local nb = {}
    for i = 1, N do
        local list = {}
        if exists[i] then
            for _, j in ipairs(neighbours(W, H, i)) do
                if exists[j] then
                    list[#list + 1] = j
                end
            end
        end
        nb[i] = list
    end

    local known = {}
    for i = 1, N do
        if exists[i] and flag[i] then
            known[i] = 1
        end
    end

    local conflict = nil
    local function setKnown(i, v)
        local old = known[i]
        if old == nil then
            known[i] = v
            return true
        end
        if old ~= v then
            conflict = conflict or ("cell " .. i .. " is both safe and a mine")
        end
        return false
    end

    local cons = {}
    for i = 1, N do
        if exists[i] and open[i] and value[i] ~= nil then
            local vars, f = {}, 0
            for _, j in ipairs(nb[i]) do
                if flag[j] then
                    f = f + 1
                elseif not open[j] then
                    vars[#vars + 1] = j
                end
            end
            cons[#cons + 1] = { vars = vars, target = value[i] - f, src = i }
        end
    end

    local function pruneOne(c)
        local keep = {}
        for _, v in ipairs(c.vars) do
            local k = known[v]
            if k == nil then
                keep[#keep + 1] = v
            elseif k == 1 then
                c.target = c.target - 1
            end
        end
        c.vars = keep
    end

    local function basic()
        local changed = false
        for _, c in ipairs(cons) do
            pruneOne(c)
            local n = #c.vars
            if n == 0 then
                if c.target ~= 0 then
                    conflict = conflict or ("number at cell " .. c.src .. " does not fit the flags around it")
                end
            elseif c.target < 0 or c.target > n then
                conflict = conflict or ("number at cell " .. c.src .. " cannot be met")
            elseif c.target == 0 then
                for _, v in ipairs(c.vars) do
                    if setKnown(v, 0) then
                        changed = true
                    end
                end
            elseif c.target == n then
                for _, v in ipairs(c.vars) do
                    if setKnown(v, 1) then
                        changed = true
                    end
                end
            end
        end
        return changed
    end

    local function subsets()
        local changed = false
        local byVar = {}
        for ci, c in ipairs(cons) do
            pruneOne(c)
            for _, v in ipairs(c.vars) do
                local list = byVar[v]
                if not list then
                    list = {}
                    byVar[v] = list
                end
                list[#list + 1] = ci
            end
        end
        for ai, a in ipairs(cons) do
            pruneOne(a)
            if #a.vars > 0 then
                for _, bi in ipairs(byVar[a.vars[1]] or {}) do
                    if bi ~= ai and conflict == nil then
                        local b = cons[bi]
                        pruneOne(a)
                        pruneOne(b)
                        if #a.vars > 0 and #b.vars > #a.vars then
                            local setA, setB = {}, {}
                            for _, v in ipairs(a.vars) do
                                setA[v] = true
                            end
                            for _, v in ipairs(b.vars) do
                                setB[v] = true
                            end
                            local sub = true
                            for _, v in ipairs(a.vars) do
                                if not setB[v] then
                                    sub = false
                                    break
                                end
                            end
                            if sub then
                                local diff = {}
                                for _, v in ipairs(b.vars) do
                                    if not setA[v] then
                                        diff[#diff + 1] = v
                                    end
                                end
                                local dt = b.target - a.target
                                if dt < 0 or dt > #diff then
                                    conflict = conflict or ("numbers at cells " .. a.src .. " and " .. b.src .. " contradict")
                                elseif dt == 0 then
                                    for _, v in ipairs(diff) do
                                        if setKnown(v, 0) then
                                            changed = true
                                        end
                                    end
                                elseif dt == #diff then
                                    for _, v in ipairs(diff) do
                                        if setKnown(v, 1) then
                                            changed = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return changed
    end

    local function globalRule()
        if total == nil then
            return false
        end
        local mines, unknowns = 0, {}
        for i = 1, N do
            if exists[i] then
                if known[i] == 1 then
                    mines = mines + 1
                elseif known[i] == nil and not open[i] then
                    unknowns[#unknowns + 1] = i
                end
            end
        end
        local remaining = total - mines
        if remaining < 0 then
            conflict = conflict or "the board holds more mines than the game count"
            return false
        end
        local changed = false
        if #unknowns > 0 then
            if remaining == 0 then
                for _, i in ipairs(unknowns) do
                    if setKnown(i, 0) then
                        changed = true
                    end
                end
            elseif remaining == #unknowns then
                for _, i in ipairs(unknowns) do
                    if setKnown(i, 1) then
                        changed = true
                    end
                end
            end
        end
        return changed
    end

    local rounds = 0
    local progress = true
    while progress and conflict == nil and rounds < 2000 do
        rounds = rounds + 1
        local a = basic()
        local b = subsets()
        local c = false
        if full then
            c = globalRule()
        end
        progress = a or b or c
    end
    if conflict then
        res.error = conflict
        return res
    end

    local parent, frontier = {}, {}
    for _, c in ipairs(cons) do
        pruneOne(c)
        for _, v in ipairs(c.vars) do
            frontier[v] = true
            parent[v] = v
        end
    end
    for _, c in ipairs(cons) do
        if #c.vars > 1 then
            local root = findRoot(parent, c.vars[1])
            for k = 2, #c.vars do
                local other = findRoot(parent, c.vars[k])
                if other ~= root then
                    parent[other] = root
                end
            end
        end
    end
    local varList = {}
    for v in pairs(frontier) do
        varList[#varList + 1] = v
    end
    table.sort(varList)
    local comps, byRoot = {}, {}
    for _, v in ipairs(varList) do
        local r = findRoot(parent, v)
        local comp = byRoot[r]
        if not comp then
            comp = { vars = {}, cons = {}, exact = false, n = 0 }
            byRoot[r] = comp
            comps[#comps + 1] = comp
        end
        comp.vars[#comp.vars + 1] = v
    end
    for _, c in ipairs(cons) do
        if #c.vars > 0 then
            local comp = byRoot[findRoot(parent, c.vars[1])]
            comp.cons[#comp.cons + 1] = c
        end
    end

    local frontierCount = #varList
    local unknownCount, minesKnown = 0, 0
    for i = 1, N do
        if exists[i] then
            if known[i] == 1 then
                minesKnown = minesKnown + 1
            elseif known[i] == nil and not open[i] then
                unknownCount = unknownCount + 1
            end
        end
    end
    local outside = unknownCount - frontierCount
    local remaining = nil
    if total ~= nil then
        remaining = total - minesKnown
    end

    local exactAll = true
    for _, comp in ipairs(comps) do
        comp.n = #comp.vars
        if full and comp.n <= exactLimit and workLeft > 0 then
            local model = buildModel(comp.vars, comp.cons)
            local cnt, cellK, spent = enumerate(model, workLeft)
            if cnt then
                comp.exact = true
                comp.cnt, comp.cellK = cnt, cellK
                workLeft = workLeft - spent
            else
                workLeft = 0
            end
        end
        if not comp.exact then
            exactAll = false
        end
    end

    local exactVar = {}
    for _, comp in ipairs(comps) do
        if comp.exact then
            local sumC = 0
            for k = 1, #comp.cnt do
                sumC = sumC + comp.cnt[k]
            end
            if sumC == 0 then
                res.error = "no assignment of the frontier fits the numbers (stale board?)"
                return res
            end
            for k = 1, #comp.cnt do
                comp.cnt[k] = comp.cnt[k] / sumC
            end
            for li = 1, comp.n do
                local row = comp.cellK[li]
                for k = 1, #row do
                    row[k] = row[k] / sumC
                end
            end
        end
        for _, v in ipairs(comp.vars) do
            exactVar[v] = comp.exact
        end
    end

    local P = {}
    for _, comp in ipairs(comps) do
        if not comp.exact then
            local sumP, cntP = {}, {}
            for _, c in ipairs(comp.cons) do
                local dens = c.target / #c.vars
                for _, v in ipairs(c.vars) do
                    sumP[v] = (sumP[v] or 0) + dens
                    cntP[v] = (cntP[v] or 0) + 1
                end
            end
            for _, v in ipairs(comp.vars) do
                P[v] = math.min(1, math.max(0, (sumP[v] or 0.5) / (cntP[v] or 1)))
            end
        end
    end

    local probes = 0
    local probeCertain = {}
    if full then
        local probeLeft = opts.probeWork or 300000
        local probeLimit = opts.probeLimit or 20000
        for _, comp in ipairs(comps) do
            if not comp.exact and probeLeft > 0 then
                local model = buildModel(comp.vars, comp.cons)
                for li = 1, comp.n do
                    if probeLeft <= 0 then
                        break
                    end
                    local v = comp.vars[li]
                    if known[v] == nil then
                        local canMine, s1 = probeFit(model, li, 1, math.min(probeLimit, probeLeft))
                        probeLeft = probeLeft - (s1 or 0)
                        probes = probes + 1
                        local canSafe = nil
                        if probeLeft > 0 then
                            local s2
                            canSafe, s2 = probeFit(model, li, 0, math.min(probeLimit, probeLeft))
                            probeLeft = probeLeft - (s2 or 0)
                            probes = probes + 1
                        end
                        if canMine == false and canSafe == false then
                            res.error = "a cell fits neither value (stale board?)"
                            return res
                        elseif canMine == false then
                            probeCertain[v] = 0
                        elseif canSafe == false then
                            probeCertain[v] = 1
                        end
                    end
                end
            end
        end
        for v, val in pairs(probeCertain) do
            if known[v] == nil then
                setKnown(v, val)
            end
            P[v] = val
        end
        if total ~= nil then
            local mk = 0
            for i = 1, N do
                if exists[i] and known[i] == 1 then
                    mk = mk + 1
                end
            end
            remaining = total - mk
        end
    end

    local Pout = nil
    if total ~= nil and exactAll and remaining ~= nil then

        local F = frontierCount
        local lf = logFactorials(math.max(unknownCount, 1))
        local logw, best = {}, nil
        for t = 0, F do
            local r = remaining - t
            local l = false
            if outside == 0 then
                if r == 0 then
                    l = 0
                end
            elseif r >= 0 and r <= outside then
                l = lf[outside] - lf[r] - lf[outside - r]
            end
            logw[t + 1] = l
            if l and (best == nil or l > best) then
                best = l
            end
        end
        local wOut = {}
        for t = 0, F do
            local l = logw[t + 1]
            if l and best ~= nil then
                wOut[t + 1] = math.exp(l - best)
            else
                wOut[t + 1] = 0
            end
        end
        local m = #comps
        local pre, suf = { [0] = { 1 } }, { [m + 1] = { 1 } }
        for j = 1, m do
            pre[j] = polyMul(pre[j - 1], comps[j].cnt)
        end
        for j = m, 1, -1 do
            suf[j] = polyMul(comps[j].cnt, suf[j + 1])
        end
        local D = pre[m]
        local Z = 0
        for t = 0, F do
            Z = Z + D[t + 1] * wOut[t + 1]
        end
        if Z <= 0 then
            res.error = "the mine count does not fit the board (stale count?)"
            return res
        end
        for j = 1, m do
            local comp = comps[j]
            local excl = polyMul(pre[j - 1], suf[j + 1])
            local G = {}
            for k = 0, comp.n do
                local acc = 0
                for s = 0, #excl - 1 do
                    local t = s + k
                    if t <= F then
                        acc = acc + excl[s + 1] * wOut[t + 1]
                    end
                end
                G[k + 1] = acc
            end
            for li = 1, comp.n do
                local row = comp.cellK[li]
                local num = 0
                for k = 0, comp.n do
                    num = num + row[k + 1] * G[k + 1]
                end
                P[comp.vars[li]] = num / Z
            end
        end
        if outside > 0 then
            local E = 0
            for t = 0, F do
                E = E + D[t + 1] * wOut[t + 1] * (remaining - t)
            end
            Pout = (E / Z) / outside
        end
    else
        for _, comp in ipairs(comps) do
            if comp.exact then
                for li, v in ipairs(comp.vars) do
                    local s = 0
                    for k = 1, comp.n + 1 do
                        s = s + comp.cellK[li][k]
                    end
                    P[v] = s
                end
            end
        end
        if outside > 0 then
            if remaining ~= nil then
                local expect = 0
                for _, v in ipairs(varList) do
                    expect = expect + (P[v] or 0.5)
                end
                Pout = math.min(1, math.max(0, (remaining - expect) / outside))
            else
                local sumP = 0
                for _, v in ipairs(varList) do
                    sumP = sumP + (P[v] or 0.5)
                end
                Pout = (frontierCount > 0) and (sumP / frontierCount) or 0.5
            end
        end
    end

    local EPS = 1e-9
    for _, v in ipairs(varList) do
        if exactVar[v] and known[v] == nil then
            local p = P[v]
            if p <= EPS then
                setKnown(v, 0)
            elseif p >= 1 - EPS then
                setKnown(v, 1)
            end
        end
    end

    for i = 1, N do
        if exists[i] and not open[i] and not flag[i] then
            local k = known[i]
            if k == 0 then
                res.safe[#res.safe + 1] = i
                res.probs[i] = 0
            elseif k == 1 then
                res.mines[#res.mines + 1] = i
                res.probs[i] = 1
            else
                local p = P[i]
                if p == nil then
                    p = Pout or 0.5
                end
                res.probs[i] = p
            end
        end
    end

    if full then
        local bestI, bestP, bestFront, bestInfo = nil, math.huge, false, -1
        for i = 1, N do
            if exists[i] and not open[i] and not flag[i] and known[i] == nil then
                local p = res.probs[i]
                local front = (P[i] ~= nil)
                local info = 0
                for _, j in ipairs(nb[i]) do
                    if open[j] and value[j] ~= nil then
                        info = info + 1
                    end
                end
                local better = false
                if bestI == nil or p < bestP - 1e-12 then
                    better = true
                elseif math.abs(p - bestP) <= 1e-12 then
                    if front ~= bestFront then
                        better = front
                    else
                        better = info > bestInfo
                    end
                end
                if better then
                    bestI, bestP, bestFront, bestInfo = i, p, front, info
                end
            end
        end
        res.guess = bestI
        res.guessP = bestI and bestP or nil
    end

    res.stats = {
        comps = #comps,
        frontier = frontierCount,
        outside = outside,
        exact = exactAll,
        probes = probes,
        work = (opts.work or 400000) - workLeft,
        seconds = os.clock() - clock0,
    }
    return res
end
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local TIME = { now = function() return os.clock() end }

local CONFIG = {
    Movement = "hop",
    HopWait = 0.01,
    HopPoll = 0.01,
    HopTimeout = 0.3,
    HopBatch = 8,
    WalkSpeed = 28,
    MaxWalkTiles = 12,
    WalkWaypointTimeout = 1.5,
    Solve = false,
    SolverInterval = 0.03,
    MaxGuessRisk = 1,
    BlockSeconds = 5,
    ShowMarks = true,
    ShowHeat = true,
    ShowGuess = true,
    ESPInterval = 0.03,
    ShowDistance = 0,
    Opacity = 0.6,
    AutoFlag = false,
    FlagDelay = 0.05,
    FlagRange = 30,
    Tick = 0.02,
}

local COLOURS = {
    safe = Color3.fromRGB(60, 220, 90),
    mine = Color3.fromRGB(230, 50, 50),
    guess = Color3.fromRGB(255, 230, 60),
    lowRisk = Color3.fromRGB(80, 170, 255),
    highRisk = Color3.fromRGB(255, 120, 60),
}

local UNOPENED = {
    { 0.459, 0.804, 0.392 }, { 0.404, 0.706, 0.345 },
    { 0.804, 0.392, 0.392 }, { 0.706, 0.345, 0.345 },
    { 0.392, 0.741, 0.804 }, { 0.345, 0.651, 0.706 },
}
local EXCLUDED = { 1.0, 1.0, 0.49 }
local DIRS4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local DIRS8 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

local UI = {}
local LIB = nil
local recent, moveCount, errorCount, flagCount, noDetector = {}, 0, 0, 0, 0
local lastError = nil
local alive = true
local board, fastRes, fullRes, shown = nil, nil, nil, nil
local lastSig = nil
local highlights = {}
local flagged = {}
local failures, blockedUntil = {}, {}
local marksNote = "waiting for the board"
local flagNote = "off"
local nextESP, nextSolve, nextFlag = 0, 0, 0
local colourSig = ""
local lastSolveState = false

local function notify(text, kind)
    if LIB then
        pcall(function()
            LIB:Notify({ Title = "TokaiHub", Content = text, Type = kind, Duration = 2.5 })
        end)
        return
    end
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "TokaiHub", Text = text, Duration = 2.5 })
    end)
end

local function noteMove(i, ok)
    if ok then
        moveCount = moveCount + 1
    end
    table.insert(recent, 1, { tile = i, ok = ok })
    while #recent > 8 do
        table.remove(recent)
    end
end

local function rootPart()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function colourIs(c, rgb)
    return math.abs(c.R - rgb[1]) < 0.05 and math.abs(c.G - rgb[2]) < 0.05 and math.abs(c.B - rgb[3]) < 0.05
end

local function unopenedColour(part)
    if colourIs(part.Color, EXCLUDED) then
        return false
    end
    for _, rgb in ipairs(UNOPENED) do
        if colourIs(part.Color, rgb) then
            return true
        end
    end
    return false
end

local function numberOnTile(part)
    for _, d in ipairs(part:GetDescendants()) do
        if d:IsA("TextLabel") and d.Visible then
            local digits = string.match(d.Text, "%d+")
            local n = digits and tonumber(digits)
            if n and n >= 1 and n <= 8 then
                return n
            end
        end
    end
    return nil
end

local function classifyFlagTile(part)
    local gui = part:FindFirstChild("NumberGui")
    if not gui then
        return "unopened"
    end
    local label = gui:FindFirstChild("TextLabel")
    local text = label and label.Text or ""
    if text == "" then
        return "number", 0
    end
    if text == "X" then
        return "mine"
    end
    local n = tonumber(text)
    if n then
        return "number", n
    end
    return nil
end

local function classifyColourTile(part)
    if part.Name ~= "Part" then
        return nil
    end
    if unopenedColour(part) then
        return "unopened"
    end
    local n = numberOnTile(part)
    if n then
        return "number", n
    end
    return nil
end

local candidates = { list = {}, at = -math.huge }
local function colourCandidates()
    local age = TIME.now() - candidates.at
    if age > 2 or (age > 0.5 and #candidates.list == 0) then
        candidates.at = TIME.now()
        local list = {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and d.Name == "Part" then
                list[#list + 1] = d
            end
        end
        candidates.list = list
    end
    return candidates.list
end

local function buildBoard(entries)
    local size = entries[1].part.Size.X
    if not size or size <= 0 then
        return nil, "tile size unknown"
    end
    local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
    for _, e in ipairs(entries) do
        local p = e.part.Position
        minX = math.min(minX, p.X)
        maxX = math.max(maxX, p.X)
        minZ = math.min(minZ, p.Z)
        maxZ = math.max(maxZ, p.Z)
    end
    local W = math.floor((maxX - minX) / size + 0.5) + 1
    local H = math.floor((maxZ - minZ) / size + 0.5) + 1
    local b = {
        W = W, H = H, size = size, minX = minX, minZ = minZ,
        exists = {}, open = {}, value = {}, flag = {}, tileOf = {}, walk = {},
        hidden = 0, numbers = 0, flags = 0,
    }
    local sig = {}
    for _, e in ipairs(entries) do
        local p = e.part.Position
        local col = math.floor((p.X - minX) / size + 0.5) + 1
        local row = math.floor((p.Z - minZ) / size + 0.5) + 1
        local i = (row - 1) * W + col
        if b.exists[i] then
            return nil, "two tiles share one spot"
        end
        b.exists[i] = true
        b.tileOf[i] = e.part
        if e.state == "number" then
            b.open[i] = true
            b.value[i] = e.value
            b.walk[i] = true
            b.numbers = b.numbers + 1
        elseif e.state == "mine" then
            b.flag[i] = true
            b.flags = b.flags + 1
        else
            b.hidden = b.hidden + 1
        end
        sig[#sig + 1] = i .. ":" .. e.state .. ":" .. tostring(e.value or "")
    end
    table.sort(sig)
    b.sig = W .. "x" .. H .. "|" .. table.concat(sig, ";")
    return b
end

local function readBoard()
    local flagFolder = workspace:FindFirstChild("Flag")
    local parts = flagFolder and flagFolder:FindFirstChild("Parts")
    local entries, kind = {}, nil
    if parts then
        kind = "flag"
        for _, part in ipairs(parts:GetChildren()) do
            local state, value = classifyFlagTile(part)
            if state then
                entries[#entries + 1] = { part = part, state = state, value = value }
            end
        end
    else
        kind = "colour"
        for _, part in ipairs(colourCandidates()) do
            if part.Parent then
                local state, value = classifyColourTile(part)
                if state then
                    entries[#entries + 1] = { part = part, state = state, value = value }
                end
            end
        end
    end
    if #entries == 0 then
        return nil, "no tiles found (" .. kind .. " layout)"
    end
    local b, err = buildBoard(entries)
    if not b then
        return nil, err
    end
    b.kind = kind
    b.info = string.format("%dx%d | %d hidden | %d numbers | %d flags | %s layout", b.W, b.H, b.hidden, b.numbers, b.flags, kind)
    return b, nil
end

local function currentRound()
    local info = ReplicatedStorage:FindFirstChild("Info")
    local running = info and info:FindFirstChild("GameRunning")
    return not (running and running.Value == false)
end

local function totalMines()
    local info = ReplicatedStorage:FindFirstChild("Info")
    local mines = info and info:FindFirstChild("Mines")
    return mines and mines.Value or nil
end

local function tileOpen(part, kind)
    if not part.Parent then
        return true
    end
    if kind == "flag" then
        return part:FindFirstChild("NumberGui") ~= nil
    end
    return not unopenedColour(part)
end

local function noteFailure(i)
    failures[i] = (failures[i] or 0) + 1
    if failures[i] >= 2 then
        blockedUntil[i] = TIME.now() + CONFIG.BlockSeconds
        failures[i] = 0
    end
end

local function blocked(i)
    return blockedUntil[i] ~= nil and TIME.now() < blockedUntil[i]
end

local function standAbove(tile)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not tile or not tile.Parent then
        return false
    end
    local p = tile.Position
    root.CFrame = CFrame.new(p.X, p.Y + tile.Size.Y / 2 + 3, p.Z)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    return true
end

local function waitOpen(b, i)
    local tile = b.tileOf[i]
    if not tile then
        return false
    end
    local t0 = TIME.now()
    repeat
        if tileOpen(tile, b.kind) then
            return true
        end
        task.wait(CONFIG.HopPoll)
    until TIME.now() - t0 > CONFIG.HopTimeout
    return false
end

local function hop(b, i)
    local tile = b.tileOf[i]
    if not tile or not standAbove(tile) then
        noteFailure(i)
        noteMove(i, false)
        return false
    end
    task.wait(CONFIG.HopWait)
    if waitOpen(b, i) then
        failures[i] = nil
        noteMove(i, true)
        return true
    end
    noteFailure(i)
    noteMove(i, false)
    return false
end

local function playerCell(b)
    local root = rootPart()
    if not root then
        return nil
    end
    local p = root.Position
    local col = math.floor((p.X - b.minX) / b.size + 0.5) + 1
    local row = math.floor((p.Z - b.minZ) / b.size + 0.5) + 1
    if col < 1 or col > b.W or row < 1 or row > b.H then
        return nil
    end
    return (row - 1) * b.W + col
end

local function findPath(b, from, to)
    if not from or not to then
        return nil
    end
    if from == to then
        return {}
    end
    local parent, seen = {}, { [from] = true }
    local queue, head = { from }, 1
    while head <= #queue do
        local cur = queue[head]
        head = head + 1
        if cur == to then
            break
        end
        local col = (cur - 1) % b.W + 1
        local row = math.floor((cur - 1) / b.W) + 1
        for _, d in ipairs(DIRS4) do
            local nc, nr = col + d[1], row + d[2]
            if nc >= 1 and nc <= b.W and nr >= 1 and nr <= b.H then
                local j = (nr - 1) * b.W + nc
                if not seen[j] and (b.walk[j] or j == to) then
                    seen[j] = true
                    parent[j] = cur
                    queue[#queue + 1] = j
                end
            end
        end
    end
    if not seen[to] then
        return nil
    end
    local path, cur = {}, to
    while cur ~= from do
        table.insert(path, 1, cur)
        cur = parent[cur]
    end
    return path
end

local function walkTo(b, i)
    local from = playerCell(b)
    local path = from and findPath(b, from, i)
    if not path or #path == 0 or #path > CONFIG.MaxWalkTiles then
        return false
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then
        return false
    end
    hum.WalkSpeed = CONFIG.WalkSpeed
    for _, j in ipairs(path) do
        local tile = b.tileOf[j]
        if not tile or not tile.Parent then
            return false
        end
        local target = Vector3.new(tile.Position.X, root.Position.Y, tile.Position.Z)
        hum:MoveTo(target)
        local t0 = TIME.now()
        while (root.Position - target).Magnitude > 1.5 do
            task.wait(0.05)
            if TIME.now() - t0 > CONFIG.WalkWaypointTimeout then
                hum.Jump = true
                return false
            end
        end
    end
    return true
end

local function goTo(b, i)
    if CONFIG.Movement == "walk" and walkTo(b, i) then
        if waitOpen(b, i) then
            failures[i] = nil
            noteMove(i, true)
            return true
        end
        noteFailure(i)
        noteMove(i, false)
        return false
    end
    return hop(b, i)
end

local function hopBatch(b, list)
    local visited, moved = 0, 0
    for _, i in ipairs(list) do
        if visited >= CONFIG.HopBatch then
            break
        end
        if not blocked(i) then
            if hop(b, i) then
                moved = moved + 1
            end
            visited = visited + 1
        end
    end
    return moved
end

local function act(b, r)
    local ready = {}
    for _, i in ipairs(r.safe) do
        local tile = b.tileOf[i]
        if tile and tile.Parent and not blocked(i) then
            ready[#ready + 1] = i
        end
    end
    if #ready > 0 then
        if CONFIG.Movement == "walk" then
            return goTo(b, ready[1]) and 1 or 0
        end
        return hopBatch(b, ready)
    end
    local g = r.guess
    if g and (r.guessP or 1) <= CONFIG.MaxGuessRisk and not blocked(g) and b.tileOf[g] and b.tileOf[g].Parent then
        return goTo(b, g) and 1 or 0
    end
    return 0
end

local function heatColour(p)
    local lo, hi = COLOURS.lowRisk, COLOURS.highRisk
    return Color3.fromRGB((lo.R + (hi.R - lo.R) * p) * 255, (lo.G + (hi.G - lo.G) * p) * 255, (lo.B + (hi.B - lo.B) * p) * 255)
end

local function touchesNumber(b, i)
    local col = (i - 1) % b.W + 1
    local row = math.floor((i - 1) / b.W) + 1
    for _, d in ipairs(DIRS8) do
        local nc, nr = col + d[1], row + d[2]
        if nc >= 1 and nc <= b.W and nr >= 1 and nr <= b.H then
            local j = (nr - 1) * b.W + nc
            if b.open[j] and (b.value[j] or 0) > 0 then
                return true
            end
        end
    end
    return false
end

local function paint(tile, colour, transparency, key)
    local rec = highlights[tile]
    if colour == nil then
        if rec then
            pcall(function()
                rec.inst:Destroy()
            end)
            highlights[tile] = nil
        end
        return
    end
    if not rec then
        local inst = Instance.new("Highlight")
        inst.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        inst.Adornee = tile
        inst.Parent = tile
        rec = { inst = inst, key = nil }
        highlights[tile] = rec
    end
    if rec.key ~= key then
        rec.key = key
        rec.inst.FillColor = colour
        rec.inst.OutlineColor = colour
        rec.inst.FillTransparency = transparency
        rec.inst.OutlineTransparency = 0.2
    end
end

local function clearMarks()
    for tile in pairs(highlights) do
        paint(tile, nil)
    end
end

local function refreshMarks(b, r)
    local want = {}
    local root = rootPart()
    local transparency = 1 - CONFIG.Opacity
    local function allowed(tile)
        if CONFIG.ShowDistance <= 0 or not root then
            return true
        end
        return (tile.Position - root.Position).Magnitude <= CONFIG.ShowDistance
    end
    local function put(i, kind, colour)
        local tile = b.tileOf[i]
        if tile and tile.Parent and allowed(tile) then
            want[tile] = { kind = kind, colour = colour }
        end
    end
    if CONFIG.ShowMarks then
        if CONFIG.ShowHeat and r.probs then
            for i, p in pairs(r.probs) do
                if p > 0 and p < 1 and b.exists[i] and not b.open[i] and not b.flag[i] and touchesNumber(b, i) then
                    put(i, "risk", heatColour(p))
                end
            end
        end
        if CONFIG.ShowGuess and r.guess and b.exists[r.guess] and not b.open[r.guess] then
            put(r.guess, "guess", COLOURS.guess)
        end
        for _, i in ipairs(r.safe) do
            put(i, "safe", COLOURS.safe)
        end
        for _, i in ipairs(r.mines) do
            put(i, "mine", COLOURS.mine)
        end
    end
    local counts = { safe = 0, mine = 0, guess = 0, risk = 0 }
    for _, m in pairs(want) do
        counts[m.kind] = counts[m.kind] + 1
    end
    for tile in pairs(highlights) do
        if want[tile] == nil then
            paint(tile, nil)
        end
    end
    for tile, m in pairs(want) do
        local c = m.colour
        local key = string.format("%.3f,%.3f,%.3f,%.3f", c.R, c.G, c.B, transparency)
        paint(tile, c, transparency, key)
    end
    local total = counts.safe + counts.mine + counts.guess + counts.risk
    if not CONFIG.ShowMarks then
        marksNote = "marks off"
    elseif b.numbers == 0 and counts.guess > 0 then
        marksNote = "no numbers yet: the yellow tile is the first guess"
    elseif b.numbers == 0 then
        marksNote = "no numbers yet: open one tile first"
    elseif total == 0 then
        marksNote = "numbers read, nothing to mark"
    else
        marksNote = string.format("%d safe, %d mine, %d guess, %d risk", counts.safe, counts.mine, counts.guess, counts.risk)
    end
end

local function flagNext(b, r)
    if not CONFIG.AutoFlag then
        flagNote = "off"
        return false
    end
    if type(fireclickdetector) ~= "function" then
        flagNote = "fireclickdetector is not available in this executor"
        return false
    end
    local root = rootPart()
    if not root then
        flagNote = "no character"
        return false
    end
    local best, bestD = nil, math.huge
    for _, i in ipairs(r.mines) do
        local tile = b.tileOf[i]
        if tile and tile.Parent and not flagged[tile] then
            local d = (tile.Position - root.Position).Magnitude
            if d <= CONFIG.FlagRange and d < bestD then
                best, bestD = tile, d
            end
        end
    end
    if not best then
        if #r.mines == 0 then
            flagNote = "no certain mines yet"
        else
            flagNote = "certain mines are out of range or already flagged"
        end
        return false
    end
    flagged[best] = true
    local cd = best:FindFirstChildWhichIsA("ClickDetector", true)
    if not cd then
        noDetector = noDetector + 1
        flagNote = "no ClickDetector on the tile (" .. noDetector .. " so far)"
        return false
    end
    fireclickdetector(cd)
    flagCount = flagCount + 1
    flagNote = "flagging"
    return true
end

local function reportError(r)
    if r and r.error and r.error ~= lastError then
        lastError = r.error
        errorCount = errorCount + 1
        notify("numbers do not fit: " .. r.error, "Error")
    end
end

local function solveBoard(b, mode)
    local st = { open = b.open, value = b.value, flag = b.flag, exists = b.exists }
    local total = totalMines()
    local r = Core.solve(b.W, b.H, st, { totalMines = total, mode = mode })
    if r.error and total then
        local r2 = Core.solve(b.W, b.H, st, { mode = mode })
        if not r2.error then
            r2.totalIgnored = true
            return r2
        end
    end
    return r
end

local function modeName()
    if CONFIG.Solve then
        return "rage"
    end
    if CONFIG.ShowMarks then
        return "legit"
    end
    return "off"
end

local function status()
    local safe = shown and #shown.safe or 0
    local mines = shown and #shown.mines or 0
    local ms = (shown and shown.stats and shown.stats.seconds or 0) * 1000
    return string.format("mode %s | move %s | safe %d | mines %d | solve %.1f ms", modeName(), CONFIG.Movement, safe, mines, ms)
end

local function setMode(m)
    if UI.solve and type(UI.solve.Set) == "function" then
        pcall(function()
            UI.solve:Set(m == "rage", true)
        end)
    end
    if UI.showMarks and type(UI.showMarks.Set) == "function" then
        pcall(function()
            UI.showMarks:Set(m ~= "off", true)
        end)
    end
    CONFIG.Solve = m == "rage"
    CONFIG.ShowMarks = m ~= "off"
    lastSolveState = CONFIG.Solve
    nextESP, nextSolve, nextFlag = 0, 0, 0
    if m == "off" then
        clearMarks()
        lastSig, fastRes, fullRes, shown = nil, nil, nil, nil
        marksNote = "marks off"
    end
end

local function syncUI()
    if not UI.ready then
        return
    end
    local solve = UI.solve:Get() == true
    if solve ~= lastSolveState then
        lastSolveState = solve
        nextSolve = 0
        notify(solve and "auto solve on" or "auto solve off", solve and "Success" or "Warning")
    end
    CONFIG.Solve = solve
    CONFIG.ShowMarks = UI.showMarks:Get() == true
    CONFIG.ShowHeat = UI.showHeat:Get() == true
    CONFIG.ShowGuess = UI.showGuess:Get() == true
    CONFIG.AutoFlag = UI.autoFlag:Get() == true
    CONFIG.FlagDelay = UI.flagDelay:Get()
    CONFIG.FlagRange = UI.flagRange:Get()
    CONFIG.ESPInterval = UI.espScan:Get() / 1000
    CONFIG.SolverInterval = UI.solverScan:Get() / 1000
    CONFIG.MaxGuessRisk = UI.guessRisk:Get() / 100
    CONFIG.ShowDistance = UI.showDistance:Get()
    CONFIG.Opacity = UI.opacity:Get() / 100
    local teleport = UI.movement:Get() ~= "Walk"
    CONFIG.Movement = teleport and "hop" or "walk"
    CONFIG.HopWait = UI.tpSpeed:Get() / 1000
    CONFIG.HopBatch = math.floor(UI.tpBatch:Get())
    CONFIG.HopTimeout = UI.tpTimeout:Get() / 1000
    CONFIG.WalkSpeed = UI.walkSpeed:Get()
    CONFIG.MaxWalkTiles = math.floor(UI.maxWalk:Get())
    CONFIG.WalkWaypointTimeout = UI.walkTimeout:Get() / 1000
    local cs = { UI.colSafe:Get(), UI.colMine:Get(), UI.colGuess:Get(), UI.colLow:Get(), UI.colHigh:Get() }
    COLOURS.safe, COLOURS.mine, COLOURS.guess = cs[1], cs[2], cs[3]
    COLOURS.lowRisk, COLOURS.highRisk = cs[4], cs[5]
    local parts = {}
    for _, c in ipairs(cs) do
        parts[#parts + 1] = string.format("%.3f,%.3f,%.3f", c.R, c.G, c.B)
    end
    local sig = table.concat(parts, ";")
    if sig ~= colourSig then
        colourSig = sig
        clearMarks()
    end
    UI.tpSpeed:SetVisible(teleport)
    UI.tpBatch:SetVisible(teleport)
    UI.tpTimeout:SetVisible(teleport)
    UI.walkSpeed:SetVisible(not teleport)
    UI.maxWalk:SetVisible(not teleport)
    UI.walkTimeout:SetVisible(not teleport)
end

local function tickOnce(force)
    syncUI()
    if not CONFIG.ShowMarks then
        clearMarks()
    end
    local now = TIME.now()
    local wantSolve = CONFIG.Solve
    local wantMarks = CONFIG.ShowMarks
    local wantFlag = CONFIG.AutoFlag
    if not (wantSolve or wantMarks or wantFlag) then
        lastSig, fastRes, fullRes, shown, board = nil, nil, nil, nil, nil
        marksNote = "marks off"
        flagNote = "off"
        return
    end
    local doMarks = wantMarks and (force or now >= nextESP)
    local doSolve = wantSolve and (force or now >= nextSolve)
    local doFlag = wantFlag and (force or now >= nextFlag)
    if not (doMarks or doSolve or doFlag) then
        return
    end
    local b, err = readBoard()
    if not b then
        clearMarks()
        lastSig, fastRes, fullRes, shown, board = nil, nil, nil, nil, nil
        marksNote = err or "no tiles found"
        if err and not string.find(err, "no tiles", 1, true) and err ~= lastError then
            lastError = err
            errorCount = errorCount + 1
            notify("board unreadable: " .. err, "Warning")
        end
        nextESP = now + CONFIG.ESPInterval
        nextSolve = now + CONFIG.SolverInterval
        nextFlag = now + CONFIG.FlagDelay
        return
    end
    board = b
    if b.numbers == 0 then
        flagged = {}
    end
    if b.sig ~= lastSig then
        lastSig = b.sig
        fastRes = solveBoard(b, "basic")
        fullRes = nil
        reportError(fastRes)
    end
    if not fastRes or fastRes.error then
        clearMarks()
        shown = nil
        marksNote = fastRes and ("solver error: " .. fastRes.error) or "no result"
        nextESP = now + CONFIG.ESPInterval
        nextSolve = now + CONFIG.SolverInterval
        nextFlag = now + CONFIG.FlagDelay
        return
    end
    shown = fullRes or fastRes
    if doMarks then
        refreshMarks(b, shown)
        nextESP = now + CONFIG.ESPInterval
    end
    if doFlag then
        flagNext(b, fastRes)
        nextFlag = now + CONFIG.FlagDelay
    end
    local moved = 0
    if doSolve then
        if currentRound() then
            moved = act(b, fastRes)
        end
        nextSolve = now + ((moved > 0) and 0 or CONFIG.SolverInterval)
    end
    local wantFull = (doMarks and (CONFIG.ShowHeat or CONFIG.ShowGuess)) or (doSolve and currentRound())
    if wantFull and moved == 0 then
        if not fullRes then
            task.wait()
            fullRes = solveBoard(b, "full")
            reportError(fullRes)
            if fullRes.error then
                fullRes = nil
            end
        end
        if fullRes then
            shown = fullRes
            if doMarks then
                refreshMarks(b, fullRes)
            end
            if doSolve and currentRound() then
                act(b, fullRes)
            end
        end
    end
end

local function stop()
    alive = false
    CONFIG.Solve = false
    CONFIG.AutoFlag = false
    clearMarks()
    lastSig, fastRes, fullRes, shown, board = nil, nil, nil, nil, nil
    marksNote = "stopped"
end

task.spawn(function()
    while alive do
        local ok, err = pcall(tickOnce, false)
        if not ok then
            local text = tostring(err)
            if text ~= lastError then
                lastError = text
                errorCount = errorCount + 1
                warn("[TokaiHub] " .. text)
            end
        end
        task.wait(CONFIG.Tick)
    end
end)

genv.MS2_STOP = stop
genv.MS2 = {
    config = CONFIG,
    setMode = setMode,
    step = function()
        tickOnce(true)
    end,
    tick = function()
        tickOnce(false)
    end,
    stop = stop,
    status = status,
    note = function()
        return marksNote
    end,
    flagNote = function()
        return flagNote
    end,
}
notify("TokaiHub ready: Auto solve is in the Solver tab")
local LIB_PATH = "HawkTokaiLib/Source.luau"
local LIB_URL = "https://raw.githubusercontent.com/longtokaiikari-source/HawkTokaiLib/refs/heads/main/Source.luau"

local function loadLibrary()
    local okRead, src = pcall(readfile, LIB_PATH)
    if okRead and type(src) == "string" and #src > 0 then
        local okRun, lib = pcall(function()
            return loadstring(src)()
        end)
        if okRun and type(lib) == "table" then
            return lib, "local copy"
        end
    end
    local okGet, body = pcall(function()
        return game:HttpGet(LIB_URL)
    end)
    if okGet and type(body) == "string" and #body > 0 then
        local okRun, lib = pcall(function()
            return loadstring(body)()
        end)
        if okRun and type(lib) == "table" then
            return lib, "repo"
        end
    end
    return nil, nil
end

local function buildUI(lib)
    local Window = lib:CreateWindow({
        Name = "TokaiHub",
        LoadingSubtitle = "Minesweeper",
        ToggleUIKeybind = "RightControl",
        ConfigurationSaving = { Enabled = true, FolderName = "TokaiHub/Minesweeper" },
        ToggleButton = { Platform = "Both", Icon = "crosshair" },
        Backdrop = { Weather = "None", Tint = 0.45 },
        Home = { Title = "TokaiHub", Welcome = "Minesweeper, ready when you are," },
    })
    Window:SetWatermark({ Text = "TokaiHub", FPS = true, Ping = true })
    UI.window = Window
    Window:OnUnload(function()
        stop()
    end)

    local Solver = Window:CreateTab({ Name = "Solver", Icon = "crosshair" })
    local Solve = Solver:CreateSubTab({ Name = "Solve" })
    local Auto = Solve:AddLeftGroupbox({ Name = "Auto solve", Icon = "zap" })
    UI.solve = Auto:CreateToggle({
        Name = "Auto solve",
        Desc = "moves onto certain safe tiles, then the best guess",
        CurrentValue = false,
    })
    UI.solverScan = Auto:CreateSlider({
        Name = "Solver scan speed",
        Desc = "how often the solver reads the board and acts",
        Range = { 0, 400 },
        Increment = 10,
        Suffix = " ms",
        CurrentValue = 30,
        Flag = "MS2_SolverScan",
    })
    local Guessing = Solve:AddRightGroupbox({ Name = "Guessing", Icon = "crosshair" })
    UI.guessRisk = Guessing:CreateSlider({
        Name = "Max guess risk",
        Desc = "a guess is only taken at or below this mine chance",
        Range = { 0, 100 },
        Increment = 5,
        Suffix = "%",
        CurrentValue = 100,
        Flag = "MS2_GuessRisk",
    })

    local Movement = Solver:CreateSubTab({ Name = "Movement" })
    local Route = Movement:AddLeftGroupbox({ Name = "Move by", Icon = "sliders-horizontal" })
    UI.movement = Route:CreateDropdown({
        Name = "Move by",
        Options = { "Teleport (TP)", "Walk" },
        CurrentOption = "Teleport (TP)",
        AllowNone = false,
        Flag = "MS2_MoveBy",
    })
    local TP = Movement:AddLeftGroupbox({ Name = "Teleport speed", Icon = "zap" })
    UI.tpSpeed = TP:CreateSlider({
        Name = "TP speed",
        Desc = "wait after landing before the tile is checked",
        Range = { 0, 300 },
        Increment = 5,
        Suffix = " ms",
        CurrentValue = 10,
        Flag = "MS2_TPSpeed",
    })
    UI.tpBatch = TP:CreateSlider({
        Name = "Tiles per scan",
        Range = { 1, 16 },
        Increment = 1,
        Suffix = " tiles",
        CurrentValue = 8,
        Flag = "MS2_HopBatch",
    })
    UI.tpTimeout = TP:CreateSlider({
        Name = "Give up after",
        Range = { 50, 1000 },
        Increment = 10,
        Suffix = " ms",
        CurrentValue = 300,
        Flag = "MS2_TPTimeout",
    })
    local Walking = Movement:AddRightGroupbox({ Name = "Walking", Icon = "repeat" })
    UI.walkSpeed = Walking:CreateSlider({
        Name = "Walk speed",
        Range = { 16, 60 },
        Increment = 2,
        CurrentValue = 28,
        Flag = "MS2_WalkSpeed",
    })
    UI.maxWalk = Walking:CreateSlider({
        Name = "Longest walk",
        Range = { 1, 30 },
        Increment = 1,
        Suffix = " tiles",
        CurrentValue = 12,
        Flag = "MS2_MaxWalk",
    })
    UI.walkTimeout = Walking:CreateSlider({
        Name = "Waypoint timeout",
        Range = { 300, 5000 },
        Increment = 100,
        Suffix = " ms",
        CurrentValue = 1500,
        Flag = "MS2_WalkTimeout",
    })

    local Flags = Window:CreateTab({ Name = "Flags", Icon = "flag" })
    local Auto2 = Flags:AddLeftGroupbox({ Name = "Auto flag", Icon = "flag" })
    UI.autoFlag = Auto2:CreateToggle({
        Name = "Auto flag mines",
        Desc = "clicks certain mines, works without auto solve",
        CurrentValue = false,
    })
    UI.flagDelay = Auto2:CreateSlider({
        Name = "Flag delay",
        Desc = "seconds between two flags",
        Range = { 0.05, 10 },
        Increment = 0.05,
        Suffix = " s",
        CurrentValue = 0.05,
        Flag = "MS2_FlagDelay",
    })
    local Reach = Flags:AddRightGroupbox({ Name = "Reach", Icon = "crosshair" })
    UI.flagRange = Reach:CreateSlider({
        Name = "Flag range",
        Desc = "studs from your character",
        Range = { 1, 30 },
        Increment = 1,
        Suffix = " studs",
        CurrentValue = 30,
        Flag = "MS2_FlagStuds",
    })

    local ESP = Window:CreateTab({ Name = "ESP", Icon = "eye" })
    local Marks = ESP:CreateSubTab({ Name = "Marks" })
    local Show = Marks:AddLeftGroupbox({ Name = "Show", Icon = "layout-grid" })
    UI.showMarks = Show:CreateToggle({
        Name = "Show marks",
        Desc = "runs on its own, no mode to pick",
        CurrentValue = true,
    })
    UI.showHeat = Show:CreateToggle({
        Name = "Risk heat",
        Desc = "colours unknown tiles next to numbers by mine chance",
        CurrentValue = true,
    })
    UI.showGuess = Show:CreateToggle({
        Name = "Best guess",
        Desc = "marks the tile the solver would guess",
        CurrentValue = true,
    })
    UI.espScan = Show:CreateSlider({
        Name = "ESP scan speed",
        Range = { 30, 1000 },
        Increment = 10,
        Suffix = " ms",
        CurrentValue = 30,
        Flag = "MS2_ESPScan",
    })
    local Look = Marks:AddRightGroupbox({ Name = "Distance and opacity", Icon = "sliders-horizontal" })
    UI.showDistance = Look:CreateSlider({
        Name = "Show distance",
        Desc = "only tiles this close to you; 0 = no limit",
        Range = { 0, 500 },
        Increment = 5,
        Suffix = " studs",
        CurrentValue = 0,
        Flag = "MS2_ShowDistance",
    })
    UI.opacity = Look:CreateSlider({
        Name = "Opacity",
        Range = { 0, 100 },
        Increment = 5,
        Suffix = "%",
        CurrentValue = 60,
        Flag = "MS2_Opacity",
    })
    local Colours = ESP:CreateSubTab({ Name = "Colours" })
    local Certain = Colours:AddLeftGroupbox({ Name = "Certain tiles", Icon = "monitor" })
    UI.colSafe = Certain:CreateColorPicker({ Name = "Safe tile", Color = COLOURS.safe, Flag = "MS2_ColSafe" })
    UI.colMine = Certain:CreateColorPicker({ Name = "Mine tile", Color = COLOURS.mine, Flag = "MS2_ColMine" })
    UI.colGuess = Certain:CreateColorPicker({ Name = "Best guess", Color = COLOURS.guess, Flag = "MS2_ColGuess" })
    local Heat = Colours:AddRightGroupbox({ Name = "Risk heat", Icon = "monitor" })
    UI.colLow = Heat:CreateColorPicker({ Name = "Low risk", Color = COLOURS.lowRisk, Flag = "MS2_ColLow" })
    UI.colHigh = Heat:CreateColorPicker({ Name = "High risk", Color = COLOURS.highRisk, Flag = "MS2_ColHigh" })

    local Status = Window:CreateTab({ Name = "Status", Icon = "activity" })
    local Session = Status:AddLeftGroupbox({ Name = "Solver", Icon = "timer" })
    Session:CreateStatus({
        Name = "Auto solve",
        Pin = true,
        UpdateRate = 0.25,
        Update = function()
            if CONFIG.Solve then
                return "on", "Success"
            end
            return "off", "Warning"
        end,
    })
    Session:CreateStatus({
        Name = "Board",
        Style = "Row",
        UpdateRate = 0.5,
        Update = function()
            if not board then
                return "none", "Warning"
            end
            return board.info, "Accent"
        end,
    })
    Session:CreateStatus({
        Name = "Marks",
        Style = "Row",
        UpdateRate = 0.5,
        Update = function()
            return marksNote
        end,
    })
    Session:CreateStatus({
        Name = "Safe tiles",
        Style = "Stat",
        Pin = true,
        UpdateRate = 0.25,
        Update = function()
            return shown and #shown.safe or 0
        end,
    })
    Session:CreateStatus({
        Name = "Mines",
        Style = "Stat",
        UpdateRate = 0.25,
        Update = function()
            return shown and #shown.mines or 0
        end,
    })
    Session:CreateStatus({
        Name = "Solve time",
        Style = "Row",
        UpdateRate = 0.5,
        Update = function()
            local ms = shown and shown.stats and shown.stats.seconds * 1000 or 0
            return string.format("%.1f ms", ms)
        end,
    })
    local Health = Status:AddRightGroupbox({ Name = "Health", Icon = "heart-pulse" })
    Health:CreateStatus({
        Name = "Round",
        Style = "Dot",
        UpdateRate = 0.5,
        Update = function()
            if currentRound() then
                return "Running", "Success"
            end
            return "Waiting", "Warning"
        end,
    })
    Health:CreateStatus({
        Name = "Movement",
        Style = "Row",
        UpdateRate = 0.5,
        Update = function()
            return CONFIG.Movement == "walk" and "walk" or "teleport"
        end,
    })
    Health:CreateStatus({
        Name = "Flag state",
        Style = "Row",
        UpdateRate = 0.5,
        Update = function()
            return flagNote
        end,
    })
    Health:CreateStatus({
        Name = "Flags sent",
        Style = "Row",
        UpdateRate = 0.5,
        Update = function()
            return flagCount
        end,
    })
    Health:CreateStatus({
        Name = "Errors",
        Style = "Row",
        UpdateRate = 0.5,
        Update = function()
            return errorCount, errorCount > 0 and "Error" or "Success"
        end,
    })
    Health:CreateStatus({
        Name = "Last error",
        Style = "Row",
        UpdateRate = 0.5,
        Update = function()
            return lastError or "none"
        end,
    })
    Health:CreateStatus({
        Name = "Exact",
        Style = "Badge",
        UpdateRate = 0.5,
        Update = function()
            if not shown or not shown.stats then
                return "none", "Warning"
            end
            if shown.stats.exact then
                return "Exact", "Success"
            end
            return "Estimated", "Warning"
        end,
    })
    local Jobs = Status:AddLeftGroupbox({ Name = "Recent tiles", Icon = "list-checks" })
    Jobs:CreateStatusList({
        Name = "Moves",
        MaxRows = 6,
        EmptyText = "No moves yet",
        UpdateRate = 0.5,
        Update = function()
            local rows = {}
            for n, entry in ipairs(recent) do
                rows[n] = {
                    Text = "tile " .. entry.tile,
                    Value = entry.ok and "opened" or "missed",
                    Tone = entry.ok and "Success" or "Warning",
                }
            end
            return rows
        end,
    })

    local Settings = Window:CreateTab({ Name = "Settings", Icon = "settings" })
    local Interface = Settings:AddLeftGroupbox({ Name = "Interface", Icon = "monitor" })
    Interface:CreateKeybind({
        Name = "Toggle UI",
        CurrentKeybind = "RightControl",
        OnChanged = function(key)
            Window:SetKeybind(key)
        end,
    })
    Interface:CreateButton({
        Name = "Unload",
        Icon = "power",
        Callback = function()
            lib:Confirm({
                Title = "Unload TokaiHub?",
                Content = "The window closes and the solver stops.",
                Icon = "power",
                ConfirmText = "Unload",
                CancelText = "Keep",
                Callback = function()
                    Window:Destroy()
                end,
            })
        end,
    })
    Settings:CreateConfigManager({ Name = "Configs", Side = "Left" })
    Settings:CreateThemeManager({ Name = "Themes", Side = "Right" })

    pcall(function()
        Window:LoadAutoload()
    end)
    UI.ready = true
end

local LIBRARY, libSource = loadLibrary()
if LIBRARY then
    LIB = LIBRARY
    if libSource ~= "local copy" then
        warn("[TokaiHub] HawkTokaiLib loaded from the repo, not pinned. put Source.luau in HawkTokaiLib/ to pin it")
    end
    local okUI, uiErr = pcall(buildUI, LIBRARY)
    if not okUI then
        warn("[TokaiHub] ui failed: " .. tostring(uiErr))
    end
else
    warn("[TokaiHub] HawkTokaiLib could not be loaded, the solver runs with its defaults")
end

genv.MS2.ui = UI

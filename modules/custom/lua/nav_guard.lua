-----------------------------------
-- nav_guard.lua: shared "stay out of the walls" helper for squad mates (trusts), bots, crowd NPCs and field
-- adventurers. Every placement (setPos, BotPlace, spawn spots) and every scripted move (pathTo) can ask it for a
-- spot that is on the zone's walking map (navmesh), and the brains call watch() so a unit that has ended up inside
-- a wall or off the map is walked back out (and, if that does not work, put back) instead of staying stuck.
--
-- What it uses from the engine: zone:isNavigablePoint({ x, y, z }) (lua_zone.cpp -> NavMesh::validPosition: a
-- navmesh polygon within 0.5 yalms sideways and 1 yalm up or down). A zone with no navmesh answers "yes" for every
-- point (NullNavMesh), so in such a zone nothing here changes anything. If the call is missing or errors, every
-- function falls back to what the caller asked for (the old behaviour): it can never stop the server.
--
-- Loaded with pcall(require, 'modules/custom/lua/nav_guard') by the files that use it (it is not in init.txt).
-- Lines are printed as "[navguard] ..." (recoveries only, and at most one per unit per 30 s).
-----------------------------------
local NG = {}

NG.on          = true  -- false: snap() hands back what it was given, watch() does nothing
NG.watchEvery  = 3     -- seconds between checks of one unit
NG.walkAfter   = 3     -- bad checks in a row before the unit is walked back to its last good spot (about 9 s)
NG.placeAfter  = 6     -- bad checks in a row before it is put there (about 18 s: the walk did not get it out)
NG.repathMin   = 1.5   -- yalms: pathTo() does not restart a path whose goal moved less than this
NG.log         = true

local state = {} -- [entity id] = { at, bad, good = {x,y,z,zone}, goal = {x,y,z}, said }

local function now()
    return os.time()
end

local function zoneOf(ref)
    if ref == nil then
        return nil
    end

    if type(ref) == 'number' then
        local ok, z = pcall(GetZone, ref)
        return ok and z or nil
    end

    -- an entity (has getZone) or a zone object (has isNavigablePoint)
    local ok, z = pcall(function()
        if ref.isNavigablePoint then
            return ref
        end

        return ref:getZone()
    end)
    return ok and z or nil
end

NG.zoneOf = zoneOf

-- true / false, or nil when it cannot be told (no API, an error). The y found is returned with true.
local DY = { 0, 1.5, -1.5 }
local function probe(zone, x, y, z)
    if zone == nil or x == nil or y == nil or z == nil then
        return nil
    end

    local fn = zone.isNavigablePoint
    if fn == nil then
        return nil
    end

    for _, dy in ipairs(DY) do
        local ok, res = pcall(fn, zone, { x = x, y = y + dy, z = z })
        if not ok then
            return nil
        end

        if res then
            return true, y + dy
        end
    end

    return false
end

-- is this spot on the walking map? (nil: unknown)
function NG.valid(zoneRef, x, y, z)
    if not NG.on then
        return nil
    end

    local zone = zoneOf(zoneRef)
    local ok = probe(zone, x, y, z)
    return ok
end

-- on it, or within a yalm of it (for units already standing somewhere: the map stops short of walls)
local NEAR = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local function onOrNear(zone, x, y, z)
    local ok = probe(zone, x, y, z)
    if ok ~= false then
        return ok
    end

    for _, d in ipairs(NEAR) do
        if probe(zone, x + d[1], y, z + d[2]) then
            return true
        end
    end

    return false
end

-- (failure mode 1, crossing a wall) is the straight line a -> b on the walking map the whole way? The map has a gap
-- at every wall, so a sample every 0.75 yalms that falls off it means the line goes through geometry (or off a
-- ledge). true / false, or nil when it cannot be told.
NG.segStep = 0.75
local function segClear(zone, a, b)
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local len = math.sqrt(dx * dx + dz * dz)
    local n = math.floor(len / NG.segStep)
    for i = 1, n do
        local f = i / (n + 1)
        local ok = probe(zone, a.x + dx * f, a.y + dy * f, a.z + dz * f)
        if ok == nil then
            return nil
        end

        if not ok then
            return false
        end
    end

    return true
end

NG.segClear = function(zoneRef, a, b)
    local ok, res = pcall(segClear, zoneOf(zoneRef), a, b)
    if ok then
        return res
    end

    return nil
end

-- (failure mode 3, a different part of the area) the map piece (ximesh floor id) under a spot; 0 / nil = unknown
local function floorOf(zone, x, y, z)
    if zone == nil or zone.getFloorId == nil then
        return nil
    end

    local ok, id = pcall(zone.getFloorId, zone, { x = x, y = y, z = z })
    if ok and type(id) == 'number' and id ~= 0 then
        return id
    end

    return nil
end

-- a spot beside an anchor is only taken when it is walkable, on the same map piece, and the line to it is clear
local function acceptBeside(zone, anchor, x, y, z)
    if anchor == nil then
        return true
    end

    local fa, fc = floorOf(zone, anchor.x, anchor.y, anchor.z), floorOf(zone, x, y, z)
    if fa and fc and fa ~= fc then
        return false
    end

    return segClear(zone, anchor, { x = x, y = y, z = z }) ~= false
end

local function ring(zone, cx, cy, cz, r, towards, anchor)
    local base = towards or 0
    for i = 0, 7 do
        -- (alternating sides from the preferred direction: the closest good spot to it first)
        local k = (i % 2 == 0) and (i / 2) or -((i + 1) / 2)
        local a = base + k * math.pi / 4
        local x, z = cx + r * math.cos(a), cz + r * math.sin(a)
        local ok, gy = probe(zone, x, cy, z)
        if ok and acceptBeside(zone, anchor, x, gy, z) then
            return x, gy, z
        end
    end

    return nil
end

-- A spot on the walking map for a wanted spot `cand` ({x,y,z}), near `anchor` ({x,y,z}: the owner / the unit
-- itself, a spot known to be good). prefer = 'anchor' (default, for placements: pull the spot in towards the anchor
-- first, so it never lands on the far side of a wall) or 'goal' (for moves: look around the goal first).
-- Returns x, y, z and how ('ok', 'unknown', 'moved', 'anchor').
function NG.snap(zoneRef, cand, anchor, prefer)
    if not NG.on or cand == nil then
        return cand and cand.x, cand and cand.y, cand and cand.z, 'unknown'
    end

    local okAll, rx, ry, rz, how = pcall(function()
        local zone = zoneOf(zoneRef)
        -- placements (prefer 'anchor') must also be in a straight, clear line from the anchor on its map piece;
        -- move goals (prefer 'goal') need not be: the path finder walks round corners to them
        local beside = (prefer ~= 'goal') and anchor or nil
        local ok, gy = probe(zone, cand.x, cand.y, cand.z)
        if ok == nil then
            return cand.x, cand.y, cand.z, 'unknown'
        end

        if ok and acceptBeside(zone, beside, cand.x, gy, cand.z) then
            return cand.x, gy, cand.z, 'ok'
        end

        local function towardsAnchor()
            if anchor == nil then
                return nil
            end

            for _, f in ipairs({ 0.75, 0.5, 0.25 }) do
                local x = anchor.x + (cand.x - anchor.x) * f
                local y = anchor.y + (cand.y - anchor.y) * f
                local z = anchor.z + (cand.z - anchor.z) * f
                local good, py = probe(zone, x, y, z)
                if good and acceptBeside(zone, beside, x, py, z) then
                    return x, py, z
                end
            end

            return nil
        end

        local function aroundGoal()
            local dir = anchor and math.atan2(anchor.z - cand.z, anchor.x - cand.x) or 0
            for _, r in ipairs({ 1, 2 }) do
                local x, y, z = ring(zone, cand.x, cand.y, cand.z, r, dir, beside)
                if x then
                    return x, y, z
                end
            end

            return nil
        end

        local first, second = towardsAnchor, aroundGoal
        if prefer == 'goal' then
            first, second = aroundGoal, towardsAnchor
        end

        local x, y, z = first()
        if not x then
            x, y, z = second()
        end

        if x then
            return x, y, z, 'moved'
        end

        if anchor then
            return anchor.x, anchor.y, anchor.z, 'anchor'
        end

        return cand.x, cand.y, cand.z, 'failed' -- (nothing good near it, and nothing to fall back on)
    end)

    if not okAll then
        return cand.x, cand.y, cand.z, 'unknown'
    end

    return rx, ry, rz, how
end

-- the same, from and to plain numbers: x, y, z = NG.spot(zone, x, y, z, anchorPos)
function NG.spot(zoneRef, x, y, z, anchor, prefer)
    local rx, ry, rz = NG.snap(zoneRef, { x = x, y = y, z = z }, anchor, prefer)
    return rx, ry, rz
end

-- setPos with the spot put on the walking map first. zoneId: as setPos's 5th argument (another area), or nil.
-- anchor: the spot it is placed beside ({x,y,z}: the player, the camp, the NPC); nil = look around the spot itself.
function NG.setPos(e, x, y, z, rot, zoneId, anchor)
    local rx, ry, rz = x, y, z
    if NG.on then
        local okS, sx, sy, sz = pcall(NG.spot, zoneId or e, x, y, z, anchor, anchor and 'anchor' or 'goal')
        if okS and sx ~= nil then
            rx, ry, rz = sx, sy, sz
        end
    end

    if zoneId ~= nil then
        return e:setPos(rx, ry, rz, rot or 0, zoneId)
    end

    return e:setPos(rx, ry, rz, rot or 0)
end

local function posOf(e)
    local ok, p = pcall(function()
        return e:getPos()
    end)
    return ok and p or nil
end

local function d2(a, b)
    return (a.x - b.x) ^ 2 + (a.z - b.z) ^ 2
end

-- A scripted move for a mob / NPC / trust: the goal is put on the walking map first, and a path that is already
-- going to (about) the same place is not restarted (restarting every second is what makes them stutter).
-- flags: as entity:pathTo (nil = the engine's default). Returns true when a path was asked for or kept.
function NG.pathTo(e, x, y, z, flags, opts)
    if e == nil or x == nil then
        return false
    end

    local id = e:getID()
    local me = posOf(e)
    local gx, gy, gz = x, y, z
    if NG.on and me then
        gx, gy, gz = NG.spot(e, x, y, z, me, 'goal')
    end

    local st = state[id] or {}
    state[id] = st
    local minMove = (opts and opts.repath) or NG.repathMin
    if st.goal and d2(st.goal, { x = gx, z = gz }) < minMove * minMove then
        local okF, following = pcall(function()
            return e:isFollowingPath()
        end)
        if okF and following then
            return true -- (already on its way there)
        end
    end

    st.goal = { x = gx, y = gy, z = gz }
    local ok = pcall(function()
        if flags ~= nil then
            e:pathTo(gx, gy, gz, flags)
        else
            e:pathTo(gx, gy, gz)
        end
    end)
    return ok
end

local function say(id, text, force)
    local st = state[id]
    if NG.log and st and (force or now() >= (st.said or 0)) then
        st.said = now() + 30
        print('[navguard] ' .. text)
    end
end

-- Called from a unit's own brain tick (any rate: it checks itself every NG.watchEvery seconds).
-- opts.kind   = 'bot' (a bot player: walked with BotMoveTo), 'npc' (a crowd NPC) or nil (mob / trust: pathTo)
-- opts.owner  = who it belongs to / follows (a player, a party leader): the fallback spot
-- opts.follow = true while it is meant to be following the owner (not camping, not fighting, not on an errand)
-- A check is bad when (2) it stands off the walking map (inside a wall, out of bounds), or, with an owner close by,
-- (1) a wall stands between them (it went through one: canSee with the invisible zone walls counted, and no clear
-- line on the map), or, while following, (3) it is far from the owner and has not got any closer for a while
-- (it is on a piece of the map that does not join the owner's: an island, behind a locked area, the wrong floor).
-- After NG.walkAfter bad checks in a row it is walked back (last good spot, or the owner for 1 and 3); after
-- NG.placeAfter it is put there. Returns true when it moved the unit.
NG.nearOwner = 6   -- yalms: closer than this, a wall between unit and owner counts as bad
NG.farOwner  = 25  -- yalms: following and further than this without closing in counts as bad
local function shouldSkip(e, opts)
    if opts and opts.kind == 'npc' then
        return false
    end

    -- (isAlive is only for battle entities: on a crowd NPC it prints an error)
    return not e:isAlive()
end

local function judge(e, st, zone, zoneId, p, opts)
    local ok = onOrNear(zone, p.x, p.y, p.z)
    if ok == nil then
        return nil -- (no navmesh query here: nothing to go by)
    end

    if not ok then
        return 'off the walking map'
    end

    local owner = opts and opts.owner
    if owner == nil then
        return false
    end

    local okO, oz = pcall(function()
        return owner:getZoneID()
    end)
    local op = okO and oz == zoneId and posOf(owner) or nil
    if op == nil then
        st.ownerD = nil
        return false
    end

    local dd = math.sqrt(d2(p, op))
    if dd < NG.nearOwner and dd > 1.5 and math.abs(p.y - op.y) < 4 then
        local okS, sees = pcall(function()
            return e:canSee(owner, false)
        end)
        if okS and sees == false and segClear(zone, op, p) == false then
            return 'behind a wall from its owner'
        end
    end

    if opts.follow and dd > NG.farOwner then
        local last = st.ownerD
        st.ownerD = dd
        if last and dd > last - 1 then
            return 'cut off from its owner'
        end

        return false
    end

    st.ownerD = nil
    return false
end

function NG.watch(e, opts)
    if not NG.on or e == nil then
        return false
    end

    local okAll, moved = pcall(function()
        local id = e:getID()
        local st = state[id]
        if st == nil then
            st = {}
            state[id] = st
        end

        local t = now()
        if t < (st.at or 0) then
            return false
        end

        st.at = t + NG.watchEvery

        if shouldSkip(e, opts) then
            return false
        end

        local zone = e:getZone()
        local zoneId = e:getZoneID()
        local p = posOf(e)
        if zone == nil or p == nil then
            return false
        end

        local why = judge(e, st, zone, zoneId, p, opts)
        if why == nil then
            return false
        end

        if why == false then
            st.good = { x = p.x, y = p.y, z = p.z, zone = zoneId }
            st.bad, st.why = 0, nil
            return false
        end

        st.bad = (st.bad or 0) + 1
        st.why = why
        if st.bad < NG.walkAfter then
            return false
        end

        -- where to: for "off the map", its last good spot in this area; for the other two (and with no good spot,
        -- or a good spot 30+ yalms away) the owner's spot, when that is on the map
        local to = (why == 'off the walking map' and st.good and st.good.zone == zoneId) and st.good or nil
        local owner = opts and opts.owner
        if owner ~= nil then
            local okO, oz = pcall(function()
                return owner:getZoneID()
            end)
            local op = okO and oz == zoneId and posOf(owner) or nil
            if op and (to == nil or d2(to, p) > 30 * 30) and probe(zone, op.x, op.y, op.z) ~= false then
                to = { x = op.x, y = op.y, z = op.z }
            end
        end

        if to == nil then
            return false
        end

        local isBot = opts and opts.kind == 'bot'
        if st.bad < NG.placeAfter then
            if st.bad == NG.walkAfter then
                -- first: walk (the path finder starts from the nearest point of the map, so it steps out of a wall)
                if isBot then
                    pcall(BotMoveTo, id, to.x, to.y, to.z)
                else
                    pcall(function()
                        e:pathTo(to.x, to.y, to.z)
                    end)
                end

                say(id, string.format('%s is %s at (%.1f %.1f %.1f) in zone %d: walking it back', e:getName(), why, p.x, p.y, p.z, zoneId))
                return true
            end

            return false
        end

        -- still stuck: put it there
        if isBot then
            pcall(BotStop, id)
        else
            pcall(function()
                e:clearPath()
            end)
        end

        e:setPos(to.x, to.y, to.z, p.rot or 0)
        st.bad, st.ownerD = 0, nil
        say(id, string.format('%s was %s in zone %d: put back at (%.1f %.1f %.1f)', e:getName(), why, zoneId, to.x, to.y, to.z), true)
        return true
    end)

    return okAll and moved or false
end

-- forget a unit (despawned, logged out); harmless to skip, entries are small
function NG.forget(e)
    pcall(function()
        state[e:getID()] = nil
    end)
end

xi = xi or {}
xi.navguard = NG
return NG

--!strict
-- A meme guardian that sits on its nest. When its egg is stolen it chases the thief; if it catches them the egg goes back,
-- if it loses them (time, distance) it walks home. A pure 2D state machine: the server moves a model to (x, z).
local Guardian = {}

export type State = "Idle" | "Chase" | "Return"
export type Guardian = {
	x: number,
	z: number,
	homeX: number,
	homeZ: number,
	speed: number,
	state: State,
	chaseLeft: number,
	stun: number, -- seconds left held by a trap (it cannot move or catch anyone)
}

function Guardian.new(homeX: number, homeZ: number, speed: number): Guardian
	return { x = homeX, z = homeZ, homeX = homeX, homeZ = homeZ, speed = speed, state = "Idle", chaseLeft = 0, stun = 0 }
end

-- The egg was stolen: start chasing for `seconds`.
function Guardian.alert(g: Guardian, seconds: number)
	g.state = "Chase"
	g.chaseLeft = seconds
end

local function moveToward(g: Guardian, tx: number, tz: number, dt: number): number
	local dx, dz = tx - g.x, tz - g.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 1e-6 then
		return 0
	end
	local step = math.min(g.speed * dt, dist)
	g.x += dx / dist * step
	g.z += dz / dist * step
	return dist - step
end

-- A trap sprang on this guardian: it stands still for `seconds` (a longer stun is not shortened).
function Guardian.stunned(g: Guardian, seconds: number)
	g.stun = math.max(g.stun, seconds)
end

-- Keeps the guardian inside its own terrain (a box in x and z), so a chase can never carry it out into the Safe Zone or the
-- next terrain. Returns true if it had to be pulled back.
function Guardian.confine(g: Guardian, minX: number, maxX: number, minZ: number, maxZ: number): boolean
	local x, z = math.clamp(g.x, minX, maxX), math.clamp(g.z, minZ, maxZ)
	local moved = x ~= g.x or z ~= g.z
	g.x, g.z = x, z
	return moved
end

-- Advances one tick. `target` is the thief's position (nil if they are gone or no longer carrying the egg). Returns true on
-- the tick the guardian catches them.
function Guardian.step(
	g: Guardian,
	dt: number,
	target: { x: number, z: number }?,
	catchRadius: number,
	leash: number
): boolean
	if g.stun > 0 then
		-- held by a trap: the chase clock keeps running, so the thief gets away, but nothing moves
		g.stun = math.max(0, g.stun - dt)
		if g.state == "Chase" then
			g.chaseLeft -= dt
			if g.chaseLeft <= 0 then
				g.state = "Return" -- it gives up while held, and walks home once it is free
			end
		end
		return false
	end
	if g.state == "Chase" then
		g.chaseLeft -= dt
		local fromHome = math.sqrt((g.x - g.homeX) ^ 2 + (g.z - g.homeZ) ^ 2)
		if not target or g.chaseLeft <= 0 or fromHome > leash then
			g.state = "Return"
		else
			local left = moveToward(g, target.x, target.z, dt)
			if left <= catchRadius then
				g.state = "Return"
				return true
			end
		end
	end
	if g.state == "Return" then
		local left = moveToward(g, g.homeX, g.homeZ, dt)
		if left < 0.05 then
			g.x, g.z = g.homeX, g.homeZ
			g.state = "Idle"
		end
	end
	return false
end

return Guardian

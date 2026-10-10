--!strict
-- Slides the tread ridges along every treadmill whose owner is running on it, so the belt visibly moves. The server only
-- publishes one number per treadmill (BeltSpeed, studs per second, 0 when nobody is running); the motion itself costs the
-- server nothing. Ridges are plain anchored parts laid out by World; we move each one back along the belt and wrap it round.
local RunService = game:GetService("RunService")

local Treadmills = {}

type Belt = { belt: BasePart, ridges: { BasePart }, phase: number, scanned: number }

-- Where ridge `slot` of `count` sits (distance from the belt's middle, toward the front) after the belt has moved `phase` studs.
function Treadmills.ridgeOffset(slot: number, count: number, length: number, phase: number): number
	local spacing = length / count
	return ((slot + 0.5) * spacing - phase) % length - length / 2
end

function Treadmills.start()
	local belts: { [Instance]: Belt } = {}
	-- With streaming the ridges can arrive after the belt, so the list is topped up (twice a second) until every ridge the server
	-- built is here. The server says how many there are in the belt's "Ridges" attribute.
	local function scan(plot: Instance, entry: Belt)
		local ridges: { BasePart } = {}
		for _, child in plot:GetChildren() do
			if child.Name == "Ridge" and child:IsA("BasePart") then
				table.insert(ridges, child)
			end
		end
		entry.ridges = ridges
		entry.scanned = os.clock()
	end
	local function find(plot: Instance): Belt?
		local known = belts[plot]
		if known then
			local expected = known.belt:GetAttribute("Ridges")
			if typeof(expected) == "number" and #known.ridges < expected and os.clock() - known.scanned > 0.5 then
				scan(plot, known)
			end
			return known
		end
		local belt = plot:FindFirstChild("Treadmill")
		if not belt or not belt:IsA("BasePart") then
			return nil
		end
		local entry: Belt = { belt = belt, ridges = {}, phase = 0, scanned = 0 }
		scan(plot, entry)
		belts[plot] = entry
		return entry
	end
	RunService.RenderStepped:Connect(function(dt)
		local map = workspace:FindFirstChild("Map")
		if not map then
			return
		end
		for _, plot in map:GetChildren() do
			if string.match(plot.Name, "^Plot_") then
				local entry = find(plot)
				local speed = if entry then entry.belt:GetAttribute("BeltSpeed") else nil
				if entry and typeof(speed) == "number" and speed > 0 and speed < 200 then
					local length = entry.belt.Size.Z
					entry.phase = (entry.phase + speed * dt) % length
					local declared = entry.belt:GetAttribute("Ridges")
					local count: number = if typeof(declared) == "number" then declared else #entry.ridges
					for _, ridge in entry.ridges do
						local slot = ridge:GetAttribute("Slot")
						if typeof(slot) == "number" then
							local front = Treadmills.ridgeOffset(slot, count, length, entry.phase)
							-- the belt's front is along its LookVector, which is local -Z
							ridge.CFrame = entry.belt.CFrame * CFrame.new(0, 0.3, -front)
						end
					end
				end
			end
		end
	end)
end

return Treadmills

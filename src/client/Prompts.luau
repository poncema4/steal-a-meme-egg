--!strict
-- Keeps each player's screen uncluttered. The server makes ONE prompt per thing, so everyone would see "Rebirth" on other
-- people's bases. A prompt's Enabled flag changed on the client only affects that client, so each screen switches off what
-- does not belong to its player: only your own base shows its pads.
local Prompts = {}

-- which actions belong to the base's owner
local OWNER_ONLY = {
	["Instant hatch"] = true,
	["Upgrade treadmill"] = true,
	["Buy slot"] = true,
	["Rebirth"] = true,
}

local function plotOf(prompt: Instance): Instance?
	local node = prompt.Parent
	while node do
		if string.match(node.Name, "^Plot_") then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Decides whether this player should see this prompt.
function Prompts.visible(action: string, ownerId: number, myId: number): boolean
	if OWNER_ONLY[action] then
		return ownerId == myId
	end
	return true
end

function Prompts.start(player: Player)
	local function apply(prompt: ProximityPrompt)
		local plot = plotOf(prompt)
		if plot then
			local owner = (plot:GetAttribute("OwnerUserId") :: number?) or 0
			prompt.Enabled = Prompts.visible(prompt.ActionText, owner, player.UserId)
		end
	end
	local function watch(plot: Instance)
		if not string.match(plot.Name, "^Plot_") then
			return
		end
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			for _, d in plot:GetDescendants() do
				if d:IsA("ProximityPrompt") then
					apply(d)
				end
			end
		end)
	end
	local map = workspace:WaitForChild("Map")
	for _, child in map:GetChildren() do
		watch(child)
	end
	map.ChildAdded:Connect(watch)
	map.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			apply(d)
		else
			-- a whole model was parented in (a base redrawing its characters): look inside it as well
			for _, inner in d:GetDescendants() do
				if inner:IsA("ProximityPrompt") then
					apply(inner)
				end
			end
		end
	end)
	for _, d in map:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			apply(d)
		end
	end
end

return Prompts

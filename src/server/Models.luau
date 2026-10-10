--!strict
-- Puts the real brick models (ServerStorage.Models, built by art/brick) on the world. A host part says where a model stands;
-- the host itself stays as an invisible anchor for prompts and tags. When a template is missing the caller keeps its plain look.
local ServerStorage = game:GetService("ServerStorage")

local Models = {}

local GOLD = Color3.fromRGB(255, 205, 40)
local RAINBOW_SPAN = 6

local function template(kind: string, id: string): Model?
	local root = ServerStorage:FindFirstChild("Models")
	local folder = root and root:FindFirstChild(kind)
	local found = folder and folder:FindFirstChild(id)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

function Models.has(kind: string, id: string): boolean
	return template(kind, id) ~= nil
end

-- Gold turns a model to glowing gold, Rainbow shifts its hue up its height.
local function tint(model: Model, mutation: string?, floorY: number)
	if mutation ~= "Gold" and mutation ~= "Rainbow" then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			part.Material = Enum.Material.Neon
			if mutation == "Gold" then
				local c = part.Color
				part.Color =
					Color3.new(c.R + (GOLD.R - c.R) * 0.6, c.G + (GOLD.G - c.G) * 0.6, c.B + (GOLD.B - c.B) * 0.6)
			else
				part.Color = Color3.fromHSV(((part.Position.Y - floorY) / RAINBOW_SPAN) % 1, 0.7, 1)
			end
		end
	end
end

-- Stands model `id` on the bottom of `host`, facing `front` (default the host's own front). Replaces any model already there.
function Models.show(host: BasePart, kind: string, id: string, mutation: string?, front: Vector3?): boolean
	local parent = host.Parent
	if not parent then
		return false
	end
	local old = parent:FindFirstChild("Visual")
	if old then
		old:Destroy()
	end
	local source = template(kind, id)
	if not source then
		return false
	end
	local clone = source:Clone()
	clone.Name = "Visual"
	local floorY = host.Position.Y - host.Size.Y / 2
	local at = Vector3.new(host.Position.X, floorY, host.Position.Z)
	local look = front or host.CFrame.LookVector
	clone:PivotTo(CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z)))
	tint(clone, mutation, floorY)
	clone.Parent = parent
	return true
end

function Models.hide(host: BasePart)
	local old = host.Parent and host.Parent:FindFirstChild("Visual")
	if old then
		old:Destroy()
	end
end

return Models

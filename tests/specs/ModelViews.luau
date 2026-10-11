--!nocheck
-- The UI is flat: the Index, Pets, Shop and HUD show 2D pictures (black silhouettes until discovered), never 3D views.
local Fake = require("../fake/Roblox")

local function find(root, name)
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

return function(t)
	local world = Fake.world()
	local Instance, Vector3, CFrame, Color3 = world.instance, world.Vector3, world.CFrame, world.Color3
	local rs = world.service("ReplicatedStorage")
	local models = Instance.new("Folder")
	models.Name = "Models"
	models.Parent = rs
	local pets = Instance.new("Folder")
	pets.Name = "Pets"
	pets.Parent = models
	for _, id in { "BonkBean", "SleepySock" } do
		local model = Instance.new("Model")
		model.Name = id
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.new(0.2, 0.2, 0.2)
		root.CFrame = CFrame.new(0, 0, 0)
		root.Parent = model
		model.PrimaryPart = root
		local blob = Instance.new("Part")
		blob.Name = "Blob"
		blob.Color = Color3.fromRGB(200, 90, 40)
		blob.Size = Vector3.new(2, 2, 2)
		blob.CFrame = CFrame.new(0, 1, 0)
		blob.Parent = model
		model.Parent = pets
	end
	local icons = Instance.new("Folder")
	icons.Name = "Icons"
	icons.Parent = models
	for _, id in { "cart", "shoe" } do
		local model = Instance.new("Model")
		model.Name = id
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.new(0.2, 0.2, 0.2)
		root.CFrame = CFrame.new(0, 0, 0)
		root.Parent = model
		model.PrimaryPart = root
		local blob = Instance.new("Part")
		blob.Name = "Blob"
		blob.Size = Vector3.new(2, 2, 2)
		blob.CFrame = CFrame.new(0, 1, 0)
		blob.Parent = model
		model.Parent = icons
	end
	local ok, err = pcall(world.load, "src/server/main.server")
	t.check("the server starts", ok, tostring(err))
	if not ok then
		return
	end
	local session = world.load("src/server/Session")
	local ana = world.addPlayer("Ana", 95)
	world.spawnCharacter(ana)
	world.advance(0.6)
	world.setLocal(ana)
	local panels = world.load("src/client/Panels")
	local started, api = pcall(panels.start, ana)
	t.check("the panels start", started, tostring(api))
	if not started then
		return
	end
	local screen = ana.PlayerGui:FindFirstChild("Panels")
	api.index()
	session.get(ana).base.slots[1] = { kind = "char", id = "BonkBean", mutation = "Normal" }
	session.changed(ana)
	world.advance(1)
	local bonk = find(screen, "Card_BonkBean")
	local sock = find(screen, "Card_SleepySock")
	-- the UI is flat, like the real game: pictures, never 3D views, even when the client has the 3D models
	t.check(
		"an Index card is a flat picture, not a 3D view",
		find(bonk, "Model3D") == nil and find(bonk, "Picture") ~= nil
	)
	t.check("the portrait letter is hidden behind the picture", find(bonk, "Letter").Visible == false)
	t.check("an undiscovered one is a black silhouette", find(sock, "Picture").ImageColor3 == Color3.new(0, 0, 0))
	api.pets()
	world.advance(1)
	t.check("the pet row is a flat picture too", find(find(screen, "PetRow_1"), "Model3D") == nil)
	local anyViewport = false
	for _, d in screen:GetDescendants() do
		if d:IsA("ViewportFrame") then
			anyViewport = true
		end
	end
	t.check("no panel uses a 3D view", not anyViewport)

	-- the HUD icons are flat pictures too
	local hud = world.load("src/client/Hud")
	hud.start(ana, { shop = function() end, index = function() end })
	local hudGui = ana.PlayerGui:FindFirstChild("Hud")
	local shopButton = find(hudGui, "ShopButton")
	t.check(
		"the Shop button's cart is a picture",
		find(shopButton, "Icon") ~= nil and find(shopButton, "Model3D") == nil
	)
	local stats = find(hudGui, "Stats")
	t.check(
		"so is the speed shoe",
		find(find(stats, "Speed"), "Icon") ~= nil and find(find(stats, "Speed"), "Model3D") == nil
	)
	-- Roblox rules the real Studio run showed: padding insets children (so the icon steps back out of it) and a square icon is
	-- sized from its height, not its width
	local icon = find(shopButton, "Icon") :: GuiObject
	t.check("the icon sits inside the padding, at the button's left edge", icon.Position.X.Offset < 0)
	t.check(
		"and it has a real size in pixels (a zero-width scale drew nothing in Studio)",
		icon.Size.X.Offset > 20 and icon.Size.Y.Offset > 20 and icon.Size.X.Scale == 0
	)
	t.check(
		"the Slow Mode track steps back out of the label's padding too",
		(find(hudGui, "Track") :: GuiObject).Position.X.Offset < 0
	)
end

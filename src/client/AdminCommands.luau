--!strict
-- The owner's chat commands (/resetme, /maxme, /event ...). They are made HERE, on the admin's own client, only once the server
-- has marked the player IsAdmin, so no one else ever sees them in the chat suggestions. Typing one sends it to the server, which
-- checks again that the player really is an admin.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local AdminCommands = {}

AdminCommands.NAMES = { "event", "give", "giveall", "announce", "clear", "help", "resetme", "maxme" }

function AdminCommands.start(player: Player)
	local built = false
	local function build()
		if built or player:GetAttribute("IsAdmin") ~= true then
			return
		end
		built = true
		local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminCommand") :: RemoteEvent
		for _, name in AdminCommands.NAMES do
			local command = Instance.new("TextChatCommand")
			command.Name = `Admin_{name}`
			command.PrimaryAlias = `/{name}`
			command.Parent = TextChatService
			command.Triggered:Connect(function(_source, text)
				remote:FireServer(text)
			end)
		end
	end
	player:GetAttributeChangedSignal("IsAdmin"):Connect(build)
	build()
end

return AdminCommands

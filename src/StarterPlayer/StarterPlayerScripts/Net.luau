-- Client side of the remotes. The server creates them in ReplicatedStorage.Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Net = {}

-- Calls a server function. Always returns a table with `ok`, even if the call itself fails.
function Net.Invoke(name: string, ...: any): { [string]: any }
	local remote = remotes:WaitForChild(name) :: RemoteFunction
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok then
		return { ok = false, message = "Connection problem, please try again." }
	end
	if type(result) ~= "table" then
		return { ok = false }
	end
	return result
end

function Net.Fire(name: string, ...: any)
	local remote = remotes:WaitForChild(name) :: RemoteEvent
	remote:FireServer(...)
end

function Net.On(name: string, callback: (...any) -> ()): RBXScriptConnection
	local remote = remotes:WaitForChild(name) :: RemoteEvent
	return remote.OnClientEvent:Connect(callback)
end

return Net

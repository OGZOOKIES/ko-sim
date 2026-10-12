-- Creates the remotes listed in Shared/Remotes and wraps their handlers with:
--   * per-player rate limits
--   * a per-player lock, so one request finishes before the next starts
--   * error handling, so a bug in a handler never leaves a request hanging
--
-- Handlers for RemoteFunctions return a table: { ok = boolean, message = string?, ... }.
-- Never trust arguments from the client: check their types and look everything up in config.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared.Remotes)
local Log = require(Shared.Utilities.Log)

local log = Log.new("Net")

local Net = {}

local folder: Folder
local busy: { [Player]: boolean } = {}
local buckets: { [Player]: { [string]: { Tokens: number, Last: number } } } = {}

function Net.Init()
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in RemoteNames.Functions do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in RemoteNames.Events do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		buckets[player] = nil
	end)
end

-- Token bucket: allows bursts up to `perSecond` and refills at `perSecond` per second.
local function allow(player: Player, name: string, perSecond: number): boolean
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[name]
	if not bucket then
		bucket = { Tokens = perSecond, Last = now }
		playerBuckets[name] = bucket
	end
	bucket.Tokens = math.min(perSecond, bucket.Tokens + (now - bucket.Last) * perSecond)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function getRemote(name: string, className: string): Instance
	local remote = folder:FindFirstChild(name)
	assert(remote and remote:IsA(className), `{name} is not a {className} in Shared/Remotes`)
	return remote
end

export type HandleOptions = { RateLimit: number? }

-- Answers a RemoteFunction.
function Net.Handle(name: string, handler: (Player, ...any) -> any, options: HandleOptions?)
	local remote = getRemote(name, "RemoteFunction") :: RemoteFunction
	local rate = if options and options.RateLimit then options.RateLimit else 6

	remote.OnServerInvoke = function(player: Player, ...)
		if not allow(player, name, rate) then
			return { ok = false, message = "Slow down a little!" }
		end
		if busy[player] then
			return { ok = false, message = "Please wait..." }
		end
		busy[player] = true
		local ok, result = pcall(handler, player, ...)
		busy[player] = nil
		if not ok then
			log.warn(`{name} failed for {player.Name}:`, result)
			return { ok = false, message = "Something went wrong. Please try again." }
		end
		if type(result) ~= "table" then
			return { ok = true }
		end
		return result
	end
end

-- Listens to a RemoteEvent fired by clients. Requests over the rate limit are dropped.
function Net.On(name: string, handler: (Player, ...any) -> (), options: HandleOptions?)
	local remote = getRemote(name, "RemoteEvent") :: RemoteEvent
	local rate = if options and options.RateLimit then options.RateLimit else 10

	remote.OnServerEvent:Connect(function(player, ...)
		if not allow(player, name, rate) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			log.warn(`{name} failed for {player.Name}:`, err)
		end
	end)
end

function Net.Fire(name: string, player: Player, ...: any)
	local remote = getRemote(name, "RemoteEvent") :: RemoteEvent
	remote:FireClient(player, ...)
end

function Net.FireAll(name: string, ...: any)
	local remote = getRemote(name, "RemoteEvent") :: RemoteEvent
	remote:FireAllClients(...)
end

function Net.Notify(player: Player, message: string, kind: string?)
	Net.Fire("Notify", player, message, kind or "Info")
end

-- Standard replies
function Net.Ok(message: string?, extra: { [string]: any }?): { [string]: any }
	local result: { [string]: any } = { ok = true, message = message }
	if extra then
		for key, value in extra do
			result[key] = value
		end
	end
	return result
end

function Net.Fail(message: string?): { [string]: any }
	return { ok = false, message = message }
end

Net.NotLoaded = table.freeze({ ok = false, message = "Your data is still loading..." })

return Net

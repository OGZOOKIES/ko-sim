-- The latest copy of this player's data, as sent by the server.
-- Read-only on the client: changes only ever come from the server.

local ClientState = {
	Data = nil :: { [string]: any }?,
}

local changed = Instance.new("BindableEvent")
ClientState.Changed = changed.Event -- (data, previousData)

function ClientState.Set(data: { [string]: any })
	local previous = ClientState.Data
	ClientState.Data = data
	changed:Fire(data, previous)
end

function ClientState.Wait(): { [string]: any }
	while not ClientState.Data do
		changed.Event:Wait()
	end
	return ClientState.Data :: { [string]: any }
end

return ClientState

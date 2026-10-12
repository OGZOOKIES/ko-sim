--!strict
-- Small logging helper so every message says where it came from.
--
-- Usage:
--   local log = Log.new("Launch")
--   log.info("Round started")      --> [Server][Launch] Round started
--   log.debug("speed", 120)        --> only printed in Studio when GameConfig.DebugLogging is true

local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

export type Logger = {
	debug: (...any) -> (),
	info: (...any) -> (),
	warn: (...any) -> (),
	error: (...any) -> (),
}

local Log = {}

local side = if RunService:IsServer() then "Server" else "Client"
local debugEnabled = GameConfig.DebugLogging and RunService:IsStudio()

function Log.new(tag: string): Logger
	local prefix = `[{side}][{tag}]`

	return {
		debug = function(...)
			if debugEnabled then
				print(prefix, "[debug]", ...)
			end
		end,
		info = function(...)
			print(prefix, ...)
		end,
		warn = function(...)
			warn(prefix, ...)
		end,
		-- Reports an error without stopping the calling script.
		error = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring((select(i, ...))))
			end
			task.spawn(error, `{prefix} {table.concat(parts, " ")}`, 0)
		end,
	}
end

return Log

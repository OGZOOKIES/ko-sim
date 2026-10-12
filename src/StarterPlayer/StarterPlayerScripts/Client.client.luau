-- Client entry point. Starts listening for data first, then initialises and starts controllers.

local ClientState = require(script.Parent.ClientState)
local Net = require(script.Parent.Net)

local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"UIController",
	"TrainingController",
	"LaunchController",
	"PetController",
	"WorldController",
}

Net.On("StateUpdated", ClientState.Set)

local controllers = {}
for _, name in ORDER do
	controllers[name] = require(Controllers:WaitForChild(name))
end
for _, name in ORDER do
	controllers[name].Init()
end
for _, name in ORDER do
	controllers[name].Start()
end

-- In case the first update arrived before we were listening.
task.spawn(function()
	while not ClientState.Data do
		local result = Net.Invoke("GetState")
		if result.ok and result.data then
			if not ClientState.Data then
				ClientState.Set(result.data)
			end
			break
		end
		task.wait(1)
	end
end)

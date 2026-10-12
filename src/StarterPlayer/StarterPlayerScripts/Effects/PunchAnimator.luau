-- Punch poses for any character (yours or other players'), on R15 or R6.
--
-- If PunchConfig.Animations has uploaded ids, those animations play. Otherwise a procedural punch
-- is layered on top of the character's normal animation by adjusting its Motor6D joints each
-- frame (after the Animator has run). Nothing here replicates or affects gameplay.
--
--   PunchAnimator.SetWindUp(character, amount)   0..1 while charging (0 clears it)
--   PunchAnimator.Punch(character)               plays the strike once

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PunchConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.PunchConfig)

local PunchAnimator = {}

type Joints = {
	R15: boolean,
	Waist: Motor6D?,
	RightShoulder: Motor6D?,
	RightElbow: Motor6D?,
	LeftShoulder: Motor6D?,
	LeftElbow: Motor6D?,
}

type State = {
	Joints: Joints,
	WindUp: number,
	PunchStart: number?,
	Tracks: { [string]: AnimationTrack }?,
}

local states: { [Model]: State } = {}

local function motor(parent: Instance?, name: string): Motor6D?
	local found = parent and parent:FindFirstChild(name)
	return if found and found:IsA("Motor6D") then found else nil
end

local function findJoints(character: Model): Joints?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return {
			R15 = true,
			Waist = motor(character:FindFirstChild("UpperTorso"), "Waist"),
			RightShoulder = motor(character:FindFirstChild("RightUpperArm"), "RightShoulder"),
			RightElbow = motor(character:FindFirstChild("RightLowerArm"), "RightElbow"),
			LeftShoulder = motor(character:FindFirstChild("LeftUpperArm"), "LeftShoulder"),
			LeftElbow = motor(character:FindFirstChild("LeftLowerArm"), "LeftElbow"),
		}
	end
	local torso = character:FindFirstChild("Torso")
	return {
		R15 = false,
		RightShoulder = motor(torso, "Right Shoulder"),
		LeftShoulder = motor(torso, "Left Shoulder"),
	}
end

local function uploadedTracks(character: Model): { [string]: AnimationTrack }?
	if PunchConfig.Animations.Punch == "" then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local tracks = {}
	for name, id in PunchConfig.Animations do
		if id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				tracks[name] = track
			end
		end
	end
	return tracks
end

local function getState(character: Model): State?
	local state = states[character]
	if state then
		return state
	end
	local joints = findJoints(character)
	if not joints then
		return nil
	end
	state = { Joints = joints, WindUp = 0, PunchStart = nil, Tracks = uploadedTracks(character) }
	states[character] = state
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			states[character] = nil
		end
	end)
	return state
end

local function rotate(joint: Motor6D?, x: number, y: number, z: number)
	if joint and (x ~= 0 or y ~= 0 or z ~= 0) then
		joint.Transform = joint.Transform * CFrame.Angles(x, y, z)
	end
end

-- 0 -> 1 while the fist extends, holds, then eases back to 0.
local function extension(t: number): number
	local extend = PunchConfig.ExtendTime / PunchConfig.PunchDuration
	if t < extend then
		local u = t / extend
		return 1 - (1 - u) * (1 - u) -- fast out
	elseif t < 0.55 then
		return 1
	end
	local u = (t - 0.55) / 0.45
	return 1 - u * u * (3 - 2 * u)
end

local function apply(state: State)
	local w = state.WindUp
	local e = 0
	if state.PunchStart then
		local t = (os.clock() - state.PunchStart) / PunchConfig.PunchDuration
		if t >= 1 then
			state.PunchStart = nil
		else
			e = extension(t)
		end
	end
	if w == 0 and e == 0 then
		return
	end
	local hold = w * (1 - e)
	local j = state.Joints
	if j.R15 then
		rotate(j.Waist, 0, -0.35 * hold + 0.35 * e, 0)
		rotate(j.RightShoulder, -0.6 * hold + 1.5 * e, 0, 0.25 * hold)
		rotate(j.RightElbow, 1.6 * hold + 0.1 * e, 0, 0)
		rotate(j.LeftShoulder, 0.9 * hold + 0.5 * e, 0, 0)
		rotate(j.LeftElbow, 1.8 * hold + 1.2 * e, 0, 0)
	else
		rotate(j.RightShoulder, 0, 0, -0.7 * hold + 1.57 * e)
		rotate(j.LeftShoulder, 0, 0, -1 * hold - 0.6 * e)
	end
end

function PunchAnimator.SetWindUp(character: Model, amount: number)
	local state = getState(character)
	if not state then
		return
	end
	if state.Tracks and state.Tracks.WindUp then
		local track = state.Tracks.WindUp
		if amount > 0 and not track.IsPlaying then
			track:Play(0.1)
		elseif amount == 0 and track.IsPlaying then
			track:Stop(0.1)
		end
		return
	end
	state.WindUp = math.clamp(amount, 0, 1)
end

function PunchAnimator.Punch(character: Model)
	local state = getState(character)
	if not state then
		return
	end
	if state.Tracks and state.Tracks.Punch then
		if state.Tracks.WindUp then
			state.Tracks.WindUp:Stop(0.05)
		end
		state.Tracks.Punch:Play(0.05)
		return
	end
	state.PunchStart = os.clock()
	-- The wind-up flows into the strike, then lets go.
	task.delay(PunchConfig.PunchDuration * 0.5, function()
		state.WindUp = 0
	end)
end

RunService.Stepped:Connect(function()
	for character, state in states do
		if character.Parent then
			apply(state)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		states[player.Character] = nil
	end
end)

return PunchAnimator

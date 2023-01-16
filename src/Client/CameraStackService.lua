--[=[
	Holds camera states and allows for the last camera state to be retrieved. Also
	initializes an impulse and default camera as the bottom of the stack. Is a singleton.

	@class CameraStackService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local DefaultCamera = require("DefaultCamera")
local ImpulseCamera = require("ImpulseCamera")
local ServiceBag = require("ServiceBag")
local Maid = require("Maid")
local CameraStack = require("CameraStack")

assert(RunService:IsClient(), "[CameraStackService] - Only require CameraStackService on client")

local CameraStackService = {}
CameraStackService.ServiceName = "CameraStackService"
CameraStackService._cameraStack = nil
CameraStackService._defaultCamera = nil
CameraStackService._rawDefaultCamera = nil
CameraStackService._impulseCamera = nil
CameraStackService._maid = nil
CameraStackService._doNotUseDefaultCamera = nil

--[=[
	Initializes a new camera stack. Should be done via the ServiceBag.
	@param serviceBag ServiceBag
]=]
function CameraStackService:Init(serviceBag)
	assert(ServiceBag.isServiceBag(serviceBag), "Not a valid service bag")

	CameraStackService._maid = Maid.new()
	CameraStackService._key = HttpService:GenerateGUID(false)

	CameraStackService._cameraStack = CameraStack.new()

	-- Initialize default cameras
	CameraStackService._rawDefaultCamera = DefaultCamera.new()
	CameraStackService._maid:GiveTask(CameraStackService._rawDefaultCamera)

	CameraStackService._impulseCamera = ImpulseCamera.new()
	CameraStackService._defaultCamera = (CameraStackService._rawDefaultCamera + CameraStackService._impulseCamera):SetMode("Relative")

	-- Add camera to stack
	CameraStackService:Add(CameraStackService._defaultCamera)

	RunService:BindToRenderStep("CameraStackUpdateInternal" .. CameraStackService._key, Enum.RenderPriority.Camera.Value + 75, function()
		debug.profilebegin("camerastackservice")

		local state = CameraStackService:GetTopState()
		if state then
			state:Set(Workspace.CurrentCamera)
		end

		debug.profileend()
	end)

	CameraStackService._maid:GiveTask(function()
		RunService:UnbindFromRenderStep("CameraStackUpdateInternal" .. CameraStackService._key)
	end)
end

function CameraStackService:Start()
	CameraStackService._started = true

	-- TODO: Allow rebinding
	if CameraStackService._doNotUseDefaultCamera then
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

		-- TODO: Handle camera deleted too!
		Workspace.CurrentCamera:GetPropertyChangedSignal("CameraType"):Connect(function()
			Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		end)
	else
		CameraStackService._rawDefaultCamera:BindToRenderStep()
	end
end

--[=[
	Prevents the default camera from being used
	@param doNotUseDefaultCamera boolean
]=]
function CameraStackService:SetDoNotUseDefaultCamera(doNotUseDefaultCamera)
	assert(not CameraStackService._started, "Already started")

	CameraStackService._doNotUseDefaultCamera = doNotUseDefaultCamera
end

--[=[
	Pushes a disable state onto the camera stack
	@return function -- Function to cancel disable
]=]
function CameraStackService:PushDisable()
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:PushDisable()
end

--[=[
	Outputs the camera stack. Intended for diagnostics.
]=]
function CameraStackService:PrintCameraStack()
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:PrintCameraStack()
end

--[=[
	Returns the default camera
	@return SummedCamera -- DefaultCamera + ImpulseCamera
]=]
function CameraStackService:GetDefaultCamera()
	assert(CameraStackService._defaultCamera, "Not initialized")

	return CameraStackService._defaultCamera
end

--[=[
	Returns the impulse camera. Useful for adding camera shake.

	Shaking the camera:
	```lua
	CameraStackService._cameraStackService:GetImpulseCamera():Impulse(Vector3.new(0.25, 0, 0.25*(math.random()-0.5)))
	```

	You can also sum the impulse camera into another effect to layer the shake on top of the effect
	as desired.

	```lua
	-- Adding global custom camera shake to a custom camera effect
	local customCameraEffect = ...
	return (customCameraEffect + CameraStackService._cameraStackService:GetImpulseCamera()):SetMode("Relative")
	```

	@return ImpulseCamera
]=]
function CameraStackService:GetImpulseCamera()
	assert(CameraStackService._impulseCamera, "Not initialized")

	return CameraStackService._impulseCamera
end

--[=[
	Returns the default camera without any impulse cameras
	@return DefaultCamera
]=]
function CameraStackService:GetRawDefaultCamera()
	assert(CameraStackService._rawDefaultCamera, "Not initialized")

	return CameraStackService._rawDefaultCamera
end

--[=[
	Gets the camera current on the top of the stack
	@return CameraEffect
]=]
function CameraStackService:GetTopCamera()
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:GetTopCamera()
end

--[=[
	Retrieves the top state off the stack at this time
	@return CameraState?
]=]
function CameraStackService:GetTopState()
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:GetTopState()
end

--[=[
	Returns a new camera state that retrieves the state below its set state.

	@return CustomCameraEffect -- Effect below
	@return (CameraState) -> () -- Function to set the state
]=]
function CameraStackService:GetNewStateBelow()
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:GetNewStateBelow()
end

--[=[
	Retrieves the index of a state
	@param state CameraEffect
	@return number? -- index

]=]
function CameraStackService:GetIndex(state)
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:GetIndex(state)
end

--[=[
	Returns the current stack.

	:::warning
	Do not modify this stack, this is the raw memory of the stack
	:::

	@return { CameraState<T> }
]=]
function CameraStackService:GetRawStack()
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:GetRawStack()
end

--[=[
	Gets the current camera stack

	@return CameraStack
]=]
function CameraStackService:GetCameraStack()
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:GetStack()
end

--[=[
	Removes the state from the stack
	@param state CameraState
]=]
function CameraStackService:Remove(state)
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:Remove(state)
end

--[=[
	Adds the state from the stack
	@param state CameraState
]=]
function CameraStackService:Add(state)
	assert(CameraStackService._cameraStack, "Not initialized")

	return CameraStackService._cameraStack:Add(state)
end

function CameraStackService:Destroy()
	CameraStackService._maid:DoCleaning()
end

return CameraStackService
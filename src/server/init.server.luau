--!strict
-- Robdev server entry point. Two-phase bootstrap: every system's init() runs
-- first (wiring, registering actions), then every system's start() (connecting
-- events, starting loops). Systems never depend on load order this way.

local Systems = script:WaitForChild("Systems")

local loaded: { [string]: any } = {}
for _, child in Systems:GetChildren() do
	if child:IsA("ModuleScript") then
		loaded[child.Name] = require(child) :: any
	end
end

for _, system in loaded do
	if typeof(system.init) == "function" then
		system.init()
	end
end

for _, system in loaded do
	if typeof(system.start) == "function" then
		task.spawn(system.start)
	end
end

print("[Robdev] server started")

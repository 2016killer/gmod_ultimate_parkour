--[[
作者:白狼
2025 11 5
]]--

-- ==================== 生命期测试 ===============
if not GetConVar('developer'):GetBool() then return end



local actionName = 'InterruptTest'
local action, _ = UltiPar.Register(actionName)

local function InterruptFunc(ply, ...)
	UltiPar.printdata('InterruptFunc', ply, ...)
	return true
end

local lifecycleTestAction, _ = UltiPar.Register('LifeCycleTest')
lifecycleTestAction.Interrupts[actionName] = InterruptFunc


action.Check = function() print('Check ' .. actionName); return true end
action.Start = function() print('Start ' .. actionName); return true end
action.Play = function() print('Play ' .. actionName); return true end
action.Clear = function() print('Clear ' .. actionName) end


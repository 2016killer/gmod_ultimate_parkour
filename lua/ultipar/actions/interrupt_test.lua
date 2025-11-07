--[[
作者:白狼
2025 11 5
]]--

-- ==================== 生命期测试 ===============
if not GetConVar('developer'):GetBool() then return end


local actionName2 = 'InterruptTest'
local action2, _ = UltiPar.Register(actionName2)

local function InterruptFunc(ply, ...)
	UltiPar.printdata('InterruptFunc', ...)
end


action2.Check = function() print('Check ' .. actionName2); return true end
action2.Start = function() print('Start ' .. actionName2); return true end
action2.Play = function() print('Play ' .. actionName2); return true end
action2.Clear = function() print('Clear ' .. actionName2) end


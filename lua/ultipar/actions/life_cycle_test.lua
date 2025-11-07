--[[
作者:白狼
2025 11 5
]]--

-- ==================== 生命期测试 ===============
local actionName1 = 'LifeCycleTest'
local action1, _ = UltiPar.Register(actionName1)

local actionName2 = 'LifeCycleTest_Breaker'
local action2, _ = UltiPar.Register(actionName2)

action1.Interrupts = {
	['LifeCycleTest_Breaker'] = true
}

UltiPar.RegisterEffect(
	actionName1, 
	'default',
	{label = '#default'}
)

action2.Check = function() print('Check ' .. actionName2); return true end
action2.Start = function() print('Start ' .. actionName2); return true end
action2.Play = function() print('Play ' .. actionName2); return true end
action2.Clear = function() print('Clear ' .. actionName2) end

if CLIENT then
	action2.Invisible = true

	action1.CreateOptionMenu = function(panel)
		local testButton = panel:Button('Test', '')
		testButton.DoClick = function()
			UltiPar.Trigger(LocalPlayer(), action1, {shit = true})
		end

		local accidentBreakTestButton = panel:Button('Accident Break Test', '')
		accidentBreakTestButton.DoClick = function()
			UltiPar.Trigger(LocalPlayer(), action1, {shit = true})
			timer.Simple(1, function()
				RunConsoleCommand('kill')
			end)
		end

		local interruptTestButton = panel:Button('Interrupt Test', '')
		interruptTestButton.DoClick = function()
			UltiPar.Trigger(LocalPlayer(), action1, {shit = true})
			timer.Simple(1, function()
				UltiPar.Trigger(LocalPlayer(), action2)
			end)
		end

	end
end

--[[
作者:白狼
2025 11 1
]]--

-- ==================== 生命期测试 ===============

local actionName1 = 'LifeCycleTest'
local action1, _ = UltiPar.Register(actionName1)

action1.Interrupts = {
	['LifeCycleTest_Breaker'] = true
}

if CLIENT then
	action1.CreateOptionMenu = function(panel)
		local testButton = panel:Button('Test', '')
		testButton.DoClick = function()
			UltiPar.Trigger(LocalPlayer(), actionName1, {shit = true})
		end

		local accidentBreakTestButton = panel:Button('Accident Break Test', '')
		accidentBreakTestButton.DoClick = function()
			UltiPar.Trigger(LocalPlayer(), actionName1, {shit = true})
			timer.Simple(1, function()
				RunConsoleCommand('kill')
			end)
		end

		local interruptTestButton = panel:Button('Interrupt Test', '')
		interruptTestButton.DoClick = function()
			UltiPar.Trigger(LocalPlayer(), actionName1, {shit = true})
			timer.Simple(1, function()
				UltiPar.Trigger(LocalPlayer(), 'LifeCycleTest_Breaker')
			end)
		end

	end
end

local origincheck = action1.Check
action1.Check = function(ply, appenddata)
	origincheck(ply, appenddata)
	return {starttime = CurTime()}
end

local origincheckend = action1.CheckEnd
action1.CheckEnd = function(ply, checkdata, starttime)
	if CurTime() - starttime > 2 then
		origincheckend(ply, checkdata, starttime)
		return {endtime = CurTime()}
	else
		return false
	end
end

local effect, _ = UltiPar.RegisterEffect(
	actionName1, 
	'default',
	{
		label = '#default'
	}
)


-- ==================== 生命期测试 中断 ===============

local actionName2 = 'LifeCycleTest_Breaker'
local action2, _ = UltiPar.Register(actionName2)

if CLIENT then
	action2.Invisible = true
end

action2.Check = function()
	print('Check ' .. actionName2)
	return {}
end

action2.CheckEnd = 0.0

action2.Play = function()
	print('Play ' .. actionName2)
end

action2.Clear = function()
	print('Clear ' .. actionName2)
end

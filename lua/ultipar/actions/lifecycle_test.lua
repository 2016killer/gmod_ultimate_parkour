--[[
作者:白狼
2025 11 5
]]--

-- ==================== 生命期测试 ===============
if not GetConVar('developer'):GetBool() then return end

local actionName = 'LifeCycleTest'
local action, _ = UltiPar.Register(actionName)

UltiPar.RegisterEffect(
	actionName, 
	'default',
	{label = '#default'}
)

function action:Check(ply, ...)
	UltiPar.printdata('Check', ply, ...)
	return CurTime(), 'that', 'is', 'shit', 'check'
end

function action:Start(ply, ...)
	UltiPar.printdata('Start', ply, ...)
end

function action:Play(ply, mv, cmd, ...)
	local starttime = select(1, ...)
	local curtime = CurTime()
	if curtime - starttime > 2 then
		UltiPar.printdata('Play', ply, ...)
		return curtime, 'oh', 'my', 'god', 'play', 'end'
	end
	return false
end

function action:Clear(ply, ...)
	UltiPar.printdata('Clear', ply, ...)
end

if CLIENT then
	action.CreateOptionMenu = function(panel)
		local testButton = panel:Button('Test', '')
		testButton.DoClick = function()
			UltiPar.Trigger(LocalPlayer(), action, false, 'Shit', 'fuck')
		end

		local accidentBreakTestButton = panel:Button('Accident Break Test', '')
		accidentBreakTestButton.DoClick = function()
			UltiPar.Trigger(LocalPlayer(), action, {shit = true})
			timer.Simple(1, function()
				RunConsoleCommand('kill')
			end)
		end

		local interruptTestButton = panel:Button('Interrupt Test', '')
		interruptTestButton.DoClick = function()
			UltiPar.Trigger(LocalPlayer(), action, {shit = true})
			timer.Simple(1, function()
				UltiPar.Trigger(LocalPlayer(), action2)
			end)
		end

	end
end

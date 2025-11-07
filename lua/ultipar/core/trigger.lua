--[[
	作者:白狼
	2025 11 5

--]]
UltiPar = UltiPar or {}
local UltiPar = UltiPar


local function Execute(ply, action, checkresult, breakin, breakinresult)
	-- [StartEffect, Start]
	if not action then return end
	
	-- 执行动作
	checkresult = action:Start(ply, checkresult, breakin, breakinresult) or checkresult
	checkresult = istable(checkresult) and checkresult or {checkresult}
	
	-- 执行特效
	local effect = GetPlayerEffect(ply, action)
	if effect then effect:start(ply, checkresult, breakin, breakinresult) end

	-- 标记播放
	SetCurrentData(ply, action, checkresult, CurTime())

	hook.Run('UltiParExecute', ply, action, checkresult, breakin, breakinresult)
	return checkresult
end 

local function End(ply, action, checkresult, checkendresult, breaker, breakresult)
	-- 动作结束
	-- 分为自然结束、强制结束、中断结束
	-- 自然结束breaker为nil, 强制结束breaker为true, 中断结束breaker为table
	-- [ClearEffect, Clear]

	if not action then return end
	
	action:Clear(ply, checkresult, checkendresult, breaker, breakresult)

	local effect = GetPlayerEffect(ply, action)
	if effect then effect:clear(ply, checkresult, checkendresult, breaker, breakresult) end

	local currentAciton = GetPlayingAction(ply)
	if currentAciton and currentAciton.Name == action.Name then 
		SetCurrentData(ply)
	end

	hook.Run('UltiParEnd', ply, action, checkresult, checkendresult, breaker, breakresult)
end

local function Trigger(ply, action, appenddata, checkresult)
	-- 触发动作
	-- action 动作
	-- appenddata 附加数据
	-- checkresult 用于绕过Check, 直接执行

	-- 检查动作是否禁用
	local actionName = action.Name

	if IsActionDisable(actionName) then
		// print(string.format('Action "%s" is disabled.', actionName))
		return
	end

	local currentAciton, currentCheckresult, _ = GetCurrentData(ply)

	-- 检查是否允许中断当前动作
	if currentAciton and not AllowInterrupt(ply, currentAciton, actionName) then 
		-- 不允许中断当前动作
		// print(string.format('Action "%s" is not allow "%s" interrupt.', currentAciton.Name, actionName))
		return 
	end

	checkresult = checkresult or action:Check(ply, appenddata)
	if not checkresult then
		return
	end

	checkresult = istable(checkresult) and checkresult or {checkresult}
	
	if SERVER then
		if currentAciton then
			End(ply, currentAciton, currentCheckresult, nil, action, checkresult)
		end

		checkresult = Execute(ply, action, checkresult, currentAciton, currentCheckresult)

		-- 为减少传输次数, 中断数据包与播放数据包合并发送
		net.Start('UltiParExecute')
			net.WriteString(actionName)
			net.WriteTable(checkresult)
			net.WriteString(currentAciton and currentAciton.Name or '')
			net.WriteTable(currentCheckresult or {})
		net.Send(ply)
	elseif CLIENT then
		net.Start('UltiParExecute')
			net.WriteString(actionName)
			net.WriteTable(checkresult)
		net.SendToServer()
	end

	return checkresult
end

local function ForceEnd(ply)
	local action, checkresult, starttime = GetCurrentData(ply)
	
	SetCurrentData(ply)
	SetMoveControl(ply, false, false, 0, 0)

	if action then	
		End(ply, action, checkresult, nil, true, nil)
		net.Start('UltiParEnd')
			net.WriteString(action.Name)
			net.WriteTable(checkresult)
			net.WriteBool(true)
		net.Send(ply)
	end
end

if SERVER then
	util.AddNetworkString('UltiParEnd')
	util.AddNetworkString('UltiParExecute')

	hook.Add('SetupMove', 'ultipar.play', function(ply, mv, cmd)
		local action, checkresult, starttime = GetCurrentData(ply)
		if not action then return end


		local succ, err = pcall(action.Play, action, ply, mv, cmd, checkresult, starttime)
		-- 异常处理, 清除移动数据
		if not succ then
			ErrorNoHalt(string.format('Action "%s" Play error: %s\n', action.Name, err))
			ForceEnd(ply)
			return
		end

		local endresult = err
		if not endresult then
			return
		end

		endresult = istable(endresult) and endresult or {endresult}

		End(ply, action, checkresult, endresult, nil, nil)
		net.Start('UltiParEnd')
			net.WriteString(action.Name)
			net.WriteTable(checkresult)
			net.WriteBool(false)
			net.WriteTable(endresult)
		net.Send(ply)
	end)

	net.Receive('UltiParExecute', function(len, ply)
		local actionName = net.ReadString()
		local checkresult = net.ReadTable()

		// print('net Receive UltiParExecute')
		local action = GetAction(actionName)
		if not action then return end

		Trigger(ply, action, nil, checkresult)
	end)

	hook.Add('PlayerInitialSpawn', 'ultipar.init', function(ply)
		ForceEnd(ply)
		ply.ultipar_effect_config = ply.ultipar_effect_config or {}
	end)

	hook.Add('PlayerSpawn', 'ultipar.clear', ForceEnd)

	hook.Add('PlayerDeath', 'ultipar.clear', ForceEnd)

	hook.Add('PlayerSilentDeath', 'ultipar.clear', ForceEnd)

	concommand.Add('up_forceend', ForceEnd)
elseif CLIENT then
	net.Receive('UltiParExecute', function(len, ply)
		local actionName = net.ReadString()
		local checkresult = net.ReadTable()
		local currentAcitonName = net.ReadString()
		local currentCheckresult = net.ReadTable()

		// print('net Receive UltiParExecute')
		ply = LocalPlayer()
		local currentAciton = GetAction(currentAcitonName)
		local action = GetAction(actionName)
		
		if currentAcitonName ~= '' then
			End(ply, currentAciton, currentCheckresult, nil, action, checkresult)
		else
			currentAciton = nil
			currentCheckresult = nil
		end

		checkresult = Execute(ply, action, checkresult, currentAciton, currentCheckresult)
	end)

	net.Receive('UltiParEnd', function(len, ply)
		local actionName = net.ReadString()
		local checkresult = net.ReadTable()
		local forceEnd = net.ReadBool()
		local endresult = not forceEnd and net.ReadTable() or nil
		
		// print('net Receive UltiParEnd')
		ply = LocalPlayer()
		local action = GetAction(actionName)
		End(ply, action, checkresult, endresult, forceEnd or nil, nil)
	end)
end
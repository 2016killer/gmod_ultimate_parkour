--[[
	作者:白狼
	2025 11 5
	Trigger: Check -> Start -> StartEffect-> Play -> Clear -> ClearEffect
--]]
UltiPar = UltiPar or {}

UltiPar.TRIGGERNW_FLAG_START = 'START'
UltiPar.TRIGGERNW_FLAG_END = 'END'
UltiPar.TRIGGERNW_FLAG_INTERRUPT = 'INTERRUPT'
UltiPar.TRIGGERNW_FLAG_MOVE_CONTROL = 'MOVE_CONTROL'

local TRIGGERNW_FLAG_START = UltiPar.TRIGGERNW_FLAG_START
local TRIGGERNW_FLAG_END = UltiPar.TRIGGERNW_FLAG_END
local TRIGGERNW_FLAG_INTERRUPT = UltiPar.TRIGGERNW_FLAG_INTERRUPT
local TRIGGERNW_FLAG_MOVE_CONTROL = UltiPar.TRIGGERNW_FLAG_MOVE_CONTROL

local function HandleResult(...)
	if select(1, ...) then
		return table.Pack(...)
	else
		return nil
	end
end


local function StartTriggerNet(ply)
	ply.ultipar_tnet = ply.ultipar_tnet or {}
end

local function WriteStart(ply, actionName, data)
	local target = ply.ultipar_tnet
	table.Add(target, {TRIGGERNW_FLAG_START, actionName, #data})
	table.Add(target, data)
end

local function WriteEnd(ply, actionName, data)
	local target = ply.ultipar_tnet
	table.Add(target, {TRIGGERNW_FLAG_END, actionName, #data})
	table.Add(target, data)
end

local function WriteInterrupt(ply, actionName, data, breakerName)
	local target = ply.ultipar_tnet
	table.Add(target, {TRIGGERNW_FLAG_INTERRUPT, actionName, #data + 1, breakerName})
	table.Add(target, data)
end

local function WriteMoveControl(ply, enable, ClearMovement, RemoveKeys, AddKeys)
	local target = ply.ultipar_tnet
	table.Add(target, {TRIGGERNW_FLAG_MOVE_CONTROL,
		'', 4, enable, ClearMovement, RemoveKeys, AddKeys
	})
end

local function SendTriggerNet(ply)
	if not ply.ultipar_tnet then 
		ErrorNoHalt('UltiPar: SendTriggerNet: ply.ultipar_tnet is nil\n')
		return 
	end
	net.Start('UltiParEvents')
		net.WriteTable(ply.ultipar_tnet, true)
	net.Send(ply)
	ply.ultipar_tnet = nil
end

if SERVER then
	UltiPar.StartTriggerNet = StartTriggerNet
	UltiPar.WriteStart = WriteStart
	UltiPar.WriteEnd = WriteEnd
	UltiPar.WriteInterrupt = WriteInterrupt
	UltiPar.WriteMoveControl = WriteMoveControl
else
	StartTriggerNet = nil
	WriteStart = nil
	WriteEnd = nil
	WriteInterrupt = nil
	WriteMoveControl = nil
end

local IsActionDisable = UltiPar.IsActionDisable
local GetPlayerCurrentEffect = UltiPar.GetPlayerCurrentEffect
local GetAction = UltiPar.GetAction
UltiPar.Trigger = function(ply, action, checkResult, ...)
	-- 动作触发器
	-- checkResult 用于绕过Check, 直接执行
	
	local actionName = action.Name
	if IsActionDisable(actionName) then 
		return 
	end

	-- 检查中断
	local playing = ply.ultipar_playing
	local playingData = ply.ultipar_playing_data
	if playing then
		local interruptFunc = playing.Interrupts[actionName]
		if isfunction(interruptFunc) and interruptFunc(ply, unpack(playingData)) then
			ply.ultipar_playing = nil
			ply.ultipar_playing_data = nil
		else
			return
		end
	end

	checkResult = istable(checkResult) and checkResult or HandleResult(action:Check(ply, ...))
	if not checkResult then
		return
	end


	if SERVER then
		action:Start(ply, unpack(checkResult))

		-- 执行特效
		local effect = GetPlayerCurrentEffect(ply, action)
		if effect then 
			effect:start(ply, unpack(checkResult)) 
		end

		-- 启动播放
		ply.ultipar_playing = action
		ply.ultipar_playing_data = checkResult

		StartTriggerNet(ply)
			if playing then
				WriteInterrupt(ply, playing.Name, playingData, actionName)
			end
			WriteStart(ply, actionName, checkResult)
		SendTriggerNet(ply)

		if playing then
			hook.Run('UltiParInterrupt', ply, playing, playingData, action, checkResult)
		end
		hook.Run('UltiParStart', ply, action, checkResult)
	elseif CLIENT then
		net.Start('UltiParStart')
			net.WriteString(actionName)
			net.WriteTable(checkResult)
		net.SendToServer()
	end

	return checkResult
end


if SERVER then
	local function ForceEnd(ply)
		local playing = ply.ultipar_playing
		local playingData = ply.ultipar_playing_data

		ply.ultipar_playing = nil
		ply.ultipar_playing_data = nil

		if playing then	
			playing:Clear(ply)
			local effect = GetPlayerCurrentEffect(ply, playing)
			if effect then 
				effect:clear(ply) 
			end

			StartTriggerNet(ply)
				WriteEnd(ply, playing.Name, {})
				WriteMoveControl(ply, false, false, 0, 0)
			SendTriggerNet(ply)

			hook.Run('UltiParEnd', ply, action, {})
		end
	end

	util.AddNetworkString('UltiParStart')
	util.AddNetworkString('UltiParEvents')

	net.Receive('UltiParStart', function(len, ply)
		local actionName = net.ReadString()
		local checkResult = net.ReadTable()

		local action = GetAction(actionName)
		if not action then 
			return 
		end

		UltiPar.Trigger(ply, action, checkResult)
	end)

	hook.Add('SetupMove', 'ultipar.play', function(ply, mv, cmd)
		local playing = ply.ultipar_playing
		if not playing then 
			return 
		end

		local playingData = ply.ultipar_playing_data

		local endResult = HandleResult(pcall(playing.Play, playing, ply, mv, cmd, unpack(playingData)))

		-- 异常处理
		local succ, err = endResult[1], endResult[2]
		if not succ then
			ErrorNoHalt(string.format('Action "%s" Play error: %s\n', playing.Name, err))
			ForceEnd(ply)
			return
		end

		if not endResult[2] then
			return
		end

		if endResult then
			ply.ultipar_playing = nil
			ply.ultipar_playing_data = nil

			playing:Clear(ply, unpack(endResult, 2))

			local effect = GetPlayerCurrentEffect(ply, playing)
			if effect then 
				effect:clear(ply, unpack(endResult, 2)) 
			end

			StartTriggerNet(ply)
				-- 这里endResult第一位是pcall的返回值, 客户端需要去掉
				WriteEnd(ply, playing.Name, endResult)
				WriteMoveControl(ply, false, false, 0, 0)
			SendTriggerNet(ply)

			hook.Run('UltiParEnd', ply, playing, endResult)
		end
	end)

	hook.Add('PlayerSpawn', 'ultipar.clear', ForceEnd)

	hook.Add('PlayerDeath', 'ultipar.clear', ForceEnd)

	hook.Add('PlayerSilentDeath', 'ultipar.clear', ForceEnd)

	concommand.Add('up_forceend', ForceEnd)
elseif CLIENT then
	function HandleTriggerData(data, point)
		point = point or 1

		local flag = data[point]
		local actionName = data[point + 1]
		local len = data[point + 2]
		
		local result = {unpack(data, point + 3, point + 2 + len)}
	
		return flag, actionName, result, point + 3 + len
	end

	net.Receive('UltiParEvents', function(len, ply)
		local data = net.ReadTable(true)
		
		ply = LocalPlayer()

		local depth = 0
		local point = 1
		while point <= #data and depth < 5 do
			local flag, actionName, result, nextPoint = HandleTriggerData(data, point)
			point = nextPoint

			local action = GetAction(actionName)
			if not action then 
				return 
			end

			local effect = GetPlayerCurrentEffect(ply, action)

			if flag == TRIGGERNW_FLAG_START then
				action:Start(ply, unpack(result))
				if effect then 
					effect:start(ply, unpack(result)) 
				end

				hook.Run('UltiParStart', ply, action, result)
			elseif flag == TRIGGERNW_FLAG_END then
				action:Clear(ply, unpack(result))
				if effect then 
					effect:clear(ply, unpack(result)) 
				end

				hook.Run('UltiParEnd', ply, action, result)
			elseif flag == TRIGGERNW_FLAG_MOVE_CONTROL then
				MoveControl.enable = result[1]
				MoveControl.ClearMovement = result[2]
				MoveControl.RemoveKeys = result[3]
				MoveControl.AddKeys = result[4]
			elseif flag == TRIGGERNW_FLAG_INTERRUPT then
				local breakerName = result[1]

				local interruptFunc = action.Interrupts[breakerName]
				if isfunction(interruptFunc) then
					interruptFunc(ply, unpack(result, 2))
				end

				hook.Run('UltiParInterrupt', ply, action, result, 
					GetAction(breakerName), nil
				)
			end
			depth = depth + 1
		end
	end)

	local MoveControl = {}
	hook.Add('CreateMove', 'ultipar.move.control', function(cmd)
		if not MoveControl.enable then return end
		if MoveControl.ClearMovement then
			cmd:ClearMovement()
		end

		local RemoveKeys = MoveControl.RemoveKeys
		if isnumber(RemoveKeys) and RemoveKeys ~= 0 then
			cmd:RemoveKey(RemoveKeys)
		end

		local AddKeys = MoveControl.AddKeys
		if isnumber(AddKeys) and AddKeys ~= 0 then
			cmd:AddKey(AddKeys)
		end
	end)

end

UltiPar.HandleResult = HandleResult

UltiPar.GetPlaying = function(ply)
	return ply.ultipar_playing
end

UltiPar.GetPlayingData = function(ply)
	return ply.ultipar_playing_data
end

UltiPar.SetPlayingData = function(ply, data)
	ply.ultipar_playing_data = data
end
--[[
	作者:白狼
	2025 11 5
--[[ 
	ActionTemplate: {
		Name = 'template',
		Effects = {
			default = {
				name = 'default',
				label = '#default',
				start = function(self, ply, ...(startdata or checkdata))
					-- 特效
				end
				clear = function(self, ply, ...(cleardata or enddata))	
					-- 清除特效
				end
			},
			...
		},

		-- 定义其他动作中断时的行为
		Interrupts = {
			ExampleAcitonName = function(self, ply, ...)
			end
		}

		Check = function(self, ply, ...)
			-- 检查动作是否可执行
			return checkdata
		end,

		Start = function(self, ply, ...(checkdata))
			-- 开始
			return startdata
		end,

		Play = function(self, ply, mv, cmd, ...(startdata or checkdata))
			-- 执行, 返回有效则结束
			return enddata
		end,

		Clear = function(self, ply, ...(enddata))
			-- 清除动作
			return cleardata
		end,
	}

	Trigger: Check -> Execute:[Start -> StartEffect]-> Play -> End[Clear -> ClearEffect]
--]]

local function printdata(flag, ...)
    local total = select('#', ...)
	print('[UltiPar]: ---------------' .. flag .. '---------------')
	print('total:', total)
    for i = 1, total do
        local data = select(i, ...)
        if istable(data) then
			print('arg'..tostring(i)..':', data)
			PrintTable(data)
		else
			print('arg'..tostring(i)..':', data)
		end
    end
	print('\n\n')
end

local function debugwireframebox(pos, mins, maxs, lifetime, color, ignoreZ)
	lifetime = lifetime or 1
	color = color or Color(255,255,255)
	ignoreZ = ignoreZ or false

	local ref = mins + pos

	local temp = maxs - mins
	local axes = {Vector(0, 0, temp.z), Vector(0, temp.y, 0), Vector(temp.x, 0, 0)}

	for i = 1, 3 do
		for j = 0, 3 do
			local pos1 = ref
			if bit.band(j, 0x01) ~= 0 then pos1 = pos1 + axes[1] end
			if bit.band(j, 0x02) ~= 0 then pos1 = pos1 + axes[2] end

			debugoverlay.Line(pos1, pos1 + axes[3], lifetime, color, ignoreZ)
		end
		axes[i], axes[3] = axes[3], axes[i]
	end
end


UltiPar = UltiPar or {}
local UltiPar = UltiPar

UltiPar.ActionSet = UltiPar.ActionSet or {}
UltiPar.DisabledSet = UltiPar.DisabledSet or {}
UltiPar.MoveControl = UltiPar.MoveControl or {} -- 移动控制, 此变量不可直接修改, 使用SetMoveControl修改, 服务器端无意义
UltiPar.emptyfunc = function() end

local DisabledSet = UltiPar.DisabledSet
local ActionSet = UltiPar.ActionSet
local MoveControl = UltiPar.MoveControl

UltiPar.GetAction = function(actionName)
	-- 不存在返回nil
	return ActionSet[actionName]
end

UltiPar.GetEffect = function(action, effectName)
	-- 不存在返回nil
	return action.Effects[effectName]
end

UltiPar.Register = function(name, action)
	-- 返回动作表和是否已存在
	-- 不支持覆盖

	local exist
	if istable(ActionSet[name]) then
		action = ActionSet[name]
		exist = true
	elseif istable(action) then
		ActionSet[name] = action
		exist = false
	else
		action = {}
		ActionSet[name] = action
		exist = false
	end

	action.Name = name
	action.Effects = action.Effects or {}
	action.Interrupts = action.Interrupts or {}
	action.Check = action.Check or function(self, ply, ...)
		printdata(
			string.format('Check Action "%s"', self.Name),
			ply, ...
		)

		return 'fuck', 'shit'
	end

	action.Start = action.Start or function(self, ply, ...)
		printdata(
			string.format('Start Action "%s"', self.Name),
			ply, ...
		)
	end

	action.Play = action.Play or function(self, ply, mv, cmd, ...)
		if CurTime() - starttime > 2 then
			printdata(
				string.format('Play Action "%s"', self.Name),
				ply, ...
			)
			return {mygod = true}
		end
	end

	action.Clear = action.Clear or function(self, ply, ...)
		printdata(
			string.format('Clear Action "%s"', self.Name),
			ply, ...
		)
	end

	if not exist and CLIENT and UltiPar.ActionManager then 
		UltiPar.ActionManager:RefreshNode() 
	end

	return action, exist
end

UltiPar.RegisterEffect = function(actionName, effectName, effect)
	-- 注册动作特效, 返回特效和是否已存在
	-- 不支持覆盖

	local action = Register(actionName)

	local exist
	if istable(action.Effects[effectName]) then
		effect = action.Effects[effectName]
		exist = true
	elseif istable(effect) then
		action.Effects[effectName] = effect
		exist = false
	else
		effect = {}
		action.Effects[effectName] = effect
		exist = false
	end
	
	effect.Name = effectName
	effect.start = effect.start or function(ply, checkdata, breakin, breakinresult)
		-- 特效
		printdata(
			string.format('start Action "%s" Effect "%s"', actionName, effectName),
			ply, checkdata, breakin, breakinresult
		)
	end

	effect.clear = effect.clear or function(ply, checkdata, enddata, breaker, breakresult)
		-- 当中断或强制退出时enddata为nil, 否则为表
		-- 强制中断时 breaker 为 true	
		-- 清除特效
		printdata(
			string.format('clear Action "%s" Effect "%s"', actionName, effectName),
			ply, checkdata, enddata, breaker, breakresult
		)
	end

	return effect, exist
end

UltiPar.RegisterEffectEasy = function(actionName, effectName, effect)
	-- 注册动作特效, 返回特效和是否已存在
	-- 支持覆盖
	local action = GetAction(actionName)
	if not action then
		ErrorNoHalt(string.format('Action "%s" not found', actionName))
		return
	end

	local default = GetEffect(action, 'default')
	if not default then
		print(string.format('Action "%s" has no default effect', actionName))
		default = {}
	end

	return RegisterEffect(
		actionName, 
		effectName, 
		table.Merge(table.Copy(default), effect)
	)
end


UltiPar.GetPlayingData = function(ply)
	return ply.ultipar_playing and ply.ultipar_playing[3] or nil
end

UltiPar.GetPlayingData = function(ply)
	return ply.ultipar_playing_data
end

UltiPar.SetPlayingData = function(ply, data)
	if not istable(data) then
		Error(string.format('SetPlayingData: data must be a table, but got %s', type(data)))
	end

	ply.ultipar_playing_data = data
end

UltiPar.CheckInterrupt = function(ply, action, breakerName)
	if isfunction(action.Interrupts[breakerName]) then
		return action.Interrupts[breakerName](ply)
	end
end

UltiPar.GetPlayerEffect = function(ply, action)
	-- 获取指定玩家当前动作的特效
	if ply.ultipar_effect_config[action.Name] == 'Custom' then
		local CustomEffects = ply.ultipar_effect_config['CUSTOM']
		return CustomEffects and CustomEffects[action.Name] or nil
	else
		return action.Effects[ply.ultipar_effect_config[action.Name] or 'default']
	end
end

UltiPar.IsActionDisable = function(actionName)
	return DisabledSet[actionName]
end

UltiPar.SetActionDisable = function(actionName, disable)
	DisabledSet[actionName] = disable
end

UltiPar.ToggleActionDisable = function(actionName)
	DisabledSet[actionName] = !DisabledSet[actionName]
end


UltiPar.LoadLuaFiles = function(path)
	local dir = string.format('ultipar/%s/', path)
	local filelist = file.Find(dir .. '*.lua', 'LUA')

	for _, filename in pairs(filelist) do
		client = string.StartWith(filename, 'cl_')
		server = string.StartWith(filename, 'sv_')

		if SERVER then
			if not client then
				include(dir .. filename)
				print('[UltiPar]: AddFile:' .. filename)
			end

			if not server then
				AddCSLuaFile(dir .. filename)
			end
		else
			if client or not server then
				include(dir .. filename)
				print('[UltiPar]: AddFile:' .. filename)
			end
		end
	end
end


UltiPar.LoadLuaFiles('core')
UltiPar.LoadLuaFiles('actions')
UltiPar.LoadLuaFiles('effects')
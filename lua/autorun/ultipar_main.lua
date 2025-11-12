--[[
	作者:白狼
	2025 11 5
--[[ 
	ActionTemplate: {
		Name = 'template',
		Effects = {
			default = {
				name = 'default',
				start = function(self, ply, ...(checkResult))
					-- 特效
				end
				clear = function(self, ply, ...(endResult))	
					-- 清除特效
				end
			},
			...
		},

		-- 定义其他动作中断时的行为
		Interrupts = {
			ExampleAcitonName = true
		}

		InterruptsFunc = {
			ExampleAcitonName = function(self, ply, playingAction, ...(checkResult))
				-- 在这里定义中断行为
				-- 可能需要清理特效之类的
				return (true or false) -- 是否中断
			end
		},

		Check = function(self, ply, ...)
			-- 检查动作是否可执行
			return checkResult
		end,

		Start = function(self, ply, ...(checkResult))
		end,

		Play = function(self, ply, mv, cmd, ...(checkResult))
			-- 执行, 返回有效则结束
			return endResult
		end,

		Clear = function(self, ply, mv, cmd, ...(endResult))
		end,
	}

	Trigger: Check -> Start -> StartEffect-> Play -> Clear -> ClearEffect
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
UltiPar.emptyfunc = function() end
UltiPar.printdata = printdata

local DisabledSet = UltiPar.DisabledSet
local ActionSet = UltiPar.ActionSet


UltiPar.GetAction = function(actionName)
	-- 不存在返回nil
	return ActionSet[actionName]
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
	action.InterruptsFunc = action.InterruptsFunc or {}
	action.Check = action.Check or function(self, ply, ...)
		printdata(
			string.format('Check Action "%s"', self.Name),
			ply, ...
		)

		return false
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
			return true
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

UltiPar.IsActionDisable = function(actionName)
	return DisabledSet[actionName]
end

UltiPar.SetActionDisable = function(actionName, disable)
	DisabledSet[actionName] = disable
end

UltiPar.ToggleActionDisable = function(actionName)
	DisabledSet[actionName] = !DisabledSet[actionName]
end

UltiPar.EnableInterrupt = function(actionName1, actionName2)
	local action1 = UltiPar.Register(actionName1)
	action1.Interrupts[actionName2] = true
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
if CLIENT then
	UltiPar.LoadUserDataFromDisk = function(path)
		-- 从磁盘加载用户数据
		local content = file.Read(path, 'DATA')

		if content == nil then
			print(string.format('[UltiPar]: LoadUserDataFromDisk() - file "%s" content is nil', path))
			return {}
		else
			local data = util.JSONToTable(content)
			if istable(data) then
				return data
			else
				ErrorNoHalt(string.format('UltiPar.LoadUserDataFromDisk() - file "%s" content is not valid json\n', path))
				return {}
			end
		end
	end

	UltiPar.SaveUserDataToDisk = function(data, path)
		if not istable(data) then
			ErrorNoHalt(string.format('SaveUserDataToDisk: data must be a table, but got %s\n', type(data)))
			return
		end

		local content = util.TableToJSON(data, true)
		if content == nil then
			ErrorNoHalt(string.format('SaveUserDataToDisk: table to json failed, path: %s\n', path))
			return
		end

		local succ = file.Write(path, content)
		print(string.format('[UltiPar]: save user data to disk %s, result: %s', path, succ))
	end
end


UltiPar.LoadLuaFiles('core')
UltiPar.LoadLuaFiles('actions')
UltiPar.LoadLuaFiles('effects')
UltiPar.LoadLuaFiles('effectseasy')
UltiPar.Version = '2.1.0'

file.CreateDir('ultipar')

if SERVER then
	concommand.Add('up_debug_sv', function()
		PrintTable(UltiPar)
	end)
elseif CLIENT then
	concommand.Add('up_debug_cl', function()
		PrintTable(UltiPar)
	end)
end

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
				start = function(self, ply, checkdata, breakin, breakinresult)
					-- 特效
				end
				clear = function(self, ply, checkdata, enddata, breaker, breakresult)	
					-- 清除特效
				end
			},
			...
		},

		-- 指定了可以中断该动作的其他动作
		Interrupts = {
			ExampleAcitonName = true
		}

		Check = function(self, ply, appenddata)
			-- 检查动作是否可执行
			-- 返回值如果不是表则自动包装为表
			return checkdata
		end,

		Start = function(self, ply, checkdata, breakin, breakinresult)
			-- 开始
			-- 可以返回表覆盖checkdata
		end,

		Play = function(self, ply, mv, cmd, checkdata, starttime)
			-- 执行, 如果返回真, 则结束动作
			-- 返回值如果不是表则自动包装为表
			return enddata
		end,

		Clear = function(self, ply, checkdata, enddata, breaker, breakresult)
			-- 当中断或强制退出时enddata为nil, 否则为表
			-- 强制中断时 breaker 为 true
			-- 清除动作
		end,
	}

	Trigger: Check -> Execute:[StartEffect, Start]-> Play -> End[ClearEffect, Clear]
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
UltiPar.ActionSet = UltiPar.ActionSet or {}
UltiPar.DisabledSet = UltiPar.DisabledSet or {}
UltiPar.MoveControl = UltiPar.MoveControl or {} -- 移动控制, 此变量不可直接修改, 使用SetMoveControl修改, 服务器端无意义
UltiPar.emptyfunc = function() end

local DisabledSet = UltiPar.DisabledSet
local ActionSet = UltiPar.ActionSet
local MoveControl = UltiPar.MoveControl

local function GetAction(actionName)
	-- 获取动作
	-- 返回动作表, 如果不存在则返回nil
	return ActionSet[actionName]
end

local function GetEffect(action, effect)
	-- 获取特效
	-- 返回特效表, 如果不存在则返回nil
	return action.Effects[effect]
end

local function Register(name, action)
	-- 注册动作, 返回动作和是否已存在
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
	action.Check = action.Check or function(self, ply, appenddata)
		printdata(
			string.format('Check Action "%s"', self.Name),
			ply, appenddata
		)

		return {fuck = true}
	end

	action.Start = action.Start or function(self, ply, checkdata, breakin, breakinresult)
		printdata(
			string.format('Start Action "%s"', self.Name),
			ply, checkdata, breakin, breakinresult
		)
	end

	action.Play = action.Play or function(self, ply, mv, cmd, checkdata, starttime)
		if CurTime() - starttime > 2 then
			printdata(
				string.format('Play Action "%s"', self.Name),
				ply, checkdata, starttime
			)

			return {mygod = true}
		end
	end

	action.Clear = action.Clear or function(self, ply, checkdata, enddata, breaker, breakresult)
		printdata(
			string.format('Clear Action "%s"', self.Name),
			ply, checkdata, enddata, breaker, breakresult
		)
	end

	if not exist and CLIENT and UltiPar.ActionManager then 
		UltiPar.ActionManager:RefreshNode() 
	end

	return action, exist
end

local function RegisterEffect(actionName, effectName, effect)
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

local function EnableInterrupt(action, actionName2)
	-- 启用中断
	action.Interrupts[actionName2] = true
end

local function GetCurrentAction(ply)
	-- 获取当前播放的动作
	return ply.ultipar_playing and ply.ultipar_playing[1] or nil
end

local function GetCurrentActionCheckResult(ply)
	return ply.ultipar_playing and ply.ultipar_playing[2] or nil
end

local function GetCurrentActionStartTime(ply)
	return ply.ultipar_playing and ply.ultipar_playing[3] or nil
end

local function GetCurrentData(ply)
	-- 获取当前播放数据
	-- action, checkresult, starttime
	if ply.ultipar_playing then
		return unpack(ply.ultipar_playing)
	else
		return nil
	end
end

local function SetCurrentData(ply, action, checkresult, starttime)
	-- 设置当前播放数据
	-- action, checkresult, starttime
	if action then
		ply.ultipar_playing = {
			action, 
			checkresult, 
			starttime or CurTime()
		}
	else
		ply.ultipar_playing = nil
	end
end

local function AllowInterrupt(ply, action, breakerName)
	-- 允许中断
	return action.Interrupts[breakerName] ~= nil
end

local function GetPlayerEffect(ply, action)
	-- 获取指定玩家当前动作的特效
	return action.Effects[ply.ultipar_effect_config[action.Name] or 'default']
end

local function IsActionDisable(actionName)
	-- 检查动作是否启用
	return DisabledSet[actionName]
end

local function SetActionDisable(actionName, disable)
	-- 设置动作是否禁用
	DisabledSet[actionName] = disable
end

local function ToggleActionDisable(actionName)
	-- 切换动作禁用状态
	DisabledSet[actionName] = !DisabledSet[actionName]
end

----------------移动控制
local CMoveData = FindMetaTable( "CMoveData" )

function CMoveData:RemoveKeys(keys)
	-- Using bitwise operations to clear the key bits.
	local newbuttons = bit.band(self:GetButtons(), bit.bnot(keys))
	self:SetButtons(newbuttons)
end

function CMoveData:AddKeys(keys)
	local newbuttons = bit.bor(self:GetButtons(), keys)
	self:SetButtons(newbuttons)
end

local function SetMoveControl(ply, enable, ClearMovement, RemoveKeys, AddKeys)
	if SERVER then
		net.Start('UltiParMoveControl')
			net.WriteBool(enable)
			net.WriteBool(ClearMovement)
			net.WriteInt(RemoveKeys, 32)
			net.WriteInt(AddKeys, 32)
		net.Send(ply)
	elseif CLIENT then
		MoveControl.enable = enable
		MoveControl.ClearMovement = ClearMovement
		MoveControl.RemoveKeys = RemoveKeys
		MoveControl.AddKeys = AddKeys
	end
end

if SERVER then
	util.AddNetworkString('UltiParMoveControl')
elseif CLIENT then
	net.Receive('UltiParMoveControl', function()
		local enable = net.ReadBool()
		local ClearMovement = net.ReadBool()
		local RemoveKeys = net.ReadInt(32)
		local AddKeys = net.ReadInt(32)

		SetMoveControl(nil, enable, ClearMovement, RemoveKeys, AddKeys)
	end)

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
----------------

----------------触发器
local function Execute(ply, action, checkresult, breakin, breakinresult)
	-- [StartEffect, Start]
	if not action then return end
	
	-- 执行动作
	checkresult = action:Start(ply, checkresult, breakin, breakinresult) or checkresult

	-- 执行特效
	local effect = GetPlayerEffect(ply, action)
	if effect then effect:start(ply, checkresult, breakin, breakinresult) end

	-- 标记播放
	SetCurrentData(ply, action, checkresult, CurTime())

	hook.Run('UltiParExecute', ply, action, checkresult, breakin, breakinresult)
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

	local currentAciton = GetCurrentAction(ply)
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

		Execute(ply, action, checkresult, currentAciton, currentCheckresult)

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
			ForceEnd(ply)
			ErrorNoHalt(string.format('Action "%s" Play error: %s\n', action.Name, err))
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

		Execute(ply, action, checkresult, currentAciton, currentCheckresult)
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
----------------
UltiPar.SetMoveControl = SetMoveControl
UltiPar.SetCurrentData = SetCurrentData
UltiPar.GetCurrentAction = GetCurrentAction
UltiPar.GetCurrentActionCheckResult = GetCurrentActionCheckResult
UltiPar.GetCurrentActionStartTime = GetCurrentActionStartTime
UltiPar.GetCurrentData = GetCurrentData
UltiPar.ToggleActionDisable = ToggleActionDisable
UltiPar.GetAction = GetAction
UltiPar.GetPlayerEffect = GetPlayerEffect
UltiPar.GetEffect = GetEffect
UltiPar.Trigger = Trigger
UltiPar.Register = Register
UltiPar.RegisterEffect = RegisterEffect
UltiPar.AllowInterrupt = AllowInterrupt
UltiPar.SetActionDisable = SetActionDisable
UltiPar.IsActionDisable = IsActionDisable
UltiPar.debugwireframebox = debugwireframebox
UltiPar.EnableInterrupt = EnableInterrupt
UltiPar.End = End
UltiPar.Execute = Execute


UltiPar.CreateConVars = function(convars)
	for _, v in ipairs(convars) do
		CreateConVar(v.name, v.default, v.flags or { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
	end
end

if CLIENT then
	local white = Color(255, 255, 255)
	local function GetConVarPhrase(name)
		-- 替换第一个下划线为点号
		local start, ending, phrase = string.find(name, "_", 1)

		if start == nil then
			return name
		else
			return '#' .. name:sub(1, start - 1) .. '.' .. name:sub(ending + 1)
		end
	end

	UltiPar.CreateConVarMenu = function(panel, convars)
		for _, v in ipairs(convars) do
			local name = v.name
			local widget = v.widget or 'NumSlider'
			local default = v.default or '0'
			local label = v.label or GetConVarPhrase(name)

			if widget == 'NumSlider' then
				panel:NumSlider(
					label, 
					name, 
					v.min or 0, v.max or 1, 
					v.decimals or 2
				)
			elseif widget == 'CheckBox' then
				panel:CheckBox(label, name)
			elseif widget == 'ComboBox' then
				panel:ComboBox(
					label, 
					name, 
					v.choices or {}
				)
			elseif widget == 'TextEntry' then
				panel:TextEntry(label, name)
			end

			if v.help then
				if isstring(v.help) then
					panel:ControlHelp(v.help)
				else
					panel:ControlHelp(label .. '.' .. 'help')
				end
			end
		end
		
		local defaultButton = panel:Button('#default')
		
		defaultButton.DoClick = function()
			for _, v in ipairs(convars) do
				RunConsoleCommand(v.name, v.default or '0')
			end
		end
	end

	UltiPar.CreateActionEditor = function(actionName)
		local action = UltiPar.GetAction(actionName)

		local Window = vgui.Create('DFrame')
		Window:SetTitle(language.GetPhrase('ultipar.actionmanager') .. '  ' .. actionName)
		Window:MakePopup()
		Window:SetSizable(true)
		Window:SetSize(400, 300)
		Window:Center()
		Window:SetDeleteOnClose(true)

		local Tabs = vgui.Create('DPropertySheet', Window)
		Tabs:Dock(FILL)

		local effectConfig = LocalPlayer().ultipar_effect_config
		if istable(effectConfig) then
			local UserPanel = vgui.Create('DPanel', Tabs)
			UserPanel:Dock(FILL)

			local effecttree = vgui.Create('DTree', UserPanel)
			effecttree:Dock(FILL)

			effecttree.RefreshNode = function(self)
				self:Clear()
				for k, v in pairs(action.Effects) do
					local icon
					if effectConfig[action.Name] == k then
						icon = 'icon16/accept.png'
					else
						icon = isstring(v.icon) and v.icon or 'icon16/attach.png'
					end
					local label = isstring(v.label) and v.label or k

					local node = self:AddNode(label, icon)
					node.effect = k

					local playButton = vgui.Create('DButton', node)
					playButton:SetSize(60, 18)
					// playButton:SetPos(170, 0)
					playButton:Dock(RIGHT)
					
					playButton:SetText('')
					playButton:SetIcon('icon16/cd_go.png')
					
					playButton.DoClick = function()
						effectConfig[action.Name] = node.effect
						
						UltiPar.SendEffectConfigToServer(effectConfig)
						UltiPar.SaveEffectConfigToDisk(effectConfig)
						effecttree:RefreshNode()

						UltiPar.EffectTest(LocalPlayer(), action.Name, node.effect)
					end
				end
			end

			local curSelectedNode = nil 
			effecttree.OnNodeSelected = function(self, selNode)
				if curSelectedNode == selNode then
					effectConfig[action.Name] = selNode.effect
					
					UltiPar.SendEffectConfigToServer(effectConfig)
					UltiPar.SaveEffectConfigToDisk(effectConfig)
					effecttree:RefreshNode()

					curSelectedNode = nil
				else
					curSelectedNode = selNode
				end
			end

			effecttree:RefreshNode()

			Tabs:AddSheet('#ultipar.effect', UserPanel, 'icon16/user.png', false, false, '')
		end

		if isfunction(action.CreateOptionMenu) then
			local DScrollPanel = vgui.Create('DScrollPanel', Tabs)
			local OptionPanel = vgui.Create('DForm', DScrollPanel)
			OptionPanel:Dock(FILL)
			OptionPanel.Paint = function(self, w, h)
				draw.RoundedBox(0, 0, 0, w, h, white)
			end

			action.CreateOptionMenu(OptionPanel)

			Tabs:AddSheet('#ultipar.options', DScrollPanel, 'icon16/wrench.png', false, false, '')
		end
	end
end

-- 加载动作文件
local function LoadLuaFiles()
	local filelist = file.Find('ultipar/*.lua', 'LUA')
	for _, filename in pairs(filelist) do
		client = string.StartWith(filename, 'cl_')
		server = string.StartWith(filename, 'sv_')

		if SERVER then
			if not client then
				include('ultipar/' .. filename)
				print('[UltiPar]: AddFile:' .. filename)
			end

			if not server then
				AddCSLuaFile('ultipar/' .. filename)
			end
		else
			if client or not server then
				include('ultipar/' .. filename)
				print('[UltiPar]: AddFile:' .. filename)
			end
		end
	end
end

UltiPar.LoadLuaFiles = function()
	if CLIENT then
		if not GetConVar('developer'):GetBool() then
			LocalPlayer():ChatPrint('[UltiPar]: must set "developer" to 1 before loading lua files')
			return
		end

		net.Start('UltiParLoadLuaFiles')
		net.SendToServer()
	elseif SERVER then
		LoadLuaFiles()
		net.Start('UltiParLoadLuaFiles')
		net.Broadcast()
	end
end

if SERVER then
	util.AddNetworkString('UltiParLoadLuaFiles')

	net.Receive('UltiParLoadLuaFiles', function(len, ply)
		if not IsValid(ply) or not ply:IsSuperAdmin() then 
			ply:ChatPrint('[UltiPar]: must be super admin to load lua files')
			return 
		end
		UltiPar.LoadLuaFiles()
	end)
elseif CLIENT then
	net.Receive('UltiParLoadLuaFiles', function()
		LoadLuaFiles()
	end)
end

LoadLuaFiles()
--[[
	作者:白狼
	2025 11 1

	使用ActionSet存储动作
	ActionSet以及Action.Effects具有单向写入的性质, 不支持覆盖。
	在这里, 我们使用API Register和RegisterEffect注册动作和特效, 而不是直接操作ActionSet
--]]

--[[ 
	ActionTemplate: {
		Name = 'template',
		Effects = {
			default = {
				label = '#default',
				func = function(ply, checkdata)
					-- 特效
				end
			},
			...
		},

		-- 指定了可以中断该动作的其他动作
		Interrupts = {
			ExampleAciton = 1
		}

		Check = function(ply)
			-- 检查动作是否可执行
			return checkdata
		end,

		Play = function(ply, checkdata)
			-- 播放动作
		end,

		CheckEnd = number or function(ply, checkdata)
			-- 检查动作是否执行完毕
			return checkend
		end,

		Clear = function(ply, checkdata)
			-- 清除动作
		end,
	}
]]--

UltiPar = UltiPar or {}
UltiPar.ActionSet = UltiPar.ActionSet or {}
UltiPar.MoveControl = {} -- 移动控制, 此变量不可直接修改, 使用SetMoveControl修改


local ActionSet = UltiPar.ActionSet

local function GetAction(actionName)
	-- 获取动作
	return ActionSet[actionName]
end

local function GetCurrentEffect(ply, action)
	-- 获取指定玩家当前动作的特效
	return action.Effects[ply.ultipar_effect_config[action.Name] or 'default']
end

local function GetEffect(action, effect)
	-- 获取特效
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
	action.Check = action.Check or function(ply)
		ErrorNoHalt(string.format('[UltiPar]: Action "%s" Check function is not defined.\n', name))
		return false
	end

	action.Play = action.Play or function(ply, checkdata)
		ErrorNoHalt(string.format('[UltiPar]: Action "%s" Play function is not defined.\n', name))
	end

	action.CheckEnd = action.CheckEnd or function(ply, checkdata)
		ErrorNoHalt(string.format('[UltiPar]: Action "%s" CheckEnd is not defined.\n', name))
		return true
	end

	action.Clear = action.Clear or function(ply, checkdata)
		ErrorNoHalt(string.format('[UltiPar]: Action "%s" Clear is not defined.\n', name))
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

	effect.func = effect.func or function(ply, checkdata)
		-- 特效
		ErrorNoHalt(string.format('Effect "%s" func is not defined.\n', effectName))
	end

	return effect, exist
end

local function AllowInterrupt(ply, actionName)
	-- 允许中断
	local action = GetAction(ply.ultipar_playing)
	return action and action.Interrupts[actionName] ~= nil
end

local function Trigger(ply, actionName, appenddata)
	-- 触发动作
	-- 客户端调用执行Check, 成功后向服务器请求执行Play等
	-- 服务器调用执行Check, 成功后执行Play等并通知客户端执行Play等

	local action = GetAction(actionName)

	if ply.ultipar_playing and not AllowInterrupt(ply, actionName) or not action then 
		return 
	end

	local checkresult = action.Check(ply, appenddata)
	if not checkresult then
		return
	end

	if SERVER then
		hook.Run('UltiParStart', ply, actionName, checkresult)
	
		local interruptedActionName = ply.ultipar_playing
		local interruptedCheckresult
		local interruptedAction
		if interruptedActionName then
			interruptedAction = GetAction(interruptedActionName)
			interruptedCheckresult = ply.ultipar_end[2]
			hook.Run('UltiParEnd', ply, interruptedActionName, interruptedCheckresult, true)
			interruptedAction.Clear(ply, interruptedCheckresult)
		end

		-- 标记进行中的动作和结束条件, 如果结束条件是实数则使用定时结束, 如果是函数则使用函数结束
		local checkend = action.CheckEnd
		ply.ultipar_playing = actionName
		ply.ultipar_end = {
			isnumber(checkend) and CurTime() + checkend or checkend,
			checkresult
		}
		
		-- 执行动作
		action.Play(ply, checkresult)

		-- 执行特效
		local effect = GetCurrentEffect(ply, action)
		if effect then effect.func(ply, checkresult) end

		net.Start('UltiParPlay')
			net.WriteString(actionName)
			net.WriteTable(checkresult)
			net.WriteString(interruptedActionName or '')
			net.WriteTable(interruptedCheckresult or {})
		net.Send(ply)
	elseif CLIENT then
		net.Start('UltiParPlay')
			net.WriteString(actionName)
			net.WriteTable(checkresult)
		net.SendToServer()
	end
end


UltiPar.debugwireframebox = function(pos, mins, maxs, lifetime, color, ignoreZ)
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

UltiPar.GetAction = GetAction
UltiPar.GetCurrentEffect = GetCurrentEffect
UltiPar.GetEffect = GetEffect
UltiPar.Trigger = Trigger
UltiPar.Register = Register
UltiPar.RegisterEffect = RegisterEffect
UltiPar.AllowInterrupt = AllowInterrupt

if SERVER then
	util.AddNetworkString('UltiParMoveControl')
	util.AddNetworkString('UltiParPlay')
	util.AddNetworkString('UltiParEnd')
	util.AddNetworkString('UltiParEffectConfig')
	util.AddNetworkString('UltiParEffectTest')

	net.Receive('UltiParEffectTest', function(len, ply)
		local actionName = net.ReadString()
		local effect = net.ReadString()
		
		local action = GetAction(actionName)
		if not action then
			return
		end

		local effect = GetEffect(action, effect)
		if not effect then
			return
		end

		effect.func(ply, nil)
	end)

	net.Receive('UltiParPlay', function(len, ply)
		local actionName = net.ReadString()
		local checkresult = net.ReadTable()

		local action = GetAction(actionName)

		if ply.ultipar_playing and not AllowInterrupt(ply, actionName) or not action then 
			return 
		end

		hook.Run('UltiParStart', ply, actionName, checkresult)
	
		local interruptedActionName = ply.ultipar_playing
		local interruptedCheckresult
		local interruptedAction
		if interruptedActionName then
			interruptedAction = GetAction(interruptedActionName)
			interruptedCheckresult = ply.ultipar_end[2]
			hook.Run('UltiParEnd', ply, interruptedActionName, interruptedCheckresult, true)
			interruptedAction.Clear(ply, interruptedCheckresult)
		end

		-- 标记进行中的动作和结束条件, 如果结束条件是实数则使用定时结束, 如果是函数则使用函数结束
		local checkend = action.CheckEnd
		ply.ultipar_playing = actionName
		ply.ultipar_end = {
			isnumber(checkend) and CurTime() + checkend or checkend,
			checkresult
		}
		
		-- 执行动作
		action.Play(ply, checkresult)

		-- 执行特效
		local effect = GetCurrentEffect(ply, action)
		if effect then effect.func(ply, checkresult) end

		net.Start('UltiParPlay')
			net.WriteString(actionName)
			net.WriteTable(checkresult)
			net.WriteString(interruptedActionName or '')
			net.WriteTable(interruptedCheckresult or {})
		net.Send(ply)
	end)

	net.Receive('UltiParEffectConfig', function(len, ply)
		local effectConfig = net.ReadTable()
		ply.ultipar_effect_config = effectConfig or ply.ultipar_effect_config
	end)

	local function SetMoveControl(ply, enable, ClearMovement, RemoveKeys, AddKeys)
		net.Start('UltiParMoveControl')
			net.WriteBool(enable)
			net.WriteBool(ClearMovement)
			net.WriteInt(RemoveKeys, 32)
			net.WriteInt(AddKeys, 32)
		net.Send(ply)
	end

	local function EasyMoveCall(ply, mv, cmd)
		local movedata = ply.ultipar_move
		local dt = CurTime() - movedata.starttime

		mv:SetOrigin(
			LerpVector(
				dt / movedata.duration, 
				movedata.startpos, 
				movedata.endpos
			)
		) 

		if dt >= movedata.duration then 
			mv:SetOrigin(movedata.endpos)
			ply:SetMoveType(MOVETYPE_WALK)
			mv:SetVelocity(movedata.startvel)
			ply.ultipar_move = nil -- 移动结束, 清除移动数据
			SetMoveControl(ply, false, false, 0, 0)
		end
	end

	local function StartEasyMove(ply, endpos, duration, removekeys, addkeys)
		ply:SetMoveType(MOVETYPE_NOCLIP)

		ply.ultipar_move = {
			Call = EasyMoveCall,
			startpos = ply:GetPos(),
			endpos = endpos,
			duration = duration,
			starttime = CurTime(),
			startvel = ply:GetVelocity()
		}

		SetMoveControl(ply, true, true, removekeys or IN_JUMP, addkeys or 0)
	end

	hook.Add('SetupMove', 'ultipar.move', function(ply, mv, cmd)
		if not ply.ultipar_move then return end
		local call = ply.ultipar_move.Call
		local endcondition = ply.ultipar_move.EndCondition

		if isfunction(call) then
			call(ply, mv, cmd)
		else	
			-- 异常处理, 清除移动数据
			SetMoveControl(ply, false, false, 0, 0)
			ply.ultipar_move = nil
		end

		if isfunction(endcondition) and endcondition(ply, mv, cmd) then
			ply.ultipar_move = nil
		end
	end)

	hook.Add('PlayerPostThink', 'ultipar.checkend', function(ply)
		if ply.ultipar_playing == nil then return end
		local checkend, checkresult = unpack(ply.ultipar_end)

		local flag
		if isnumber(checkend) then
			flag = CurTime() > checkend	
		elseif isfunction(checkend) then
			flag = checkend(ply, checkresult)
		else
			flag = true
		end

		if flag then
			local actionName = ply.ultipar_playing
			ply.ultipar_playing = nil
			ply.ultipar_end = nil

			net.Start('UltiParEnd')
				net.WriteString(actionName)
				net.WriteTable(checkresult)
			net.Send(ply)

			local action = GetAction(actionName)
			action.Clear(ply, checkresult)
			hook.Run('UltiParEnd', ply, actionName, checkresult, false)
		end

	end)

	local function Clear(ply)
		ply.ultipar_playing = nil
		ply.ultipar_move = nil
		ply.ultipar_end = nil
		
		UltiPar.SetMoveControl(ply, false, false, 0, 0)
	end

	hook.Add('PlayerDeath', 'ultipar.clear', Clear)

	hook.Add('PlayerSilentDeath', 'ultipar.clear', Clear)
	
	hook.Add('PlayerInitialSpawn', 'ultipar.init', function(ply)
		Clear(ply)
		ply.ultipar_effect_config = ply.ultipar_effect_config or {}
	end)

	UltiPar.SetMoveControl = SetMoveControl
	UltiPar.StartEasyMove = StartEasyMove
	
	concommand.Add('up_clear', Clear)

elseif CLIENT then
	net.Receive('UltiParPlay', function(len, ply)
		local actionName = net.ReadString()
		local checkresult = net.ReadTable()
		local interruptedActionName = net.ReadString()
		local interruptedCheckresult = net.ReadTable()

		ply = LocalPlayer()

		if interruptedActionName ~= '' then
			local interruptedAction = GetAction(interruptedActionName)
			interruptedAction.Clear(ply, interruptedCheckresult)
		end


		local action = GetAction(actionName)
	
		action.Play(ply, checkresult)
	
		-- 执行特效
		local effect = GetCurrentEffect(ply, action)
		if effect then
			effect.func(ply, checkresult)
		end
	end)

	net.Receive('UltiParEnd', function(len, ply)
		local actionName = net.ReadString()
		local checkresult = net.ReadTable()

		ply = LocalPlayer()
		local action = UltiPar.GetAction(actionName)

		action.Clear(ply, checkresult)
	end)

	local function LoadEffectFromDisk(path)
		-- 从磁盘加载动作的特效配置
		path = path or 'ultipar_effect_config.json'

		local content = file.Read(path, 'DATA')

		if content == nil then
			return nil
		else
			local default_config = util.JSONToTable(content)
			if istable(default_config) then
				return default_config
			else
				-- 文件内容损坏
				ErrorNoHalt(string.format('UltiPar.LoadEffectFromDisk() - file "%s" content is not valid json\n', path))
				return nil
			end
		end
	end

	local function SaveEffectConfigToDisk(effectConfig, path)
		-- 保存动作的特效配置到磁盘
		path = path or 'ultipar_effect_config.json'
		local content = util.TableToJSON(effectConfig)
		local succ = file.Write(path, content)
		print(string.format('[UltiPar]: save effect config to disk %s, result: %s', path, succ))
	end

	local function SendEffectConfigToServer(effectConfig)
		net.Start('UltiParEffectConfig')
			net.WriteTable(effectConfig)
		net.SendToServer()
	end

	local function EffectTest(actionName, effect)
		net.Start('UltiParEffectTest')
			net.WriteString(actionName)
			net.WriteString(effect)
		net.SendToServer()
	end
	
	hook.Add('KeyPress', 'ultipar.init', function(ply, key)
		if key == IN_FORWARD then 
			local effectConfig = LoadEffectFromDisk()
			if effectConfig ~= nil then
				SendEffectConfigToServer(effectConfig)
			else
				print('[UltiPar]: use default effect config')
			end
			LocalPlayer().ultipar_effect_config = effectConfig or {}
			 
			hook.Remove('KeyPress', 'ultipar.init')
		end
	end)

	local MoveControl = UltiPar.MoveControl
	local function SetMoveControl(_, enable, ClearMovement, RemoveKeys, AddKeys)
		MoveControl.enable = enable
		MoveControl.ClearMovement = ClearMovement
		MoveControl.RemoveKeys = RemoveKeys
		MoveControl.AddKeys = AddKeys
	end

	net.Receive('UltiParMoveControl', function()
		local enable = net.ReadBool()
		local ClearMovement = net.ReadBool()
		local RemoveKeys = net.ReadInt(32)
		local AddKeys = net.ReadInt(32)

		SetMoveControl(nil, 
			enable, 
			ClearMovement, 
			RemoveKeys, 
			AddKeys
		)
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


	local vecpunch_vel = Vector()
	local vecpunch_offset = Vector()

	local angpunch_vel = Vector()
	local angpunch_offset = Vector()

	local punch = false

	hook.Add('CalcView', 'ultipar.punch', function(ply, pos, angles, fov)
		if not punch then return end

		local dt = FrameTime()
		local vecacc = -(vecpunch_offset * 50 + 10 * vecpunch_vel)
		vecpunch_offset = vecpunch_offset + vecpunch_vel * dt 
		vecpunch_vel = vecpunch_vel + vecacc * dt	

		local angacc = -(angpunch_offset * 50 + 10 * angpunch_vel)
		angpunch_offset = angpunch_offset + angpunch_vel * dt 
		angpunch_vel = angpunch_vel + angacc * dt	

		local view = GAMEMODE:CalcView(ply, pos, angles, fov) 
		local eyeAngles = view.angles - ply:GetViewPunchAngles()

		view.origin = view.origin + eyeAngles:Forward() * vecpunch_offset.x +
			eyeAngles:Right() * vecpunch_offset.y +
			eyeAngles:Up() * vecpunch_offset.z

		view.angles = view.angles + Angle(angpunch_offset.x, angpunch_offset.y, angpunch_offset.z)

		local vecoffsetLen = vecpunch_offset:LengthSqr()
		local angoffsetLen = angpunch_offset:LengthSqr()
		local vecvelLen = vecpunch_vel:LengthSqr()
		local angvelLen = angpunch_vel:LengthSqr()

		if vecoffsetLen < 0.1 and vecvelLen < 0.1 and angoffsetLen < 0.1 and angvelLen < 0.1 then
			vecpunch_offset = Vector()
			vecpunch_vel = Vector()

			angpunch_offset = Vector()
			angpunch_vel = Vector()

			punch = false
		end

		return view
	end)

	UltiPar.SetVecPunchOffset = function(vec)
		punch = true
		vecpunch_offset = vec
	end

	UltiPar.SetAngPunchOffset = function(vec)
		punch = true
		angpunch_offset = ang
	end

	UltiPar.SetVecPunchVel = function(vec)
		punch = true
		vecpunch_vel = vec
	end

	UltiPar.SetAngPunchVel = function(vec)
		punch = true
		angpunch_vel = vec
	end

	UltiPar.GetVecPunchOffset = function() return vecpunch_offset end
	UltiPar.GetAngPunchOffset = function() return angpunch_offset end
	UltiPar.GetVecPunchVel = function() return vecpunch_vel end
	UltiPar.GetAngPunchVel = function() return angpunch_vel end

	UltiPar.SetMoveControl = SetMoveControl
	UltiPar.LoadEffectFromDisk = LoadEffectFromDisk
	UltiPar.SendEffectConfigToServer = SendEffectConfigToServer
	UltiPar.SaveEffectConfigToDisk = SaveEffectConfigToDisk
	UltiPar.EffectTest = EffectTest
end

-- 加载动作文件
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

if CLIENT then
	local white = Color(255, 255, 255)
	local function drawwhite(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, white)
	end

	-- UI界面
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
					playButton:SetSize(36, 18)
					playButton:SetPos(170, 0)
					
					playButton:SetText('')
					playButton:SetIcon('icon16/cd_go.png')
					
					playButton.DoClick = function()
						-- 服务器端特效
						UltiPar.EffectTest(action.Name, node.effect)

						-- 客户端特效
						local effect = GetEffect(action, node.effect)
						if isfunction(effect.func) then
							effect.func(ply, nil)
						end
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
			OptionPanel.Paint = drawwhite

			action.CreateOptionMenu(OptionPanel)

			Tabs:AddSheet('#ultipar.options', DScrollPanel, 'icon16/wrench.png', false, false, '')
		end
	end

	hook.Add('PopulateToolMenu', 'ultipar.menu', function()
		spawnmenu.AddToolMenuOption('Options', 
			language.GetPhrase('ultipar.category'), 
			'ultipar.menu', 
			language.GetPhrase('ultipar.actionmanager'), '', '', 
			function(panel)
				panel:Clear()
			
				local tree = vgui.Create('DTree')
				tree:SetSize(200, 200)

				local curSelectedNode = nil 
				tree.OnNodeSelected = function(self, selNode)
					if curSelectedNode == selNode then
						UltiPar.CreateActionEditor(selNode.action)
						curSelectedNode = nil
					else
						curSelectedNode = selNode
					end
				end

				tree.RefreshNode = function(self)
					tree:Clear()
					for k, v in pairs(UltiPar.ActionSet) do
						local node = self:AddNode(
							isstring(v.label) and v.label or k, 
							isstring(v.icon) and v.icon or 'icon32/tool.png'
						)
						node.action = v.Name
					end
				end
				tree:RefreshNode()

				local RefreshButton = panel:Button('#ultipar.refresh')
				RefreshButton.DoClick = function()
					tree:RefreshNode()
				end

				panel:AddItem(tree)

				UltiPar.ActionManager = tree
			end)
	end)
end

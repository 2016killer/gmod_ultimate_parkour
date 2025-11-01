--[[
	使用ActionSet存储动作
	ActionSet以及Action.Effects具有单向写入的性质, 不支持覆盖。
	在这里, 我们使用API Register和RegisterEffect注册动作和特效, 而不是直接操作ActionSet
--]]

UltiPar = UltiPar or {}
UltiPar.ActionSet = UltiPar.ActionSet or {}
UltiPar.MoveControl = {} -- 移动控制, 此变量不可直接修改, 使用SetMoveControl修改

local ActionSet = UltiPar.ActionSet

local emptyeffect = {}
local emptyaction = {
	Name = 'Error',
	Effects = {
		default = emptyeffect,
	}
}

local function GetAction(target)
	-- 获取动作, 返回动作表和动作名, 带有存在性检查
	if isstring(target) then
		return ActionSet[target], target
	elseif istable(target) then
		return target, target.Name
	else 
		ErrorNoHalt(string.format('UltiPar.GetAction() - target "%s" not valid', tostring(target)))
		return emptyaction, 'Error'
	end
end

local function GetCurrentEffect(ply, action)
	-- 获取指定玩家、指定的动作特效
	local effect = action.Effects[ply.ultipar_effect_config[action.Name] or 'default']
	if istable(effect) then
		return effect
	else
		return emptyeffect
	end
end

local function GetEffect(action, effect)
	-- 获取特效
	local effect = action.Effects[effect]
	if istable(effect) then
		return effect
	else
		return emptyeffect
	end
end

local function Register(name, action)
	-- 注册动作, 返回动作和是否已存在
	-- 不支持覆盖, 不支持有效性检查

	local result, exist
	if ActionSet[name] and istable(ActionSet[name]) then
		result = ActionSet[name]
		exist = true
	elseif istable(action) then
		action.Name = name
		ActionSet[name] = action

		result = action
		exist = false
	else
		action = {Name = name, Effects = {}}
		ActionSet[name] = action

		result = action
		exist = false
	end

	if not exist and CLIENT and action.ActionManager then 
		UltiPar.ActionManager:RefreshNode() 
	end

	return result, exist
end


local function RegisterEffect(name, effectname, effect)
	-- 注册动作特效, 返回特效和是否已存在
	-- 不支持覆盖, 不支持有效性检查

	local action, _ = Register(name)
	action.Effects = action.Effects or {}

	local result, exist
	if action.Effects[effectname] and istable(action.Effects[effectname]) then
		result = action.Effects[effectname]
		exist = true
	elseif istable(effect) then
		action.Effects[effectname] = effect

		result = effect
		exist = false
	else
		effect = {}

		result = effect
		exist = false
	end

	return result, exist
end


local function Trigger(ply, target)
	-- 触发动作
	-- 客户端调用执行Check, 成功后向服务器请求执行Play
	-- 服务器调用执行Check, 成功后执行Play并通知客户端执行 Play

	if SERVER and ply.ultipar_playing then 
		return 
	end

	-- 当动作不存在时引发异常
	local action, actionName = UltiPar.GetAction(target)

	local check = action.Check
	if isfunction(check) then
		local checkresult = check(ply)
		if checkresult then
			if SERVER and isfunction(action.Play) then
				local succ, err = pcall(hook.Run, 'UltiParStart', ply, actionName, checkresult)
				if not succ then
					ErrorNoHalt(string.format('UltiParStart hook error: %s\n', err))
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
				if isfunction(effect.func) then
					effect.func(ply, checkresult)
				end

				net.Start('UltiParPlay')
					net.WriteString(actionName)
					net.WriteTable(checkresult)
				net.Send(ply)
			elseif CLIENT then
				net.Start('UltiParPlay')
					net.WriteString(actionName)
					net.WriteTable(checkresult)
				net.SendToServer()
			end
		end
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

if SERVER then
	util.AddNetworkString('UltiParMoveControl')
	util.AddNetworkString('UltiParPlay')
	util.AddNetworkString('UltiParEnd')
	util.AddNetworkString('UltiParEffectConfig')
	util.AddNetworkString('UltiParEffectTest')

	net.Receive('UltiParEffectTest', function(len, ply)
		local actionName = net.ReadString()
		local effect = net.ReadString()
		
		local action, _ = UltiPar.GetAction(actionName)

		local effect = GetEffect(action, effect)
		if isfunction(effect.func) then
			effect.func(ply, nil)
		end
	end)

	net.Receive('UltiParPlay', function(len, ply)
		if ply.ultipar_playing then 
			return 
		end

		local target = net.ReadString()
		local checkresult = net.ReadTable()

		local action, actionName = UltiPar.GetAction(target)
		if isfunction(action.Play) then
			local succ, err = pcall(hook.Run, 'UltiParStart', ply, actionName, checkresult)
			if not succ then
				ErrorNoHalt(string.format('UltiParStart hook error: %s\n', err))
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
			if isfunction(effect.func) then
				effect.func(ply, checkresult)
			end

			net.Start('UltiParPlay')
				net.WriteString(actionName)
				net.WriteTable(checkresult)
			net.Send(ply)
		end
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
		end

		if flag then
			local succ, err = pcall(hook.Run, 'UltiParEnd', ply, ply.ultipar_playing, checkresult)
			if not succ then
				ErrorNoHalt(string.format('UltiParEnd hook error: %s\n', err))
			end
			
			net.Start('UltiParEnd')
				net.WriteString(ply.ultipar_playing)
				net.WriteTable(checkresult)
			net.Send(ply)

			local action, actionName = UltiPar.GetAction(ply.ultipar_playing)
			if isfunction(action.Clear) then
				local succ, err = pcall(action.Clear, ply, checkresult)
				if not succ then
					ErrorNoHalt(string.format('UltiParEnd action.Clear error: %s\n', err))
				end
			end

			ply.ultipar_playing = nil
			ply.ultipar_end = nil
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
		local target = net.ReadString()
		local checkresult = net.ReadTable()

		ply = LocalPlayer()
		local action, actionName = UltiPar.GetAction(target)
		if isfunction(action.Play) then	
			local succ, err = pcall(action.Play, ply, checkresult)
			if not succ then
				ErrorNoHalt(string.format('UltiParPlay action.Play error: %s\n', err))
			end

			-- 执行特效
			local effect = GetCurrentEffect(ply, action)
			if isfunction(effect.func) then
				local succ, err = pcall(effect.func, ply, checkresult)
				if not succ then
					ErrorNoHalt(string.format('UltiParPlay effect %s error: %s\n', effect.label, err))
				end
			end
		end
	end)

	net.Receive('UltiParEnd', function(len, ply)
		local target = net.ReadString()
		local checkresult = net.ReadTable()

		ply = LocalPlayer()
		local action, actionName = UltiPar.GetAction(target)
		if isfunction(action.Clear) then	
			local succ, err = pcall(action.Clear, ply, checkresult)
			if not succ then
				ErrorNoHalt(string.format('UltiParEnd action.Clear error: %s\n', err))
			end
		end
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
				ErrorNoHalt(string.format('UltiPar.LoadEffectFromDisk() - file '%s' content is not valid json\n', path))
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
	UltiPar.CreateActionEditor = function(target)
		local action, actionName = UltiPar.GetAction(target)

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

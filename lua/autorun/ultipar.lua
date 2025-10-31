UltiPar = UltiPar or {}
UltiPar.ActionSet = UltiPar.ActionSet or {}
local ActionSet = UltiPar.ActionSet

local function GetAction(target)
	-- 获取动作, 返回动作表和动作名, 带有存在性检查
	if isstring(target) then
		return ActionSet[target], target
	elseif istable(target) then
		return target, target.Name
	else 
		Error(string.format('UltiPar.GetAction() - target "%s" not valid', tostring(target)))
	end
end

local function Register(name, action)
	-- 注册动作, 返回动作表和是否已存在
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
		action = {Name = name}
		ActionSet[name] = action

		result = action
		exist = false
	end

	if not exist and CLIENT and action.ActionManager then 
		UltiPar.ActionManager:RefreshNode() 
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
				// local view = action.Views[ply.ultipar_effect[actionName]]
				// if istable(view) and isfunction(view.func) then
				// 	view.func(ply, checkresult)
				// end
				// ply.ultipar_views = nil
				// if isfunction(action.Views[]) then
				// 	action.End(ply, checkresult)
				// end

			elseif CLIENT then
				 

			end
		end
	end
end

UltiPar.GetAction = GetAction
UltiPar.Trigger = Trigger
UltiPar.Register = Register


if SERVER then
	util.AddNetworkString('UltiParPlay')

	net.Receive('UltiParPlay', function(len, ply)
		local target = net.ReadString()
		local checkresult = net.ReadTable()

		local action, actionName = UltiPar.GetAction(target)
		if isfunction(action.Play) then

		end
	end)

	local function EasyMoveCall(ply, mv, cmd)
		local dt = CurTime() - ply.ultipar_move.starttime
		
		mv:SetOrigin(
			LerpVector(
				dt / ply.ultipar_move.duration, 
				ply.ultipar_move.startpos, 
				ply.ultipar_move.endpos
			)
		) 

		if dt >= ply.ultipar_move.duration then 
			ply:SetMoveType(MOVETYPE_WALK)
			mv:SetOrigin(ply.ultipar_move.endpos)
			mv:SetVelocity(ply.ultipar_move.startvel)
			
			ply.ultipar_move = nil -- 移动结束, 清除移动数据
		end
	end

	local function StartEasyMove(ply, endpos, duration)
		ply.ultipar_move = {
			Call = EasyMoveCall,
			startpos = ply:GetPos(),
			endpos = endpos,
			duration = duration,
			starttime = CurTime(),
			startvel = ply:GetVelocity()
		}
		ply:SetMoveType(MOVETYPE_NONE)
	end

	hook.Add('SetupMove', 'ultipar.move', function(ply, mv, cmd)
		if not ply.ultipar_move then return end
		local call = ply.ultipar_move.Call
		local endcondition = ply.ultipar_move.EndCondition

		if isfunction(call) then
			call(ply, mv, cmd)
		else
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
			
			ply.ultipar_playing = nil
			ply.ultipar_end = nil
		end

	end)


	local function Clear(ply)
		ply.ultipar_playing = nil
		ply.ultipar_move = nil
		ply.ultipar_end = nil
	end

	hook.Add('PlayerDeath', 'ultipar.clear', Clear)

	hook.Add('PlayerSilentDeath', 'ultipar.clear', Clear)
	
	hook.Add('PlayerInitialSpawn', 'ultipar.init', function(ply)
		Clear(ply)
		ply.ultipar_effect = {}
	end)

	UltiPar.StartEasyMove = StartEasyMove
end

-- 加载动作文件
local filelist = file.Find('ultipar/*.lua', 'LUA')
for _, filename in pairs(filelist) do
	client = string.StartWith(filename, 'cl_')
	server = string.StartWith(filename, 'sv_')

	if SERVER then
		if not client then
			include('ultipar/' .. filename)
			print('UltiPar: AddFile:' .. filename)
		end

		if not server then
			AddCSLuaFile('ultipar/' .. filename)
		end
	else
		if client or not server then
			include('ultipar/' .. filename)
			print('UltiPar: AddFile:' .. filename)
		end
	end
end

local filelist = file.Find('ultipar/*.json', 'LUA')
for _, filename in pairs(filelist) do
	print(filename)
end

if CLIENT then
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

		local UserPanel = vgui.Create('DPanel', Tabs)
		UserPanel:Dock(FILL)

		local effecttree = vgui.Create('DTree', UserPanel)
		effecttree:Dock(FILL)

		for k, v in pairs(action.Views) do
			local node = effecttree:AddNode(
				isstring(v.label) and v.label or k, 
				isstring(v.icon) and v.icon or 'icon16/attach.png'
			)
		end

		Tabs:AddSheet('#ultipar.effect', UserPanel, 'icon16/user.png', false, false, '')
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


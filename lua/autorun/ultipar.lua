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

	if not exist and CLIENT then 
		UltiPar.ActionManager:RefreshNode() 
	end

	return result, exist
end

local function Trigger(ply, target, data)
	-- 触发动作
	if ply.ultipar_playing then 
		return 
	end

	-- 当动作不存在时引发异常
	local action, actionName = UltiPar.GetAction(target)

	local playcall = action.Play
	local check = action.Check
	local checkend = action.CheckEnd

	if isfunction(check) and check(ply, data) then
		if isfunction(playcall) then
			ply.ultipar_playing = actionName
			ply.ultipar_end = isnumber(checkend) and CurTime() + checkend or checkend

			playcall(ply, data)
		end
	end
end

UltiPar.GetAction = GetAction
UltiPar.Play = PlayAction
UltiPar.Check = Check
UltiPar.Trigger = Trigger
UltiPar.Register = Register


if SERVER then
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
		local checkend = ply.ultipar_end

		if isnumber(checkend) then
			if CurTime() > checkend then
				ply.ultipar_playing = nil
				ply.ultipar_end = nil
			end
		elseif isfunction(checkend) and checkend(ply) then
			ply.ultipar_playing = nil
			ply.ultipar_end = nil
		end
	end)

	hook.Add('PlayerSpawn', 'ultipar.init', function(ply)
		ply.ultipar_playing = nil
		ply.ultipar_move = nil
		ply.ultipar_end = nil
	end)

	concommand.Add('ultipar_move_debug', function(ply, cmd, args)
		if ply:IsAdmin() then
			local tr = ply:GetEyeTrace()
			local endpos = tr.HitPos + tr.HitNormal * 64
			StartEasyMove(ply, endpos, 1)
		end
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


		local soundbrowser = vgui.Create('DFileBrowser', UserPanel)
		function soundbrowser:OnDoubleClick(path)
			if soundbrowser.soundobj then
				soundbrowser.soundobj:Stop()
				soundbrowser.soundobj = nil	
			end
			soundbrowser.selectFile = string.sub(path, 7, -1)
			soundbrowser.soundobj = CreateSound(LocalPlayer(), soundbrowser.selectFile)
			soundbrowser.soundobj:PlayEx(1, 100)
		end

		function soundbrowser:OnRemove()
			if soundbrowser.soundobj then
				soundbrowser.soundobj:Stop()
				soundbrowser.soundobj = nil	
			end
		end

		local viewtree = vgui.Create('DTree', UserPanel)

		local div = vgui.Create('DHorizontalDivider', UserPanel)
		div:Dock(FILL)
		div:SetLeft(viewtree)
		div:SetRight(soundbrowser)
		div:SetDividerWidth(4)
		div:SetLeftMin(20) 
		div:SetRightMin(20)
		div:SetLeftWidth(200)


		Tabs:AddSheet('#ultipar.view', UserPanel, 'icon16/user.png', false, false, '')

		if isfunction(action.CreateOptionMenu) then
			local OptionPanel = vgui.Create('DPanel', Tabs)
			OptionPanel:Dock(FILL)
			action.CreateOptionMenu(OptionPanel)

			Tabs:AddSheet('#ultipar.option', OptionPanel, 'icon16/application_edit.png', false, false, '')
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




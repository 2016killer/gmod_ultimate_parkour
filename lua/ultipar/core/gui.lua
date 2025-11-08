--[[
	作者:白狼
	2025 11 1
--]]
UltiPar = UltiPar or {}

UltiPar.CreateConVars = function(convars)
	for _, v in ipairs(convars) do
		CreateConVar(v.name, v.default, v.flags or { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
	end
end

if SERVER then return end

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

local function PropertyViewText(v)
	if isstring(v) then
		return string.format('"%s"', v)
	elseif isnumber(v) then
		return string.format('%s', v)
	elseif isbool(v) then
		return string.format('%s', v and 'true' or 'false')
	elseif isvector(v) or isangle(v) then
		return string.format('[%s]', v)
	elseif isfunction(v) then
		return string.format('%s', 'function')
	elseif ismatrix(v) then
		return string.format('[%s]', v)
	elseif istable(v) then
		return string.format('%s', 'table')
	end

	return ''
end

UltiPar.CreateEffectPropertyPanel = function(actionName, effect, effecttree)
	local panel = vgui.Create('DForm')
	local iscustom = !!effect.linkName
	if iscustom then
		for k, v in pairs(effect) do
			if k == 'label' or k == 'linkName' or k == 'Name' then
				continue
			elseif isstring(v) then
				local textEntry = panel:TextEntry(k .. ':', '')
				textEntry:SetText(v)
				textEntry.OnChange = function(self)
					local val = self:GetText()
					print(k, val)
					effect[k] = val
				end
			elseif isnumber(v) then
				local numEntry = panel:TextEntry(k .. ':', '')
				numEntry:SetText(tostring(v))
				numEntry.OnChange = function(self)
					local val = tonumber(self:GetText()) or 0
					print(k, val)
					effect[k] = val
				end
			elseif isbool(v) then
				local checkBox = panel:CheckBox(k .. ':', '')
				checkBox:SetChecked(v)
				checkBox.OnChange = function(self, checked)
					print(k, checked)
					effect[k] = checked
				end
			elseif isvector(v) or isangle(v) then
				local vecEntry = panel:TextEntry(k .. ':', '')
				vecEntry:SetText(util.TableToJSON({v}))
				vecEntry.OnChange = function(self)
					local val = util.JSONToTable(self:GetText())
					if not val or not val[1] or 
						(not isvector(val[1]) and not isangle(val[1])) then
						return
					end

					val = val[1]
					print(k, val)
					effect[k] = val
				end
			end
		end

		local saveButton = vgui.Create('DButton')
		saveButton:SetText('#ultipar.save')
		saveButton.DoClick = function()
			local effectConfig = LocalPlayer().ultipar_effect_config

			effectConfig[actionName] = 'Custom'
			effectConfig['CUSTOM'] = effectConfig['CUSTOM'] or {}
			effectConfig['CUSTOM'][actionName] = effect

			UltiPar.InitCustomEffect(actionName, effect)
			UltiPar.SaveEffectConfigToDisk(effectConfig)
			UltiPar.SendEffectConfigToServer(effectConfig)
			// PrintTable(effectConfig)
		end

		local playButton = panel:Button('#ultipar.playeffect')
		playButton.DoClick = function()
			UltiPar.EffectTest(LocalPlayer(), actionName, 'Custom')
			saveButton:DoClick()
		end

		panel:AddItem(saveButton)

		panel:SetLabel(string.format('%s %s %s', 
			language.GetPhrase('#ultipar.custom'), 
			language.GetPhrase('#ultipar.property'),
			language.GetPhrase('#ultipar.link') .. ':' .. effect.linkName
		))
	else
		local customButton = panel:Button('#ultipar.custom')
		customButton:SetText('#ultipar.custom')
		customButton:SetIcon('icon64/tool.png')

		customButton.DoClick = function()
			local effectConfig = LocalPlayer().ultipar_effect_config
			local custom = UltiPar.CreateCustomEffect(actionName, effect.Name)

			effectConfig[actionName] = 'Custom'
			effectConfig['CUSTOM'] = effectConfig['CUSTOM'] or {}
			effectConfig['CUSTOM'][actionName] = custom

			UltiPar.InitCustomEffect(actionName, custom)
			UltiPar.SaveEffectConfigToDisk(effectConfig)
			UltiPar.SendEffectConfigToServer(effectConfig)
			// PrintTable(effectConfig)
			effecttree.Effects['Custom'] = custom
			effecttree:RefreshNode()
		end
		
		for k, v in pairs(effect) do
			panel:Help(k .. '=' .. PropertyViewText(v))
		end

		panel:SetLabel(string.format('%s %s %s', 
			effect.Name, 
			language.GetPhrase('#ultipar.property'),
			''
		))
	end

	return panel
end

UltiPar.CreateActionEditor = function(actionName)
	local action = UltiPar.GetAction(actionName)

	local width, height = 600, 400
	local Window = vgui.Create('DFrame')
	Window:SetTitle(language.GetPhrase('ultipar.actionmanager') .. '  ' .. actionName)
	Window:MakePopup()
	Window:SetSizable(true)
	Window:SetSize(width, height)
	Window:Center()
	Window:SetDeleteOnClose(true)

	local Tabs = vgui.Create('DPropertySheet', Window)
	Tabs:Dock(FILL)

	local effectConfig = LocalPlayer().ultipar_effect_config
	local customEffect = (effectConfig['CUSTOM'] or {})[actionName]
	
	local Effects = table.Copy(action.Effects)
	if customEffect then Effects['Custom'] = customEffect end
	

	if istable(effectConfig) then
		local UserPanel = vgui.Create('DPanel', Tabs)
		UserPanel:Dock(FILL)

		local div = vgui.Create('DHorizontalDivider', UserPanel)
		div:Dock(FILL)
		div:SetDividerWidth(10)
		
		local effecttree = vgui.Create('DTree', UserPanel)
		effecttree.Effects = Effects
		div:SetLeft(effecttree)
		div:SetLeftWidth(0.5 * width)

		effecttree.RefreshNode = function(self)
			self:Clear()
			if div:GetRight() then div:GetRight():Remove() end
			for k, v in pairs(Effects) do
				local icon
				if effectConfig[action.Name] == k then
					icon = 'icon16/accept.png'
					self.currentEffect = k
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
				
				playButton:SetText('#ultipar.playeffect')
				playButton:SetIcon('icon16/cd_go.png')
				
				playButton.DoClick = function()
					UltiPar.EffectTest(LocalPlayer(), action.Name, node.effect)
				end
			end
		end

		local curSelectedNode = nil
		local clicktime = 0
		effecttree.OnNodeSelected = function(self, selNode)
			if CurTime() - clicktime < 0.2 and curSelectedNode == selNode and self.currentEffect ~= selNode.effect then
				effectConfig[action.Name] = selNode.effect
				
				UltiPar.SendEffectConfigToServer(effectConfig)
				UltiPar.SaveEffectConfigToDisk(effectConfig)
				effecttree:RefreshNode()

				curSelectedNode = nil
			else
				if div:GetRight() then
					div:GetRight():Remove()
				end

				local effect = Effects[selNode.effect]
		
				local propPanel = UltiPar.CreateEffectPropertyPanel(actionName, effect, effecttree)
				propPanel:SetParent(UserPanel)
				
				local rightwidth = width - div:GetLeftWidth()
				rightwidth = rightwidth < 80 and 200 or rightwidth

				div:SetRight(propPanel)
				div:SetLeftWidth(width - rightwidth)

				curSelectedNode = selNode
			end
			clicktime = CurTime()
		end

		effecttree:RefreshNode()

		Tabs:AddSheet('#ultipar.effect', UserPanel, 'icon16/user.png', false, false, '')
	end

	if isfunction(action.CreateOptionMenu) then
		local DScrollPanel = vgui.Create('DScrollPanel', Tabs)
		local OptionPanel = vgui.Create('DForm', DScrollPanel)
		OptionPanel:SetLabel('Options')
		OptionPanel:Dock(FILL)
		OptionPanel.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, white)
		end

		action.CreateOptionMenu(OptionPanel)

		Tabs:AddSheet('#ultipar.options', DScrollPanel, 'icon16/wrench.png', false, false, '')
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

UltiPar.CreateGlobalMenu = function(panel)
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

		local keys = {}
		for k, v in pairs(UltiPar.ActionSet) do table.insert(keys, k) end
		table.sort(keys)

		for i, k in ipairs(keys) do
			local v = UltiPar.ActionSet[k]
			if v.Invisible then continue end
			local label = isstring(v.label) and v.label or k
			local icon = isstring(v.icon) and v.icon or 'icon32/tool.png'

			local node = self:AddNode(label, icon)
			node.action = v.Name

			local disableButton = vgui.Create('DButton', node)
			disableButton:SetSize(20, 18)
			disableButton:Dock(RIGHT)
			
			disableButton:SetText('')
			disableButton:SetIcon(UltiPar.IsActionDisable(k) and 'icon16/delete.png' or 'icon16/accept.png')
			
			disableButton.DoClick = function()
				UltiPar.ToggleActionDisable(k)
				disableButton:SetIcon(UltiPar.IsActionDisable(k) and 'icon16/delete.png' or 'icon16/accept.png')
			end

			local editButton = vgui.Create('DButton', node)
			editButton:SetSize(20, 18)
			editButton:Dock(RIGHT)
			
			editButton:SetText('')
			editButton:SetIcon('icon16/application_edit.png')
			
			editButton.DoClick = function()
				UltiPar.CreateActionEditor(node.action)
			end
		end

		keys = nil
	end

	panel:AddItem(tree)

	local LoadButton = panel:Button('#ultipar.load')
	LoadButton.DoClick = function()
		UltiPar.ReadActionDisable()
	end

	local SaveButton = panel:Button('#ultipar.save')
	SaveButton.DoClick = function()
		UltiPar.WriteActionDisable(UltiPar.DisabledSet)
	end

	UltiPar.ActionManager = tree
	UltiPar.ReadActionDisable()

	panel:ControlHelp(UltiPar.Version)
end

hook.Add('PopulateToolMenu', 'ultipar.menu', function()
	spawnmenu.AddToolMenuOption('Options', 
		language.GetPhrase('ultipar.category'), 
		'ultipar.menu', 
		language.GetPhrase('ultipar.actionmanager'), '', '', 
		UltiPar.CreateGlobalMenu
	)
end)

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

UltiPar.EffectValueFormat = function(v)
	if isstring(v) then
		return string.format('"%s"', v)
	elseif isnumber(v) then
		return string.format('%s', v)
	elseif isbool(v) then
		return string.format('%s', v and 'true' or 'false')
	elseif isvector(v) or isangle(v) then
		return string.format('[%s]', v)
	elseif isfunction(v) then
		return string.format('%s', v)
	elseif ismatrix(v) then
		return string.format('[%s]', v)
	elseif istable(v) then
		return string.format('%s', 'table')
	end

	return ''
end

UltiPar.Translate = function(key, prefix, sep)
	prefix = prefix or 'upgui'
	
	local split = string.Split(key, sep or '_')
	local result = ''
	local len = #split
	for i, v in ipairs(split) do
		result = result .. language.GetPhrase(string.format('#%s.%s', prefix, v)) .. (i == len and '' or '.')
	end

	return result
end

UltiPar.TranslateContributor = function(key, prefix)
	prefix = prefix or 'upgui'

	local split = string.Split(key, '-')
	local result = ''
	local len = #split
	for i, v in ipairs(split) do
		if i == len and len > 1 then
			result = result .. v
		elseif i == len then
			result = result .. language.GetPhrase(string.format('#%s.%s', prefix, v))
		else
			result = result .. language.GetPhrase(string.format('#%s.%s', prefix, v)) .. '-'
		end
	end

	return result
end


UltiPar.CreateEffectPropertyEditor = function(actionName, effect, effecttree)
	local DScrollPanel = vgui.Create('DScrollPanel')
	local panel = vgui.Create('DForm', DScrollPanel)
	panel:Dock(FILL)

	local keys = {}
	for k, v in pairs(effect) do table.insert(keys, k) end
	table.sort(keys)

	local saveButton = vgui.Create('DButton')
	saveButton:SetText('#upgui.save')
	saveButton.DoClick = function()
		local effectConfig = LocalPlayer().ultipar_effect_config
		local customEffects = LocalPlayer().ultipar_effects_custom

		effectConfig[actionName] = 'Custom'
		customEffects[actionName] = effect

		UltiPar.InitCustomEffect(actionName, effect)

		UltiPar.SaveUserDataToDisk(effectConfig, 'ultipar/effect_config.json')
		UltiPar.SaveUserDataToDisk(customEffects, 'ultipar/effects_custom.json')
	
		UltiPar.SendEffectConfigToServer(effectConfig)
		UltiPar.SendCustomEffectsToServer(customEffects)
		// PrintTable(effectConfig)
	end

	local playButton = panel:Button('#upgui.playeffect')
	playButton.DoClick = function()
		UltiPar.EffectTest(LocalPlayer(), actionName, 'Custom')
		saveButton:DoClick()
	end

	panel:AddItem(saveButton)


	for _, k in ipairs(keys) do
		local v = effect[k]
		local keyPhrase = UltiPar.Translate(k, effect.prefix)
		if k == 'linkName' or k == 'Name' then
			continue
		elseif isstring(v) and (k == 'VManipAnim' or k == 'VMLegsAnim') then
			local target = k == 'VManipAnim' and VManip.Anims or VMLegs.Anims
			local anims = {}
			for k, _ in pairs(target) do table.insert(anims, k) end
			table.sort(anims)

			local animComboBox = panel:ComboBox(keyPhrase .. ':', '')
			animComboBox.OnSelect = function(self, _, anim)
				print(k, anim)
				effect[k] = anim
			end

			for _, anim in ipairs(anims) do
				animComboBox:AddChoice(anim, nil, anim == v)
			end
		elseif isstring(v) then
			local textEntry = panel:TextEntry(keyPhrase .. ':', '')
			textEntry:SetText(v)
			textEntry.OnChange = function(self)
				local val = self:GetText()
				print(k, val)
				effect[k] = val
			end
		elseif isnumber(v) then
			local numEntry = panel:TextEntry(keyPhrase .. ':', '')
			numEntry:SetText(tostring(v))
			numEntry.OnChange = function(self)
				local val = tonumber(self:GetText()) or 0
				print(k, val)
				effect[k] = val
			end
		elseif isbool(v) then
			local checkBox = panel:CheckBox(keyPhrase .. ':', '')
			checkBox:SetChecked(v)
			checkBox.OnChange = function(self, checked)
				print(k, checked)
				effect[k] = checked
			end
		elseif isvector(v) or isangle(v) then
			local vecEntry = panel:TextEntry(keyPhrase .. ':', '')
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

	panel:SetLabel(string.format('%s %s %s', 
		language.GetPhrase('#upgui.custom'), 
		language.GetPhrase('#upgui.property'),
		language.GetPhrase('#upgui.link') .. ':' .. effect.linkName
	))

	return DScrollPanel
end

UltiPar.CreateEffectPropertyPreview = function(actionName, effect, effecttree)
	local DScrollPanel = vgui.Create('DScrollPanel')
	local panel = vgui.Create('DForm', DScrollPanel)
	panel:Dock(FILL)

	local keys = {}
	for k, v in pairs(effect) do table.insert(keys, k) end
	table.sort(keys)

	local customButton = panel:Button('#upgui.custom')
	customButton:SetText('#upgui.custom')
	customButton:SetIcon('icon64/tool.png')

	customButton.DoClick = function()
		local effectConfig = LocalPlayer().ultipar_effect_config
		local customEffects = LocalPlayer().ultipar_effects_custom
		local custom = UltiPar.CreateCustomEffect(actionName, effect.Name)

		effectConfig[actionName] = 'Custom'
		customEffects[actionName] = custom

		UltiPar.InitCustomEffect(actionName, custom)
	
		UltiPar.SaveUserDataToDisk(effectConfig, 'ultipar/effect_config.json')
		UltiPar.SaveUserDataToDisk(customEffects, 'ultipar/effects_custom.json')

		UltiPar.SendEffectConfigToServer(effectConfig)
		UltiPar.SendCustomEffectsToServer(customEffects)
		// PrintTable(effectConfig)
		effecttree.Effects['Custom'] = custom
		effecttree:RefreshNode()
	end
	
	for _, k in ipairs(keys) do
		local v = effect[k]
		local keyPhrase = UltiPar.Translate(k, effect.prefix)
		panel:Help(keyPhrase .. '=' .. UltiPar.EffectValueFormat(v))
	end

	panel:SetLabel(string.format('%s %s %s', 
		effect.Name, 
		language.GetPhrase('#upgui.property'),
		''
	))

	return DScrollPanel
end

UltiPar.CreateActionEditor = function(actionName)
	local action = UltiPar.GetAction(actionName)

	local width, height = 600, 400
	local Window = vgui.Create('DFrame')
	Window:SetTitle(language.GetPhrase('#upgui.actionmanager') .. '  ' .. actionName)
	Window:MakePopup()
	Window:SetSizable(true)
	Window:SetSize(width, height)
	Window:Center()
	Window:SetDeleteOnClose(true)

	local Tabs = vgui.Create('DPropertySheet', Window)
	Tabs:Dock(FILL)

	local effectConfig = LocalPlayer().ultipar_effect_config
	local customEffect = LocalPlayer().ultipar_effects_custom[actionName]
	
	local Effects = {}
	for k, v in pairs(action.Effects) do Effects[k] = v end
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
				local label = UltiPar.TranslateContributor(k, v.prefix)

				local node = self:AddNode(label, icon)
				node.effect = k

				local playButton = vgui.Create('DButton', node)
				playButton:SetSize(60, 18)
				// playButton:SetPos(170, 0)
				playButton:Dock(RIGHT)
				
				playButton:SetText('#upgui.playeffect')
				playButton:SetIcon('icon16/cd_go.png')
				
				playButton.DoClick = function()
					UltiPar.EffectTest(LocalPlayer(), action.Name, node.effect)

					print(node.effect)
					effectConfig[action.Name] = node.effect

					UltiPar.SaveUserDataToDisk(effectConfig, 'ultipar/effect_config.json')
					UltiPar.SendEffectConfigToServer(effectConfig)

					self:RefreshNode()
				end
			end
		end

		local curSelectedNode = nil
		local clicktime = 0
		effecttree.OnNodeSelected = function(self, selNode)
			if CurTime() - clicktime < 0.2 and curSelectedNode == selNode and self.currentEffect ~= selNode.effect then
				UltiPar.EffectTest(LocalPlayer(), action.Name, selNode.effect)

				print(selNode.effect)
				effectConfig[action.Name] = selNode.effect
				
				UltiPar.SendEffectConfigToServer(effectConfig)
				UltiPar.SaveUserDataToDisk(effectConfig, 'ultipar/effect_config.json')
				effecttree:RefreshNode()

				curSelectedNode = nil
			else
				if div:GetRight() then
					div:GetRight():Remove()
				end

				local effect = Effects[selNode.effect]
				local iscustom = !!effect.linkName
				
				local propPanel = nil
				if iscustom and effect.CreateEffectPropertyEditor then
					propPanel = effect.CreateEffectPropertyEditor(actionName, effect, effecttree)
				elseif iscustom and not effect.CreateEffectPropertyEditor then
					propPanel = UltiPar.CreateEffectPropertyEditor(actionName, effect, effecttree)
				elseif not iscustom and effect.CreateEffectPropertyPreview then
					propPanel = effect.CreateEffectPropertyPreview(actionName, effect, effecttree)
				elseif not iscustom and not effect.CreateEffectPropertyPreview then
					propPanel = UltiPar.CreateEffectPropertyPreview(actionName, effect, effecttree)
				end
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

		Tabs:AddSheet('#upgui.effect', UserPanel, 'icon16/user.png', false, false, '')
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

		Tabs:AddSheet('#upgui.options', DScrollPanel, 'icon16/wrench.png', false, false, '')
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
			local label = UltiPar.Translate(k, v.prefix, '-')
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

	local LoadButton = panel:Button('#upgui.load')
	LoadButton.DoClick = function()
		UltiPar.ReadActionDisable()
	end

	local SaveButton = panel:Button('#upgui.save')
	SaveButton.DoClick = function()
		UltiPar.WriteActionDisable(UltiPar.DisabledSet)
	end

	UltiPar.ActionManager = tree
	UltiPar.ReadActionDisable()

	panel:ControlHelp(UltiPar.Version)
end

hook.Add('PopulateToolMenu', 'ultipar.menu', function()
	spawnmenu.AddToolMenuOption('Options', 
		language.GetPhrase('#upgui.category'), 
		'#upgui.menu', 
		language.GetPhrase('#upgui.actionmanager'), '', '', 
		UltiPar.CreateGlobalMenu
	)
end)

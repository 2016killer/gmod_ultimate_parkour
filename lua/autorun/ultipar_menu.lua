--[[
	作者:白狼
	2025 11 1
--]]

if SERVER then return end
UltiPar = UltiPar or {}

UltiPar.DisabledSet = UltiPar.DisabledSet or {}
UltiPar.ActionSet = UltiPar.ActionSet or {}

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

			local LoadLuaButton = panel:Button('#ultipar.loadlua')
			LoadLuaButton.DoClick = function()
				UltiPar.LoadLuaFiles()
			end
		end)
end)

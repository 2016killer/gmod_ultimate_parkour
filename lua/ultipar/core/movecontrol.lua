--[[
	作者:白狼
	2025 11 5
--]]
UltiPar.SetMoveControl = function(ply, enable, ClearMovement, RemoveKeys, AddKeys)
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

		UltiPar.SetMoveControl(nil, enable, ClearMovement, RemoveKeys, AddKeys)
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

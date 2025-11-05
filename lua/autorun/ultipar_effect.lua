--[[
	作者:白狼
	2025 11 1
--]]

UltiPar = UltiPar or {}

UltiPar.EffectTest = function(ply, actionName, effectName)
	local action = UltiPar.GetAction(actionName)
	if not action then
		return
	end

	local effect = UltiPar.GetEffect(action, effectName)
	if not effect then
		return
	end

	effect:start(ply, nil)
	timer.Simple(1, function()
		effect:clear(ply, nil)
	end)
	if CLIENT then
		net.Start('UltiParEffectTest')
			net.WriteString(actionName)
			net.WriteString(effectName)
		net.SendToServer()
	end
end

if SERVER then
	util.AddNetworkString('UltiParEffectConfig')
	util.AddNetworkString('UltiParEffectTest')

	net.Receive('UltiParEffectTest', function(len, ply)
		local actionName = net.ReadString()
		local effectName = net.ReadString()
		
		UltiPar.EffectTest(ply, actionName, effectName)
	end)

	net.Receive('UltiParEffectConfig', function(len, ply)
		local effectConfig = net.ReadTable()
		ply.ultipar_effect_config = effectConfig or ply.ultipar_effect_config
	end)
elseif CLIENT then
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

	hook.Add('KeyPress', 'ultipar.init.effect', function(ply, key)
		if key == IN_FORWARD then 
			local effectConfig = LoadEffectFromDisk()
			if effectConfig ~= nil then
				SendEffectConfigToServer(effectConfig)
			else
				print('[UltiPar]: use default effect config')
			end
			LocalPlayer().ultipar_effect_config = effectConfig or {}
			 
			hook.Remove('KeyPress', 'ultipar.init.effect')
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

	UltiPar.LoadEffectFromDisk = LoadEffectFromDisk
	UltiPar.SendEffectConfigToServer = SendEffectConfigToServer
	UltiPar.SaveEffectConfigToDisk = SaveEffectConfigToDisk
end
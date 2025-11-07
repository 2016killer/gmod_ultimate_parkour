--[[
	作者:白狼
	2025 11 1
--]]

UltiPar = UltiPar or {}
local UltiPar = UltiPar

UltiPar.RegisterEffect = function(actionName, effectName, effect)
	-- 注册动作特效, 返回特效和是否已存在
	-- 不支持覆盖

	local action = UltiPar.Register(actionName)

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
	effect.start = effect.start or function(ply, ...)
		-- 特效
		printdata(
			string.format('start Action "%s" Effect "%s"', actionName, effectName),
			ply, ...
		)
	end

	effect.clear = effect.clear or function(ply, ...)
		-- 当中断或强制退出时enddata为nil, 否则为表
		-- 强制中断时 breaker 为 true	
		-- 清除特效
		printdata(
			string.format('clear Action "%s" Effect "%s"', actionName, effectName),
			ply, ...
		)
	end

	return effect, exist
end

UltiPar.RegisterEffectEasy = function(actionName, effectName, effect)
	-- 注册动作特效, 返回特效和是否已存在

	local action = UltiPar.GetAction(actionName)
	if not action then
		ErrorNoHalt(string.format('Action "%s" not found', actionName))
		return
	end

	local default = UltiPar.GetEffect(action, 'default')
	if not default then
		print(string.format('Action "%s" has no default effect', actionName))
		default = {}
	end

	return UltiPar.RegisterEffect(
		actionName, 
		effectName, 
		table.Merge(table.Copy(default), effect)
	)
end


UltiPar.GetEffect = function(action, effectName)
	-- 从全局特效中获取, 不存在返回nil
	return action.Effects[effectName]
end

UltiPar.GetPlayerEffect = function(ply, action, effectName)
	if effectName == 'Custom' then
		return ply.ultipar_effects_custom[action.Name]
	else
		return action.Effects[effectName]
	end
end

UltiPar.GetPlayerCurrentEffect = function(ply, action)
	-- 获取指定玩家动作的当前特效
	return UltiPar.GetPlayerEffect(ply, action, ply.ultipar_effect_config[action.Name] or 'default')
end

UltiPar.EffectTest = function(ply, actionName, effectName)
	local action = UltiPar.GetAction(actionName)
	if not action then
		print(string.format('[UltiPar]: effect test failed, action "%s" not found', actionName))
		return
	end

	local effect = UltiPar.GetPlayerEffect(ply, action, effectName)
	-- 特效不存在
	if not effect then
		print(string.format('[UltiPar]: effect test failed, action "%s" effect "%s" not found', actionName, effectName))
		return
	end

	effect:start(ply)
	timer.Simple(1, function()
		effect:clear(ply)
	end)
	if CLIENT then
		net.Start('UltiParEffectTest')
			net.WriteString(actionName)
			net.WriteString(effectName)
		net.SendToServer()
	end
end

UltiPar.InitCustomEffect = function(actionName, custom)
	custom.Name = 'Custom'
	local linkName = custom.linkName
	if not isstring(linkName) then
		print(string.format('[UltiPar]: register custom effect failed, action "%s" linkName "%s" is not string', actionName, linkName))
		return false
	end

	local action = UltiPar.GetAction(actionName)
	if not action then
		print(string.format('[UltiPar]: register custom effect failed, action "%s" not found', actionName))
		return false
	end

	local linkEffect = UltiPar.GetEffect(action, linkName)
	if not linkEffect then
		print(string.format('[UltiPar]: register custom effect failed, action "%s" effect "%s" not found', actionName, linkName))
		return false
	end

	for k, v in pairs(linkEffect) do
		if custom[k] == nil then custom[k] = v end
	end

	return true
end

UltiPar.CreateCustomEffect = function(actionName, linkName)
	local action = UltiPar.GetAction(actionName)
	if not action then
		print(string.format('[UltiPar]: copy action "%s" link "%s" to custom failed, action not found', actionName, linkName))
		return nil
	end

	local linkEffect = UltiPar.GetEffect(action, linkName)
	if not linkEffect then
		print(string.format('[UltiPar]: copy action "%s" link "%s" to custom failed, link not found', actionName, linkName))
		return nil
	end

	local custom = {
		Name = 'Custom',
		label = '#ultipar.custom',
		linkName = linkName
	}

	return custom
end


if SERVER then
	util.AddNetworkString('UltiParEffectCustom')
	util.AddNetworkString('UltiParEffectConfig')
	util.AddNetworkString('UltiParEffectTest')

	net.Receive('UltiParEffectTest', function(len, ply)
		local actionName = net.ReadString()
		local effectName = net.ReadString()
		
		UltiPar.EffectTest(ply, actionName, effectName)
	end)

	net.Receive('UltiParEffectConfig', function(len, ply)
		local content = net.ReadString()
		// content = util.Decompress(content)

		local effectConfig = util.JSONToTable(content or '')
		if not istable(effectConfig) then
			print('[UltiPar]: receive effect config is not table')
			return
		end

		table.Merge(ply.ultipar_effect_config, effectConfig)
	end)

	net.Receive('UltiParEffectCustom', function(len, ply)
		local content = net.ReadString()
		// content = util.Decompress(content)

		local customEffects = util.JSONToTable(content or '')
		if not istable(customEffects) then
			print('[UltiPar]: receive custom effects is not table')
			return
		end

		-- 初始化自定义特效
		for k, v in pairs(customEffects) do
			UltiPar.InitCustomEffect(k, v)
		end

		table.Merge(ply.ultipar_effects_custom, customEffects)
	end)


	hook.Add('PlayerInitialSpawn', 'ultipar.init.effect', function(ply)
		ply.ultipar_effect_config = ply.ultipar_effect_config or {}
		ply.ultipar_effects_custom = ply.ultipar_effects_custom or {}
		hook.Remove('PlayerInitialSpawn', 'ultipar.init.effect')
	end)

elseif CLIENT then
	UltiPar.SendCustomEffectsToServer = function(effects)
		-- 为了过滤掉一些不能序列化的数据
		local content = util.TableToJSON(effects)
		if not content then
			print('[UltiPar]: send custom effects to server failed, content is not valid json')
			return
		end
		// content = util.Compress(content)

		net.Start('UltiParEffectCustom')
			net.WriteString(content)
		net.SendToServer()
	end

	UltiPar.SendEffectConfigToServer = function(effectConfig)
		local content = util.TableToJSON(effectConfig)
		if not content then
			print('[UltiPar]: send effect config to server failed, content is not valid json')
			return
		end
		// content = util.Compress(content)

		net.Start('UltiParEffectConfig')
			net.WriteString(content)
		net.SendToServer()
	end

	hook.Add('KeyPress', 'ultipar.init.effect', function(ply, key)
		if key == IN_FORWARD then 
			local customEffects = UltiPar.LoadUserDataFromDisk('ultipar/effects_custom.json')
			local effectConfig = UltiPar.LoadUserDataFromDisk('ultipar/effect_config.json')
			
			UltiPar.SendCustomEffectsToServer(customEffects)
			UltiPar.SendEffectConfigToServer(effectConfig)

			-- 初始化自定义特效
			for k, v in pairs(customEffects) do
				UltiPar.InitCustomEffect(k, v)
			end

			ply.ultipar_effect_config = effectConfig or {}
			ply.ultipar_effects_custom = customEffects or {}
			
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
end
--[[
作者:白狼
2025 11 1
]]--

-- ==================== 低爬动作 ===============

---------------------- 菜单 ----------------------
local convars = {
	{
		name = 'dp_workmode',
		default = '1',
		widget = 'CheckBox',
		help = true,
	},

	{
		name = 'dp_los_cos',
		default = '0.64',
		widget = 'NumSlider',
		min = 0,
		max = 1,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_falldamage',
		default = '1',
		widget = 'CheckBox'
	},

	{
		name = 'dp_lc_keymode',
		default = '1',
		widget = 'CheckBox',
		help = true,
	},

	{
		name = 'dp_lc_per',
		default = '0.1',
		widget = 'NumSlider',
		min = 0.05,
		max = 3600,
		decimals = 2,
	},

	{
		name = 'dp_lc_max',
		default = '0.85',
		widget = 'NumSlider',
		min = 0,
		max = 0.85,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_lc_min',
		default = '0.5',
		widget = 'NumSlider',
		min = 0,
		max = 0.85,
		decimals = 2,
	},

	{
		name = 'dp_lc_vault',
		default = '1',
		widget = 'CheckBox'
	},

	{
		name = 'dp_vault_vlen',
		default = '0.5',
		widget = 'NumSlider',
		min = 0.25,
		max = 0.6,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_lc_vault_hlen',
		default = '2',
		widget = 'NumSlider',
		min = 0,
		max = 3,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_vault_double',
		default = '0.3',
		widget = 'NumSlider',
		min = 0,
		max = 2,
		decimals = 2,
		help = true,
	}
}

UltiPar.CreateConVars(convars)
local dp_workmode = GetConVar('dp_workmode')
local dp_los_cos = GetConVar('dp_los_cos')
local dp_falldamage = GetConVar('dp_falldamage')
local dp_lc_keymode = GetConVar('dp_lc_keymode')
local dp_lc_per = GetConVar('dp_lc_per')
local dp_lc_min = GetConVar('dp_lc_min')
local dp_lc_max = GetConVar('dp_lc_max')

local dp_lc_vault = GetConVar('dp_lc_vault')
local dp_lc_vault_hlen = GetConVar('dp_lc_vault_hlen')
local dp_vault_vlen = GetConVar('dp_vault_vlen')
local dp_vault_double = GetConVar('dp_vault_double')

local action, _ = UltiPar.Register('DParkour-LowClimb')
if CLIENT then
	action.label = '#dp.lowclimb'
	action.icon = 'dparkour/icon.jpg'

	action.CreateOptionMenu = function(panel)
		UltiPar.CreateConVarMenu(panel, convars)
	end
else
	convars = nil
end
---------------------- 动作逻辑 ----------------------
action.ClimbSpeed = function(ply, ref)
	-- 返回爬楼初始速度、结束速度
	return math.max(
			ply:GetJumpPower() + 0.25 * (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed()), 
			ref[3]
		),
		0
end

action.VaultSpeed = function(ply, ref, isdouble)
	-- 返回Vault初始速度、结束速度、过渡速度
	if isdouble then
		local startvel, _ = action.ClimbSpeed(ply, ref)
		local _, endvel = action.VaultSpeed(ply, ref, false)
		return startvel, endvel * 0.8, startvel * 0.2
	else
		local vaultDir = ply:EyeAngles():Forward()
		vaultDir[3] = 0

		local startvel = ref:Dot(vaultDir)

		return startvel,
			math.max(
				ply:GetJumpPower() + (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed()),
				startvel
			)
	end
end

action.IsDoubleVault = function(ply, blockheight)
	local pmins, pmaxs = ply:GetHull()
	local plyHeight = pmaxs[3] - pmins[3]

	return blockheight > dp_vault_double:GetFloat() * plyHeight
end


action.Clear = function()
	// print('低爬动作清除')
end

local GeneralClimbCheck = UltiPar.GeneralClimbCheck
action.Check = function(ply)
	-- 低爬检测范围更长, 两个身位左右
	local bmins, bmaxs = ply:GetCollisionBounds()
	local plyWidth = math.max(bmaxs[1] - bmins[1], bmaxs[2] - bmins[2])
	local plyHeight = bmaxs[3] - bmins[3]
	
	local blockHeightMax = dp_lc_max:GetFloat() * plyHeight
	local blockHeightMin = dp_lc_min:GetFloat() * plyHeight

	bmaxs[3] = blockHeightMax
	bmins[3] = blockHeightMin

	local landdata = GeneralClimbCheck(ply, {
		blen = 2 * plyWidth,
		ehlen = 0.5 * plyWidth,
		evlen = blockHeightMax - blockHeightMin,
		bmins = bmins,
		bmaxs = bmaxs,
		loscos = dp_los_cos:GetFloat(),
	})

	if not dp_lc_vault:GetBool() then
		return landdata
	end

	if landdata then
		local plyWidth = math.max(bmaxs[1] - bmins[1], bmaxs[2] - bmins[2])

		local vaultdata = UltiPar.GeneralVaultCheck(ply, {
			hlen = dp_lc_vault_hlen:GetFloat() * plyWidth,
			vlen = dp_vault_vlen:GetFloat() * plyHeight,
			landdata = landdata,
		})

		if vaultdata == nil then
			return landdata
		else
			return {landdata[1], landdata[2], landdata[3], vaultdata[2], vaultdata[3]}
		end
	end

end

action.CheckEnd = 0.5

action.Play = function(ply, data)
	if CLIENT or data == nil then return end
	local _, landpos, blockheight, vaultpos, blockheightVault = unpack(data)


	-- 检测摔落伤害
	if dp_falldamage:GetBool() then
		local fallspeed = ply:GetVelocity()[3]
		if fallspeed < -600 then
			local damage = hook.Run('GetFallDamage', ply, fallspeed) or 0
			if damage > 0 then
				local d = DamageInfo()
				d:SetDamage(damage)
				d:SetAttacker(Entity(0))
				d:SetDamageType(DMG_FALL) 

				ply:TakeDamageInfo(d)
				ply:EmitSound('Player.FallDamage', 100, 100)	
			end 
		end
	end


	if not vaultpos then
		-- 检测一下落脚点能否站立
		local endpos = landpos
		local needduck = UltiPar.GeneralLandSpaceCheck(ply, endpos)

		-- 移动的初始速度由玩家移动能力和跳跃能力决定
		local startvel, endvel = action.ClimbSpeed(ply, ply:GetVelocity())
		
		UltiPar.StartSmoothMove(
			ply, 
			nil,
			endpos, 
			startvel,
			endvel,
			needduck and IN_JUMP or bit.bor(IN_JUMP, IN_DUCK), 
			needduck and IN_DUCK or 0
		)
	else
		local endpos = vaultpos

		if action.IsDoubleVault(ply, blockheightVault) then
			-- 二段翻越, 最终速度衰减到0.8倍, 过渡速度为0.2倍
			local startvel, endvel, middlevel = action.VaultSpeed(ply, ply:GetVelocity(), true)

			local middlepos = landpos
			middlepos[3] = endpos[3]

			UltiPar.StartSmoothDoubleVault(
				ply, 
				nil,
				endpos, 
				startvel,
				endvel,
				middlepos,
				middlevel,
				bit.bor(IN_JUMP, IN_DUCK), 
				0
			)
		else
			local startvel, endvel = action.VaultSpeed(ply, ply:GetVelocity(), false)
			
			UltiPar.StartSmoothVault(
				ply, 
				nil,
				endpos, 
				startvel,
				endvel,
				bit.bor(IN_JUMP, IN_DUCK), 
				0
			)
		end

	end
end

local function effectfunc_default(ply, data)
	if data == nil then
		-- 演示模式
		if SERVER then
			-- 防止CalcView不兼容, 还是用ViewPunch吧
			ply:ViewPunch(Angle(0, 0, -8))
		elseif CLIENT then
			UltiPar.SetVecPunchVel(Vector(100, 0, -10))
			// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
			VManip:PlayAnim('vault')
			VMLegs:PlayAnim('dp_lazy_BaiLang')
			surface.PlaySound('dparkour/bailang/vault.mp3')
		end
	else
		local pos, landpos, _, vaultpos, blockheightVault = unpack(data)
		if SERVER then
			-- 防止CalcView不兼容, 还是用ViewPunch吧
			if not vaultpos then
				ply:ViewPunch(Angle(0, 0, -5))
			else
				if action.IsDoubleVault(ply, blockheightVault) then
					ply:ViewPunch(Angle(8, 0, 0))

					local middlepos = landpos
					middlepos[3] = vaultpos[3]
					local duration = 2 * (middlepos:Distance(pos)) / (1.2 * action.ClimbSpeed(ply, ply:GetVelocity()))
					
					timer.Simple(duration, function()
						ply:ViewPunch(Angle(0, 0, -8))
					end)
				else
					ply:ViewPunch(Angle(0, 0, -8))
				end
			end
		elseif CLIENT then
			if not vaultpos then
				UltiPar.SetVecPunchVel(Vector(0, 0, 25))
				// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
				VManip:PlayAnim('vault')
				surface.PlaySound('dparkour/bailang/lowclimb.mp3')
			else
				if action.IsDoubleVault(ply, blockheightVault) then
					UltiPar.SetVecPunchVel(Vector(0, 0, 25))
					// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
					VManip:PlayAnim('vault')
					surface.PlaySound('dparkour/bailang/lowclimb.mp3')

					local middlepos = landpos
					middlepos[3] = vaultpos[3]
					local duration = 2 * (middlepos:Distance(pos)) / (1.2 * action.ClimbSpeed(ply, ply:GetVelocity()))
					
					timer.Simple(math.max(0.2, duration), function()
						UltiPar.SetVecPunchVel(Vector(100, 0, -10))
						// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
						VManip:PlayAnim('vault')
						VMLegs:PlayAnim('dp_lazy_BaiLang')
						surface.PlaySound('dparkour/bailang/vault.mp3')
					end)
				else
					UltiPar.SetVecPunchVel(Vector(100, 0, -10))
					// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
					VManip:PlayAnim('vault')
					VMLegs:PlayAnim('dp_lazy_BaiLang')
					surface.PlaySound('dparkour/bailang/vault.mp3')
				end
			end
		end
	end
end

local effect, _ = UltiPar.RegisterEffect(
	'DParkour-LowClimb', 
	'default',
	{
		label = '#default'
	}
)
effect.func = effectfunc_default

UltiPar.RegisterEffect(
	'DParkour-LowClimb', 
	'SP-VManip-白狼',
	{
		label = '#dp.effect.SP_VManip_BaiLang',
		func = effectfunc_default
	}
)


if CLIENT then
	local triggertime = 0
	local Trigger = UltiPar.Trigger
	hook.Add('Think', 'dparkour.lowclimb.trigger', function()
		local ply = LocalPlayer()
		if dp_workmode:GetBool() then return end
		if dp_lc_keymode:GetBool() then 
			if not ply:KeyDown(IN_JUMP) then 
				return 
			end
		else
			if not ply.dp_runtrigger then 
				return 
			end
		end

		local curtime = CurTime()
		if curtime - triggertime < dp_lc_per:GetFloat() then return end
		triggertime = curtime

		Trigger(LocalPlayer(), 'DParkour-LowClimb')
	end)

	hook.Add('KeyPress', 'dparkour.lowclimb.trigger', function(ply, key)
		if key == IN_JUMP and dp_lc_keymode:GetBool() and not dp_workmode:GetBool() then 
			Trigger(ply, 'DParkour-LowClimb') 
		end
	end)

	concommand.Add('+dp_lowclimb_cl', function(ply)
		ply.dp_runtrigger = true
		Trigger(LocalPlayer(), 'DParkour-LowClimb')
	end)

	concommand.Add('-dp_lowclimb_cl', function(ply)
		ply.dp_runtrigger = false
	end)
	
	hook.Add('ShouldDisableLegs', 'dparkour.gmodleg', function()
		return VMLegs and VMLegs:IsActive()
	end)
elseif SERVER then
	local triggertime = 0
	local Trigger = UltiPar.Trigger
	hook.Add('PlayerPostThink', 'dparkour.lowclimb.trigger', function(ply)
		if not dp_workmode:GetBool() then return end
		if dp_lc_keymode:GetBool() then 
			if not ply:KeyDown(IN_JUMP) then 
				return 
			end
		else
			if not ply.dp_runtrigger then 
				return 
			end
		end

		local curtime = CurTime()
		if curtime - triggertime < dp_lc_per:GetFloat() then return end
		triggertime = curtime

		Trigger(ply, 'DParkour-LowClimb')
	end)

	hook.Add('KeyPress', 'dparkour.lowclimb.trigger', function(ply, key)
		if key == IN_JUMP and dp_lc_keymode:GetBool() and dp_workmode:GetBool() then 
			Trigger(ply, 'DParkour-LowClimb') 
		end
	end)

	concommand.Add('+dp_lowclimb_sv', function(ply)
		ply.dp_runtrigger = true
		Trigger(ply, 'DParkour-LowClimb')
	end)

	concommand.Add('-dp_lowclimb_sv', function(ply)
		ply.dp_runtrigger = false
	end)
end



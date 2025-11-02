--[[
作者:白狼
2025 11 1
]]--

-- ==================== 低爬动作 ===============
local debugwireframebox = UltiPar.debugwireframebox

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
		name = 'dp_lc_vault_vlen',
		default = '0.6',
		widget = 'NumSlider',
		min = 0.25,
		max = 0.6,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_lc_vault_min',
		default = '0.25',
		widget = 'NumSlider',
		min = 0.25,
		max = 0.5,
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
	}

}

UltiPar.CreateConVars(convars)
local dp_workmode = GetConVar('dp_workmode')
local dp_los_cos = GetConVar('dp_los_cos')
local dp_lc_keymode = GetConVar('dp_lc_keymode')
local dp_lc_per = GetConVar('dp_lc_per')
local dp_lc_min = GetConVar('dp_lc_min')
local dp_lc_max = GetConVar('dp_lc_max')

local dp_lc_vault = GetConVar('dp_lc_vault')
local dp_lc_vault_vlen = GetConVar('dp_lc_vault_vlen')
local dp_lc_vault_min = GetConVar('dp_lc_vault_min')
local dp_lc_vault_hlen = GetConVar('dp_lc_vault_hlen')


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

	if landdata then
		local plyWidth = math.max(bmaxs[1] - bmins[1], bmaxs[2] - bmins[2])

		local vaultdata = UltiPar.GeneralVaultCheck(ply, {
			hlen = dp_lc_vault_hlen:GetFloat() * plyWidth,
			vlen = dp_lc_vault_vlen:GetFloat() * plyHeight,
			landdata = landdata,
		})

		if vaultdata == nil then
			return {landdata[1].HitPos, landdata[2]}
		else

			return {landdata[1].HitPos, landdata[2], vaultdata[1].HitPos, vaultdata[2]}
		end
	end

end

action.CheckEnd = 0.5

action.Play = function(ply, data)
	if CLIENT or data == nil then return end
	local landpos, blockheight, vaultpos, blockheightMirror = unpack(data)

	if not vaultpos then
		-- 检测一下落脚点能否站立
		local endpos = landpos
		local needduck = UltiPar.GeneralLandSpaceCheck(ply, endpos)

		-- 移动的初始速度由玩家移动能力和跳跃能力决定
		local startvel = ply:GetJumpPower() + 0.25 * (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed())
			startvel = math.max(ply:GetVelocity():Length(), startvel)
		
		UltiPar.StartSmoothMove(
			ply, 
			endpos, 
			startvel,
			0,
			needduck and IN_JUMP or bit.bor(IN_JUMP, IN_DUCK), 
			needduck and IN_DUCK or 0
		)
	else
		local endpos = vaultpos

		-- 移动的最终速度由玩家移动能力和跳跃能力决定
		local startvel = ply:GetVelocity():Length()
		local endvel = ply:GetJumpPower() + (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed())
			endvel = math.max(startvel, endvel)
		
		UltiPar.StartSmoothVault(
			ply, 
			endpos, 
			startvel,
			endvel,
			bit.bor(IN_JUMP, IN_DUCK), 
			0
		)
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
		local landpos, blockheight, vaultpos, blockheightMirror = unpack(data)
		if SERVER then
			-- 防止CalcView不兼容, 还是用ViewPunch吧
			if not vaultpos then
				ply:ViewPunch(Angle(0, 0, -5))
			else
				ply:ViewPunch(Angle(0, 0, -8))
			end
		elseif CLIENT then
			if not vaultpos then
				UltiPar.SetVecPunchVel(Vector(0, 0, 25))
				// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
				VManip:PlayAnim('vault')
				surface.PlaySound('dparkour/bailang/lowclimb.mp3')
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

local effect, _ = UltiPar.RegisterEffect(
	'DParkour-LowClimb', 
	'default',
	{
		label = '#default'
	}
)
effect.func = effectfunc_default

local function effectfunc_VManip_mtbNTB(ply, data)
	if SERVER then return end
	if data == nil then
		UltiPar.SetVecPunchVel(Vector(50, 0, -10))
		UltiPar.SetAngPunchVel(Vector(0, 0, -50))
		VManip:PlayAnim('vault')
		surface.PlaySound('dparkour/mtbntb/lowclimb.mp3')
	end
end

UltiPar.RegisterEffect(
	'DParkour-LowClimb', 
	'VManip-mtbNTB',
	{
		label = '#dp.effect.VManip_mtbNTB',
		func = effectfunc_VManip_mtbNTB,
	}
)

if CLIENT then
	local triggertime = 0
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

		UltiPar.Trigger(LocalPlayer(), 'DParkour-LowClimb')
	end)

	hook.Add('KeyPress', 'dparkour.lowclimb.trigger', function(ply, key)
		if key == IN_JUMP and dp_lc_keymode:GetBool() and not dp_workmode:GetBool() then 
			UltiPar.Trigger(ply, 'DParkour-LowClimb') 
		end
	end)


	concommand.Add('+dp_lowclimb_cl', function(ply)
		ply.dp_runtrigger = true
		UltiPar.Trigger(LocalPlayer(), 'DParkour-LowClimb')
	end)

	concommand.Add('-dp_lowclimb_cl', function(ply)
		ply.dp_runtrigger = false
	end)
	
	hook.Add('ShouldDisableLegs', 'dparkour.gmodleg', function()
		return VMLegs and VMLegs:IsActive()
	end)
elseif SERVER then
	local triggertime = 0
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

		UltiPar.Trigger(ply, 'DParkour-LowClimb')
	end)

	hook.Add('KeyPress', 'dparkour.lowclimb.trigger', function(ply, key)
		if key == IN_JUMP and dp_lc_keymode:GetBool() and dp_workmode:GetBool() then 
			UltiPar.Trigger(ply, 'DParkour-LowClimb') 
		end
	end)

	concommand.Add('+dp_lowclimb_sv', function(ply)
		ply.dp_runtrigger = true
		UltiPar.Trigger(ply, 'DParkour-LowClimb')
	end)

	concommand.Add('-dp_lowclimb_sv', function(ply)
		ply.dp_runtrigger = false
	end)
end



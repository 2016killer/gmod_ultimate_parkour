--[[
作者:白狼
2025 11 1
]]--

-- ==================== 高爬动作 ===============
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
		name = 'dp_lh_keymode',
		default = '1',
		widget = 'CheckBox',
		help = true,
	},

	{
		name = 'dp_lh_per',
		default = '0.1',
		widget = 'NumSlider',
		min = 0.05,
		max = 3600,
		decimals = 2,
	},

	{
		name = 'dp_lh_max',
		default = '1.3',
		widget = 'NumSlider',
		min = 0.86,
		max = 2,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_lh_min',
		default = '0.86',
		widget = 'NumSlider',
		min = 0.86,
		max = 2,
		decimals = 2,
	},

	{
		name = 'dp_lh_vault',
		default = '1',
		widget = 'CheckBox'
	},

	{
		name = 'dp_lh_vault_vlen',
		default = '0.6',
		widget = 'NumSlider',
		min = 0.25,
		max = 0.6,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_lh_vault_min',
		default = '0.25',
		widget = 'NumSlider',
		min = 0.25,
		max = 0.5,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_lh_vault_hlen',
		default = '1.5',
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
local dp_lh_keymode = GetConVar('dp_lh_keymode')
local dp_lh_per = GetConVar('dp_lh_per')
local dp_lh_min = GetConVar('dp_lh_min')
local dp_lh_max = GetConVar('dp_lh_max')

local action, _ = UltiPar.Register('DParkour-HighClimb')
if CLIENT then
	action.label = '#dp.highclimb'
	action.icon = 'dparkour/icon.jpg'

	action.CreateOptionMenu = function(panel)
		UltiPar.CreateConVarMenu(panel, convars)
	end
else
	convars = nil
end
---------------------- 动作逻辑 ----------------------
action.Clear = function()
	// print('高爬动作清除')
end

local GeneralClimbCheck = UltiPar.GeneralClimbCheck
action.Check = function(ply)
	-- 高爬检测范围短, 半个身位左右
	local bmins, bmaxs = ply:GetCollisionBounds()
	local plyWidth = math.max(bmaxs[1] - bmins[1], bmaxs[2] - bmins[2])
	local plyHeight = bmaxs[3] - bmins[3]
	
	local blockHeightMax = dp_lh_max:GetFloat() * plyHeight
	local blockHeightMin = dp_lh_min:GetFloat() * plyHeight

	bmaxs[3] = blockHeightMax

	return GeneralClimbCheck(ply, {
		blen = 0.5 * plyWidth,
		ehlen = 0.5 * plyWidth,
		evlen = blockHeightMax - blockHeightMin,
		bmins = bmins,
		bmaxs = bmaxs,
		loscos = dp_los_cos:GetFloat(),
	})

end

action.CheckEnd = 0.5

action.Play = function(ply, data)
	if CLIENT or data == nil then return end
	local trace, blockheight = unpack(data)

	-- 检测一下落脚点能否站立
	local endpos = trace.HitPos
	local needduck = UltiPar.GeneralLandSpaceCheck(ply, endpos)

	-- 移动的初始速度由玩家移动能力和跳跃能力决定
	local startvel = ply:GetJumpPower() + 0.25 * (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed())
		startvel = math.max(ply:GetVelocity():Length(), startvel)
	
	UltiPar.StartEasyMove(
		ply, 
		ply:GetPos(), 
		0.5, 
		needduck and IN_JUMP or bit.bor(IN_JUMP, IN_DUCK), 
		needduck and IN_DUCK or 0
	)
	timer.Simple(0.1, function()
		UltiPar.StartSmoothMove(
			ply, 
			endpos, 
			startvel,
			0,
			needduck and IN_JUMP or bit.bor(IN_JUMP, IN_DUCK), 
			needduck and IN_DUCK or 0
		)
	end)
end

local function effectfunc_default(ply, data)
	if data == nil then
		-- 演示模式
		if SERVER then
			-- 防止CalcView不兼容, 还是用ViewPunch吧
			ply:ViewPunch(Angle(-20, 5, 0))
			timer.Simple(0.2, function()
				ply:ViewPunch(Angle(20, 0, 0))
			end)
		elseif CLIENT then
			timer.Simple(0.2, function()
				UltiPar.SetVecPunchVel(Vector(0, 0, 25))
			end)
			// UltiPar.SetAngPunchVel(Vector(0, 0, -50))

			VManip:PlayAnim('dp_catch_BaiLang')
			surface.PlaySound('dparkour/bailang/highclimb.mp3')
		end
	else
		if SERVER then
			-- 防止CalcView不兼容, 还是用ViewPunch吧
			ply:ViewPunch(Angle(-20, 5, 0))
			timer.Simple(0.2, function()
				ply:ViewPunch(Angle(20, 0, 0))
			end)
		elseif CLIENT then
			timer.Simple(0.2, function()
				UltiPar.SetVecPunchVel(Vector(0, 0, 25))
			end)
			// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
			
			VManip:PlayAnim('dp_catch_BaiLang')
			surface.PlaySound('dparkour/bailang/highclimb.mp3')
		end
	end
end

local effect, _ = UltiPar.RegisterEffect(
	'DParkour-HighClimb', 
	'default',
	{
		label = '#default'
	}
)
effect.func = effectfunc_default


if CLIENT then
	local triggertime = 0
	hook.Add('Think', 'dparkour.highclimb.trigger', function()
		local ply = LocalPlayer()
		if dp_workmode:GetBool() then return end
		if dp_lh_keymode:GetBool() then 
			if not ply:KeyDown(IN_JUMP) then 
				return 
			end
		else
			if not ply.dp_runtrigger then 
				return 
			end
		end

		local curtime = CurTime()
		if curtime - triggertime < dp_lh_per:GetFloat() then return end
		triggertime = curtime

		UltiPar.Trigger(LocalPlayer(), 'DParkour-HighClimb')
	end)

	hook.Add('KeyPress', 'dparkour.highclimb.trigger', function(ply, key)
		if key == IN_JUMP and dp_lh_keymode:GetBool() and not dp_workmode:GetBool() then 
			UltiPar.Trigger(ply, 'DParkour-HighClimb') 
		end
	end)


	concommand.Add('+dp_highclimb_cl', function(ply)
		ply.dp_runtrigger = true
		UltiPar.Trigger(LocalPlayer(), 'DParkour-HighClimb')
	end)

	concommand.Add('-dp_highclimb_cl', function(ply)
		ply.dp_runtrigger = false
	end)
	
	hook.Add('ShouldDisableLegs', 'dparkour.gmodleg', function()
		return VMLegs and VMLegs:IsActive()
	end)
elseif SERVER then
	local triggertime = 0
	hook.Add('PlayerPostThink', 'dparkour.highclimb.trigger', function(ply)
		if not dp_workmode:GetBool() then return end
		if dp_lh_keymode:GetBool() then 
			if not ply:KeyDown(IN_JUMP) then 
				return 
			end
		else
			if not ply.dp_runtrigger then 
				return 
			end
		end

		local curtime = CurTime()
		if curtime - triggertime < dp_lh_per:GetFloat() then return end
		triggertime = curtime

		UltiPar.Trigger(ply, 'DParkour-HighClimb')
	end)

	hook.Add('KeyPress', 'dparkour.highclimb.trigger', function(ply, key)
		if key == IN_JUMP and dp_lh_keymode:GetBool() and dp_workmode:GetBool() then 
			UltiPar.Trigger(ply, 'DParkour-HighClimb') 
		end
	end)

	concommand.Add('+dp_highclimb_sv', function(ply)
		ply.dp_runtrigger = true
		UltiPar.Trigger(ply, 'DParkour-HighClimb')
	end)

	concommand.Add('-dp_highclimb_sv', function(ply)
		ply.dp_runtrigger = false
	end)
end



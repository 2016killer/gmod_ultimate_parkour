--[[
作者:白狼
2025 11 1
]]--

-- ==================== 低爬动作 ===============
local UltiPar = UltiPar
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
		name = 'dp_lc_blen',
		default = '1.5',
		widget = 'NumSlider',
		min = 0,
		max = 2,
		decimals = 2,
		help = true,
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
	}
}

UltiPar.CreateConVars(convars)
local dp_workmode = GetConVar('dp_workmode')
local dp_los_cos = GetConVar('dp_los_cos')
local dp_falldamage = GetConVar('dp_falldamage')
local dp_lc_keymode = GetConVar('dp_lc_keymode')
local dp_lc_per = GetConVar('dp_lc_per')
local dp_lc_blen = GetConVar('dp_lc_blen')
local dp_lc_min = GetConVar('dp_lc_min')
local dp_lc_max = GetConVar('dp_lc_max')

local actionName = 'DParkour-LowClimb'
local action, _ = UltiPar.Register(actionName)
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
function action:GetSpeed(ply, ref)
	-- 返回爬楼初始速度、结束速度
	return math.max(
			ply:GetJumpPower() + 0.25 * (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed()), 
			(UltiPar.XYNormal(ply:EyeAngles():Forward()) + UltiPar.unitzvec):Dot(ref) * 0.707
        ),
        0
end

function action:Check(ply)
	if ply:GetMoveType() == MOVETYPE_NOCLIP or ply:InVehicle() or !ply:Alive() then 
		return
	end

	local bmins, bmaxs = ply:GetCollisionBounds()
	local plyWidth = math.max(bmaxs[1] - bmins[1], bmaxs[2] - bmins[2])
	local plyHeight = bmaxs[3] - bmins[3]
	
	local blockHeightMax = dp_lc_max:GetFloat() * plyHeight
	local blockHeightMin = dp_lc_min:GetFloat() * plyHeight
    local blen = dp_lc_blen:GetFloat() * plyWidth

	bmaxs[3] = blockHeightMax
	bmins[3] = blockHeightMin

	local startpos, landpos, blockheight = UltiPar.GeneralClimbCheck(ply, 
		blen,
        bmins,
		bmaxs,
		0.5 * plyWidth,
		blockHeightMax - blockHeightMin,
		dp_los_cos:GetFloat()
	)

    if not startpos then 
        return 
    end

    local plyvel = ply:GetVelocity()
	-- 检测摔落伤害
	if dp_falldamage:GetBool() then
        local damageinfo = UltiPar.GetFallDamageInfo(ply, plyvel[3], -600)
        if damageinfo then 
            ply:TakeDamageInfo(damageinfo)
            ply:EmitSound('Player.FallDamage', 100, 100)
        end
	end

	local dis = (landpos - startpos):Length()
	local dir = (landpos - startpos):GetNormal()
    local startspeed, endspeed = self:GetSpeed(ply, plyvel)
	local duration = dis * 2 / (startspeed + endspeed)

    return startpos,
        landpos,
        blockheight,
		plyvel,
        startspeed,
        endspeed, 
        duration,
        CurTime(),
		dir
end

function action:Start(ply, startpos, landpos, ...)
    if CLIENT then return end
    local needduck = UltiPar.GeneralLandSpaceCheck(ply, landpos)
    UltiPar.WriteMoveControl(ply, true, true, 
		needduck and IN_JUMP or bit.bor(IN_DUCK, IN_JUMP),
		needduck and IN_DUCK or 0)
	ply:SetMoveType(MOVETYPE_NOCLIP)
end

function action:Play(ply, mv, cmd, startpos, landpos, blockheight, plyvel, startspeed, endspeed, duration, starttime, dir)
	-- 保险一点
	local dt = CurTime() - starttime

    local acc = (endspeed - startspeed) / duration
	local endflag = dt > duration

	mv:SetOrigin(startpos + (0.5 * acc * dt * dt + startspeed * dt) * dir)

	if endflag then 
		return landpos
	else
		return nil
	end
end

function action:Clear(ply, mv, cmd, landpos)
    ply:SetMoveType(MOVETYPE_WALK)
	if SERVER then
		-- 开环控制必须加这个
	    if UltiPar.GeneralLandSpaceCheck(ply, ply:GetPos()) then
			mv:SetOrigin(landpos)
		end
    end
end

if CLIENT then
	local triggertime = 0
	local Trigger = UltiPar.Trigger
	hook.Add('Think', 'dparkour.lowclimb.trigger', function()
		local ply = LocalPlayer()
		if dp_workmode:GetBool() then 
			return 
		end

		if dp_lc_keymode:GetBool() then 
			if not ply:KeyDown(IN_JUMP) then return end
		else
			if not ply.dp_runtrigger_lc then return end
		end

		local curtime = CurTime()
		if curtime - triggertime < dp_lc_per:GetFloat() then return end
		triggertime = curtime

		Trigger(ply, action)
	end)

	hook.Add('KeyPress', 'dparkour.lowclimb.trigger', function(ply, key)
		if key == IN_JUMP and dp_lc_keymode:GetBool() and not dp_workmode:GetBool() then 
			Trigger(ply, action) 
		end
	end)

	concommand.Add('+dp_lowclimb_cl', function(ply)
		Trigger(ply, action)
		ply.dp_runtrigger_lc = true
	end)

	concommand.Add('-dp_lowclimb_cl', function(ply)
		ply.dp_runtrigger_lc = false
	end)
	
	hook.Add('ShouldDisableLegs', 'dparkour.gmodleg', function()
		return VMLegs and VMLegs:IsActive()
	end)
elseif SERVER then
	local triggertime = 0
	local Trigger = UltiPar.Trigger
	hook.Add('PlayerPostThink', 'dparkour.lowclimb.trigger', function(ply)
		if not dp_workmode:GetBool() then 
			return 
		end

		if dp_lc_keymode:GetBool() then 
			if not ply:KeyDown(IN_JUMP) then return end
		else
			if not ply.dp_runtrigger_lc then return end
		end

		local curtime = CurTime()
		if curtime - triggertime < dp_lc_per:GetFloat() then return end
		triggertime = curtime

		Trigger(ply, action)
	end)

	hook.Add('KeyPress', 'dparkour.lowclimb.trigger', function(ply, key)
		if key == IN_JUMP and dp_lc_keymode:GetBool() and dp_workmode:GetBool() then 
			Trigger(ply, action) 
		end
	end)

	concommand.Add('+dp_lowclimb_sv', function(ply)
		Trigger(ply, action)
		ply.dp_runtrigger_lc = true
	end)

	concommand.Add('-dp_lowclimb_sv', function(ply)
		ply.dp_runtrigger_lc = false
	end)
end
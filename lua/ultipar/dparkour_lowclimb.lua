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
}

UltiPar.CreateConVars(convars)
local dp_workmode = GetConVar('dp_workmode')
local dp_los_cos = GetConVar('dp_los_cos')
local dp_lc_keymode = GetConVar('dp_lc_keymode')
local dp_lc_per = GetConVar('dp_lc_per')
local dp_lc_min = GetConVar('dp_lc_min')
local dp_lc_max = GetConVar('dp_lc_max')



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

	return GeneralClimbCheck(ply, {
		blen = 2 * plyWidth,
		ehlen = 0.5 * plyWidth,
		evlen = blockHeightMax - blockHeightMin,
		bmins = bmins,
		bmaxs = bmaxs,
		loscos = dp_los_cos:GetFloat(),
	})
// if ply:KeyDown(IN_FORWARD) and not ply:KeyDown(IN_DUCK) then
// 		-- 翻越不需要检查落脚点是否在斜坡上
	
// 		-- lhv_wmax 是最大翻越宽度
// 		local lhv_wmax = dp_lhv_wmax:GetFloat() * plyWidth
// 		local maxVaultWidthVec = eyeDir * lhv_wmax

// 		-- 简单检测一下是否会被阻挡
// 		local linelen = (lhv_wmax + 0.707 * plyWidth)
// 		local line = eyeDir * linelen
		
// 		local simpletrace1 = util.QuickTrace(trace.HitPos + unitzvec * dmaxs[3], line, ply)
// 		local simpletrace2 = util.QuickTrace(trace.HitPos + unitzvec * (dmaxs[3] * 0.5), line, ply)
		
// 		if simpletrace1.StartSolid or simpletrace2.StartSolid then
// 			// print('卡住了')
// 			return {trace, false, blockheight}
// 		end

// 		if simpletrace1.Hit or simpletrace2.Hit then
// 			maxVaultWidthVec = eyeDir * math.max(
// 				0, 
// 				linelen * math.min(simpletrace1.Fraction, simpletrace2.Fraction) - plyWidth * 0.707
// 			)
// 		end
// 		debugoverlay.Line(simpletrace1.StartPos, simpletrace1.HitPos, 1, Color(0, 0, 255))
// 		debugoverlay.Line(simpletrace2.StartPos, simpletrace2.HitPos, 1, Color(0, 0, 255))


// 		-- 检查凹陷是否符合条件 
// 		startpos = trace.HitPos + maxVaultWidthVec
// 		endpos = startpos - unitzvec * blockheight

// 		local vchecktrace = util.TraceHull({
// 			filter = ply, 
// 			mask = MASK_PLAYERSOLID,
// 			start = startpos,
// 			endpos = endpos,
// 			mins = dmins,
// 			maxs = dmaxs,
// 		})

// 		debugoverlay.Line(vchecktrace.StartPos, vchecktrace.HitPos, 1, Color(0, 0, 255))
// 		debugwireframebox(vchecktrace.HitPos, dmins, dmaxs, 1, Color(0, 0, 255))


// 		if vchecktrace.StartSolid then
// 			// print('翻越高度检测, 卡住了')
// 			return {trace, false, blockheight}
// 		end

// 		// print(vchecktrace.Fraction * blockheight, math.min(lh_min, 0.2 * plyHeight))
// 		if vchecktrace.Fraction * blockheight < math.min(lh_min, 0.2 * plyHeight) then
// 			// print('凹陷程度不足')
// 			return {trace, false, blockheight}
// 		end

// 		debugoverlay.Line(vchecktrace.StartPos, vchecktrace.HitPos, 0.5, Color(0, 0, 255))
// 		debugwireframebox(vchecktrace.HitPos, dmins, dmaxs, 0.5, Color(0, 0, 255))

// 		local pmins, pmaxs = ply:GetCollisionBounds()

// 		startpos = vchecktrace.HitPos + unitzvec
// 		endpos = startpos - maxVaultWidthVec
// 		hchecktrace = util.TraceHull({
// 			filter = ply, 
// 			mask = MASK_PLAYERSOLID,
// 			start = startpos,
// 			endpos = endpos,
// 			mins = pmins,
// 			maxs = pmaxs,
// 		})

// 		if hchecktrace.HitPos:Distance2DSqr(trace.HitPos) > lhv_wmax * lhv_wmax then
// 			// print('翻越宽度不符合')
// 			return {trace, false, blockheight}
// 		end

// 		debugoverlay.Line(hchecktrace.StartPos, hchecktrace.HitPos, 0.5, Color(0, 0, 0))
// 		debugwireframebox(hchecktrace.HitPos, pmins, pmaxs, 0.5, Color(0, 0, 0))

// 		hchecktrace.HitPos = hchecktrace.HitPos + eyeDir * math.min(5, hchecktrace.Fraction * lhv_wmax)

// 		return {trace, hchecktrace, blockheight}
// 	else
// 		return {trace, false, blockheight}
// 	end

end

action.CheckEnd = 0.5

action.Play = function(ply, data)
	if CLIENT or data == nil then return end
	local trace, blockheight = unpack(data)

	-- 检测一下落脚点能否站立
	local endpos = trace.HitPos
	local pmins, pmaxs = ply:GetHull()
	local spacecheck = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = endpos,
		endpos = endpos,
		mins = pmins,
		maxs = pmaxs,
	})

	-- 如果不能站立, 则需要蹲
	local needduck = spacecheck.Hit or spacecheck.StartSolid

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
end

local function effectfunc_default(ply, data)
	if SERVER then return end

	if data == nil then
		-- 演示模式
		UltiPar.SetVecPunchVel(Vector(0, 0, 25))
		UltiPar.SetAngPunchVel(Vector(0, 0, -50))
		VManip:PlayAnim('vault')
		surface.PlaySound('dparkour/bailang/lowclimb.mp3')
	else
		UltiPar.SetVecPunchVel(Vector(0, 0, 25))
		UltiPar.SetAngPunchVel(Vector(0, 0, -50))
		VManip:PlayAnim('vault')
		surface.PlaySound('dparkour/bailang/lowclimb.mp3')
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



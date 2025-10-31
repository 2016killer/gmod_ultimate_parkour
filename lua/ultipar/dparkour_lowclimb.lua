--[[
原文件作者:白狼
主页:https://steamcommunity.com/id/whitewolfking/
此文件为其修改版本。
]]--

---------------------- 低爬动作 ----------------------
local function XYNormal(v)
	v[3] = 0
	v:Normalize()
	return v
end

local unitvec = Vector(0, 0, 1)

---------------------- 菜单 ----------------------
local dp_workmode = CreateConVar('dp_workmode', '1', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_los_cos = CreateConVar('dp_los_cos', '0.64', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })

local dp_lc_keymode = CreateConVar('dp_lc_keymode', '1', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lc_per = CreateConVar('dp_lc_per', '0.2', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lc_max = CreateConVar('dp_lc_max', '0.75', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lc_min = CreateConVar('dp_lc_min', '0.5', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lcv_wmax = CreateConVar('dp_lcv_wmax', '2.5', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lcv_hmax = CreateConVar('dp_lcv_hmax', '0.3', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lcv_smin = CreateConVar('dp_lcv_smin', '200', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })

local action, _ = UltiPar.Register('DParkour-LowClimb')
if CLIENT then
	action.label = '#dp.lowclimb'
	action.icon = 'dparkour/icon.jpg'

	action.CreateOptionMenu = function(panel)
		panel:Clear()
		panel:CheckBox('#dp.workmode', 'dp_workmode')
		panel:ControlHelp('#dp.workmode.help')

		panel:NumSlider('#dp.los_cos', 'dp_los_cos', 0, 1, 2)
		panel:ControlHelp('#dp.los_cos.help')

		panel:Help('#dp.lc.help')
		
		panel:CheckBox('#dp.lc_keymode', 'dp_lc_keymode')
		panel:ControlHelp('#dp.lc_keymode.help')

		panel:NumSlider('#dp.lc_max', 'dp_lc_max', 0, 1, 2)
		panel:NumSlider('#dp.lc_min', 'dp_lc_min', 0, 1, 2)

		panel:NumSlider('#dp.lcv_wmax', 'dp_lcv_wmax', 0, 3, 2)
		panel:NumSlider('#dp.lcv_hmax', 'dp_lcv_hmax', 0, 1, 2)
		panel:ControlHelp('#dp.lcv_hmax.help')
		panel:NumSlider('#dp.lcv_smin', 'dp_lcv_smin', 100, 300, 0)
		
		local default = panel:Button('#default', '')
		default.DoClick = function()
			LocalPlayer():ConCommand('dp_workmode 1')
			LocalPlayer():ConCommand('dp_los_cos 0.64')
			LocalPlayer():ConCommand('dp_lc_per 0.2')
			LocalPlayer():ConCommand('dp_lc_max 0.75')
			LocalPlayer():ConCommand('dp_lc_min 0.5')
			LocalPlayer():ConCommand('dp_lcv_wmax 2.5')
			LocalPlayer():ConCommand('dp_lcv_hmax 0.3')
			LocalPlayer():ConCommand('dp_lcv_smin 200')
		end
	end
end

action.Check = function(ply)
	if ply:GetMoveType() == MOVETYPE_NOCLIP or ply:InVehicle() or !ply:Alive() then 
		return
	end
	
	local eyeDir = XYNormal(ply:GetForward())
	local pos = ply:GetPos() + unitvec

	local bmins, bmaxs = ply:GetCollisionBounds()
	local plyWidth = math.max(bmaxs[1] - bmins[1], bmaxs[2] - bmins[2])
	local plyHeight = bmaxs[3] - bmins[3]
	
	local lc_min = dp_lc_min:GetFloat()
	local lc_max = dp_lc_max:GetFloat()
	local lcv_wmax = dp_lcv_wmax:GetFloat()
	local lcv_hmax = dp_lcv_hmax:GetFloat()

	-- 把碰撞盒最低点抬到18单位, 主要是因为18一般是台阶的高度, 是能够走上去的
	bmaxs[3] = bmins[3] + lc_min * plyHeight
	bmins[3] = math.max(bmins[3], math.min(18, bmaxs[3]))
	

	-- 检测障碍
	local BlockTrace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = pos,
		endpos = pos + eyeDir * plyWidth * 2,
		mins = bmins,
		maxs = bmaxs,
	})

	debugoverlay.Box(BlockTrace.HitPos, bmins, bmaxs, 0.05, BlockTrace.Hit and BlockTrace.HitNormal[3] < 0.707 and Color(255, 0, 0) or Color(0, 255, 0))
	if not BlockTrace.Hit or BlockTrace.HitNormal[3] >= 0.707 then
		-- print('非障碍')
		return
	end

	-- 判断是否对准了障碍物
	local temp = -Vector(BlockTrace.HitNormal)
	temp[3] = 0
	if temp:Dot(eyeDir) < dp_los_cos:GetFloat() then 
		-- print('未对准')
		return 
	end

	-- 确保不是被玩家拿着的物品挡住了
	if SERVER and BlockTrace.Entity:IsPlayerHolding() then
		-- print('被玩家拿着')
		return
	end
	
	-- 现在要找到落脚点并且确保落脚点有足够空间, 所以检测蹲时的碰撞盒
	-- 假设蹲时的碰撞盒小于站立时
	local dmins, dmaxs = ply:GetHullDuck()

	-- 从碰撞点往前走半个身位看看有没有落脚点
	local startpos = BlockTrace.HitPos + Vector(0, 0, lc_max * plyHeight) + eyeDir * plyWidth * 0.5
	local endpos = BlockTrace.HitPos - eyeDir * plyWidth * 0.5

	local trace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = startpos,
		endpos = endpos,
		mins = dmins,
		maxs = dmaxs,
	})

	-- 确保落脚位置不在滑坡上
	if trace.HitNormal[3] < 0.707 then
		-- print('在滑坡上')
		return
	end

	-- 检测落脚点是否有足够空间
	local trlen = trace.Fraction * (startpos[3] - endpos[3])
	-- OK, 预留1的单位高度防止极端情况
	if trlen < 1 then
		-- print('卡住了')
		return
	end
	

	-- 必须确保障碍高度在lc_min和lc_max之间, 一般低于最低值的情况应该是踩空了
	local blockheight = trace.HitPos[3] - pos[3]
	if blockheight > lc_max * plyHeight or blockheight < lc_min * plyHeight then
		-- print('高度不符合')
		return
	end

	 
	debugoverlay.Line(trace.StartPos, trace.HitPos, 0.05, Color(255, 255, 0))
	debugoverlay.Box(trace.HitPos, dmins, dmaxs, 0.05, Color(255, 255, 0))

	-- OK, 如果按下了前向键的话, 再检测一下是否符合翻越条件
	if ply:KeyDown(IN_FORWARD) then
		-- 翻越不需要检查落脚点是否在斜坡上
		-- lcv_hmax 新落脚点最大高度。
		-- lcv_wmax 是最大翻越宽度
		
		-- 检查凹陷是否符合条件 
		startpos = trace.HitPos + eyeDir * plyWidth * lcv_wmax
		endpos = startpos - Vector(0, 0, blockheight)

		local vchecktrace = util.TraceHull({
			filter = ply, 
			mask = MASK_PLAYERSOLID,
			start = startpos,
			endpos = endpos,
			mins = dmins,
			maxs = dmaxs,
		})

		-- 确保落在凹陷的地方
		if vchecktrace.HitPos[3] - pos[3] > lcv_hmax * plyHeight then
			-- print('翻越高度不符合')
			return
		end

		debugoverlay.Line(vchecktrace.StartPos, vchecktrace.HitPos, 0.05, Color(0, 0, 255))
		debugoverlay.Box(vchecktrace.HitPos, dmins, dmaxs, 0.05, Color(0, 0, 255))


		startpos = vchecktrace.HitPos + unitvec
		endpos = startpos - eyeDir * plyWidth * lcv_wmax
		hchecktrace = util.TraceHull({
			filter = ply, 
			mask = MASK_PLAYERSOLID,
			start = startpos,
			endpos = endpos,
			mins = dmins,
			maxs = dmaxs,
		})

		if hchecktrace.HitPos:Distance2D(trace.HitPos) > lcv_wmax * plyWidth then
			-- print('翻越宽度不符合')
			return
		end

		debugoverlay.Line(hchecktrace.StartPos, hchecktrace.HitPos, 0.05, Color(0, 0, 0))
		debugoverlay.Box(hchecktrace.HitPos, dmins, dmaxs, 0.05, Color(0, 0, 0))

		return {hchecktrace, true}
	else
		trace.HitPos[3] = trace.HitPos[3] + 1
		return {trace, false}
	end

end

action.CheckEnd = 0.5

action.Play = function(ply, data)
	local trace, dovault = unpack(data)

	UltiPar.StartEasyMove(ply, trace.HitPos, 0.5)
end



// hook.Add('CreateMove', 'dj2climb', function(cmd)
// 	if Notclimbing then return end
// 	//cmd:ClearButtons()
// 	if !LocalPlayer():Alive() then Notclimbing = true end
// 	cmd:ClearMovement()
// 	cmd:RemoveKey(IN_JUMP)
// 	if NeedDuck then cmd:AddKey(IN_DUCK) end
// end)

action.Effects = action.Effects or {}


if CLIENT then
	-- 视图震动特效
	local vault_punch_vel = 0
	local vault_punch_offset = 0
	local vault_punch = false
	hook.Add('CalcView', 'dparkour_vault', function(ply, pos, angles, fov)
		local dt = FrameTime()
		local acc = -(vault_punch_offset * 50 + 10 * vault_punch_vel)
		vault_punch_offset = vault_punch_offset + vault_punch_vel * dt 
		vault_punch_vel = vault_punch_vel + acc * dt	

		local view = GAMEMODE:CalcView(ply, pos, angles, fov) 
		view.origin = view.origin + vault_punch_offset * Vector((view.angles - ply:GetViewPunchAngles()):Forward())
		return view
	end)
end


local function VManipBaiLang(ply, data)
	if CLIENT then
		vault_punch = true
		vault_punch_vel = 50
		VManip:PlayAnim('longvault1')
		VMLegs:PlayAnim('lazyvaultnew')
	else
		ply:ViewPunch(Angle(0, 0, 50))
	end
end

action.Effects['VManip-白狼'] = {
	label = '#dp.VManipBaiLang',
	func = nil,
}

action.Effects['VManip-mtbNTB'] = {
	label = '#dp.VManipMtbNTB',
	func = nil,
}

action.Effects['VManip-datae'] = {
	label = '#dp.VManipdatae',
	func = nil,
}




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

	concommand.Add('+dp_lowclimb_cl', function(ply)
		ply.dp_runtrigger = true
	end)

	concommand.Add('-dp_lowclimb_cl', function(ply)
		ply.dp_runtrigger = false
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

	concommand.Add('+dp_lowclimb_sv', function(ply)
		ply.dp_runtrigger = true
	end)

	concommand.Add('-dp_lowclimb_sv', function(ply)
		ply.dp_runtrigger = false
	end)

end


hook.Add('ShouldDisableLegs', 'dparkour.gmodleg', function()
	return VMLegs:IsActive()
end)
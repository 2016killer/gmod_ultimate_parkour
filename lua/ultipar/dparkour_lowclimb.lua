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

local function debugwireframebox(pos, mins, maxs, lifetime, color, ignoreZ)
	lifetime = lifetime or 1
	color = color or Color(255,255,255)
	ignoreZ = ignoreZ or false

	local ref = mins + pos

	local temp = maxs - mins
	local axes = {Vector(0, 0, temp.z), Vector(0, temp.y, 0), Vector(temp.x, 0, 0)}

	for i = 1, 3 do
		for j = 0, 3 do
			local pos1 = ref
			if bit.band(j, 0x01) ~= 0 then pos1 = pos1 + axes[1] end
			if bit.band(j, 0x02) ~= 0 then pos1 = pos1 + axes[2] end

			debugoverlay.Line(pos1, pos1 + axes[3], lifetime, color, ignoreZ)
		end
		axes[i], axes[3] = axes[3], axes[i]
	end
end

local unitzvec = Vector(0, 0, 1)

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
		
		panel:NumSlider('#dp.lc_per', 'dp_lc_per', 0.2, 3600, 2)

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
	local pos = ply:GetPos() + unitzvec

	local bmins, bmaxs = ply:GetCollisionBounds()
	local plyWidth = math.max(bmaxs[1] - bmins[1], bmaxs[2] - bmins[2])
	local plyHeight = bmaxs[3] - bmins[3]
	
	local lc_min = dp_lc_min:GetFloat() * plyHeight
	local lc_max = dp_lc_max:GetFloat() * plyHeight
	local lcv_wmax = dp_lcv_wmax:GetFloat() * plyWidth
	local lcv_hmax = dp_lcv_hmax:GetFloat() * plyHeight

	bmaxs[3] = lc_max
	bmins[3] = lc_min
	
	-- 检测障碍
	local BlockTrace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = pos,
		endpos = pos + eyeDir * plyWidth * 2,
		mins = bmins,
		maxs = bmaxs,
	})

	debugwireframebox(BlockTrace.HitPos, bmins, bmaxs, 0.5, BlockTrace.Hit and BlockTrace.HitNormal[3] < 0.707 and Color(255, 0, 0) or Color(0, 255, 0))
	if not BlockTrace.Hit or BlockTrace.HitNormal[3] >= 0.707 then
		// print('非障碍')
		return
	end

	-- 判断是否对准了障碍物
	local temp = -Vector(BlockTrace.HitNormal)
	temp[3] = 0
	if temp:Dot(eyeDir) < dp_los_cos:GetFloat() then 
		// print('未对准')
		return 
	end

	-- 确保不是被玩家拿着的物品挡住了
	if SERVER and BlockTrace.Entity:IsPlayerHolding() then
		// print('被玩家拿着')
		return
	end
	
	-- 现在要找到落脚点并且确保落脚点有足够空间, 所以检测蹲时的碰撞盒
	-- 假设蹲时的碰撞盒小于站立时
	local dmins, dmaxs = ply:GetHullDuck()

	-- 从碰撞点往前走半个身位看看有没有落脚点
	local startpos = BlockTrace.HitPos + unitzvec * lc_max + eyeDir * plyWidth * 0.5
	local endpos = BlockTrace.HitPos + eyeDir * plyWidth * 0.5

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
		// print('在滑坡上')
		return
	end

	-- 检测落脚点是否有足够空间
	local trlen = trace.Fraction * (startpos[3] - endpos[3])
	-- OK, 预留1的单位高度防止极端情况
	if trace.StartSolid or trlen < 1 then
		// print('卡住了')
		return
	end
	

	-- 必须确保障碍高度在lc_min和lc_max之间, 一般低于最低值的情况应该是踩空了
	local blockheight = trace.HitPos[3] - pos[3]
	if blockheight > lc_max or blockheight < lc_min then
		// print('高度不符合')
		return
	end

	// PrintTable(trace)
	debugoverlay.Line(trace.StartPos, trace.HitPos, 0.5, Color(255, 255, 0))
	debugwireframebox(trace.StartPos, dmins, dmaxs, 0.5, Color(0, 255, 255))
	debugwireframebox(trace.HitPos, dmins, dmaxs, 0.5, Color(255, 255, 0))

	-- OK, 如果按下了前向键的话, 再检测一下是否符合翻越条件
	if ply:KeyDown(IN_FORWARD) then
		-- 翻越不需要检查落脚点是否在斜坡上
		-- lcv_hmax 新落脚点最大高度。
		-- lcv_wmax 是最大翻越宽度
		local maxVaultWidthVec = eyeDir * lcv_wmax

		local simpletrace1 = util.QuickTrace(trace.HitPos + unitzvec * 2, maxVaultWidthVec, ply)
		local simpletrace2 = util.QuickTrace(trace.HitPos + unitzvec * dmaxs[3], maxVaultWidthVec, ply)

		if simpletrace1.Hit or simpletrace2.Hit then
			// print('阻挡')
			return {trace, false}
		end

		-- 检查凹陷是否符合条件 
		startpos = trace.HitPos + maxVaultWidthVec
		endpos = startpos - unitzvec * blockheight

		local vchecktrace = util.TraceHull({
			filter = ply, 
			mask = MASK_PLAYERSOLID,
			start = startpos,
			endpos = endpos,
			mins = dmins,
			maxs = dmaxs,
		})

		if vchecktrace.StartSolid then
			// print('翻越高度检测, 卡住了')
			return {trace, false}
		end

		-- 确保落在凹陷的地方
		if vchecktrace.HitPos[3] - pos[3] > lcv_hmax then
			// print('翻越高度不符合')
			return {trace, false}
		end

		debugoverlay.Line(vchecktrace.StartPos, vchecktrace.HitPos, 0.5, Color(0, 0, 255))
		debugwireframebox(vchecktrace.HitPos, dmins, dmaxs, 0.5, Color(0, 0, 255))


		startpos = vchecktrace.HitPos + unitzvec
		endpos = startpos - maxVaultWidthVec
		hchecktrace = util.TraceHull({
			filter = ply, 
			mask = MASK_PLAYERSOLID,
			start = startpos,
			endpos = endpos,
			mins = dmins,
			maxs = dmaxs,
		})

		if hchecktrace.HitPos:Distance2DSqr(trace.HitPos) > lcv_wmax * lcv_wmax then
			// print('翻越宽度不符合')
			return {trace, false}
		end

		debugoverlay.Line(hchecktrace.StartPos, hchecktrace.HitPos, 0.5, Color(0, 0, 0))
		debugwireframebox(hchecktrace.HitPos, dmins, dmaxs, 0.5, Color(0, 0, 0))

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



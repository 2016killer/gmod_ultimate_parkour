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

local debugwireframebox = UltiPar.debugwireframebox

local unitzvec = Vector(0, 0, 1)

---------------------- 菜单 ----------------------
local dp_workmode = CreateConVar('dp_workmode', '1', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_los_cos = CreateConVar('dp_los_cos', '0.64', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })

local dp_lc_keymode = CreateConVar('dp_lc_keymode', '1', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lc_per = CreateConVar('dp_lc_per', '0.2', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lc_max = CreateConVar('dp_lc_max', '0.85', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lc_min = CreateConVar('dp_lc_min', '0.5', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lcv_wmax = CreateConVar('dp_lcv_wmax', '2', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lcv_hmax = CreateConVar('dp_lcv_hmax', '0.3', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
local dp_lcdv_h = CreateConVar('dp_lcdv_h', '0.7', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })

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

		panel:NumSlider('#dp.lc_per', 'dp_lc_per', 0.05, 3600, 2)

		panel:CheckBox('#dp.lc_keymode', 'dp_lc_keymode')
		panel:ControlHelp('#dp.lc_keymode.help')

		panel:NumSlider('#dp.lc_max', 'dp_lc_max', 0, 1, 2)
		panel:ControlHelp('#dp.lc_max.help')
		panel:NumSlider('#dp.lc_min', 'dp_lc_min', 0, 1, 2)

		panel:NumSlider('#dp.lcv_wmax', 'dp_lcv_wmax', 0, 3, 2)
		panel:ControlHelp('#dp.lcv_wmax.help')
		panel:NumSlider('#dp.lcv_hmax', 'dp_lcv_hmax', 0, 1, 2)
		panel:ControlHelp('#dp.lcv_hmax.help')
		panel:NumSlider('#dp.lcdv_h', 'dp_lcdv_h', 0, 1, 2)
		panel:ControlHelp('#dp.lcdv_h.help')
		
		local default = panel:Button('#default', '')
		default.DoClick = function()
			LocalPlayer():ConCommand('dp_workmode 1')
			LocalPlayer():ConCommand('dp_los_cos 0.64')
			LocalPlayer():ConCommand('dp_lc_per 0.2')
			LocalPlayer():ConCommand('dp_lc_max 0.85')
			LocalPlayer():ConCommand('dp_lc_min 0.5')
			LocalPlayer():ConCommand('dp_lcv_wmax 2')
			LocalPlayer():ConCommand('dp_lcv_hmax 0.3')
			LocalPlayer():ConCommand('dp_lcdv_h 0.7')
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

	-- 我们假设玩家的碰撞盒不是悬空的也就是bmins[3] = 0
	bmaxs[3] = lc_max
	bmins[3] = lc_min

	-- 检测障碍, 这是主要是为了检查是否对准了障碍物
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
	// print(blockheight)
	if blockheight > lc_max or blockheight < lc_min then
		// print('高度不符合')
		return
	end

	// PrintTable(trace)
	debugoverlay.Line(trace.StartPos, trace.HitPos, 0.5, Color(255, 255, 0))
	debugwireframebox(trace.StartPos, dmins, dmaxs, 0.5, Color(0, 255, 255))
	debugwireframebox(trace.HitPos, dmins, dmaxs, 0.5, Color(255, 255, 0))

	-- OK, 如果按下了前向键并且高度在可翻越的范围内, 再检测一下是否符合翻越条件
	local lcv_wmax = dp_lcv_wmax:GetFloat() * plyWidth
	local lcv_hmax = dp_lcv_hmax:GetFloat() * plyHeight
	
	trace.HitPos[3] = trace.HitPos[3] + 1
	if ply:KeyDown(IN_FORWARD) then
		-- 翻越不需要检查落脚点是否在斜坡上
	
		-- lcv_hmax 新落脚点必须小于这个高度。
		-- lcv_wmax 是最大翻越宽度
		local maxVaultWidthVec = eyeDir * lcv_wmax

		-- 简单检测一下是否会被阻挡
		local simpletrace1 = util.QuickTrace(trace.HitPos + unitzvec * 2, maxVaultWidthVec, ply)
		local simpletrace2 = util.QuickTrace(trace.HitPos + unitzvec * dmaxs[3], maxVaultWidthVec, ply)

		if simpletrace1.Hit or simpletrace2.Hit then
			// print('阻挡')
			return {trace, false, blockheight}
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
			return {trace, false, blockheight}
		end

		-- 确保落在凹陷的地方
		if vchecktrace.HitPos[3] - pos[3] > lcv_hmax then
			// print('翻越高度不符合')
			return {trace, false, blockheight}
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
			return {trace, false, blockheight}
		end

		debugoverlay.Line(hchecktrace.StartPos, hchecktrace.HitPos, 0.5, Color(0, 0, 0))
		debugwireframebox(hchecktrace.HitPos, dmins, dmaxs, 0.5, Color(0, 0, 0))

		hchecktrace.HitPos = hchecktrace.HitPos + eyeDir * math.min(5, hchecktrace.Fraction * lcv_wmax)

		return {trace, hchecktrace, blockheight}
	else
		return {trace, false, blockheight}
	end

end

action.CheckEnd = 0.5

local function DPVault(ply, mv, cmd)
	local movedata = ply.ultipar_move
	local dt = CurTime() - movedata.starttime

	mv:SetOrigin(
		movedata.startpos + 
		(0.5 * movedata.acc * dt * dt + movedata.startvel * dt) * movedata.dir +
		(0.5 * -200 / movedata.duration * dt * dt + 100 * dt) * unitzvec
	) 

	// print(,movedata.duration)
	
	if dt >= movedata.duration then 
		mv:SetOrigin(movedata.endpos)
		ply:SetMoveType(MOVETYPE_WALK)
		mv:SetVelocity(movedata.endvel * movedata.dir)
		ply.ultipar_move = nil -- 移动结束, 清除移动数据
		UltiPar.SetMoveControl(ply, false, false, 0, 0)
	end
end

local function StartDPVault(ply, endpos, endvel)
	ply:SetMoveType(MOVETYPE_NOCLIP)

	local startvel = ply:GetVelocity():Length()
	local dir = (endpos - ply:GetPos()):GetNormal()
	local dis = (endpos - ply:GetPos()):Length()
	local duration = 2 * dis / (endvel + startvel)
	local acc = (endvel - startvel) / duration

	ply.ultipar_move = {
		Call = DPVault,
		startpos = ply:GetPos(),
		endpos = endpos,
		duration = duration,
		starttime = CurTime(),
		startvel = startvel,
		endvel = math.max(endvel, startvel),
		acc = acc,
		dir = dir,
	}

	UltiPar.SetMoveControl(ply, true, true, removekeys or IN_JUMP, addkeys or 0)
end

local function DPUpWall(ply, mv, cmd)
	local movedata = ply.ultipar_move
	local dt = CurTime() - movedata.starttime

	mv:SetOrigin(
		movedata.startpos + 
		(0.5 * movedata.acc * dt * dt + movedata.startvel * dt) * movedata.dir
	) 

	if dt >= movedata.duration then 
		mv:SetOrigin(movedata.endpos)
		ply:SetMoveType(MOVETYPE_WALK)
		ply.ultipar_move = nil -- 移动结束, 清除移动数据
		UltiPar.SetMoveControl(ply, false, false, 0, 0)
	end
end

local function StartDPUpWall(ply, endpos, startvel)
	ply:SetMoveType(MOVETYPE_NOCLIP)

	local dir = (endpos - ply:GetPos()):GetNormal()
	local dis = (endpos - ply:GetPos()):Length()
	local duration = 2 * dis / startvel
	local acc = -startvel / duration

	ply.ultipar_move = {
		Call = DPUpWall,
		startpos = ply:GetPos(),
		endpos = endpos,
		duration = duration,
		starttime = CurTime(),
		startvel = startvel,
		acc = acc,
		dir = dir,
	}

	UltiPar.SetMoveControl(ply, true, true, removekeys or IN_JUMP, addkeys or 0)
end


local function DPDoubleVault(ply, mv, cmd)
	local movedata = ply.ultipar_move
	local dt = CurTime() - movedata.starttime

	if dt < movedata.duration then 
		mv:SetOrigin(
			movedata.startpos + 
			(0.5 * movedata.acc * dt * dt + movedata.startvel * dt) * movedata.dir
		) 
	elseif dt < movedata.duration + movedata.duration2 then
		dt = dt - movedata.duration
		mv:SetOrigin(
			movedata.endpos + 
			(0.5 * movedata.acc2 * dt * dt + movedata.startvel2 * dt) * movedata.dir2 +
			(0.5 * -200 / movedata.duration2 * dt * dt + 100 * dt) * unitzvec
		) 
	else
		mv:SetOrigin(movedata.endpos2)
		ply:SetMoveType(MOVETYPE_WALK)
		mv:SetVelocity(movedata.endvel2 * movedata.dir2)
		ply.ultipar_move = nil -- 移动结束, 清除移动数据
		UltiPar.SetMoveControl(ply, false, false, 0, 0)
	end
end

local function StartDPDoubleVault(ply, endpos, endpos2, startvel, endvel2)
	ply:SetMoveType(MOVETYPE_NOCLIP)

	local plyvel = ply:GetVelocity():Length()
	endvel2 = math.max(endvel2, plyvel)
	startvel = math.max(startvel, plyvel)

	endvel2 = math.max(endvel2, startvel)

	local endvel = startvel * 0.5
	local dir = (endpos - ply:GetPos()):GetNormal()
	local dis = (endpos - ply:GetPos()):Length()
	local duration = 2 * dis / (endvel + startvel)
	local acc = (endvel - startvel) / duration

	local startvel2 = endvel
	local dir2 = (endpos2 - endpos):GetNormal()
	local dis2 = (endpos2 - endpos):Length()
	local duration2 = 2 * dis2 / (endvel2 + startvel2)
	local acc2 = (endvel2 - startvel2) / duration2

	ply.ultipar_move = {
		Call = DPDoubleVault,
		startpos = ply:GetPos(),
		starttime = CurTime(),
		endpos = endpos,
		endpos2 = endpos2,
		duration = duration,
		duration2 = duration2,
		endvel = endvel,
		endvel2 = endvel2 * 0.9,
		startvel = startvel,
		startvel2 = startvel2,
		acc = acc,
		acc2 = acc2,
		dir = dir,
		dir2 = dir2,
	}

	UltiPar.SetMoveControl(ply, true, true, removekeys or IN_JUMP, addkeys or 0)
end

UltiPar.StartDPVault = StartDPVault
UltiPar.StartDPUpWall = StartDPUpWall
UltiPar.StartDPDoubleVault = StartDPDoubleVault

action.Play = function(ply, data)
	if CLIENT then return end
	local trace, dovault, blockheight = unpack(data)

	// UltiPar.StartEasyMove(ply, trace.HitPos, 0.3)

	if dovault then
		-- 触发二段翻越时, 首先触发低爬直到障碍高度为最小高度
		-- 整体节奏是以初始速度低爬衰减到0.5倍, 再加速翻越, 最终速度将是0.9倍
		
		local endvel = ply:GetJumpPower() + (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed())
		local pmins, pmaxs = ply:GetCollisionBounds()
		local plyHeight = pmaxs[3] - pmins[3]
		if blockheight > dp_lcdv_h:GetFloat() * plyHeight then
			local startvel = ply:GetJumpPower() + 0.25 * (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed())
			local endvel2 = endvel
			StartDPDoubleVault(
				ply, 
				trace.HitPos - dp_lc_min:GetFloat() * plyHeight * unitzvec, dovault.HitPos, 
				startvel, 
				endvel2
			)
		else
			StartDPVault(ply, dovault.HitPos, endvel)
		end
	else
		local startvel = ply:GetJumpPower() + 0.25 * (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed())
		StartDPUpWall(ply, trace.HitPos, startvel)
	end
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



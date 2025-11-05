--[[
	作者:白狼
	2025 11 1

	使用ActionSet存储动作
	ActionSet以及Action.Effects具有单向写入的性质, 不支持覆盖。
	在这里, 我们使用API Register和RegisterEffect注册动作和特效, 而不是直接操作ActionSet
--]]

local function XYNormal(v)
	v[3] = 0
	v:Normalize()
	return v
end

local unitzvec = Vector(0, 0, 1)

UltiPar = UltiPar or {}

UltiPar.GeneralClimbCheck = function(ply, appenddata)
	-- 通用障碍检查
	-- 检查前方是否有障碍并且检测是否有落脚点

	-- appenddata.blen 阻碍检测的水平距离
	-- appenddata.bmins 阻碍检测碰撞盒mins
	-- appenddata.bmaxs 阻碍检测碰撞盒maxs

	-- appenddata.ehlen 落脚点检测的水平距离
	-- appenddata.evlen 落脚点检测的垂直距离
	-- appenddata.loscos 视线与障碍物法线的余弦值, 用于判断是否对准了障碍物

	-- {落脚点检测数据, 障碍高度}

	if ply:GetMoveType() == MOVETYPE_NOCLIP or ply:InVehicle() or !ply:Alive() then 
		return
	end
	
	local eyeDir = XYNormal(ply:GetForward())
	local pos = ply:GetPos() + unitzvec

	-- 检测障碍, 这是主要是为了检查是否对准了障碍物
	local BlockTrace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = pos,
		endpos = pos + eyeDir * appenddata.blen,
		mins = appenddata.bmins,
		maxs = appenddata.bmaxs,
	})

	// debugwireframebox(
	// 	BlockTrace.HitPos, 
	// 	appenddata.bmins, 
	// 	appenddata.bmaxs, 1, BlockTrace.Hit and BlockTrace.HitNormal[3] < 0.707 and Color(255, 0, 0) or Color(0, 255, 0)
	// )
	if not BlockTrace.Hit or BlockTrace.HitNormal[3] >= 0.707 then
		// print('非障碍')
		return
	end

	-- 判断是否对准了障碍物
	local temp = -Vector(BlockTrace.HitNormal)
	temp[3] = 0
	if temp:Dot(eyeDir) < appenddata.loscos then 
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

	-- 从碰撞点往前走一点看有没有落脚点
	local startpos = BlockTrace.HitPos + unitzvec * appenddata.bmaxs[3] + eyeDir * appenddata.ehlen
	local endpos = startpos - unitzvec * appenddata.evlen

	local trace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = startpos,
		endpos = endpos,
		mins = dmins,
		maxs = dmaxs,
	})

	-- 确保落脚位置不在滑坡上且在障碍物上
	if not trace.Hit or trace.HitNormal[3] < 0.707 then
		// print('在滑坡上或不在障碍物上')
		return
	end

	-- 检测落脚点是否有足够空间
	-- OK, 预留1的单位高度防止极端情况
	if trace.StartSolid or trace.Fraction * appenddata.evlen < 1 then
		// print('卡住了')
		return
	end
	
	// PrintTable(trace)
	// debugoverlay.Line(trace.StartPos, trace.HitPos, 1, Color(255, 255, 0))
	// debugwireframebox(trace.StartPos, dmins, dmaxs, 1, Color(0, 255, 255))
	// debugwireframebox(trace.HitPos, dmins, dmaxs, 1, Color(255, 255, 0))

	trace.HitPos[3] = trace.HitPos[3] + 1

	// print(trace.HitPos[3] - pos[3])
	return {
		pos,
		trace.HitPos, 
		trace.HitPos[3] - pos[3]
	}
end

UltiPar.GeneralLandSpaceCheck = function(ply, pos)
	-- 通用站立空间检查
	local pmins, pmaxs = ply:GetHull()
	local spacecheck = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = pos,
		endpos = pos,
		mins = pmins,
		maxs = pmaxs,
	})
	
	return spacecheck.StartSolid or spacecheck.Hit 
end

UltiPar.GeneralVaultCheck = function(ply, appenddata)
	-- 通用翻越检查, 一般是接在GeneralClimbCheck后面
	-- 从落脚点开始检测, 主要检测障碍物的镜像面是否符合条件

	-- appenddata.landdata {落脚点位置, 障碍高度} 由GeneralClimbCheck返回
	-- appenddata.hlen 检测的水平范围
	-- appenddata.vlen 检测的垂直范围

	-- {落脚点检测数据, 障碍镜像高度}

	-- 翻越不需要检查落脚点是否在斜坡上

	if not ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_DUCK) then 
		return
	end
	
	-- 假设蹲伏不会改变玩家宽度
	local landdata = appenddata.landdata
	local dmins, dmaxs = ply:GetHullDuck()
	local playWidth = math.max(dmaxs[1] - dmins[1], dmaxs[2] - dmins[2])
	local eyeDir = XYNormal(ply:GetForward())
	local pos = landdata[1]


	-- 简单检测一下是否会被阻挡
	local linelen = appenddata.hlen + 0.707 * playWidth
	local line = eyeDir * linelen
	
	local simpletrace1 = util.QuickTrace(landdata[2] + unitzvec * dmaxs[3], line, ply)
	local simpletrace2 = util.QuickTrace(landdata[2] + unitzvec * (dmaxs[3] * 0.5), line, ply)
	
	// debugoverlay.Line(simpletrace1.StartPos, simpletrace1.HitPos, 1, Color(0, 0, 255))
	// debugoverlay.Line(simpletrace2.StartPos, simpletrace2.HitPos, 1, Color(0, 0, 255))

	if simpletrace1.StartSolid or simpletrace2.StartSolid then
		// print('卡住了')
		return
	end

	-- 更新水平检测范围
	local maxVaultWidth, maxVaultWidthVec
	if simpletrace1.Hit or simpletrace2.Hit then
		maxVaultWidth = math.max(
			0, 
			linelen * math.min(simpletrace1.Fraction, simpletrace2.Fraction) - playWidth * 0.707
		)
		maxVaultWidthVec = eyeDir * maxVaultWidth
	else
		maxVaultWidth = appenddata.hlen
		maxVaultWidthVec = eyeDir * maxVaultWidth
	end

	-- 检查障碍的镜像高度和是否卡住 
	startpos = landdata[2] + maxVaultWidthVec
	endpos = startpos - unitzvec * appenddata.vlen

	local vchecktrace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = startpos,
		endpos = endpos,
		mins = dmins,
		maxs = dmaxs,
	})

	// debugoverlay.Line(vchecktrace.StartPos, vchecktrace.HitPos, 1, Color(0, 0, 255))
	// debugwireframebox(vchecktrace.HitPos, dmins, dmaxs, 1, Color(0, 0, 255))


	if vchecktrace.StartSolid or vchecktrace.Hit then
		// print('翻越高度检测, 卡住了或镜像高度不足')
		return
	end

	-- 检测最终落脚点, 必须用站立时的碰撞盒检测
	local pmins, pmaxs = ply:GetHull()
	startpos = vchecktrace.HitPos + unitzvec
	endpos = startpos - maxVaultWidthVec
	hchecktrace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = startpos,
		endpos = endpos,
		mins = pmins,
		maxs = pmaxs,
	})

	// debugoverlay.Line(hchecktrace.StartPos, hchecktrace.HitPos, 0.5, Color(0, 255, 255))
	// debugwireframebox(hchecktrace.HitPos, pmins, pmaxs, 0.5, Color(0, 255, 255))


	if hchecktrace.StartSolid then
		// print('翻越宽度检测, 卡住了')
		return
	end

	return {
		pos,
		hchecktrace.HitPos + eyeDir * math.min(2, hchecktrace.Fraction * maxVaultWidth), 
		hchecktrace.HitPos[3] - pos[3]
	}
end
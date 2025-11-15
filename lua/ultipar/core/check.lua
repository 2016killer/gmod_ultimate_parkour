--[[
	作者:白狼
	2025 11 1

--]]

UltiPar.XYNormal = function(v)
	local v = Vector(v)
	v[3] = 0
	v:Normalize()
	return v
end

local XYNormal = UltiPar.XYNormal
local unitzvec = Vector(0, 0, 1)

UltiPar = UltiPar or {}

UltiPar.GeneralClimbCheck = function(ply, blen, bmins, bmaxs, ehlen, evlen, loscos)
	-- 检查前方是否有障碍并且检测是否有落脚点

	-- blen 阻碍检测的水平距离
	-- bmins 
	-- bmaxs

	-- ehlen 落脚点检测的水平距离
	-- evlen 落脚点检测的垂直距离
	-- loscos 是否对准了障碍物

	local eyeDir = XYNormal(ply:GetForward())
	local plypos = ply:GetPos() + unitzvec

	-- 主要是为了检查是否对准了障碍物和阻碍
	local BlockTrace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = plypos,
		endpos = plypos + eyeDir * blen,
		mins = bmins,
		maxs = bmaxs,
	})


	if not BlockTrace.Hit or BlockTrace.HitNormal[3] >= 0.707 then
		return
	end

	-- 判断是否对准了障碍物
	if XYNormal(-BlockTrace.HitNormal):Dot(eyeDir) < loscos then 
		return 
	end

	if SERVER and BlockTrace.Entity:IsPlayerHolding() then
		// print('被玩家拿着')
		return
	end
	
	-- 确保落脚点有足够空间, 所以检测蹲碰撞盒
	local dmins, dmaxs = ply:GetHullDuck()

	local startpos = BlockTrace.HitPos + unitzvec * bmaxs[3] + eyeDir * ehlen
	local endpos = startpos - unitzvec * evlen

	local trace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = startpos,
		endpos = endpos,
		mins = dmins,
		maxs = dmaxs,
	})

	-- 确保不在滑坡上且在障碍物上
	if not trace.Hit or trace.HitNormal[3] < 0.707 then
		return
	end

	-- 检测落脚点是否有足够空间
	-- OK, 预留1的单位高度防止极端情况
	if trace.StartSolid or trace.Fraction * evlen < 1 then
		// print('卡住了')
		return
	end
	
	trace.HitPos[3] = trace.HitPos[3] + 1

	local landpos, blockheight = trace.HitPos, trace.HitPos[3] - plypos[3]
	return plypos, landpos, blockheight
end

UltiPar.GeneralLandSpaceCheck = function(ply, startpos)
	-- 检查能否站立
	local pmins, pmaxs = ply:GetHull()
	local spacecheck = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = startpos,
		endpos = startpos,
		mins = pmins,
		maxs = pmaxs,
	})
	
	return spacecheck.StartSolid or spacecheck.Hit 
end

UltiPar.GeneralVaultCheck = function(ply, plypos, landpos, hlen, vlen)
	-- 通用翻越检查, 在GeneralClimbCheck后面
	-- 主要检测障碍物的镜像面是否符合条件


	-- 不需要检查是否在斜坡上

	-- 假设蹲伏不会改变玩家宽度
	local dmins, dmaxs = ply:GetHullDuck()
	local playWidth = math.max(dmaxs[1] - dmins[1], dmaxs[2] - dmins[2])
	local eyeDir = XYNormal(ply:GetForward())


	-- 简单检测一下是否会被阻挡
	local linelen = hlen + 0.707 * playWidth
	local line = eyeDir * linelen
	
	local simpletrace1 = util.QuickTrace(landpos + unitzvec * dmaxs[3], line, ply)
	local simpletrace2 = util.QuickTrace(landpos + unitzvec * (dmaxs[3] * 0.5), line, ply)
	

	if simpletrace1.StartSolid or simpletrace2.StartSolid then
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
		maxVaultWidth = hlen
		maxVaultWidthVec = eyeDir * maxVaultWidth
	end

	-- 检查障碍的镜像高度和是否卡住 
	startpos = landpos + maxVaultWidthVec
	endpos = startpos - unitzvec * vlen

	local vchecktrace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = startpos,
		endpos = endpos,
		mins = dmins,
		maxs = dmaxs,
	})


	if vchecktrace.StartSolid or vchecktrace.Hit then
		// print('卡住了或镜像高度不足')
		return
	end

	-- 检测最终位置, 必须用站立碰撞盒
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


	if hchecktrace.StartSolid then
		return
	end

	local vaultpos = hchecktrace.HitPos + eyeDir * math.min(2, hchecktrace.Fraction * maxVaultWidth)
	local vaultheight = hchecktrace.HitPos[3] - plypos[3]

	return vaultpos, vaultheight
end

UltiPar.GetFallDamageInfo = function(ply, fallspeed, ref)
	fallspeed = fallspeed or ply:GetVelocity()[3]
	if fallspeed < ref then
		local damage = hook.Run('GetFallDamage', ply, fallspeed) or 0
		if isnumber(damage) and damage > 0 then
			local d = DamageInfo()
			d:SetDamage(damage)
			d:SetAttacker(Entity(0))
			d:SetDamageType(DMG_FALL) 

			return d	
		end 
	end
end

UltiPar.unitzvec = unitzvec
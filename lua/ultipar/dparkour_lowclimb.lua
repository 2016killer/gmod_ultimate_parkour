--[[
原文件作者:白狼
主页:https://steamcommunity.com/id/whitewolfking/
此文件为其修改版本。
]]--

---------------------- 翻越动作 ----------------------
local action_vault, _ = UltiPar.Register('DParkour-Vault')
if CLIENT then
	action_vault.label = '#dp.vault'
	action_vault.icon = 'dparkour/icon.jpg'
end


-- 视图
action_vault.Views = action_vault.Views or {}


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

local function VManipMonkeyBaiLang(ply)
	if CLIENT then
		vault_punch = true
		vault_punch_vel = 50
		VManip:PlayAnim('longvault1')
		VMLegs:PlayAnim('monkeyvaultnew')
	else
		ply:ViewPunch(Angle(10, 0, 0))
	end
end

local function VManipLazyBaiLang(ply)
	if CLIENT then
		vault_punch = true
		vault_punch_vel = 50
		VManip:PlayAnim('longvault1')
		VMLegs:PlayAnim('lazyvaultnew')
	else
		ply:ViewPunch(Angle(0, 0, 50))
	end
end

action_vault.Views['VManip-Monkey-白狼'] = {
	label = '#dp.VManipMonkeyBaiLang',
	func = VManipMonkeyBaiLang,
}

action_vault.Views['VManip-Lazy-白狼'] = {
	label = '#dp.VManipLazyBaiLang',
	func = VManipLazyBaiLang,
}





// VManipMonkeyBaiLang = nil
// VManipLazyBaiLang = nil



local disableLegs = false
hook.Add('ShouldDisableLegs', 'dparkour.gmodleg', function()
	if disableLegs then return true end
end)



action_vault.Check = function(ply, data)
	if data == nil then return false end

	local result = data.result
	local blockdis = data.blockdis
	local blockheight = data.blockheight

	return true
end

action_vault.CheckEnd = 0.6
action_vault.Play = function(ply, data)
	local result = data.result
	local blockdis = data.blockdis
	local blockheight = data.blockheight

	UltiPar.StartEasyMove(ply, result[1].HitPos, 0.5)
end

---------------------- 低爬动作 ----------------------


---------------------- 高爬动作 ----------------------

// hook.Add('CreateMove', 'dj2climb', function(cmd)
// 	if Notclimbing then return end
// 	//cmd:ClearButtons()
// 	if !LocalPlayer():Alive() then Notclimbing = true end
// 	cmd:ClearMovement()
// 	cmd:RemoveKey(IN_JUMP)
// 	if NeedDuck then cmd:AddKey(IN_DUCK) end
// end)


local up_dpar_per = CreateConVar('up_dpar_per', '1', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })

local function XYNormal(v)
	v[3] = 0
	v:Normalize()
	return v
end

local function TotalCheck(ply)
	if ply:GetMoveType() == MOVETYPE_NOCLIP or ply:InVehicle() or !ply:Alive() then 
		return 
	end
	
	local pos = ply:GetPos()
	local pmins, pmaxs = ply:GetCollisionBounds()
	local eyeDir = XYNormal(ply:GetForward())

	local plyHeight = pmaxs[3] - pmins[3]
	local playWidth = math.max(pmaxs[1] - pmins[1], pmaxs[2] - pmins[2])


	-- 检测是否有障碍以及障碍距离
	local BlockTrace = util.TraceHull({
		filter = ply, 
		mask = MASK_PLAYERSOLID,
		start = pos,
		endpos = pos + eyeDir * playWidth * 3,
		mins = pmins,
		maxs = pmaxs,
	})

	if not BlockTrace.Hit or BlockTrace.HitNormal[3] > 0.707 then
		// print('检测到障碍')
		return
	end
	if SERVER and BlockTrace.Entity:IsPlayerHolding() then
		return
	end

	local BlockDis = pos:Distance2D(BlockTrace.HitPos)


	-- 障碍高度估算
	local VrulerLen = plyHeight * 2
	local HrulerLen = playWidth * 3

	local MaxHeightTrace = util.QuickTrace(pos, Vector(0, 0, VrulerLen), ply)
	local maxHeight = MaxHeightTrace.Fraction * VrulerLen

	local TraceList = {}
	for h = 18, maxHeight, 18 do
		table.insert(
			TraceList, 
			util.QuickTrace(pos + Vector(0, 0, h), eyeDir * HrulerLen, ply)
		)
	end

	local height = nil
	for i = 1, #TraceList do
		local tr1 = TraceList[i]
		local tr2 = TraceList[i + 1]

		if tr1.Fraction * HrulerLen > playWidth + BlockDis and (not tr2 or tr2.Fraction * HrulerLen > playWidth + BlockDis) then
			-- 当水平距离大于一个身位时，大概就是障碍物高度
			height = tr1.StartPos[3] - pos[3]
			break
		end
	end

	if height == nil then
		return
	end

	-- 筛选最终落点
	local pdmins, pdmaxs = ply:GetHullDuck()
	pdmaxs[3] = pdmaxs[3] * 0.5
	local temp = Vector(BlockTrace.HitPos)
	temp[3] = pos[3] + height + pdmaxs[3]

	local result = {}
	for i = 0, 3 do
		local startpos = temp + eyeDir * playWidth * 0.5
		local endpos = startpos - Vector(0, 0, maxHeight)

		local trace = util.TraceHull({
			filter = ply, 
			mask = MASK_PLAYERSOLID,
			start = startpos,
			endpos = endpos,
			mins = pdmins,
			maxs = pdmaxs,
		})

		table.insert(result, trace)
	end

	if #result == 0 then
		return
	else
		return {
			blockheight = height,
			blockdis = BlockDis,
			result = result,
		}
	end
end


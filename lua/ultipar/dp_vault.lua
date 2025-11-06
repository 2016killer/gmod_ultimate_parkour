--[[
作者:白狼
2025 11 1
]]--

-- ==================== 翻越动作 ===============
local UltiPar = UltiPar
---------------------- 菜单 ----------------------
local convars = {
	{
		name = 'dp_lc_vault',
		default = '1',
		widget = 'CheckBox'
	},

	{
		name = 'dp_hc_vault',
		default = '1',
		widget = 'CheckBox'
	},

	{
		name = 'dp_lc_vault_hlen',
		default = '2',
		widget = 'NumSlider',
		min = 0,
		max = 3,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_hc_vault_hlen',
		default = '1.5',
		widget = 'NumSlider',
		min = 0,
		max = 3,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_vault_vlen',
		default = '0.5',
		widget = 'NumSlider',
		min = 0.25,
		max = 0.6,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_vault_double',
		default = '0.3',
		widget = 'NumSlider',
		min = 0,
		max = 2,
		decimals = 2,
		help = true,
	}
}

UltiPar.CreateConVars(convars)
local dp_lc_vault = GetConVar('dp_lc_vault')
local dp_hc_vault = GetConVar('dp_hc_vault')
local dp_lc_vault_hlen = GetConVar('dp_lc_vault_hlen')
local dp_hc_vault_hlen = GetConVar('dp_hc_vault_hlen')
local dp_vault_vlen = GetConVar('dp_vault_vlen')
local dp_vault_double = GetConVar('dp_vault_double')

local actionName = 'DParkour-Vault'
local action, _ = UltiPar.Register(actionName)
if CLIENT then
	action.label = '#dp.vault'
	action.icon = 'dparkour/icon.jpg'

	action.CreateOptionMenu = function(panel)
		UltiPar.CreateConVarMenu(panel, convars)
	end
else
	convars = nil
end

local acitonLCName = 'DParkour-LowClimb'
local acitonHCName = 'DParkour-HighClimb'
local actionLC, _ = UltiPar.Register(acitonLCName)
local actionHC, _ = UltiPar.Register(acitonHCName)
---------------------- 动作逻辑 ----------------------
function action:GetSpeed(ply, ref, isdouble, breakin)
	-- 返回Vault初始速度、结束速度、过渡速度
	if isdouble then
		local startspeed, _ = breakin:GetSpeed(ply, ref)
		local _, endspeed = self:GetSpeed(ply, ref, false)
		return startspeed, endspeed * 0.8, startspeed * 0.4
		// return startspeed, endspeed * 0.7, startspeed * 0.2
	else
		local vaultDir = ply:EyeAngles():Forward()
		vaultDir[3] = 0

		local startspeed = ref:Dot(vaultDir)
		return startspeed,
			math.max(
				ply:GetJumpPower() + (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed()),
				startspeed
			)
	end
end

function action:IsDoubleVault(ply, blockheight)
	local pmins, pmaxs = ply:GetHull()
	local plyHeight = pmaxs[3] - pmins[3]

	return blockheight > dp_vault_double:GetFloat() * plyHeight
end

function action:Check(ply, appenddata)
	if not ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_DUCK) then 
		return
	end

	local startpos, landpos, blockheight, startspeed, endspeed, duration, dir, type_, plyvel = unpack(appenddata)
	
	if not (type_ == 1 and dp_hc_vault or dp_lc_vault):GetBool() then
		return
	end

	// print(startpos, landpos, blockheight, type_)

	local bmins, bmaxs = ply:GetHull()
	local plyWidth = math.max(bmaxs[1] - bmins[1], bmaxs[2] - bmins[2])
	local plyHeight = bmaxs[3] - bmins[3]

	local vaultdata = UltiPar.GeneralVaultCheck(ply, {
		hlen = (type_ == 1 and dp_hc_vault_hlen or dp_lc_vault_hlen):GetFloat() * plyWidth,
		vlen = dp_vault_vlen:GetFloat() * plyHeight,
		landdata = appenddata,
	})

	if not vaultdata then
		return 
	end

	local isdouble = self:IsDoubleVault(ply, vaultdata[3])
	if type_ == 1 and not isdouble then
		return
	end

	if isdouble then
		local startspeed, endspeed, middlespeed = self:GetSpeed(ply, plyvel, true,
			type_ == 1 and actionHC or actionLC)

		local vaultpos = vaultdata[2]
		local middlepos = landpos
		middlepos[3] = vaultpos[3]

		local dis_middle = (middlepos - startpos):Length()
		local dir_middle = (middlepos - startpos):GetNormal()
		local duration_middle = dis_middle * 2 / (startspeed + middlespeed)

		local dis = (vaultpos - middlepos):Length()
		local dir = (vaultpos - middlepos):GetNormal()
		local duration = dis * 2 / (middlespeed + endspeed)

		ply.dp_data = {ply:GetPos(), vaultpos, vaultdata[3], startspeed, endspeed, duration, dir,
			ply:GetPos(), middlespeed, duration_middle, dir_middle, type_
		}

		return {duration, type_}
	else
		local vaultpos = vaultdata[2]
		local startspeed, endspeed = self:GetSpeed(ply, plyvel, false)
		local dis = (vaultpos - startpos):Length()
		local dir = (vaultpos - startpos):GetNormal()
		local duration = dis * 2 / (startspeed + endspeed)

		ply.dp_data = {ply:GetPos(), vaultpos, vaultdata[3], startspeed, endspeed, duration, dir}
		
		return {duration}
	end
end

action.Start = UltiPar.emptyfunc

function action:Play(ply, mv, cmd, data, starttime)
	-- 保险一点
	if not ply.dp_data then
		return
	end

	local startpos, landpos, blockheight, startspeed, endspeed, duration, dir,
		lastpos, middlespeed, duration_middle, dir_middle, type_
	= unpack(ply.dp_data)
	
	if middlespeed then
		local dt = CurTime() - starttime

		local waittime = type_ == 1 and 0.1 or 0
		local endflag = dt > waittime + duration_middle + duration
		if dt < waittime then
			mv:SetOrigin(startpos)
		elseif dt < waittime + duration_middle then
			dt = dt - waittime

			local acc_middle = (middlespeed - startspeed) / duration_middle
			lastpos = startpos + (0.5 * acc_middle * dt * dt + startspeed * dt) * dir_middle
			mv:SetOrigin(lastpos)
			ply.dp_data[8] = lastpos -- fuck
		else
			dt = dt - waittime - duration_middle

			local acc = (endspeed - middlespeed) / duration
			mv:SetOrigin(lastpos + (0.5 * acc * dt * dt + middlespeed * dt) * dir +
				(-100 / duration * dt * dt + 100 * dt) * UltiPar.unitzvec
			)
		end

		if endflag then 
			ply:SetMoveType(MOVETYPE_WALK)
			if UltiPar.GeneralLandSpaceCheck(ply, ply:GetPos()) then
				mv:SetOrigin(landpos)
			end

			mv:SetVelocity(endspeed * UltiPar.XYNormal(dir))
		end

		return endflag
	else
		local dt = CurTime() - starttime
		local acc = (endspeed - startspeed) / duration
		local endflag = dt > duration

		mv:SetOrigin(startpos + (0.5 * acc * dt * dt + startspeed * dt) * dir +
			(-100 / duration * dt * dt + 100 * dt) * UltiPar.unitzvec
		)

		if endflag then 
			ply:SetMoveType(MOVETYPE_WALK)
			if UltiPar.GeneralLandSpaceCheck(ply, ply:GetPos()) then
				mv:SetOrigin(landpos)
			end

			mv:SetVelocity(endspeed * UltiPar.XYNormal(dir))
		end

		return endflag
	end
end

function action:Clear(ply)
	if CLIENT then return end
	ply.dp_data = nil
	ply:SetMoveType(MOVETYPE_WALK)
	UltiPar.SetMoveControl(ply, false, false, 0, 0)
end


if SERVER then
	hook.Add('UltiParExecute', 'dparkour.vault.trigger', function(ply, paction, checkresult, breakin, breakinresult)
		timer.Simple(0, function()
			if not ply.dp_data then
				return
			end
			UltiPar.Trigger(ply, action, ply.dp_data)
		end)
	end)
end
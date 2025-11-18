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
		default = '0.25',
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
	action.icon = 'dparkour/icon.jpg'

	action.CreateOptionMenu = function(panel)
		UltiPar.CreateConVarMenu(panel, convars)
	end
else
	convars = nil
end
---------------------- 动作逻辑 ----------------------
function action:GetSpeed(ply, ref)
    local startspeed = UltiPar.XYNormal(ply:EyeAngles():Forward()):Dot(ref)
    return startspeed,
        math.max(
            ply:GetJumpPower() + (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed()),
            startspeed
        )
end

function action:GetDoubleSpeed(ply, ref, ref2, type_)
	-- 返回Vault初始速度、结束速度、过渡速度
    local startspeed = ref2
    local _, endspeed = self:GetSpeed(ply, ref)
    
    if type_ == 0 then
        return startspeed, endspeed * 0.8, startspeed * 0.4
    else
        return startspeed, endspeed * 0.7, startspeed * 0.2
    end
end


function action:IsDoubleVault(ply, vaultheight)
	local pmins, pmaxs = ply:GetHull()
	local plyHeight = pmaxs[3] - pmins[3]

	return vaultheight > dp_vault_double:GetFloat() * plyHeight
end

function action:Check(ply, startpos, landpos, blockheight, plyvel, startspeed, type_)
	if ply:KeyDown(IN_BACK) or not ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_DUCK) then 
		return
	end
  
	local bmins, bmaxs = ply:GetHull()
	local plyWidth = math.max(bmaxs[1] - bmins[1], bmaxs[2] - bmins[2])
	local plyHeight = bmaxs[3] - bmins[3]

    local hlen = (type_ == 1 and dp_hc_vault_hlen or dp_lc_vault_hlen):GetFloat() * plyWidth
    local vlen = dp_vault_vlen:GetFloat() * plyHeight
	local vaultpos, vaultheight = UltiPar.GeneralVaultCheck(ply, startpos, landpos, hlen, vlen)

	if not vaultpos then
		return 
	end

	local isdouble = self:IsDoubleVault(ply, vaultheight)
	// print(vaultheight, dp_vault_double:GetFloat() * plyHeight)
    -- 高跳只能二段翻越
	if type_ == 1 and not isdouble then
		return
	end

    local ref2 = startspeed
	if isdouble then
		local startspeed, endspeed, middlespeed = self:GetDoubleSpeed(ply, plyvel, ref2, type_)

		local middlepos = landpos
		middlepos[3] = vaultpos[3]

		local dis_middle = (middlepos - startpos):Length()
		local dir_middle = (middlepos - startpos):GetNormal()
		local duration_middle = dis_middle * 2 / (startspeed + middlespeed)

		local dis = (vaultpos - middlepos):Length()
		local dir = (vaultpos - middlepos):GetNormal()
		local duration = dis * 2 / (middlespeed + endspeed)

		return ply:GetPos(), 
            vaultpos, 
            startspeed, 
            endspeed, 
            duration, 
            dir,
            type_,
            CurTime(),
            middlespeed, 
            duration_middle,
            dir_middle

        
	else
		local startspeed, endspeed = self:GetSpeed(ply, plyvel)
		local dis = (vaultpos - startpos):Length()
		local dir = (vaultpos - startpos):GetNormal()
		local duration = dis * 2 / (startspeed + endspeed)

		return ply:GetPos(), 
            vaultpos, 
            startspeed, 
            endspeed, 
            duration, 
            dir,
            type_,
            CurTime()
            // nil, 
            // nil,
            // nil, 
	end
end

function action:Start(ply, ...)
	if CLIENT then return end
	if ply:GetMoveType() ~= MOVETYPE_NOCLIP then 
		ply:SetMoveType(MOVETYPE_NOCLIP)
	end
	UltiPar.WriteMoveControl(ply, true, true, bit.bor(IN_JUMP, IN_DUCK), 0)
end

function action:Play(ply, mv, cmd,
        startpos, 
        vaultpos, 
        startspeed, 
        endspeed, 
        duration, 
        dir,  
        type_, 
        starttime,
        middlespeed, 
        duration_middle, 
        dir_middle
    )

    -- what fuck?
	if middlespeed then
		local dt = CurTime() - starttime

		local waittime = type_ == 1 and 0.1 or 0
		local endflag = dt > waittime + duration_middle + duration
		if dt < waittime then
			mv:SetOrigin(startpos)
		elseif dt < waittime + duration_middle then
			dt = dt - waittime
			local acc_middle = (middlespeed - startspeed) / duration_middle
			ply.dp_lastpos = startpos + (0.5 * acc_middle * dt * dt + startspeed * dt) * dir_middle
			mv:SetOrigin(ply.dp_lastpos)  -- fuck
		else
			dt = dt - waittime - duration_middle

			local acc = (endspeed - middlespeed) / duration
			mv:SetOrigin(ply.dp_lastpos + (0.5 * acc * dt * dt + middlespeed * dt) * dir +
				(-100 / duration * dt * dt + 100 * dt) * UltiPar.unitzvec
			)
		end

        if endflag then 
            return vaultpos, endspeed * dir
        else
            return nil
        end
	else
		local dt = CurTime() - starttime
		local acc = (endspeed - startspeed) / duration
		local endflag = dt > duration

		mv:SetOrigin(startpos + (0.5 * acc * dt * dt + startspeed * dt) * dir +
			(-100 / duration * dt * dt + 100 * dt) * UltiPar.unitzvec
		)

        if endflag then 
            return vaultpos, endspeed * dir
        else
            return nil
        end
	end
end

function action:Clear(ply, mv, cmd, vaultpos, endvel)
    ply:SetMoveType(MOVETYPE_WALK)
    if SERVER and mv then
        -- 开环控制必须加这个
        if UltiPar.GeneralLandSpaceCheck(ply, ply:GetPos()) then
            mv:SetOrigin(vaultpos)
        end
        mv:SetVelocity(endvel)
        ply.dp_lastpos = nil
    end
end


UltiPar.EnableInterrupt('DParkour-LowClimb', actionName)
UltiPar.EnableInterrupt('DParkour-HighClimb', actionName)

UltiPar.SetInterruptsFunc('DParkour-LowClimb', actionName, UltiPar.GeneralInterruptFunc)
UltiPar.SetInterruptsFunc('DParkour-HighClimb', actionName, UltiPar.GeneralInterruptFunc)

if SERVER then
	hook.Add('UltiParStart', 'dparkour.vault.trigger', function(ply, playing, checkResult)
        if playing.Name == 'DParkour-LowClimb' and dp_lc_vault:GetBool() then

            local startpos, landpos, blockheight, plyvel, startspeed = unpack(checkResult)
			UltiPar.Trigger(ply, action, false, startpos, landpos, blockheight, plyvel, startspeed, 0)

        elseif playing.Name == 'DParkour-HighClimb' and dp_hc_vault:GetBool() then

            local startpos, landpos, blockheight, plyvel, startspeed = unpack(checkResult)
			UltiPar.Trigger(ply, action, false, startpos, landpos, blockheight, plyvel, startspeed, 1)

		end
	end)


	local triggertime = 0
	local Trigger = UltiPar.Trigger
	local IsActionDisable = UltiPar.IsActionDisable

	local actionLC, _ = UltiPar.Register('DParkour-LowClimb')
	local dp_workmode = CreateConVar('dp_workmode', '1', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
	local dp_lc_keymode = CreateConVar('dp_lc_keymode', '1', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
	local dp_lc_per = CreateConVar('dp_lc_per', '0.1', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })
	hook.Add('PlayerPostThink', 'dparkour.vault.trigger', function(ply)
		if not IsActionDisable('DParkour-LowClimb') then return end
		
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

		local startpos, landpos, blockheight, plyvel, startspeed = actionLC:Check(ply)
		if not startpos then return end
		Trigger(ply, action, false, startpos, landpos, blockheight, plyvel, startspeed, 0)
	end)

	hook.Add('KeyPress', 'dparkour.vault.trigger', function(ply, key)
		if not IsActionDisable('DParkour-LowClimb') then return end
		if key == IN_JUMP and dp_lc_keymode:GetBool() and dp_workmode:GetBool() then 
			local startpos, landpos, blockheight, plyvel, startspeed = actionLC:Check(ply)
			if not startpos then return end
			
			Trigger(ply, action, false, startpos, landpos, blockheight, plyvel, startspeed, 0)
		end
	end)
end

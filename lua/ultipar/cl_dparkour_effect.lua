--[[
作者:白狼
2025 11 1
]]--

local dp_lcdv_h = CreateConVar('dp_lcdv_h', '0.8', { FCVAR_ARCHIVE, FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_SERVER_CAN_EXECUTE })

local function LowClimbEffect(ply, data, handAnim, legsAnim, soundVault, soundLowClimb)
	if data == nil then
		-- 演示模式
		UltiPar.SetVecPunchVel(Vector(50, 0, -10))
		UltiPar.SetAngPunchVel(Vector(0, 0, -50))
		VManip:PlayAnim(handAnim)
		VMLegs:PlayAnim(legsAnim)
		surface.PlaySound(soundVault)
	else
		local trace, dovault, blockheight = unpack(data)
		if dovault then
			local pmins, pmaxs = ply:GetCollisionBounds()
			if blockheight > dp_lcdv_h:GetFloat() * (pmaxs[3] - pmins[3]) then
				local startvel = ply:GetJumpPower() + 0.25 * (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed())
				// print(startvel, ply:GetVelocity():Length())
				startvel = math.max(startvel, ply:GetVelocity():Length())

				local duration = (ply:GetPos() - trace.HitPos):Length() / (1.5 * startvel)
				// print((ply:GetPos() - trace.HitPos):Length(), 1.5 * startvel, duration)

				UltiPar.SetVecPunchVel(Vector(0, 0, 25))
				UltiPar.SetAngPunchVel(Vector(150, 0, 0))

				VManip:PlayAnim(handAnim)
				surface.PlaySound(soundLowClimb)

				timer.Simple(duration, function()
					UltiPar.SetVecPunchVel(Vector(100, 0, -10))
					UltiPar.SetAngPunchVel(Vector(0, 0, -150))

					VManip:PlayAnim(handAnim)
					VMLegs:PlayAnim(legsAnim)
					surface.PlaySound(soundVault)
				end)
			else
				UltiPar.SetVecPunchVel(Vector(100, 0, -10))
				UltiPar.SetAngPunchVel(Vector(0, 0, -150))

				VManip:PlayAnim(handAnim)
				VMLegs:PlayAnim(legsAnim)
				surface.PlaySound(soundVault)
			end
		else
			UltiPar.SetVecPunchVel(Vector(0, 0, 25))
			UltiPar.SetAngPunchVel(Vector(0, 0, -100))

			VManip:PlayAnim(handAnim)
			surface.PlaySound(soundLowClimb)
		end
	end
end

local function VManip_BaiLang(ply, data)
	LowClimbEffect(ply, data, 'vault', 'dp_lazy_BaiLang', 'dparkour/bailang/vault.mp3', 'dparkour/bailang/lowclimb.mp3')
end

local function VManip_mtbNTB(ply, data)
	LowClimbEffect(ply, data, 'vault', 'dp_lazy_mtbNTB', 'dparkour/mtbntb/vault.mp3', 'dparkour/mtbntb/lowclimb.mp3')
end

local function VManip_datae(ply, data)
	LowClimbEffect(ply, data, 'vault', 'test', 'dparkour/mtbntb/vault.mp3', 'dparkour/mtbntb/lowclimb.mp3')
end

UltiPar.RegisterEffect(
	'DParkour-LowClimb', 
	'VManip-白狼',
	{
		label = '#dp.VManip_BaiLang',
		func = VManip_BaiLang,
	}
)

UltiPar.RegisterEffect(
	'DParkour-LowClimb', 
	'VManip-mtbNTB',
	{
		label = '#dp.VManip_mtbNTB',
		func = VManip_mtbNTB,
	}
)

UltiPar.RegisterEffect(
	'DParkour-LowClimb', 
	'VManip-datae',
	{
		label = '#dp.VManip_datae',
		func = VManip_datae,
	}
)

local effect, _ = UltiPar.RegisterEffect(
	'DParkour-LowClimb', 
	'default',
	{
		label = '#default',
		func = VManip_mtbNTB,
	}
)
effect.func = VManip_BaiLang



hook.Add('ShouldDisableLegs', 'dparkour.gmodleg', function()
	return VMLegs and VMLegs:IsActive()
end)
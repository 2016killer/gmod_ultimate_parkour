--[[
作者:白狼
2025 11 1
]]--

local function HighClimbEffect(ply, data, handAnim, legsAnim, soundVault, soundHighClimb)
	if data == nil then
		-- 演示模式
		UltiPar.SetAngPunchVel(Vector(-250, 0, 100))
		VManip:PlayAnim(handAnim)
		timer.Simple(0.2, function()
			UltiPar.SetVecPunchVel(Vector(0, 0, 25))
			UltiPar.SetAngPunchVel(Vector(200, 0, -50))
			surface.PlaySound(soundHighClimb)
		end)
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
				surface.PlaySound(soundHighClimb)

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
			VManip:PlayAnim(handAnim)
			UltiPar.SetAngPunchVel(Vector(-250, 0, 100))

			timer.Simple(0.2, function()
				UltiPar.SetVecPunchVel(Vector(0, 0, 25))
				UltiPar.SetAngPunchVel(Vector(500, 0, -50))
				surface.PlaySound(soundHighClimb)
			end)
		end
	end
end

local function VManip_BaiLang(ply, data)
	HighClimbEffect(ply, data, 'dp_catch_BaiLang', 'dp_lazy_BaiLang', 'dparkour/bailang/vault.mp3', 'dparkour/bailang/highclimb.mp3')
end

local function VManip_mtbNTB(ply, data)
	HighClimbEffect(ply, data, 'dp_catch_mtbNTB', 'dp_lazy_mtbNTB', 'dparkour/mtbntb/vault.mp3', 'dparkour/mtbntb/highclimb.mp3')
end


UltiPar.RegisterEffect(
	'DParkour-HighClimb', 
	'VManip-白狼',
	{
		label = '#dp.VManip_BaiLang',
		func = VManip_BaiLang,
	}
)

UltiPar.RegisterEffect(
	'DParkour-HighClimb', 
	'VManip-mtbNTB',
	{
		label = '#dp.VManip_mtbNTB',
		func = VManip_mtbNTB,
	}
)

local effect, _ = UltiPar.RegisterEffect(
	'DParkour-HighClimb', 
	'default',
	{
		label = '#default'
	}
)
effect.func = VManip_BaiLang
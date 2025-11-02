--[[
作者:白狼
2025 11 1
]]--

-- 操，ViewPunch

local function VManip_mtbNTB(ply, data)
	local handAnim = 'dp_catch_mtbNTB'
	local legsAnim = 'dp_lazy_mtbNTB'
	local soundHighClimb = 'dparkour/mtbntb/highclimb.mp3'
	local soundVault = 'dparkour/mtbntb/vault.mp3'

	if SERVER then
		ply:ViewPunch(Angle(-20, 5, 0))
		timer.Simple(0.2, function()
			ply:ViewPunch(Angle(20, 0, 0))
		end)
	end
	if CLIENT then
		if data == nil then
			-- 演示模式
			VManip:PlayAnim(handAnim)
			timer.Simple(0.2, function()
				UltiPar.SetVecPunchVel(Vector(0, 0, 25))
				surface.PlaySound(soundHighClimb)
			end)
		else
			local trace, dovault, blockheight = unpack(data)
			if dovault then
				local startvel = ply:GetJumpPower() + 0.25 * (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed())
				startvel = math.max(startvel, ply:GetVelocity():Length())

				local duration = (ply:GetPos() - trace.HitPos):Length() / (1.25 * startvel)

				VManip:PlayAnim(handAnim)
				surface.PlaySound(soundHighClimb)

				timer.Simple(0.2 + duration, function()
					UltiPar.SetVecPunchVel(Vector(100, 0, -10))
					UltiPar.SetAngPunchVel(Vector(0, 0, -150))

					VManip:PlayAnim(handAnim)
					VMLegs:PlayAnim(legsAnim)
					surface.PlaySound(soundVault)
				end)
			else
				VManip:PlayAnim(handAnim)
				timer.Simple(0.2, function()
					UltiPar.SetVecPunchVel(Vector(0, 0, 25))
					surface.PlaySound(soundHighClimb)
				end)
			end
		end
	end
end


UltiPar.RegisterEffect(
	'DParkour-HighClimb', 
	'VManip-mtbNTB',
	{
		label = '#dp.VManip_mtbNTB',
		func = VManip_mtbNTB,
	}
)

local function VManip_default(ply, data)
	local handAnim = 'dp_catch_mtbNTB'
	local legsAnim = 'dp_lazy_BaiLang'
	local soundHighClimb = 'dparkour/bailang/highclimb.mp3'
	local soundVault = 'dparkour/bailang/vault.mp3'

	if SERVER then
		ply:ViewPunch(Angle(-20, 5, 0))
		timer.Simple(0.2, function()
			ply:ViewPunch(Angle(20, 0, 0))
		end)
	end
	if CLIENT then
		if data == nil then
			-- 演示模式
			VManip:PlayAnim(handAnim)
			timer.Simple(0.2, function()
				UltiPar.SetVecPunchVel(Vector(0, 0, 25))
				surface.PlaySound(soundHighClimb)
			end)
		else
			local trace, dovault, blockheight = unpack(data)
			if dovault then
				local startvel = ply:GetJumpPower() + 0.25 * (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed())
				startvel = math.max(startvel, ply:GetVelocity():Length())

				local duration = (ply:GetPos() - trace.HitPos):Length() / (1.25 * startvel)

				VManip:PlayAnim(handAnim)
				surface.PlaySound(soundHighClimb)

				timer.Simple(0.2 + duration, function()
					UltiPar.SetVecPunchVel(Vector(100, 0, -10))
					UltiPar.SetAngPunchVel(Vector(0, 0, -150))

					VManip:PlayAnim(handAnim)
					VMLegs:PlayAnim(legsAnim)
					surface.PlaySound(soundVault)
				end)
			else
				VManip:PlayAnim(handAnim)
				timer.Simple(0.2, function()
					UltiPar.SetVecPunchVel(Vector(0, 0, 25))
					surface.PlaySound(soundHighClimb)
				end)
			end
		end
	end
end

local effect, _ = UltiPar.RegisterEffect(
	'DParkour-HighClimb', 
	'default',
	{
		label = '#default'
	}
)
effect.func = VManip_default
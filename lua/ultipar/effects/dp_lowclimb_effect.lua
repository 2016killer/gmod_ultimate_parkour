--[[
作者:白狼
2025 11 1
]]--

-- ==================== 低爬动作特效 ===============
local actionName = 'DParkour-LowClimb'

local function effectstart_default(self, ply)
	-- WOS动画
	if self.WOSAnim and self.WOSAnim ~= '' then
		if SERVER then
			ply:SetNWString('UP_WOS', self.WOSAnim)
		elseif CLIENT then
			local seq = ply:LookupSequence(self.WOSAnim)
			if seq and seq > 0 then
				ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_JUMP, seq, 0, true)
				ply:SetPlaybackRate(1)
			end
		end
	end

	-- ViewPunch
	if SERVER and self.punch then
		ply:ViewPunch(self.punch_ang)
	end

	-- upunch
	if CLIENT and self.upunch then
        UltiPar.SetVecPunchVel(self.upunch_vec)
        UltiPar.SetAngPunchVel(self.upunch_ang)
	end

	-- VManip手部动画、音效
	if CLIENT and self.VManipAnim and self.VManipAnim ~= '' then
		VManip:PlayAnim(self.VManipAnim)
	end

	-- VManip腿部动画
	if CLIENT and self.VMLegsAnim and self.VMLegsAnim ~= '' then
		VMLegs:PlayAnim(self.VMLegsAnim)
	end

	-- 音效
	if CLIENT and self.sound and self.sound ~= '' then
		surface.PlaySound(self.sound)
	end
end

UltiPar.RegisterEffect(
	actionName, 
	'default',
	{
        VManipAnim = 'vault',
        VMLegsAnim = '',
        WOSAnim = '',

        sound = 'dparkour/bailang/lowclimb.mp3',

        upunch = true,
        upunch_vec = Vector(0, 0, 25),
        upunch_ang = Vector(0, 0, -50),

		punch = false,
		punch_ang = Angle(0, 0, -5),

        start = effectstart_default,
        clear = UltiPar.GeneralEffectClear,
	}
)

actionName = nil
effectstart_default = nil


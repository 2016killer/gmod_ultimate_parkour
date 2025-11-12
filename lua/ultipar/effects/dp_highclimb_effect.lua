--[[
作者:白狼
2025 11 1
]]--

-- ==================== 高爬动作特效 ====================
local actionName = 'DParkour-HighClimb'

local function effectstart_default_first(self, ply)
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
		ply:ViewPunch(self.punch_ang_first)
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

local function effectstart_default_second(self, ply)
	-- ViewPunch
	if SERVER and self.punch then
		ply:ViewPunch(self.punch_ang_second)
	end

	-- upunch
	if CLIENT and self.upunch then
		UltiPar.SetVecPunchVel(self.upunch_vec_second)
	end
end

local function effectstart_default(self, ply)
	self:start_first(ply)
	timer.Simple(0.2, function() self:start_second(ply) end)
end

UltiPar.RegisterEffect(
	actionName, 
	'default',
	{
		VManipAnim = 'dp_catch_BaiLang',
        VMLegsAnim = '',
		WOSAnim = '',

		sound = 'dparkour/bailang/highclimb.mp3',

		upunch = true,
		upunch_vec_second = Vector(0, 0, 25),

		punch = true,
		punch_ang_first = Angle(-20, 5, 0),
		punch_vec_second = Angle(20, 0, 0),
		
		start_first = effectstart_default_first,
		start_second = effectstart_default_second,
		start = effectstart_default,
		clear = UltiPar.GeneralEffectClear,
	}
)

effectstart_default_first = nil
effectstart_default_second = nil
actionName = nil
effectstart_default = nil

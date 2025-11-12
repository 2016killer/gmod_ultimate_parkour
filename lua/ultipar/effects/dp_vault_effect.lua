--[[
作者:白狼
2025 11 5
]]--

-- ====================  翻越动作特效 ===============
local actionName = 'DParkour-Vault'

local function effectstart_default_first(self, ply, ishigh)
    if ishigh then
        return
    end

	-- ViewPunch
	if SERVER and self.punch then
		ply:ViewPunch(self.punch_ang_first)
	end

	-- upunch
	if CLIENT and self.upunch then
		UltiPar.SetAngPunchVel(self.upunch_ang_first)
	end
end

local function effectstart_default_second(self, ply)
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
		ply:ViewPunch(self.punch_ang_second)
	end

	-- upunch
	if CLIENT and self.upunch then
        UltiPar.SetVecPunchVel(self.upunch_vec_second)
        UltiPar.SetAngPunchVel(self.upunch_ang_second)
	end

	-- VManip手部动画、音效
	if CLIENT and self.VManipAnim and self.VManipAnim ~= '' then
		VManip:PlayAnim(self.VManipAnim)
	end

	-- VManip腿部动画
	if CLIENT and self.VMLegsAnim and self.VMLegsAnim ~= '' then
		VMLegs:PlayAnim(self.VMLegsAnim)
	end

    if CLIENT and self.sound and self.sound ~= '' then
        surface.PlaySound(self.sound)
    end
end

local function effectstart_default(self, ply, 
            _, 
            _, 
            _, 
            _,
            _,
            _,
            Type,
            _,
            _, 
            duration_middle
        )
    -- big shit
    // print(Type, duration_middle)

    local ishigh = Type == 1
    local isdouble = !!duration_middle

    if isdouble then
        local delay = (ishigh and 0.1 or 0) + (isdouble and duration_middle or 0)
        self:start_first(ply, ishigh)
        timer.Simple(delay, function() self:start_second(ply) end)
    else
        self:start_second(ply)
    end
end

UltiPar.RegisterEffect(
	actionName, 
	'default',
	{
        VManipAnim = 'vault',
        VMLegsAnim = 'dp_lazy_BaiLang',
        WOSAnim = '',

        sound = 'dparkour/bailang/vault.mp3',

        upunch = true,
        upunch_ang_first = Vector(100, 0, 0),
        upunch_ang_second = Vector(0, 0, -100),
        upunch_vec_second = Vector(100, 0, -10),
        
        punch = false,
        punch_ang_first = Angle(10, 0, 0),
        punch_ang_second = Angle(0, 0, -5),

        start_first = effectstart_default_first,
        start_second = effectstart_default_second,
        start = effectstart_default,
        clear = UltiPar.GeneralEffectClear
	}
)

actionName = nil
effectstart_default_first = nil
effectstart_default_second = nil
effectstart_default = nil
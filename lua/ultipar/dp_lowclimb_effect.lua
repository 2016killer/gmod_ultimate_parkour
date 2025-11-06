--[[
作者:白狼
2025 11 1
]]--

-- ==================== 低爬动作特效 ===============

local actionName = 'DParkour-LowClimb'
local action, _ = UltiPar.Register(actionName)

local function effectstart_default(self, ply, data)
    if SERVER then
        return
    elseif CLIENT then
        UltiPar.SetVecPunchVel(self.vecpunch)
        UltiPar.SetAngPunchVel(self.angpunch)
        VManip:PlayAnim(self.handanim)
        surface.PlaySound(self.sound)
    end
end

local effect, _ = UltiPar.RegisterEffect(
	actionName, 
	'default',
	{
		label = '#default',
        handanim = 'vault',
        sound = 'dparkour/bailang/lowclimb.mp3',
        vecpunch = Vector(0, 0, 25),
        angpunch = Vector(0, 0, -50),
	}
)
effect.start = effectstart_default
effect.clear = UltiPar.emptyfunc

local effect2 = table.Copy(effect)
effect2.label = '#dp.effect.SP_VManip_BaiLang'
UltiPar.RegisterEffect(
    actionName, 
    'SP-VManip-白狼', 
    effect2
)
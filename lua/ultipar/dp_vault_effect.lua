--[[
作者:白狼
2025 11 5
]]--

-- ====================  翻越动作特效 ===============

local actionName = 'DParkour-Vault'
local action, _ = UltiPar.Register(actionName)

local function effectstart_default(self, ply, data)
    if SERVER then
        return
    elseif CLIENT then
        UltiPar.SetVecPunchVel(self.vecpunch)
        UltiPar.SetAngPunchVel(self.angpunch)
        VManip:PlayAnim(self.handanim)
        VMLegs:PlayAnim(self.legsanim)
        surface.PlaySound(self.sound)
    end
end

local effect, _ = UltiPar.RegisterEffect(
	actionName, 
	'default',
	{
		label = '#default',
        handanim = 'vault',
        legsanim = 'dp_lazy_BaiLang',
        sound = 'dparkour/bailang/vault.mp3',
        vecpunch = Vector(100, 0, -10),
        angpunch = Vector(0, 0, -50),
        angpunchfirst = Vector(50, 0, 0),
	}
)
effect.start = effectstart_default
effect.clear = UltiPar.emptyfunc

UltiPar.RegisterEffect(
	actionName, 
	'SP-VManip-白狼',
	{
		label = '#dp.effect.SP_VManip_BaiLang',
		start = effectfunc_default,
		clear = UltiPar.emptyfunc
	}
)
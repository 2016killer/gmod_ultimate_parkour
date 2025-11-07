// --[[
// 作者:白狼
// 2025 11 5
// ]]--

// -- ====================  翻越动作特效 ===============
// local actionName = 'DParkour-Vault'

// local function effectstart_default(self, ply, data)
//     local duration, type_ = unpack(istable(data) and data or {})
//     if SERVER then
//         return
//     elseif CLIENT then
//         if type_ then
//             local waittime = type_ == 1 and 0.1 or 0
//             UltiPar.SetVecPunchVel(self.vecpunchfirst)
//             UltiPar.SetAngPunchVel(self.angpunchfirst)
//             timer.Simple(waittime + duration, function()
//                 UltiPar.SetVecPunchVel(self.vecpunch)
//                 UltiPar.SetAngPunchVel(self.angpunch)
//                 VManip:PlayAnim(self.handanim)
//                 VMLegs:PlayAnim(self.legsanim)
//                 surface.PlaySound(self.sound) 
//             end)
//         else
//             UltiPar.SetVecPunchVel(self.vecpunch)
//             UltiPar.SetAngPunchVel(self.angpunch)
//             VManip:PlayAnim(self.handanim)
//             VMLegs:PlayAnim(self.legsanim)
//             surface.PlaySound(self.sound) 
//         end
//     end
// end

// local effect, _ = UltiPar.RegisterEffect(
// 	actionName, 
// 	'default',
// 	{
// 		label = '#default',
//         handanim = 'vault',
//         legsanim = 'dp_lazy_BaiLang',
//         sound = 'dparkour/bailang/vault.mp3',
//         vecpunch = Vector(100, 0, -10),
//         angpunch = Vector(0, 0, -100),
//         angpunchfirst = Vector(100, 0, 0),
//         vecpunchfirst = Vector(0, 0, 25),
// 	}
// )
// effect.start = effectstart_default
// effect.clear = UltiPar.emptyfunc

// local effect2 = table.Copy(effect)
// effect2.label = '#dp.effect.SP_VManip_BaiLang'
// UltiPar.RegisterEffect(
//     actionName, 
//     'SP-VManip-白狼', 
//     effect2
// )

// actionName = nil
// effect = nil
// effectstart_default = nil
// effect2 = nil
print(3)
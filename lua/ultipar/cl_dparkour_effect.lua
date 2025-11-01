--[[
原文件作者:白狼
主页:https://steamcommunity.com/id/whitewolfking/
此文件为其修改版本。
]]--


local function LowClimbEffect(ply, data, handAnim, legsAnim, soundVault, soundLowClimb)
	if data == nil then
		-- 演示模式
		VManip:PlayAnim(handAnim)
		VMLegs:PlayAnim(legsAnim)
	else
		local trace, dovault = unpack(data)
		if dovault then
			VManip:PlayAnim(handAnim)
			VMLegs:PlayAnim(legsAnim)
			surface.PlaySound(soundVault)
		else
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

UltiPar.RegisterEffect(
	'DParkour-LowClimb', 
	'default',
	{
		label = '#default',
		func = VManip_mtbNTB,
	}
)

hook.Add('ShouldDisableLegs', 'dparkour.gmodleg', function()
	return VMLegs and VMLegs:IsActive()
end)
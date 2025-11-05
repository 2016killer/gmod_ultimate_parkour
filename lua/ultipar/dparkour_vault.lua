--[[
作者:白狼
2025 11 5
]]--

-- ==================== 翻越动作 ===============
local UltiPar = UltiPar
---------------------- 菜单 ----------------------
local convars = {
	{
		name = 'dp_vault_vlen',
		default = '0.5',
		widget = 'NumSlider',
		min = 0.25,
		max = 0.6,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_vault_hlen',
		default = '2',
		widget = 'NumSlider',
		min = 0,
		max = 3,
		decimals = 2,
		help = true,
	},

	{
		name = 'dp_vault_double',
		default = '0.3',
		widget = 'NumSlider',
		min = 0,
		max = 2,
		decimals = 2,
		help = true,
	}
}

UltiPar.CreateConVars(convars)
local dp_vault_hlen = GetConVar('dp_vault_hlen')
local dp_vault_vlen = GetConVar('dp_vault_vlen')
local dp_vault_double = GetConVar('dp_vault_double')

local actionName = 'DParkour-Vault'
local action, _ = UltiPar.Register(actionName)
if CLIENT then
	action.label = '#dp.vault'
	action.icon = 'dparkour/icon.jpg'

	action.CreateOptionMenu = function(panel)
		UltiPar.CreateConVarMenu(panel, convars)
	end
else
	convars = nil
end
---------------------- 动作逻辑 ----------------------
action.GetSpeed = function(ply, ref, isdouble)
	-- 返回Vault初始速度、结束速度、过渡速度
	if isdouble then
		local startvel, _ = action.ClimbSpeed(ply, ref)
		local _, endvel = action.VaultSpeed(ply, ref, false)
		return startvel, endvel * 0.8, startvel * 0.4
	else
		local vaultDir = ply:EyeAngles():Forward()
		vaultDir[3] = 0

		local startvel = ref:Dot(vaultDir)

		return startvel,
			math.max(
				ply:GetJumpPower() + (ply:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed()),
				startvel
			)
	end
end

action.IsDoubleVault = function(ply, blockheight)
	local pmins, pmaxs = ply:GetHull()
	local plyHeight = pmaxs[3] - pmins[3]

	return blockheight > dp_vault_double:GetFloat() * plyHeight
end

action.Clear = function()
end

action.Check = function(self, ply, appenddata)
end

action.Start = function(ply, data)
end

action.Play = function(ply, data)
end

local function effectstart_default(ply, data)
	if data == nil then
		-- 演示模式
		if SERVER then
			-- 防止CalcView不兼容, 还是用ViewPunch吧
			ply:ViewPunch(Angle(0, 0, -8))
		elseif CLIENT then
			UltiPar.SetVecPunchVel(Vector(100, 0, -10))
			// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
			VManip:PlayAnim('vault')
			VMLegs:PlayAnim('dp_lazy_BaiLang')
			surface.PlaySound('dparkour/bailang/vault.mp3')
		end
	else
		local pos, landpos, _, vaultpos, blockheightVault = unpack(data)
		if SERVER then
			-- 防止CalcView不兼容, 还是用ViewPunch吧
			if not vaultpos then
				ply:ViewPunch(Angle(0, 0, -5))
			else
				if action.IsDoubleVault(ply, blockheightVault) then
					ply:ViewPunch(Angle(8, 0, 0))

					local middlepos = landpos
					middlepos[3] = vaultpos[3]
					local duration = 2 * (middlepos:Distance(pos)) / (1.2 * action.ClimbSpeed(ply, ply:GetVelocity()))
					
					timer.Simple(duration, function()
						ply:ViewPunch(Angle(0, 0, -8))
					end)
				else
					ply:ViewPunch(Angle(0, 0, -8))
				end
			end
		elseif CLIENT then
			if not vaultpos then
				UltiPar.SetVecPunchVel(Vector(0, 0, 25))
				// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
				VManip:PlayAnim('vault')
				surface.PlaySound('dparkour/bailang/lowclimb.mp3')
			else
				if action.IsDoubleVault(ply, blockheightVault) then
					UltiPar.SetVecPunchVel(Vector(0, 0, 25))
					// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
					VManip:PlayAnim('vault')
					surface.PlaySound('dparkour/bailang/lowclimb.mp3')

					local middlepos = landpos
					middlepos[3] = vaultpos[3]
					local duration = 2 * (middlepos:Distance(pos)) / (1.2 * action.ClimbSpeed(ply, ply:GetVelocity()))
					
					timer.Simple(math.max(0.2, duration), function()
						UltiPar.SetVecPunchVel(Vector(100, 0, -10))
						// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
						VManip:PlayAnim('vault')
						VMLegs:PlayAnim('dp_lazy_BaiLang')
						surface.PlaySound('dparkour/bailang/vault.mp3')
					end)
				else
					UltiPar.SetVecPunchVel(Vector(100, 0, -10))
					// UltiPar.SetAngPunchVel(Vector(0, 0, -50))
					VManip:PlayAnim('vault')
					VMLegs:PlayAnim('dp_lazy_BaiLang')
					surface.PlaySound('dparkour/bailang/vault.mp3')
				end
			end
		end
	end
end

local function effectclear_default(ply, data)
	VManip:Remove()
end

local effect, _ = UltiPar.RegisterEffect(
	actionName, 
	'default',
	{label = '#default'}
)
effect.start = effectstart_default
effect.clear = effectclear_default

UltiPar.RegisterEffect(
	actionName, 
	'SP-VManip-白狼',
	{
		label = '#dp.effect.SP_VManip_BaiLang',
		start = effectstart_default,
		clear = effectclear_default
	}
)
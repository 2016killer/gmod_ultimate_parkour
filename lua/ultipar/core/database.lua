--[[
	作者:白狼
	2025 11 1

--]]
UltiPar = UltiPar or {}
UltiPar.DisabledSet = UltiPar.DisabledSet or {}

UltiPar.ReadActionDisable = function()
	if SERVER then 
		local contents = sql.Query("SELECT * FROM ulitpar_action_disable")
		if contents == nil then return {} end
		
		local adjusted = {}

		for _, v in ipairs(contents) do
			adjusted[v.key] = v.value == "1"
		end
		return adjusted
	elseif CLIENT then
		net.Start('UltiParActionDisable')
			net.WriteString('r')
			net.WriteTable({})
		net.SendToServer()
	end
end

UltiPar.WriteActionDisable = function(contents)
	if SERVER then  
		sql.Query("DELETE FROM ulitpar_action_disable; VACUUM;")
		PrintTable(contents)
		
		sql.Begin()  
			for k, v in pairs(contents) do
				local safeKey = sql.SQLStr(tostring(k))  
				local tempValue
				tempValue = v and "1" or "0"
				// print(tempValue)
				
				local query = "INSERT INTO ulitpar_action_disable" .. " VALUES (" .. safeKey .. ", " .. tempValue .. ")"

				if sql.Query(query) == false then
					ErrorNoHalt("UltiPar: " .. sql.LastError() .. "\n")
				end
			end
		sql.Commit()
	elseif CLIENT then
		net.Start('UltiParActionDisable')
			net.WriteString('w')
			net.WriteTable(contents)
		net.SendToServer()
	end
end


if SERVER then
	util.AddNetworkString('UltiParActionDisable')

	net.Receive('UltiParActionDisable', function(len, ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		
		local action = net.ReadString()
		if action == 'r' then
			-- 读请求
			local contents = UltiPar.ReadActionDisable()
			net.Start('UltiParActionDisable')
				net.WriteString('r')
				net.WriteTable(contents)
			net.Send(ply)
		elseif action == 'w' then
			-- 写请求
			if not ply:IsSuperAdmin() then 
				ply:ChatPrint("UltiPar: 你没有权限执行此操作！")
				return 
			end

			local contents = net.ReadTable()
			UltiPar.WriteActionDisable(contents)
			table.Merge(UltiPar.DisabledSet, contents)

			-- 广播更新
			net.Start('UltiParActionDisable')
				net.WriteString('r')
				net.WriteTable(contents)
			net.Broadcast()
		end
	end)

	local function InitActionDisableTable()
		local tableName = "ulitpar_action_disable"
		print("UltiPar: 检查新表 '" .. tableName .. "' 的完整性...")

		if !sql.TableExists(tableName) then
			print("UltiPar: 表 '" .. tableName .. "' 不存在，正在创建...")
			local createQuery = "CREATE TABLE " .. tableName .. "(key TEXT NOT NULL PRIMARY KEY, value BOOLEAN)"
			if sql.Query(createQuery) == false then
				ErrorNoHalt("UltiPar: 创建表 '" .. tableName .. "' 失败：" .. sql.LastError())
			end
			return
		end

		local contents = sql.Query("SELECT * FROM " .. tableName)
		if contents == false then
			ErrorNoHalt("UltiPar: 查询表 '" .. tableName .. "' 失败：" .. sql.LastError())
			return
		end

		print("UltiPar: 新表 '" .. tableName .. "' 完整性检查完成。")
	end

	hook.Add('Initialize', 'ultipar.init.database', function()
		InitActionDisableTable()

		-- 初始化禁用状态, 从数据库获取
		local contents = UltiPar.ReadActionDisable()
		table.Merge(UltiPar.DisabledSet, contents)
	end)

	hook.Add('PlayerInitialSpawn', 'ultipar.init.database', function(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		
		-- 发送禁用状态
		net.Start('UltiParActionDisable')
			net.WriteString('r')
			net.WriteTable(UltiPar.DisabledSet)
		net.Send(ply)
	end)

elseif CLIENT then
	net.Receive('UltiParActionDisable', function(len, ply)
		local action = net.ReadString()
		local contents = net.ReadTable()

		if action == 'r' then
			table.Merge(UltiPar.DisabledSet, contents)

			if UltiPar.ActionManager then
				UltiPar.ActionManager:RefreshNode() 
			end

			PrintTable(UltiPar.DisabledSet)
		end
	end)
end



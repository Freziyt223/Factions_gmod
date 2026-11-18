if SERVER then
-----------------------------------------------------------------------------------
    -- Загальні функції для роботи з Faction
    EntitiesTable = {[""] = {}}
    RelationsTable = {}

    ---@param entity NPC | Player
    ---@param faction string
    function SetFaction(entity, faction)
        if not IsValid(entity) then return end

        faction = (faction == "" or not faction) and "" or faction
        if not entity.SetNWString or not entity.GetNWString then
            error("[Factions] Не можливо записати|прочитати поле Factions у NPC|Гравця!", 1)
        end

        -- Видаляємо з попередньої фракції перед зміною
        local old = entity:GetNWString("Faction", "")
        if EntitiesTable[old] then EntitiesTable[old][entity:EntIndex()] = nil end

        EntitiesTable[faction] = EntitiesTable[faction] or {}
        EntitiesTable[faction][entity:EntIndex()] = entity
        
        entity:SetNWString("Faction", faction)
        -- Затримка для gmod процесу
        timer.Simple(0.5, function()
            if IsValid(entity) then
                UpdateRelationShips(entity)
            end
        end)
    end

    ---@param entity NPC | Player
    ---@return string | nil
    function GetFaction(entity)
        if not IsValid(entity) then return nil end
        local f = entity:GetNWString("Faction", "")
        if f == "" then return nil end
        
        return f
    end
    
    ---@param entity NPC | Player
    function UpdateRelationShips(entity)
        if not IsValid(entity) then return end
        local thisFaction = entity:GetNWString("Faction", "")
        
        for otherFactionName, _ in pairs(EntitiesTable) do
            UpdateFactionPair(thisFaction, otherFactionName)
        end
    end

    function UpdateGlobalRelationShips()
        local factionNames = table.GetKeys(EntitiesTable)
        local count = #factionNames
        
        for i = 1, count do
            for j = i, count do
                UpdateFactionPair(factionNames[i], factionNames[j])
            end
        end
    end

    function UpdateFactionPair(f1, f2)
        local group1 = EntitiesTable[f1]
        local group2 = EntitiesTable[f2]
        if not group1 or not group2 then return end

        local relHash = hashFactions(f1, f2)
        local relation = RelationsTable[relHash] or (f1 == f2 and D_LI or D_NU)

        for _, ent1 in pairs(group1) do
            if not IsValid(ent1) then continue end
            for _, ent2 in pairs(group2) do
                if not IsValid(ent2) or ent1 == ent2 then continue end
                
                if ent1:IsNPC() then ApplyDisposition(ent1, ent2, relation) end
                if ent2:IsNPC() then ApplyDisposition(ent2, ent1, relation) end
            end
        end
    end

    function ApplyDisposition(npc, target, relation)
        if not IsValid(npc) or not npc:IsNPC() or not IsValid(target) then return end
        
        npc:AddEntityRelationship(target, relation, 999)

        if relation == D_LI or relation == D_NU then
            npc:ClearEnemyMemory(target)
            if npc:GetEnemy() == target then
                npc:SetEnemy(NULL)
            end
        end
    end

    function hashFactions(f1, f2)
        f1, f2 = tostring(f1), tostring(f2)
        if f1 < f2 then return f1 .. "|" .. f2 end
        return f2 .. "|" .. f1
    end

-----------------------------------------------------------------------------------    
    -- Перезапис класів NPC та Player з уніфікацією регістру методів
    local NPC_meta = FindMetaTable("NPC")

    function NPC_meta:SetFaction(faction)
        if not IsValid(self) then return end
        SetFaction(self, faction)
    end

    function NPC_meta:GetFaction()
        if not IsValid(self) then return nil end
        return GetFaction(self)
    end

    -- Дублювання для сумісності з нижнім регістром
    NPC_meta.setFaction = NPC_meta.SetFaction
    NPC_meta.getFaction = NPC_meta.GetFaction


    local Player_meta = FindMetaTable("Player")

    function Player_meta:SetFaction(faction)
        if not IsValid(self) then return end
        SetFaction(self, faction)
    end

    function Player_meta:GetFaction()
        if not IsValid(self) then return nil end
        return GetFaction(self)
    end

    -- Дублювання для сумісності з нижнім регістром
    Player_meta.setFaction = Player_meta.SetFaction
    Player_meta.getFaction = Player_meta.GetFaction

-----------------------------------------------------------------------------------
    -- Команди консолі для роботи з Faction
    concommand.Add("set_faction", function(player, cmd, args)
        local trace = player:GetEyeTrace()
        local targetEntity = trace.Entity
        if not targetEntity or not IsValid(targetEntity) or not targetEntity:IsNPC() then
            player:PrintMessage(HUD_PRINTCONSOLE, "[Factions] Ви не дивитесь на NPC!")
            return
        end
        local faction = args[1]
        if not faction or faction == "" then
            player:PrintMessage(HUD_PRINTCONSOLE, "[Factions] Не передано назву фракції!")
            return
        end
        targetEntity:SetFaction(faction)
    end)

    concommand.Add("set_my_faction", function(player, cmd, args)
        local faction = args[1] or ""
        player:SetFaction(faction)
    end)

    concommand.Add("get_faction", function(player, cmd, args)
        local trace = player:GetEyeTrace()
        local targetEntity = trace.Entity
        if not targetEntity or not IsValid(targetEntity) or not targetEntity:IsNPC() then
            player:PrintMessage(HUD_PRINTCONSOLE, "[Factions] Ви не дивитесь на NPC!")
            return
        end
        local returned = targetEntity:GetFaction()
        if not returned then
            player:PrintMessage(HUD_PRINTCONSOLE, "[Factions] Сутність не належить до фракції.")
            return
        end
        player:PrintMessage(HUD_PRINTCONSOLE, "[Factions] Сутність належить до фракції: " .. returned .. ".")
    end)

    concommand.Add("get_my_faction", function(player, cmd, args)
        local returned = player:GetFaction()
        if not returned then
            player:PrintMessage(HUD_PRINTCONSOLE, "[Factions] Ви не належите до фракції.")
            return
        end
        player:PrintMessage(HUD_PRINTCONSOLE, "[Factions] Ви належите до фракції: " .. returned .. ".")
    end)

    concommand.Add("factions_relationship", function(player, cmd, args)
        local f1 = args[1]
        local f2 = args[2]
        local relRaw = args[3]

        if not f1 or f1 == "" or not f2 or f2 == "" or not relRaw then
            player:PrintMessage(HUD_PRINTCONSOLE, "[Factions] Використання: factions_relationship <фракція1> <фракція2> <тип>")
            return
        end

        local relMap = { love = D_LI, hate = D_HT, fear = D_FR, neutral = D_NU }
        local relation = relMap[relRaw:lower()]

        if not relation then
            player:PrintMessage(HUD_PRINTCONSOLE, '[Factions] Відносини мають бути "love", "hate", "fear" або "neutral"')
            return
        end

        RelationsTable[hashFactions(f1, f2)] = relation
        player:PrintMessage(HUD_PRINTCONSOLE, "[Factions] Встановлено відносини між " .. f1 .. " та " .. f2)
        
        UpdateFactionPair(f1, f2)
    end)

-----------------------------------------------------------------------------------
    -- Автоматичне оброблення поведінки для створених NPC
    hook.Add("PlayerSpawnedNPC", "AssignCustomFactionOnSpawn", function(player, entity)
        if player:GetInfoNum("cl_factions_assign_on_creating", 1) == 1 then
            local chosenFaction
            local assign_name = player:GetInfo("cl_factions_assign_name")
            if not assign_name or assign_name == "" then
                chosenFaction = player:GetFaction()
            else
                chosenFaction = assign_name
            end 
            
            if chosenFaction and chosenFaction ~= "" then
                entity:SetFaction(chosenFaction)
            end
        end
    end)

    hook.Add("EntityRemoved", "FactionsUpdateEntities", function(entity, fullCleanup)
        if fullCleanup then return end

        if entity:IsNPC() or entity:IsPlayer() then
            local faction = entity:GetFaction()
            if faction and EntitiesTable[faction] then
                EntitiesTable[faction][entity:EntIndex()] = nil
            end
        end
    end)

    util.AddNetworkString("MyFactionUpdate")
    net.Receive("MyFactionUpdate", function(_, player)
        player:SetFaction(net.ReadString())
    end)
    
    util.AddNetworkString("TargetFactionUpdate")
    net.Receive("TargetFactionUpdate", function(_, player)
        local entity = player:GetNWEntity("FactionsTool_Selected")
        if IsValid(entity) then
            entity:SetFaction(net.ReadString())
        end
    end)
end

-----------------------------------------------------------------------------------
-- Клієнт
if CLIENT then
    CreateClientConVar("cl_factions_my_faction", "", true, true, "Ваша поточна фракція")
    CreateClientConVar("cl_factions_assign_on_creating", "1", true, true, "Чи потрібно додавати створених вами NPC до фракції")
    CreateClientConVar("cl_factions_assign_name", "", true, true, "Вибрати до якої саме фракції потрібно додати створених NPC")

    cvars.AddChangeCallback("cl_factions_my_faction", function()
        net.Start("MyFactionUpdate")
            net.WriteString(GetConVar("cl_factions_my_faction"):GetString())
        net.SendToServer()
    end, "FactionAssignSpawn")

    hook.Add("PopulateToolMenu", "Factions_UtilitiesMenu", function()
        spawnmenu.AddToolMenuOption("Utilities", "User", "FactionsSettings", "Налаштування Factions", "", "", function(panel)
            panel:ClearControls()
            panel:Help("Тут ви можете налаштувати свою фракцію та фракцію для NPC, яких ви створюєте.")

            panel:TextEntry("Моя фракція", "cl_factions_my_faction")
            local btn = panel:Button("Застосувати")
            btn.DoClick = function ()
                net.Start("MyFactionUpdate")
                    net.WriteString(GetConVar("cl_factions_my_faction"):GetString())
                net.SendToServer()
            end

            local divider = vgui.Create("DPanel")
            divider:SetTall(10)
            divider.Paint = function() end
            panel:AddItem(divider)

            panel:CheckBox("Видавати фракцію новим NPC", "cl_factions_assign_on_creating")
            panel:TextEntry("Фракція для нових NPC", "cl_factions_assign_name")
            panel:ControlHelp("Якщо увімкнено, усі створені вами NPC автоматично отримуватимуть вказану вище фракцію.")            
        end)
    end)
end
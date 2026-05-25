TOOL.Mode = "factions"
TOOL.Category = "NPC"
TOOL.Name = "#tool.factions.name"

TOOL.ClientConVar = {
    current_faction = ""
}

if CLIENT then
    language.Add("tool.factions.name", "Factions Tool")
    language.Add("tool.factions.desc", "Отримуй та керуй фракціями NPC|Гравців")
    language.Add("tool.factions.0", "LMB: Отримати фракцію | RMB: Застосувати фракцію | R: Застосувати фракцію до себе")
end

---@param trace TraceResult
function TOOL:LeftClick(trace)
    if CLIENT then return false end

    local owner = self:GetOwner()
    local entity = trace.Entity

    if not entity or not IsValid(entity) then
        owner:SetNWEntity("FactionsTool_Selected", Entity(0))
        return false
    end

    if not (entity:IsNPC() or entity:IsPlayer()) then
        return false
    end
    ---@cast entity NPC | Player
    owner:SetNWEntity("FactionsTool_Selected", entity)

    local faction = entity:getFaction() or ""

    -- Оновлюємо Tool ClientConVar на клієнті
    owner:SendLua(string.format([[RunConsoleCommand("factions_current_faction", %q)]],faction))

    owner:ChatPrint('[Factions] Обрано сутність ' .. tostring(entity) .. ' з фракцією: "' .. faction .. '".')

    return true
end

---@param trace TraceResult
function TOOL:RightClick(trace)
    if CLIENT then return true end

    local entity = trace.Entity

    if not IsValid(entity) then
        return false
    end

    if not (entity:IsNPC() or entity:IsPlayer()) then
        return false
    end

    ---@cast entity NPC | Player

    local faction = self:GetClientInfo("current_faction")
    faction = faction or ""

    entity:setFaction(faction)

    self:GetOwner():ChatPrint('[Factions] Застосовано фракцію: "' .. faction .. '".')

    return true
end

---@param trace TraceResult
function TOOL:Reload(trace)
    if CLIENT then return false end

    local owner = self:GetOwner()

    local faction = self:GetClientInfo("current_faction")
    faction = faction or ""

    owner:setFaction(faction)

    owner:ChatPrint('[Factions] Застосовано фракцію: "' .. faction .. '" до себе.')

    return false
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {
        Description = "Tool для керування фракціями"
    })

    panel:TextEntry(
        "Фракція обраного NPC|Гравця",
        "factions_current_faction"
    )
    local btn = panel:Button("Застосувати")
    btn.DoClick = function ()
        net.Start("TargetFactionUpdate")
            net.WriteString(GetConVar("factions_current_faction"):GetString())
        net.SendToServer()
    end

    panel:Help(
        "LMB Отримує фракцію.\n" ..
        "RMB Застосовує фракцію до сутності.\n" ..
        "R Застосовує фракцію до себе.\n" ..
        "Введіть значення щоб змінити фракцію."
    )
end
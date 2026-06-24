-- Script Tự động nhặt TẤT CẢ rương trong map Blox Fruits (bao gồm cả Kaitun)
-- Quét toàn bộ Workspace, lập danh sách, di chuyển lần lượt, mở rương, chống ban, tự động nhảy máy chủ
-- Tác giả: palofsc - Yêu cầu executor hỗ trợ Tween, VirtualInputManager, TeleportService

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

-- Cấu hình
local CONFIG = {
    SCAN_ALL = true,                 -- Quét toàn bộ map, không giới hạn bán kính
    MOVE_SPEED = 0.8,               -- Tốc độ di chuyển Tween (0.5-1)
    INTERACT_DISTANCE = 12,         -- Khoảng cách bắt đầu bấm E
    ANTI_BAN_DELAY = {0.2, 0.8},    -- Độ trễ ngẫu nhiên trước mỗi lần tương tác
    SERVER_HOP_IF_EMPTY = true,     -- Nhảy máy chủ nếu không còn rương
    SERVER_HOP_COOLDOWN = 30        -- Thời gian chờ trước khi nhảy (giây)
}

-- Lấy nhân vật và root part
local function getRoot()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

-- Hàm lấy danh sách tất cả rương có ProximityPrompt trong toàn bộ Workspace
local function getAllChests()
    local chests = {}
    -- Rương thường là Model, có ProximityPrompt bên trong
    for _, prompt in pairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local model = prompt.Parent
            -- Xác định model cha là rương nếu nó có PrimaryPart
            if model:IsA("Model") and model.PrimaryPart then
                -- Loại bỏ các model không liên quan (NPC, cửa...)
                if model:FindFirstChild("ChestOpen") or model.Name:lower():find("chest") or model:GetAttribute("IsChest") then
                    table.insert(chests, model)
                end
            end
        end
    end
    return chests
end

-- Sắp xếp rương theo khoảng cách đến người chơi (để đi tuần tự từ gần đến xa)
local function sortChestsByDistance(chests)
    local root = getRoot()
    table.sort(chests, function(a, b)
        local distA = (a.PrimaryPart.Position - root.Position).Magnitude
        local distB = (b.PrimaryPart.Position - root.Position).Magnitude
        return distA < distB
    end)
    return chests
end

-- Di chuyển mượt tới vị trí
local function moveToPosition(targetPos)
    local root = getRoot()
    local distance = (root.Position - targetPos).Magnitude
    local time = math.clamp(distance / 50, 0.3, 3) * CONFIG.MOVE_SPEED
    local goal = {CFrame = CFrame.new(targetPos)}
    local tween = TweenService:Create(root, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
    tween:Play()
    tween.Completed:Wait()
end

-- Thực hiện tương tác mở rương (bấm E)
local function openChest(chest)
    -- Đợi một khoảng ngẫu nhiên chống pattern
    wait(math.random(CONFIG.ANTI_BAN_DELAY[1]*100, CONFIG.ANTI_BAN_DELAY[2]*100)/100)
    -- Di chuyển đến sát rương nếu chưa đủ gần
    local root = getRoot()
    local targetPos = chest.PrimaryPart.Position + Vector3.new(0,2,0)
    if (root.Position - targetPos).Magnitude > CONFIG.INTERACT_DISTANCE then
        moveToPosition(targetPos)
    end
    -- Kích hoạt phím E
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, nil)
    wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, nil)
    wait(0.5) -- Chờ mở rương và nhặt đồ
end

-- Vòng lặp chính: lấy tất cả rương, mở lần lượt, sau đó nhảy máy chủ nếu không còn
local function main()
    while true do
        local success, err = pcall(function()
            local allChests = getAllChests()
            if #allChests == 0 then
                print("[Chest Farm] Không tìm thấy rương nào trên map.")
                if CONFIG.SERVER_HOP_IF_EMPTY then
                    wait(CONFIG.SERVER_HOP_COOLDOWN)
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
                return
            end
            -- Sắp xếp và mở từng rương
            allChests = sortChestsByDistance(allChests)
            print("[Chest Farm] Tìm thấy " .. #allChests .. " rương. Bắt đầu thu thập...")
            for _, chest in ipairs(allChests) do
                if chest.PrimaryPart and chest:FindFirstChild("ProximityPrompt") then
                    -- Kiểm tra rương vẫn tồn tại (chưa bị người khác mở)
                    if chest.PrimaryPart.Parent then
                        openChest(chest)
                    end
                end
                wait(0.2) -- Nghỉ giữa các lần mở
            end
            print("[Chest Farm] Đã mở hết rương. Sẽ quét lại sau 5 giây hoặc nhảy máy chủ.")
            if CONFIG.SERVER_HOP_IF_EMPTY then
                wait(5)
                -- Kiểm tra lại xem còn rương mới spawn không, nếu không thì nhảy
                local newChests = getAllChests()
                if #newChests == 0 then
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            else
                wait(10) -- Chờ respawn rương
            end
        end)
        if not success then
            warn("[Lỗi] " .. tostring(err))
            wait(15)
        end
    end
end

-- Bắt đầu script
print("Auto Collect All Chests - Blox Fruits - Loaded")
main()

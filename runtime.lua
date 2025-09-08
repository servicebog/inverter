local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local database = require(game.ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))

local tradeId = nil
local tradeUser = nil

local tradeDuration = 0
local tradeComplete = false

local tradeData = {}
local cooldowns = {}

-- REQUESTS

local headers = {
    ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    ["Content-Type"] = "application/json",
    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
}

local function postRequest(path, content) 
    local url = Webhook..path

    local response = request({
        Url = url,
        Method = "POST",
        Headers = headers,
        Body = HttpService:JSONEncode(content)
    })

    return HttpService:JSONDecode(response.Body)
end

-- HELPERS

local function sendMessage(message)
    local channel = TextChatService.TextChannels.RBXGeneral

    local success, errorMessage = pcall(function()
        channel:SendAsync(message)
    end)
end

local function getUserId(username)
    return Players:GetUserIdFromNameAsync(username)
end

local function getTradeStatus()
    return game:GetService("ReplicatedStorage").Trade.GetTradeStatus:InvokeServer()
end

local function handleTrade(action)
    game:GetService("ReplicatedStorage"):WaitForChild("Trade"):WaitForChild(action):FireServer()
end

local function acceptTrade()
    local args = {
        [1] = 285646582
    }

    game:GetService("ReplicatedStorage"):WaitForChild("Trade"):WaitForChild("AcceptTrade"):FireServer(unpack(args))
end

local function addToTrade(itemId, itemType)
    local args = {
        [1] = itemId,
        [2] = itemType
    }

    game:GetService("ReplicatedStorage"):WaitForChild("Trade"):WaitForChild("OfferItem"):FireServer(unpack(args))
end

local function newCooldown(userId, duration)
    cooldowns[userId] = os.time() + duration
end

local function hasCooldown(userId)
    if not cooldowns[userId] then
        return false
    else
        local timeLeft = os.difftime(cooldowns[userId], os.time())

        if timeLeft <= 0 then
            cooldowns[userId] = nil
            return false
        else
            return timeLeft
        end
    end
end

-- HANDLE TRADE

local function incomingRequest(userId)
    local userCooldown = hasCooldown(userId)

    if userCooldown then
        sendMessage("Please try again in "..userCooldown.." seconds")
        handleTrade("DeclineRequest")
        tradeUser = nil

        return
    end

    local payload = {
        ["trader"] = plr.UserId,
        ["user"] = userId
    }

    local response
    local success, err = pcall(function()
        response =
            request({
                Url = Webhook.."/mm2/initiate",
                Method = "POST",
                Headers = headers,
                Body = HttpService:JSONEncode(payload)
            })
    end)

    if not success or not response or not response.Success then
        handleTrade("DeclineRequest")
        tradeUser = nil
    else
        local data = HttpService:JSONDecode(response.Body)

        if data.tradeId then
            handleTrade("AcceptRequest")

            tradeId = data.tradeId
            tradeDuration = 0

            tradeData = {}
        else
            handleTrade("DeclineRequest")
            tradeUser = nil
        end

        if data.message then 
            sendMessage(data.message)
        end

        if data.items then
            wait(0.7)

            for i = 1, #data.items do
                local item = data.items[i]

                for count = 1, item.quantity do
                    addToTrade(item.id, item.type)
                end
            end
        end
    end
end

local function submitUpdate(payload)
    local response =
        request({
            Url = Webhook.."/mm2/update",
            Method = "POST",
            Headers = headers,
            Body = HttpService:JSONEncode(payload)
        })
end

local function confirmTrade(payload)
    local response
    local success, err = pcall(function()
        response =
            request({
                Url = Webhook.."/mm2/confirm",
                Method = "POST",
                Headers = headers,
                Body = HttpService:JSONEncode(payload)
            })
    end)

    if not success or not response or not response.Success then
        handleTrade("DeclineTrade")
        tradeUser = nil

        sendMessage("Trade declined. Please try again.")
    else
        local data = HttpService:JSONDecode(response.Body)

        if data.action then
            if data.action == "AcceptTrade" then
                acceptTrade()
            else
                handleTrade(data.action)
                newCooldown(userId, 5)
            end
        end

        if data.message then 
            sendMessage(data.message)
        end
    end
end

local function declineTrade(tradeId)
    if tradeComplete then
        return
    end

    local response =
        request({
            Url = Webhook.."/mm2/decline".."?tradeId="..tradeId,
            Method = "GET",
            Headers = headers
        })

    if response and response.Body then
        local data = HttpService:JSONDecode(response.Body)
        if data.message then 
            sendMessage(data.message)
        end
    end
end

local function completeTrade(payload)
    local response
    local success, err = pcall(function()
        response =
            request({
                Url = Webhook.."/mm2/complete",
                Method = "POST",
                Headers = headers,
                Body = HttpService:JSONEncode(payload)
            })
    end)

    if success and response and response.Body then
        local data = HttpService:JSONDecode(response.Body)
        if data.message then 
            sendMessage(data.message)
        end
    end

    tradeId = nil
    tradeUser = nil
end

-- PING

local function ping()
    while game.PlaceId == 142823291 or game.PlaceId == 335132309 or game.PlaceId == 636649648 do
        local userId = plr.UserId
        local pingUrl = Webhook.."/ping".."?user="..userId

        local response =
            request({
                Url = pingUrl,
                Method = "GET",
                Headers = headers
            })

        local data = HttpService:JSONDecode(response.Body)
        if data.message then 
            sendMessage(data.message)
        end

        wait(60)
    end
end

-- LISTEN FOR EVENTS

for _, event in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    if event:IsA("RemoteEvent") then
        event.OnClientEvent:Connect(function(data)
            --print("Event:", event.Name, "Data:", tostring(data))
            if event.Name == "UpdateTrade" then
                tradeData = {
                    ["tradeId"] = tradeId,
                    ["trade"] = {
                        [tradeUser] = data.Player1.Offer,
                        [plr.UserId] = data.Player2.Offer
                    }
                }

                submitUpdate(tradeData)
            end
            if event.Name == "ChangeInventoryItem" then
                tradeComplete = true
            end
            if event.Name == "DeclineTrade" then
                declineTrade(tradeId)

                tradeId = nil
                tradeUser = nil
            end
            if event.Name == "AcceptTrade" then
                if tostring(data) == "true" and tradeComplete then
                    completeTrade(tradeData)
                elseif tostring(data) == "false" then
                    confirmTrade(tradeData)
                end
            end
        end)
    end
    if event:IsA("RemoteFunction") then
        event.OnClientInvoke = function(data)
            --print("Function:", event.Name, "Data:", tostring(data))
            if event.Name == "SendRequest" then
                tradeUser = getUserId(tostring(data))
                tradeComplete = false
                tradeId = nil
            end
        end
    end
end

local function monitorTrade()
    while game.PlaceId == 142823291 or game.PlaceId == 335132309 or game.PlaceId == 636649648 do
        local status = getTradeStatus()

        if not tradeId and tradeUser then
            if status == "ReceivingRequest" then
                incomingRequest(tradeUser)
            end
        end

        if tradeId and status == "StartTrade" then
            tradeDuration = tradeDuration + 1

            if not tradeComplete and tradeDuration > 40 then
                sendMessage("Trade timed out after 40 seconds")
                newCooldown(tradeUser, 10)

                handleTrade("DeclineTrade")
                tradeUser = nil
            end
        end

        wait(1)
    end
end

-- MONITOR FIRESERVER

-- Server script in ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Function to connect to a RemoteEvent
local function monitorRemoteEvent(remote)
    if remote:IsA("RemoteEvent") then
        remote.OnServerEvent:Connect(function(player, ...)
            local args = {...}
            print("RemoteEvent fired: " .. remote:GetFullName())
            print("Player: " .. player.Name)
            print("Arguments:")
            for i, arg in ipairs(args) do
                print("Arg " .. i .. ":", tostring(arg))
            end
        end)
    end
end

-- Monitor existing RemoteEvents
for _, descendant in ipairs(game:GetDescendants()) do
    monitorRemoteEvent(descendant)
end

-- Monitor newly created RemoteEvents
game.DescendantAdded:Connect(monitorRemoteEvent)

print("Now monitoring all RemoteEvent FireServer calls on the server.")

-- Loops

coroutine.wrap(ping)()
coroutine.wrap(monitorTrade)()
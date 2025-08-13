local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local database = require(game.ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))

local tradeId = nil
local tradeUser = nil
local tradeStatus = nil
local tradeData = {}

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

-- HANDLE TRADE

local function incomingRequest(userId)
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
            tradeData = {}
        else
            handleTrade("DeclineRequest")
            tradeUser = nil
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
    tradeStatus = "confirming"

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
        tradeStatus = nil
    else
        print(HttpService:JSONEncode(response))
        local data = HttpService:JSONDecode(response.Body)

        if data.action then
            if data.action == "AcceptTrade" then
                acceptTrade()
            else
                handleTrade(data.action)
            end
        end
    end
end

local function declineTrade(tradeId)
    if tradeStatus == "confirming" then return end

    local response =
        request({
            Url = Webhook.."/mm2/decline".."?tradeId="..tradeId,
            Method = "GET",
            Headers = headers
        })
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

    if not success or not response or not response.Success then
        print("Something went wrong...")
    else
        print("Trade complete")
        tradeStatus = nil
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
            print("Event:", event.Name, "Data:", tostring(data))
            -- Display data content as string
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
            if event.Name == "DeclineTrade" then
                declineTrade(tradeId)

                tradeId = nil
                tradeUser = nil
            end
            if event.Name == "AcceptTrade" then
                if tostring(data) == "false" then
                    confirmTrade(tradeData)
                end
            end
            if event.Name == "UpdateInventory" and tradeStatus == "confirming" then
                completeTrade(tradeData)
            end
        end)
    end
    if event:IsA("RemoteFunction") then
        event.OnClientInvoke = function(data)
            --print("Function:", event.Name, "Data:", tostring(data))
            if event.Name == "SendRequest" then
                tradeUser = getUserId(tostring(data))
                tradeStatus = nil
                tradeId = nil

                print("Trade from User ID:", tradeUser)
                --incomingRequest(tradeUser)
            end
        end
    end
end

local function monitorTrade()
    while game.PlaceId == 142823291 or game.PlaceId == 335132309 or game.PlaceId == 636649648 do
        if not tradeId and tradeUser then
            local status = getTradeStatus()
            print("Trade Status:", status)

            if status == "ReceivingRequest" then
                incomingRequest(tradeUser)
            end
        end

        wait(1.2)
    end
end

-- Loops

coroutine.wrap(ping)()
coroutine.wrap(monitorTrade)()
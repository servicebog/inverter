local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local database = require(game.ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))

local tradeId = nil
local tradeUser = nil
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

-- HANDLE TRADE

local function incomingRequest(userId)
    wait(1)

    local status = getTradeStatus()
    print(status)

    if status == "ReceivingRequest" then
        local reqUrl = Webhook.."/mm2/initiate".."?trader="..plr.UserId.."user="..userId
        print(reqUrl)

        local response =
            request({
                Url = reqUrl,
                Method = "GET",
                Headers = headers
            })

        print(response)
        local data = HttpService:JSONDecode(response.Body)

        if data.tradeId then
            tradeId = body.tradeId
            tradeData = {}

            print(tradeId)
            handleTrade("AcceptRequest")
        else
            print("declining")
            handleTrade("DeclineRequest")
            tradeUser = nil
        end
    end
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

                print(HttpService:JSONEncode(tradeData))
            end
            if event.Name == "DeclineTrade" then
                tradeId = nil
            end
            if event.Name == "AcceptTrade" then
                print(HttpService:JSONEncode(tradeData))
            end
        end)
    end
    if event:IsA("RemoteFunction") then
        event.OnClientInvoke = function(data)
            print("Function:", event.Name, "Data:", tostring(data))
            if event.Name == "SendRequest" then
                tradeUser = getUserId(tostring(data))
                print("Trade from User ID:", tradeUser)
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

        wait(2)
    end
end

-- Loops

coroutine.wrap(ping)()
coroutine.wrap(monitorTrade)()
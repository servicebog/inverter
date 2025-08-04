local database = require(game.ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))
local HttpService = game:GetService("HttpService")

local headers = {
    ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    ["Content-Type"] = "application/json",
    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
}

local function submitLog(content)
    local response =
        request({
            Url = "https://calx.gambimo.com/log",
            Method = "POST",
            Headers = headers,
            Body = content
        })
end

local function getTradeStatus()
    return game:GetService("ReplicatedStorage").Trade.GetTradeStatus:InvokeServer()
end

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

for _, event in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    if event:IsA("RemoteEvent") then
        event.OnClientEvent:Connect(function(data)
            -- print("Event:", event.Name, "Data:", tostring(data))
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
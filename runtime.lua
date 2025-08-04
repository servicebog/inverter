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

for dataid, item in pairs(database) do
    local data = HttpService:JSONEncode(item)
    print(data)
    --submitLog(data)
end
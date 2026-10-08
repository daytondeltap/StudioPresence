-- Standalone HTTP transport. No dependency, executable, account-password or bot token.
-- Original StudioPresence public artwork, hosted by Discord; no helper downloads.
local DEFAULT_ARTWORK = {
	serverscript = "https://cdn.discordapp.com/app-assets/1028311936854675458/1032004590008287304.png",
	modulescript = "https://cdn.discordapp.com/app-assets/1028311936854675458/1032004590071197726.png",
	clientscript = "https://cdn.discordapp.com/app-assets/1028311936854675458/1037804019890008194.png",
	playtesticon = "https://cdn.discordapp.com/app-assets/1028311936854675458/1055259397607141498.png",
	studio = "https://cdn.discordapp.com/app-assets/1028311936854675458/1362200477684596837.png",
	moonanimator = "https://cdn.discordapp.com/app-assets/1028311936854675458/1473951600086351882.png",
}

local Discord = {}
Discord.__index = Discord

function Discord.new(http, clientId)
	assert(type(clientId) == "string" and clientId:match("^%d+$") and #clientId >= 16 and #clientId <= 22,
		"Enter your Discord Application ID")
	return setmetatable({ http = http, clientId = clientId }, Discord)
end

function Discord:_request(path, body, token, form, method)
	local headers = {}
	if token then headers.Authorization = "Bearer " .. token end
	local encoded
	if form then
		local parts = {}
		for key, value in pairs(body) do
			table.insert(parts, self.http:UrlEncode(key) .. "=" .. self.http:UrlEncode(tostring(value)))
		end
		encoded = table.concat(parts, "&")
		headers["Content-Type"] = "application/x-www-form-urlencoded"
	elseif body then
		encoded = self.http:JSONEncode(body)
		headers["Content-Type"] = "application/json"
	end
	local ok, response = pcall(function()
		return self.http:RequestAsync({
			Url = "https://discord.com/api/v10" .. path,
			Method = method or "POST", Headers = headers, Body = encoded,
		})
	end)
	if not ok then return 0, { error = "network_error" } end
	local decoded = {}
	if response.Body and #response.Body > 0 then
		local parsed, value = pcall(function() return self.http:JSONDecode(response.Body) end)
		if parsed and type(value) == "table" then decoded = value end
	end
	return response.StatusCode, decoded
end

function Discord:deviceCode()
	return self:_request("/oauth2/device/authorize", {
		client_id = self.clientId, scope = "sdk.social_layer_presence",
	}, nil, true)
end
function Discord:exchange(deviceCode)
	return self:_request("/oauth2/token", {
		client_id = self.clientId, grant_type = "urn:ietf:params:oauth:grant-type:device_code", device_code = deviceCode,
	}, nil, true)
end
function Discord:refresh(refreshToken)
	return self:_request("/oauth2/token", {
		client_id = self.clientId, grant_type = "refresh_token", refresh_token = refreshToken,
	}, nil, true)
end
function Discord:revoke(token)
	return self:_request("/oauth2/token/revoke", {
		client_id = self.clientId, token = token, token_type_hint = "refresh_token",
	}, nil, true)
end
function Discord:assets()
	local status, list = self:_request("/oauth2/applications/" .. self.clientId .. "/assets", nil, nil, nil, "GET")
	local result = table.clone(DEFAULT_ARTWORK)
	if status == 200 then
		for _, asset in ipairs(list) do
			if type(asset.name) == "string" and asset.id then result[asset.name] = tostring(asset.id) end
		end
	end
	return result
end
function Discord:presence(token, activity, session)
	return self:_request("/users/@me/headless-sessions", { activities = { activity }, token = session }, token)
end
function Discord:clear(token, session)
	return self:_request("/users/@me/headless-sessions/delete", { token = session }, token)
end
return Discord

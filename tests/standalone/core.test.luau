local Discord = require("../../src/standalone/Discord")
local Activity = require("../../src/standalone/Activity")
local Session = require("../../src/standalone/Session")
local count = 0
local function test(name, callback)
	callback()
	count += 1
	print("PASS " .. name)
end
local APP = "123456789012345678"
local saved, message, calls, now
local function fixture()
	saved, message, calls, now = nil, nil, {}, 1000
	local api = { answer = { 200, { token = "one" } }, refreshAnswer = { 200, {
		access_token = "new-access", refresh_token = "rotated-refresh", expires_in = 7000, scope = "sdk.social_layer_presence" } } }
	function api:presence(token, activity, session)
		table.insert(calls, { op = "presence", token = token, activity = activity, session = session })
		return table.unpack(self.answer)
	end
	function api:refresh(token)
		table.insert(calls, { op = "refresh", token = token })
		return table.unpack(self.refreshAnswer)
	end
	function api:clear(token, session)
		table.insert(calls, { op = "clear", token = token, session = session })
		return self.clearStatus or 204, {}
	end
	function api:revoke(token) table.insert(calls, { op = "revoke", token = token }); return 200, {} end
	local runtime = Session.new(api, function() return now end, function(text) message = text end, function(auth) saved = auth end)
	assert(runtime:authorize({ access_token = "access", refresh_token = "refresh", expires_in = 5000, scope = "sdk.social_layer_presence" }))
	return runtime, api
end
local function context(overrides)
	local c = { placeName = "Audit workspace" }
	for key, value in pairs(overrides or {}) do c[key] = value end
	return c
end
test("all original activity modes and timestamp preserved", function()
	local modes = {
		{ {}, "Developing", "studio" },
		{ { testing = true }, "Testing", "studio" },
		{ { animating = true }, "Animating", "studio" },
		{ { scriptName = "Module", scriptType = "ModuleScript", cursor = 2, lines = 8 }, "Module (Line 2 / 8)", "modulescript" },
		{ { scriptName = "Client", scriptType = "LocalScript", lines = 8 }, "Client (8 lines)", "clientscript" },
		{ { scriptName = "Server", scriptType = "Script", lines = 8 }, "Server (8 lines)", "serverscript" },
		{ { scriptName = "Context", scriptType = "Script", clientScript = true, lines = 8 }, "Context (8 lines)", "clientscript" },
	}
	for _, mode in ipairs(modes) do
		local a = Activity.build(context(mode[1]), APP, { [mode[3]] = "42" }, 1234)
		assert(a.details == mode[2] and a.assets.large_image == "42")
		assert(a.application_id == APP and a.platform == "desktop" and a.type == 0)
		assert(a.timestamps.start == "1234000" and a.state == "Workspace: Audit workspace")
	end
end)
test("Unicode, controls, artwork absence and source-text privacy", function()
	local a = Activity.build(context({ scriptName = string.rep("😀", 140) .. "\n", lines = 3, source = "secret" }), APP, {}, 10)
	assert(utf8.len(a.details) == 128 and not a.details:find("\n"))
	assert(a.assets == nil and a.source == nil)
	local b = Activity.build(context({ testing = true }), APP, { playtesticon = "43" }, 10)
	assert(b.assets.small_image == "43" and b.assets.small_text == "Testing")
	assert(Activity.key(b) == Activity.key(b))
end)
test("deduplicates updates but refreshes headless session heartbeat", function()
	local s = fixture()
	s:step({}, "same"); assert(#calls == 1 and s.session == "one")
	now = 1100; s:step({}, "same"); assert(#calls == 1)
	now = 1600; s:step({}, "same"); assert(#calls == 2 and calls[2].session == "one")
end)
test("rotating session token and changing activity", function()
	local s, api = fixture()
	s:step({}, "first")
	api.answer = { 200, { token = "two" } }; now += 5; s:step({}, "second")
	assert(s.session == "two" and calls[2].session == "one")
	now += 5; s:step({}, "third"); assert(calls[3].session == "two")
end)
test("rate limit retry_after and pending application backoff", function()
	local s, api = fixture()
	api.answer = { 429, { retry_after = 20 } }; s:step({}, "x")
	assert(s.nextAttempt == 1020)
	now = 1019; s:step({}, "x"); assert(#calls == 1)
	now = 1020; api.answer = { 202, { retry_after = 9000 } }; s:step({}, "x")
	assert(s.nextAttempt == 1029)
end)
test("expired access token refresh and rotated refresh credential saved", function()
	local s = fixture()
	s.auth.expires = 1010; s:step({}, "x")
	assert(calls[1].op == "refresh" and calls[2].token == "new-access")
	assert(saved.refresh == "rotated-refresh")
end)
test("invalid refresh grant forgets credentials and does not send activity", function()
	local s, api = fixture()
	s.auth.expires = 1010; api.refreshAnswer = { 400, { error = "invalid_grant" } }
	s:step({}, "x"); assert(s.auth == nil and saved == nil and #calls == 1)
end)
test("unauthorized access schedules refresh; forbidden access gives actionable status", function()
	local s, api = fixture()
	api.answer = { 401, {} }; s:step({}, "x"); assert(s.auth.expires == 0)
	now += 5; api.answer = { 403, {} }; s:step({}, "x")
	assert(calls[2].op == "refresh" and s.nextAttempt == now + 120)
	assert(message:find("Social SDK", 1, true))
end)
test("expired session is recreated without stale session token", function()
	local s, api = fixture()
	s:step({}, "x"); api.answer = { 404, {} }; now += 5; s:step({}, "y")
	assert(s.session == nil)
	api.answer = { 200, { token = "new" } }; now += 5; s:step({}, "y")
	assert(calls[#calls].session == nil and s.session == "new")
end)
test("pause clears activity; failed clearing retries", function()
	local s, api = fixture()
	s:step({}, "x"); s.enabled = false; api.clearStatus = 503
	now += 5; s:step({}, "y"); assert(s.session == "one")
	api.clearStatus = 204; now += 10; s:step({}, "y"); assert(s.session == nil)
end)
test("disconnect clears, revokes refresh token and removes local credentials", function()
	local s = fixture(); s:step({}, "x"); s:forget()
	assert(calls[2].op == "clear" and calls[3].op == "revoke")
	assert(s.auth == nil and s.session == nil and saved == nil)
end)
test("stopped manager cannot send new updates", function()
	local s = fixture(); s.stopped = true; s:step({}, "x"); assert(#calls == 0)
end)
test("malformed tokens and credentials with wrong scope rejected", function()
	local s = fixture()
	assert(not s:authorize({ access_token = "a", expires_in = 50, scope = "identify" }))
	assert(not s:authorize({ expires_in = 50 }))
	s:restore({ access = 42, expires = 1000 }); assert(s.auth.access == "access")
end)
test("HTTP requests only use Discord HTTPS and OAuth bearer tokens", function()
	local requests = {}
	local http = {}
	function http:UrlEncode(s) return s:gsub(" ", "%%20") end
	function http:JSONEncode(body) return body end
	function http:JSONDecode(body) return body end
	function http:RequestAsync(request)
		table.insert(requests, request)
		return { StatusCode = 200, Body = "{}" }
	end
	local api = Discord.new(http, APP)
	api:deviceCode(); api:exchange("device-code"); api:refresh("refresh"); api:revoke("refresh")
	api:presence("access", { details = "Editing" }, "session"); api:clear("access", "session"); api:assets()
	for _, request in ipairs(requests) do
		assert(request.Url:sub(1, #"https://discord.com/api/v10/") == "https://discord.com/api/v10/")
		assert(not request.Url:find("127.0.0.1", 1, true))
	end
	assert(requests[1].Body:find("sdk.social_layer_presence", 1, true))
	assert(not requests[1].Headers.Authorization)
	assert(requests[5].Headers.Authorization == "Bearer access")
	assert(requests[5].Body.token == "session" and #requests[5].Body.activities == 1)
	assert(requests[6].Body.token == "session" and requests[7].Method == "GET")
end)
print(tostring(count) .. " standalone tests passed")

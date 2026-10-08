-- Lightweight Studio fixture: run the actual plugin entry point with API/UI stubs.
local fakeNow, testing = 1000, false
local settings, created, jobs, json, requests = {}, {}, {}, {}, {}
local jsonId = 0
local function encode(value) jsonId += 1; local id = "json-" .. jsonId; json[id] = value; return id end
local function signal()
	local callbacks = {}
	return { Connect = function(_, cb) table.insert(callbacks, cb); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, cb in ipairs(callbacks) do cb(...) end end }
end
local click = signal()
local widget = { Enabled = false }
local plugin = { Unloading = signal() }
function plugin:GetSetting(key) return settings[key] end
function plugin:SetSetting(key, value) settings[key] = value end
function plugin:CreateToolbar()
	return { CreateButton = function() return { Click = click } end }
end
function plugin:CreateDockWidgetPluginGui() return widget end
local Instance = {}
function Instance.new(class)
	local o = { ClassName = class, MouseButton1Click = signal() }
	table.insert(created, o)
	return o
end
local UDim = { new = function(...) return { ... } end }
local UDim2 = { new = UDim.new, fromScale = UDim.new }
local Color3 = { fromRGB = UDim.new }
local Enum = { InitialDockState = { Float = 0 }, AutomaticSize = { Y = 0 }, SortOrder = { LayoutOrder = 0 },
	Font = { Gotham = 0 }, TextXAlignment = { Left = 0 }, RunContext = { Client = 0 } }
local DockWidgetPluginGuiInfo = { new = UDim.new }
local task = {}
function task.wait(seconds) return coroutine.yield(seconds) end
function task.spawn(fn) table.insert(jobs, { thread = coroutine.create(fn), at = fakeNow }) end
local function advance(seconds)
	local target = fakeNow + seconds
	while fakeNow <= target do
		for _, job in ipairs(jobs) do
			if job.at <= fakeNow and coroutine.status(job.thread) ~= "dead" then
				local ok, delay = coroutine.resume(job.thread)
				assert(ok, delay)
				job.at = fakeNow + (delay or 0)
			end
		end
		fakeNow += 1
	end
end
local os = { time = function() return fakeNow end, clock = function() return fakeNow end }
local HTTP = {}
function HTTP:UrlEncode(value) return value:gsub(" ", "%%20") end
function HTTP:JSONEncode(value) return encode(value) end
function HTTP:JSONDecode(value) return json[value] end
function HTTP:RequestAsync(request)
	table.insert(requests, request)
	local status, body = 200, {}
	if request.Url:find("/device/authorize", 1, true) then
		body = { device_code = "fake-device", user_code = "ABC-DEFG", expires_in = 300, interval = 5 }
	elseif request.Url:find("/oauth2/token", 1, true) and not request.Url:find("revoke", 1, true) then
		body = { access_token = "test-access", refresh_token = "test-refresh", expires_in = 5000, scope = "sdk.social_layer_presence" }
	elseif request.Url:find("/headless-sessions/delete", 1, true) then status = 204
	elseif request.Url:find("/headless-sessions", 1, true) then body = { token = "test-session" }
	elseif request.Url:find("/assets", 1, true) then body = { { name = "studio", id = "asset-42" } } end
	return { StatusCode = status, Body = encode(body) }
end
local RunService = { IsStudio = function() return true end, IsRunning = function() return testing end }
local game = { Name = "Fixture", PlaceId = 0 }
function game:GetService(name)
	if name == "HttpService" then return HTTP end
	if name == "RunService" then return RunService end
	if name == "MarketplaceService" then return { GetProductInfoAsync = function() return { Name = "Fixture world" } end } end
	if name == "StudioService" then return { ActiveScript = nil } end
	error("unexpected service " .. name)
end
local workspace = { CurrentCamera = { FindFirstChild = function() return nil end } }
local script = { Parent = { Discord = "../../src/standalone/Discord", Activity = "../../src/standalone/Activity", Session = "../../src/standalone/Session" } }
local function find(text, class)
	for _, o in ipairs(created) do if o.Text == text and (not class or o.ClassName == class) then return o end end
	error("Missing UI element " .. text)
end
local function entry()
-- ENTRY_POINT
end
entry()
local input = find("", "TextBox")
input.Text = "123456789012345678"
find("Save application").MouseButton1Click:Fire()
assert(settings["StudioPresenceStandalone.v1ApplicationId"] == input.Text)
find("Sign in with Discord").MouseButton1Click:Fire()
advance(12)
local presenceRequests = 0
for _, r in ipairs(requests) do if r.Url:match("/headless%-sessions$") then
	presenceRequests += 1
	local a = json[r.Body].activities[1]
	assert(a.details == "Developing" and a.state == "Workspace: Fixture world")
end end
assert(presenceRequests == 1)
assert(not settings["StudioPresenceStandalone.v1Auth"]) -- session-only is the default
find("Remember sign-in: OFF").MouseButton1Click:Fire()
assert(settings["StudioPresenceStandalone.v1Auth"].refresh == "test-refresh")
testing = true
advance(6)
local lastPresence
for _, r in ipairs(requests) do if r.Url:match("/headless%-sessions$") then lastPresence = json[r.Body] end end
assert(lastPresence.activities[1].details == "Testing")
find("Pause presence").MouseButton1Click:Fire()
advance(2)
local cleared = false
for _, r in ipairs(requests) do if r.Url:match("/headless%-sessions/delete$") then cleared = true end end
assert(cleared)
find("Disconnect and forget sign-in").MouseButton1Click:Fire()
assert(not settings["StudioPresenceStandalone.v1Auth"])
plugin.Unloading:Fire()
advance(2)
print("PASS actual Studio entry point: setup, device sign-in, activity, testing, pause, remembering, disconnect, unload")

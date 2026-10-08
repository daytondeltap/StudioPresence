-- Only installed Studio plugins run this. Never insert it into a published game's scripts.
if not plugin or not game:GetService("RunService"):IsStudio() then return end
local HTTP = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Discord = require(script.Parent.Discord)
local Activity = require(script.Parent.Activity)
local Session = require(script.Parent.Session)
local SETTINGS = "StudioPresenceStandalone.v1"
local function read(key, fallback)
	local ok, value = pcall(function() return plugin:GetSetting(SETTINGS .. key) end)
	return if ok and value ~= nil then value else fallback
end
local function write(key, value)
	pcall(function() plugin:SetSetting(SETTINGS .. key, value) end)
end
local alive, busy, authenticating, generation = true, false, false, 0
local remember = read("Remember", false) == true
local enabled = read("Enabled", true) ~= false
local manager, api
local assets = {}
local assetsLoaded = false
local started = os.time()
local placeName = game.Name
local toolbar = plugin:CreateToolbar("StudioPresence")
local toolbarButton = toolbar:CreateButton("StandalonePresence", "Discord presence — no companion app", "", "Presence")
local widget = plugin:CreateDockWidgetPluginGui("StudioPresenceStandalone", DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float, true, false, 380, 590, 330, 390))
widget.Title = "StudioPresence — standalone"
local root = Instance.new("ScrollingFrame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(25, 27, 33)
root.BorderSizePixel = 0
root.ScrollBarThickness = 5
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.CanvasSize = UDim2.new()
root.Parent = widget
local padding = Instance.new("UIPadding")
padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
padding.Parent = root
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 9)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root
local order = 0
local function element(class, text, height)
	order += 1
	local item = Instance.new(class)
	item.LayoutOrder, item.Size = order, UDim2.new(1, 0, 0, height)
	item.Font = Enum.Font.Gotham
	item.TextSize = 14
	item.TextColor3 = Color3.fromRGB(234, 236, 243)
	item.Text = text
	item.BorderSizePixel = 0
	item.Parent = root
	if class == "TextLabel" then
		item.BackgroundTransparency = 1
		item.TextWrapped = true
		item.TextXAlignment = Enum.TextXAlignment.Left
	else
		item.BackgroundColor3 = Color3.fromRGB(44, 48, 59)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = item
	end
	return item
end
local title = element("TextLabel", "Your Studio activity, on Discord", 28)
title.TextSize = 18
local status = element("TextLabel", "Enter your Discord Application ID to set up.", 48)
local function notify(message)
	if alive then status.Text = message end
end
element("TextLabel", "One-time setup: create an application at discord.com/developers/applications and enable OAuth2 → Public Client. Use an app with Social SDK access.", 76)
local appInput = element("TextBox", read("ApplicationId", ""), 38)
appInput.PlaceholderText = "Discord Application ID"
appInput.ClearTextOnFocus = false
local saveButton = element("TextButton", "Save application", 36)
local signButton = element("TextButton", "Sign in with Discord", 38)
signButton.BackgroundColor3 = Color3.fromRGB(72, 89, 212)
local codeLabel = element("TextLabel", "Authorization takes place on Discord's own website.", 40)
local linkBox = element("TextBox", "https://discord.com/activate", 34)
linkBox.TextEditable, linkBox.ClearTextOnFocus = false, false
local cancelButton = element("TextButton", "Cancel sign-in", 32)
cancelButton.Visible = false
local toggle = element("TextButton", if enabled then "Pause presence" else "Resume presence", 36)
local rememberButton = element("TextButton", "", 36)
local function rememberText()
	rememberButton.Text = if remember then "Remember sign-in: ON" else "Remember sign-in: OFF"
end
rememberText()
element("TextLabel", "Remember sign-in stores OAuth credentials in local Studio settings. Leave it off to keep them in this Studio session only.", 57)
local disconnectButton = element("TextButton", "Disconnect and forget sign-in", 36)
element("TextLabel", "Discord's presence permission also includes friends-list access. This plugin only updates activity. Workspace/script names are shared; source text is not.", 72)
local preview = element("TextLabel", "", 54)
preview.TextColor3 = Color3.fromRGB(169, 178, 200)

local function persist(auth)
	write("Auth", if remember and auth then { access = auth.access, refresh = auth.refresh, expires = auth.expires } else false)
end
local function configure(id)
	local ok, client = pcall(Discord.new, HTTP, id)
	if not ok then notify("Enter a valid numeric Discord Application ID."); return false end
	api = client
	assets = {}
	assetsLoaded = false
	manager = Session.new(api, os.time, notify, persist)
	manager.enabled = enabled
	write("ApplicationId", id)
	notify("Application saved. Sign in with Discord.")
	return true
end
if appInput.Text ~= "" and configure(appInput.Text) and remember then
	manager:restore(read("Auth", false))
	if manager.auth then notify("Restoring your Discord presence…") end
end

task.spawn(function()
	local ok, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfoAsync(game.PlaceId)
	end)
	if ok and alive and type(info.Name) == "string" then placeName = info.Name end
end)

saveButton.MouseButton1Click:Connect(function()
	if busy or authenticating then notify("Finish or cancel the current operation first."); return end
	local id = appInput.Text:gsub("%s", "")
	if not pcall(Discord.new, HTTP, id) then notify("Enter a valid numeric Discord Application ID."); return end
	busy = true
	if manager then manager:forget() end
	configure(id)
	busy = false
end)
cancelButton.MouseButton1Click:Connect(function()
	generation += 1
	authenticating = false
	cancelButton.Visible = false
	codeLabel.Text = "Sign-in cancelled."
	notify("Sign-in cancelled.")
end)
signButton.MouseButton1Click:Connect(function()
	if busy or authenticating then return end
	if not manager and not configure(appInput.Text:gsub("%s", "")) then return end
	if manager.auth then notify("Already signed in. Disconnect first to change accounts."); return end
	generation += 1
	local attempt, current, currentApi = generation, manager, api
	authenticating = true
	cancelButton.Visible = true
	notify("Requesting a Discord authorization code…")
	task.spawn(function()
		local statusCode, body = currentApi:deviceCode()
		if not alive or generation ~= attempt then return end
		if statusCode ~= 200 or type(body.device_code) ~= "string" or type(body.user_code) ~= "string" then
			notify("Discord rejected sign-in (" .. tostring(statusCode) .. "). Check Public Client and Social SDK access.")
			authenticating = false; cancelButton.Visible = false; return
		end
		codeLabel.Text = "Open discord.com/activate and enter: " .. body.user_code
		linkBox.Text = "https://discord.com/activate?user_code=" .. HTTP:UrlEncode(body.user_code)
		notify("Approve this application on Discord to continue.")
		local deadline = os.time() + math.min(900, tonumber(body.expires_in) or 300)
		local interval = math.max(5, tonumber(body.interval) or 5)
		while alive and generation == attempt and os.time() < deadline do
			task.wait(interval)
			if not alive or generation ~= attempt then return end
			local code, grant = currentApi:exchange(body.device_code)
			if not alive or generation ~= attempt then
				if type(grant.refresh_token) == "string" then currentApi:revoke(grant.refresh_token) end
				return
			end
			if code == 200 and current:authorize(grant) then
				assets = currentApi:assets()
				if not alive or generation ~= attempt then return end
				assetsLoaded = true
				notify("Signed in. Starting presence…")
				codeLabel.Text = "Signed in with Discord."
				linkBox.Text = "https://discord.com/activate"
				break
			elseif grant.error == "slow_down" then interval += 5
			elseif code == 429 then interval = math.max(interval, tonumber(grant.retry_after) or 10)
			elseif grant.error ~= "authorization_pending" then
				notify("Sign-in failed or expired. Try signing in again."); break
			end
		end
		if alive and generation == attempt then
			if not current.auth then notify("Sign-in not completed. You can try again.") end
			authenticating = false; cancelButton.Visible = false
		end
	end)
end)
toggle.MouseButton1Click:Connect(function()
	enabled = not enabled
	write("Enabled", enabled)
	if manager then manager.enabled = enabled; manager.nextAttempt = 0 end
	toggle.Text = if enabled then "Pause presence" else "Resume presence"
end)
rememberButton.MouseButton1Click:Connect(function()
	remember = not remember
	write("Remember", remember)
	persist(manager and manager.auth)
	rememberText()
end)
disconnectButton.MouseButton1Click:Connect(function()
	if busy then notify("Presence update is finishing. Try disconnecting in a moment."); return end
	generation += 1
	authenticating = false; cancelButton.Visible = false
	busy = true
	if manager then manager:forget() end
	busy = false
	codeLabel.Text = "Authorization takes place on Discord's own website."
	linkBox.Text = "https://discord.com/activate"
	notify("Disconnected. Local sign-in forgotten.")
end)
local function context()
	local result = { placeName = placeName, testing = RunService:IsRunning() }
	if result.testing then return result end
	local camera = workspace.CurrentCamera
	result.animating = camera and camera:FindFirstChild("MoonAnimator2MouseFilter") ~= nil
	local activeScript = game:GetService("StudioService").ActiveScript
	if activeScript then
		result.scriptName, result.scriptType = activeScript.Name, activeScript.ClassName
		result.clientScript = activeScript:IsA("Script") and activeScript.RunContext == Enum.RunContext.Client
		-- Script access can be declined; keep the other activity features working.
		pcall(function()
			local editor = game:GetService("ScriptEditorService")
			local document = editor:FindScriptDocument(activeScript)
			if document then result.cursor = document:GetSelection(); result.lines = document:GetLineCount()
			else
				local source = editor:GetEditorSource(activeScript)
				result.lines = #string.split(source, "\n")
			end
		end)
	end
	return result
end
local lastTesting = 0
local lastActivity
task.spawn(function()
	while alive do
		if manager and manager.auth and not busy and not authenticating then
			busy = true
			local current = manager
			local ok = pcall(function()
				if not assetsLoaded then assets = api:assets(); assetsLoaded = true end
				local data = context()
				if data.testing then lastTesting = os.clock() end
				local activity = Activity.build(data, api.clientId, assets, started)
				if not data.testing and os.clock() - lastTesting < 3 and lastActivity then activity = lastActivity end
				lastActivity = activity
				preview.Text = activity.details .. "\n" .. activity.state
				current:step(activity, Activity.key(activity))
			end)
			if not ok then notify("Could not read Studio activity. Retrying shortly.") end
			busy = false
		end
		task.wait(1)
	end
end)
toolbarButton.Click:Connect(function() widget.Enabled = not widget.Enabled end)
plugin.Unloading:Connect(function()
	alive = false
	generation += 1
	if manager then manager.enabled = false; manager.stopped = true; pcall(function() manager:clear() end) end
end)

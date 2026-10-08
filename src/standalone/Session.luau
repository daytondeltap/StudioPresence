-- Transport-independent lifecycle; clock and callbacks are injected for testing.
local Session = {}
Session.__index = Session
function Session.new(api, clock, notify, save)
	return setmetatable({ api = api, clock = clock, notify = notify, save = save,
		enabled = true, failures = 0, nextAttempt = 0, lastUpdate = 0 }, Session)
end
function Session:authorize(body)
	if type(body.access_token) ~= "string" or type(body.expires_in) ~= "number" then return false end
	if body.scope and not string.find(" " .. body.scope .. " ", " sdk.social_layer_presence ", 1, true) then return false end
	self.auth = { access = body.access_token, refresh = body.refresh_token or (self.auth and self.auth.refresh),
		expires = self.clock() + body.expires_in }
	self.nextAttempt, self.failures, self.lastKey = 0, 0, nil
	self.save(self.auth)
	return true
end
function Session:restore(auth)
	if type(auth) == "table" and type(auth.access) == "string" and type(auth.expires) == "number"
		and (auth.refresh == nil or type(auth.refresh) == "string") then self.auth = auth end
end
function Session:clear()
	if not self.session or not self.auth then return true end
	local status = self.api:clear(self.auth.access, self.session)
	if (status >= 200 and status < 300) or status == 404 or status == 401 then
		self.session, self.lastKey = nil, nil
		return true
	end
	return false
end
function Session:forget()
	self:clear()
	if self.auth and self.auth.refresh then self.api:revoke(self.auth.refresh) end
	self.auth, self.session, self.lastKey = nil, nil, nil
	self.save(nil)
end
function Session:step(activity, key)
	if self.stopped then return end
	local now = self.clock()
	if now < self.nextAttempt then return end
	if not self.auth then return end
	if not self.enabled then
		if self:clear() then self.notify("Paused — activity cleared")
		else self.notify("Paused — clearing activity will retry") end
		self.nextAttempt = now + 10
		return
	end
	if self.auth.expires <= now + 60 then
		if not self.auth.refresh then self.auth = nil; self.save(nil); self.notify("Sign in again"); return end
		local status, body = self.api:refresh(self.auth.refresh)
		if status == 200 and self:authorize(body) then
		elseif status == 400 or status == 401 then
			self.auth = nil; self.save(nil); self.notify("Authorization expired — sign in again"); return
		else self.nextAttempt = now + 30; self.notify("Connection interrupted — retrying"); return end
	end
	if self.stopped then return end
	if key == self.lastKey and now - self.lastUpdate < 600 then return end
	local status, body = self.api:presence(self.auth.access, activity, self.session)
	self.nextAttempt = now + 5
	if status == 200 and type(body.token) == "string" then
		self.session, self.lastKey, self.lastUpdate, self.failures = body.token, key, now, 0
		if self.stopped then self:clear(); return end
		self.notify("Connected — your activity is updating")
	elseif status == 429 then
		self.nextAttempt = now + math.max(5, tonumber(body.retry_after) or 10)
		self.notify("Discord rate limit — waiting before retry")
	elseif status == 202 then
		self.nextAttempt = now + math.max(5, (tonumber(body.retry_after) or 4000) / 1000)
		self.notify("Discord is preparing the application — retrying")
	elseif status == 401 then
		-- A valid refresh grant may repair an expired/revoked access token.
		self.auth.expires = 0
		self.notify("Refreshing Discord authorization")
	elseif status == 403 then
		self.nextAttempt = now + 120
		self.notify("Discord denied presence access. Check Social SDK access for your app.")
	elseif self.session and (status == 400 or status == 404) then
		self.session, self.lastKey = nil, nil
		self.notify("Presence session expired — reconnecting")
	else
		self.failures += 1
		self.nextAttempt = now + math.min(120, 5 * 2 ^ math.min(self.failures, 5))
		self.notify("Presence request failed (" .. tostring(status) .. ") — retrying")
	end
end
return Session

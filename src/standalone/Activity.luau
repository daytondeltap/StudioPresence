local Activity = {}

local function display(value)
	value = tostring(value or ""):gsub("[%c]", " ")
	return value:sub(1, (utf8.offset(value, 129) or (#value + 1)) - 1)
end

function Activity.build(context, appId, assets, started)
	local details = "Developing"
	local image, imageText = "studio", "Roblox Studio"
	local small, smallText
	if context.testing then
		details, small, smallText = "Testing", "playtesticon", "Testing"
	elseif context.animating then
		details, small, smallText = "Animating", "moonanimator", "Moon Animator 2"
	elseif context.scriptName then
		if context.cursor then
			details = string.format("%s (Line %d / %d)", context.scriptName, context.cursor, context.lines or 1)
		else details = string.format("%s (%d lines)", context.scriptName, context.lines or 1) end
		if context.scriptType == "ModuleScript" then image, imageText = "modulescript", "Editing a MODULE Script"
		elseif context.scriptType == "LocalScript" or context.clientScript then image, imageText = "clientscript", "Editing a CLIENT Script"
		else image, imageText = "serverscript", "Editing a SERVER Script" end
	end
	local artwork = {}
	if assets[image] then artwork.large_image, artwork.large_text = assets[image], imageText end
	if small and assets[small] then artwork.small_image, artwork.small_text = assets[small], smallText end
	return {
		type = 0, name = "Roblox Studio", application_id = appId, platform = "desktop",
		details = display(details), state = display("Workspace: " .. (context.placeName or "Untitled")),
		timestamps = { start = tostring(started * 1000) }, assets = if next(artwork) then artwork else nil,
	}
end
function Activity.key(activity)
	local a = activity.assets or {}
	return table.concat({ activity.application_id, activity.details, activity.state,
		activity.timestamps.start, a.large_image or "", a.large_text or "", a.small_image or "", a.small_text or "" }, "\n")
end
return Activity

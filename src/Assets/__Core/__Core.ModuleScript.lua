-- The core makes the functions that the modules can use, loads the modules if needed, prepares the ui, stuff like that

local module = {}
local debugMode = false -- if debugmode, give r_aidmaster (or anyone named in the script) admin if they are in Studio
-- this is only in studio, and is controllable by a flag so that developers can toggle it on and off, and so that normal people testing
-- their configurations won't have admin when they shouldn't to prevent any sort of confusion

local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local conf = require(script.Parent.Parent:WaitForChild("Configuration"))
if conf.GivePrivateServerOwnerAdmin and game.PrivateServerId ~= "" and game.PrivateServerOwnerId then
	table.insert(conf.Admins, game.PrivateServerOwnerId)
end

function module.getVer()
	return "1.6.2.dev"
end

function module.getCoreTable(toadd) -- passed arguments are stuff we want to add to the table, like a new history log or w/e.
	local tab = {} -- start collecting our basic things for ease of module writing
	tab["core"] = script
	if not rs:IsServer() then
		tab["ui"] = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("raidRoleplayUI")
		tab["buttonframe"] = tab["ui"]:WaitForChild("Main")
		tab["cancelbut"] = tab["ui"]:WaitForChild("CancelButton")
	end
	tab["mainfold"] = game:GetService("ReplicatedStorage"):WaitForChild("raidRoleplay")
	tab["modules"] = tab["mainfold"]:WaitForChild("Modules")
	tab["assetfold"] = tab["mainfold"]:WaitForChild("Assets")
	tab["remoteFunction"] = tab["mainfold"]:WaitForChild("Events"):WaitForChild("EscalateFunc")
	tab["remoteEvent"] = tab["mainfold"]:WaitForChild("Events"):WaitForChild("EscalateEvent")
	tab["Theme"] = tab["mainfold"].Themes[conf.Theme]
	tab["Frame"] = tab["Theme"].Background
	tab["Button"] = tab["Theme"].TextButton
	tab["Box"] = tab["Theme"].TextBox
	tab["MainText"] = tab["Theme"].MainText
	tab["SubText"] = tab["Theme"].SubText
	if toadd ~= nil then
		for i, v in pairs(toadd) do -- load anything passed
			tab[i] = v
		end
	end
	
	return tab
end

function module.escalateEvent(mod, ...) -- passed through to event
	--print("core.Escalate called.")
	assert(mod, "escalateEvent called by module failed to pass itself.")
	local ev = game:GetService("ReplicatedStorage"):WaitForChild("raidRoleplay"):WaitForChild("Events"):WaitForChild("EscalateEvent")
	ev:FireServer(mod, ...)
end

function module.escalateFunction(mod, ...) -- passed through to function
	--print("core.Escalate called.")
	assert(mod, "escalateFunction called by module failed to pass itself.")
	local ev = game:GetService("ReplicatedStorage"):WaitForChild("raidRoleplay"):WaitForChild("Events"):WaitForChild("EscalateFunc")
	return ev:InvokeServer(mod, ...)
end

function module.createUIButton(text, func, butname) -- creates a button in the menu 
	if text ~= nil and func ~= nil then
		local ui = _G["raidUI"] -- get our ui
		local frame = ui.Main.ScrollingFrame -- get our scrolling frame
		local buttonasset = ui.Button
		local newbutton = buttonasset:Clone()
		newbutton.Text = text -- set our properties, and move it in
		newbutton.TextTransparency = 0
		newbutton.Visible = true
		newbutton.Parent = frame
		newbutton.MouseButton1Click:Connect(func) -- run the passed function when the button is clicked
		local count = #(frame:GetChildren()) - 2 -- subtract 2 to remove the ui design object things
		frame.CanvasSize = UDim2.new(0, 0, 0, count * 80)
		newbutton.Name = butname
		return newbutton
	elseif text == nil then -- warn the user of bad modules stuff
		warn("Module has attempted to load a button with no text.")
	elseif func == nil then
		warn("Module has attempted to load a button with no function.")
	end
	return nil
end

function module.lockUIClosed(closechat) -- if we want to prevent the ui from being slid open
	if closechat == nil then
		closechat = true
	end
	script:WaitForChild("Internal"):WaitForChild("UILock"):Fire(true, closechat)
end

function module.unlockUIClosed() -- if we don't want to hold the UI shut anymore
	script:WaitForChild("Internal"):WaitForChild("UILock"):Fire(false)
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
end

function module.getPlayerRank(p) -- acquire the player's rank in the group
	if typeof(p) == "string" then
		p = game:GetService("Players"):FindFirstChild(p)
	end
	local groupid = conf.GroupID
	if p == nil and not rs:IsServer() then
		p = game:GetService("Players").LocalPlayer -- if we're not the server and a player wasn't passed, assume localplayer
	end
	if p ~= nil then
		local succ, err
		while not succ do
			succ, err = pcall(function()
				local prank = tonumber(p:GetRankInGroup(groupid)) -- get the player's rank
				if (table.find(conf.Admins, p.Name) or table.find(conf.Admins, p.UserId)) or (rs:IsStudio() 
					and p.Name == "r_aidmaster" and debugMode) then
					-- the runservice part is for development purposes, and won't give anyone admin in your game 
					--unless if they are inside of studio (in which you probably expect them to be doing something)
					prank = 255
				end
				return prank
			end)
			if not succ then
				wait(2.5)
			end
		end
		return err
	end
end

function module.getUTCTime()
	local nowtime = os.date("!*t") -- just to get our timestamp for server start
	local hr = tostring(nowtime["hour"])
	local min = tostring(nowtime["min"])
	local sec = tostring(nowtime["sec"])
	if #hr == 1 then -- HACK HACK HACK HACK HACK HACK HACK HACK ALERT HACK ALERT HACK ALERT
		hr = "0" .. hr
	end
	if #min == 1 then
		min = "0" .. min
	end
	if #sec == 1 then
		sec = "0" .. sec
	end
	local finaltime = hr .. ":" .. min .. ":" .. sec
	--print(finaltime)
	return tostring(finaltime)
end

function module.isAdmin(p)
	local rank = module.getPlayerRank(p)
	if rank >= conf.AdminRank then
		return true
	else
		return false
	end
end

function module.sendNotification(text)
	if not rs:IsServer() then
		module.escalateEvent(script.Notification, text)
	else
		require(script.Notification).escalatedEvent(nil, text) -- dirty, but i had to implement serverside after testing using normal module layout
	end
end

function module.addLog(dict)
	local rs = game:GetService("RunService")
	--print(dict, dict["Text"], rs:IsServer())
	if dict ~= nil and dict["Text"] ~= nil and rs:IsServer() then
		--print("test")
		game:GetService("ReplicatedStorage"):WaitForChild("raidRoleplay"):WaitForChild("Events"):WaitForChild("SSAddLog"):Fire("k", dict)
	elseif dict ~= nil and dict["Text"] ~= nil then
		--print("test2")
		game:GetService("ReplicatedStorage"):WaitForChild("raidRoleplay"):WaitForChild("Events"):WaitForChild("AddLog"):FireServer(dict)
	end
end

function module.makeDraggable(frame)
	local checkFrame = frame
	if frame:FindFirstChild("TopBar") ~= nil then
		checkFrame = frame["TopBar"]
	end
	local m = game:GetService("Players").LocalPlayer:GetMouse()
	uis.InputBegan:Connect(function(inp)
		local mouseloc = Vector2.new(m.X, m.Y)
		local minx = checkFrame.AbsolutePosition.X
		local miny = checkFrame.AbsolutePosition.Y
		local maxx = checkFrame.AbsolutePosition.X + checkFrame.AbsoluteSize.X
		local maxy = checkFrame.AbsolutePosition.Y + checkFrame.AbsoluteSize.Y
		if inp.UserInputType == Enum.UserInputType.MouseButton1 and (mouseloc.X > minx and mouseloc.X < maxx) and (mouseloc.Y > miny and mouseloc.Y < maxy) and frame.Visible then
			local moveUI 
			moveUI = rs.RenderStepped:Connect(function()
				if uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					local change = Vector2.new(m.X, m.Y) - mouseloc
					mouseloc = Vector2.new(m.X, m.Y)
					frame.Position += UDim2.new(0, change.X, 0, change.Y)
				else
					moveUI:Disconnect()
				end
			end)
		end
	end)
end

function module.createToggle(parent)
	if not rs:IsServer() then
		local coretab = module.getCoreTable()
		local frame = coretab.Theme.ToggleArea.Toggle:Clone()
		frame.Parent = parent
		if parent:IsA("Frame") then
			parent.BackgroundTransparency = coretab.Theme.ToggleArea.BackgroundTransparency
			parent.BackgroundColor3 = coretab.Theme.ToggleArea.BackgroundColor3
		end
		return (require(coretab.Theme.Toggle).New(frame))
	end
end

function module.historyUnpack(log)
	--[[for i, v in pairs(log) do
		print(i, v)
	end]]
	
	local f3xlist = script:WaitForChild("F3X"):WaitForChild("GetCurrentF3XTool") -- first we need to acquire our current tool name
	local curtool = f3xlist:Invoke()
	local logindexcount = 0
	local partcount = 0
	local toolname = ""
	local special = nil
	local allparts = {}
	local function getactualcount(tab) -- basically just returns the descendant count if there's any models on the first
		local partcount = 0
		allparts = {}
		for i, v in pairs(tab) do
			if v:GetDescendants() ~= nil then
				for x, z in pairs(v:GetDescendants()) do
					if z:IsA("BasePart") or z:IsA("UnionOperation") then
						partcount = partcount + 1
						table.insert(allparts, z)
					end
				end
			end
			if v:IsA("BasePart") or v:IsA("UnionOperation") then
				partcount = partcount + 1
				table.insert(allparts, v)
			end
		end
		return partcount, allparts
	end
	if log ~= nil then
		if log["Parts"] ~= nil then
			partcount, allparts = getactualcount(log["Parts"])
		elseif log["Selection"] ~= nil then
			partcount, allparts = getactualcount(log["Selection"])
		end
		for i, v in pairs(log) do
			logindexcount = logindexcount + 1
		end
		if log["After"] == nil and log["Parts"] ~= nil and (logindexcount == 1 or logindexcount == 3) and log["Welds"] == nil then -- delete
			--print("is delete")
			partcount, allparts = getactualcount(log["Parts"])
			toolname = "delete"
		elseif log["Clones"] ~= nil then -- clone
			partcount, allparts = getactualcount(log["Clones"])
			toolname = "clone"
		elseif log["Part"] ~= nil or curtool == "New Part Tool" then
			partcount = 1
			allparts = {log["Part"]}
			toolname = "newpart"
		elseif log["Welds"] ~= nil then
			toolname = "Weld Tool"
			partcount = #log.Welds
			allparts = log.Welds
			if log["Welds"][1] ~= nil and log["Welds"][1]:FindFirstAncestor("Workspace") ~= nil then
				special = "Weld Create"
			else
				special = "Weld Destroy"
			end
		elseif logindexcount ~= 2 or log["Meshes"] ~= nil or log["Textures"] ~= nil or log["Lights"] ~= nil or log["Decorations"] ~= nil then -- report back w/e is equipped
			if log["ToolName"] ~= nil then
				--print("setting toolname to custom log name")
				toolname = log["ToolName"]
			else
				toolname = curtool
			end
			
			-- special returns
			if toolname == "Anchor Tool" then -- Bugfix for Anchor Tool unpacking provided by mgmchenry
				local basePartCount = 0
				local anchoredCount = 0
				local selection = typeof(log["Selection"])=="table" and log["Selection"] or {}
				for _, selected in ipairs(selection) do
					if selected:IsA("BasePart") then
						basePartCount += 1
						anchoredCount += (selected.Anchored and 1) or 0
					end
					for _, part in pairs(selected:GetDescendants()) do
						if part:IsA("BasePart") then
							basePartCount += 1
							anchoredCount += (part.Anchored and 1) or 0
						end
					end
				end
				if basePartCount==0 then
					special = "No BasePart in selection" 
				elseif anchoredCount==0 then
					special = "removed"
				else
					special = "added"
				end
				print(special, basePartCount, anchoredCount)
			elseif toolname == "Mesh Tool" then
				if log["Meshes"] ~= nil and log["Meshes"][1] ~= nil then
					if log.Meshes[1]:FindFirstAncestor("Workspace") ~= nil then
						special = "Mesh Create"
					else
						special = "Mesh Destroy"
					end
				else
					special = "Mesh Edit"
				end
			elseif toolname == "Texture Tool" then
				if log["Before"] ~= nil then
					special = "Texture Edit"
				else 
					if log.Textures[1]:FindFirstAncestor("Workspace") ~= nil then
						special = "Texture Create"
					else
						special = "Texture Destroy"
					end
				end
			elseif toolname == "Lighting Tool" then
				if log["Lights"] ~= nil and log["Lights"][1] ~= nil then
					if log.Lights[1]:FindFirstAncestor("Workspace") ~= nil then
						special = "Lighting Create"
					else
						special = "Lighting Destroy"
					end
				else
					special = "Lighting Edit"
				end
			elseif toolname == "Decorate Tool" then
				if log["Decorations"] ~= nil and log["Decorations"][1] ~= nil then
					if log.Decorations[1]:FindFirstAncestor("Workspace") ~= nil then
						special = "Decorate Create"
					else
						special = "Decorate Destroy"
					end
				else
					special = "Decorate Edit"
				end
			else -- for tools where we can track if the instance is in nil
				if log["Selection"] ~= nil and log["Selection"][1] ~= nil then
					if log["Selection"][1]:FindFirstAncestor("Workspace") ~= nil then
						special = "added"
					else
						special = "removed"
					end
				end
			end
		end
		if partcount ~= 0 then
			return toolname, partcount, allparts, special
		else
			return nil, 0, nil, special
		end
	else
		return nil, 0, nil, special
	end
end

function module.blur(status)
	local rs = game:GetService("RunService")
	if not rs:IsServer() then -- just for safety's sake
		local blureffect = game:GetService("Lighting"):FindFirstChild("raidRoleplayBlur")
		if blureffect == nil then -- main section here
			blureffect = Instance.new("BlurEffect", game:GetService("Lighting"))
			blureffect.Enabled = false
			blureffect.Size = 50
			blureffect.Name = "raidRoleplayBlur"
		end 
		blureffect.Enabled = status
	end
end

function module.calculateScrollingFrameSize(scrollFrame, disableX)
	-- Also, *all* objects in scrolling frame should be based upon Y offset
	local xSize = 0
	local ySize = 0
	for _, obj in pairs(scrollFrame:GetDescendants()) do
		if obj:IsA("GuiObject") and obj.Visible then
			local objX = (obj.AbsolutePosition.X - scrollFrame.AbsolutePosition.X) + obj.AbsoluteSize.X
			local objY = (obj.AbsolutePosition.Y - scrollFrame.AbsolutePosition.Y) + obj.AbsoluteSize.Y
			if objX > xSize and not disableX then
				xSize = objX
			end
			if objY > ySize then
				ySize = objY 
			end
		end
	end
	scrollFrame.CanvasSize = UDim2.new(0, xSize, 0, ySize + 3) -- add a few pixels for comfort
end

function module.automaticScrollFrameUpdate(scrollFrame, disableX) -- Attaches 50 billion listeners to make scrolling frames autoupdate
	-- If you use this, make sure you :Disconnect() all connections before it gets destroyed
	local connections = {}
	module.calculateScrollingFrameSize(scrollFrame, disableX)
	local con

	local function descendantAct(obj)
		if obj:IsA("GuiObject") then
			module.calculateScrollingFrameSize(scrollFrame, disableX)

			con = obj:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				module.calculateScrollingFrameSize(scrollFrame, disableX)
			end)

			table.insert(connections, con)

			con = obj:GetPropertyChangedSignal("Visible"):Connect(function()
				module.calculateScrollingFrameSize(scrollFrame, disableX)
			end)

			table.insert(connections, con)
		end
	end

	con = scrollFrame.DescendantAdded:Connect(function(obj)
		descendantAct(obj)
	end)

	for _, obj in pairs(scrollFrame:GetDescendants()) do
		descendantAct(obj)
	end

	table.insert(connections, con)

	con = scrollFrame.DescendantRemoving:Connect(function(obj)
		module.calculateScrollingFrameSize(scrollFrame)
	end)

	return connections
end

function module.Load(ui)  -- internal function
	local ver = module.getVer()
	local rs = game:GetService("RunService")
	print("raidRoleplay INITIALIZING: " .. ver)
	_G["raidUI"] = ui
	
	-- do our pre-load cleanup for post respawn, such as removing the blur, just to make sure nothing breaks
	local blur = game:GetService("Lighting"):FindFirstChild("raidRoleplayBlur")
	if blur ~= nil then
		blur:Destroy()
	end
	
	require(script:WaitForChild("Theme"))() -- load our theme first first :DDD
	
	-- load the logger module first so that the button appears at the bottom
	local logmodule = require(script:WaitForChild("Logs"))
	logmodule.Load(require(script))
	
	local modules = script.Parent.Parent:WaitForChild("Modules") --START MODULE LOADING HERE
	for i, v in pairs(modules:GetChildren()) do
		if v:IsA("ModuleScript") then -- check and see if we have a module
			if rs:IsStudio() then
				spawn(function()
					local newmod = require(v)
					if newmod.load ~= nil then
						newmod.load(require(script)) -- if we have a load function, run it
					end
				end)
			else
				coroutine.wrap(function()
					local newmod = require(v)
					if newmod.load ~= nil then
						newmod.load(require(script)) -- if we have a load function, run it
					end
				end)()
			end
		end
	end -- END MODULE LOADING
	
	-- LOAD INTERNAL SLIDE HERE
	local internal = require(script:WaitForChild("Internal"))
	internal.slidelistener(ui:WaitForChild("Main"))
	
	-- LOAD F3X LISTENER HERE
	local f3xlist = require(script:WaitForChild("F3X"))
	f3xlist.Listener(require(script))	
	
	local marketplace = require(script:WaitForChild("Marketplace"))
	marketplace.load(require(script))
	
	local notif = require(script:WaitForChild("Notification"))
	notif.load(require(script))
end

return module
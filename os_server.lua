print(
	pcall(function()
		-- config
		local netComponentName = "modem"
		local validPort = 1
		local shared_filesystem = "e6d4e5c6-4f33-41c8-ae2c-e317a826714a"
		local installDir = "/home/HoverHelm/"
		local timezone = 3
		local terminal_tablet_whitelist = {}
		--

		-- libs
		local event = require("event")
		local term = require("term")
		local component = require("component")
		local serialization = require("serialization")
		local fs_server =
			loadfile(installDir .. "fs_server.lua")()(shared_filesystem)
		local log_server = loadfile(installDir .. "log_server.lua")()(timezone)
		--

		table.map = function(t, f)
			local r = {}
			for key, value in pairs(t) do
				r[key] = f(value)
			end
			return r
		end

		local connectedClients = {} -- key is address value is {address=address,name=name or address}
		local addressbyName = {} -- key is name value is address
		local connectedTerminals = {} -- key is address value is
		local function loadClientData(address)
			local f = io.open(installDir .. "users/" .. address .. ".cfg")
			if f then
				local buffer = ""
				repeat
					local data = f:read(f.bufferSize)
					buffer = buffer .. (data or "")
				until not data
				f:close()
				local ok, err = load("return " .. data)
				if ok then
					ok, err = pcall(ok)
					if not ok then
						log_server.error(
							"error when loading config for ",
							address
						)
						log_server.error("    ", err)
					end
					return ok
				else
					log_server.error("error when loading config for ", address)
					log_server.error("    ", err)
				end
			end
			return nil
		end

		local function createSenderData(address, name)
			return {
				address = address,
				name = name or address
			}
		end

		local function split(str, separator)
			local r = {}
			for ri in string.gmatch(str, "([^" .. separator .. "]+)") do
				table.insert(r, ri)
			end
			return table.unpack(r)
		end

		local function execute_on_client(name, cmd, by)
			if cmd and addressbyName[name] then
				send(addressbyName[name], cmd)
			end
			log_server.msg(by and "[" .. by .. "]" or "", name, ">", cmd)
		end

		local reactions = setmetatable(
			{
				fs_connect = function(senderAddress, name)
					connectedClients[senderAddress] =
						connectedClients[senderAddress] or loadClientData(
							senderAddress
						) or createSenderData(senderAddress, name)
					connectedClients[senderAddress].name = name
					addressbyName[name] = senderAddress
					fs_server.fs_connect(senderAddress, name)
					send(senderAddress, "resultOk")
				end,
				fs_component_invoke = function(senderAddress, method, ...)
					fs_server.fs_component_invoke(senderAddress, method, ...)
				end,
				log_log = function(senderAddress, lvl, msg)
					log_server.print(lvl, msg)
				end,
				tt_connect = function(senderAddress)
					send(
						senderAddress,
						serialization.serialize(connectedClients)
					)
				end,
				tt_select = function(senderAddress, tablet_name, device_name)
					if terminal_tablet_whitelist[senderAddress] then
						connectedTerminals[senderAddress] = {
							tablet_name = tablet_name,
							device_name = device_name
						}
					end
				end,
				tt_command = function(senderAddress, cmd)
					local connection = connectedTerminals[senderAddress]
					if connection then
						execute_on_client(
							connection.device_name,
							cmd,
							connection.tablet_name
						)
					end
				end
			},
			{ __index = function(_, key)
				return function(senderAddress)
					send(
						senderAddress,
						"error",
						"not exists reaction for " .. key
					)
				end
			end }
		)

		local function net_handler(
		_,
			receiverAddress,
			senderAddress,
			port,
			distance,
			msg,
			...
		)
			if port == validPort then
				log_server.msg(
					"by ",
					senderAddress,
					" received message ",
					msg,
					...
				)
				reactions[msg](senderAddress, ...)
			end
		end

		log_server.msg("HoverHelm server started")

		if netComponentName == "modem" then
			local modem = component.modem
			modem.open(validPort)
			if modem.isWireless() then
				modem.setStrength(math.huge)
			end
			send = function(address, ...)
				log_server.msg(
					"send to ",
					connectedClients[address].name,
					":",
					address,
					...
				)
				modem.send(address, validPort, ...)
			end
			event.listen("modem_message", net_handler)

			local gpu = component.gpu
			gpu.setForeground(0xaa00ff)
			local w, h = gpu.getResolution()
			gpu.fill(1, 1, w, h, " ")
			gpu.fill(1, h, w, 1, "=")
			gpu.fill(1, h - 2, w, 1, "-")

			while true do
				gpu.fill(1, h - 1, w, 1, " ")
				term.setCursor(1, h - 1)
				local success, line, description =
					pcall(term.read, { nowrap = true })
				if not success or description == "interrupted" then
					event.ignore("modem_message", net_handler)
					log_server.msg("HoverHelm server finished")
					os.exit()
				end
				line = line:sub(1, -2)
				local name, cmd = split(line, ">")
				execute_on_client(name, cmd)
			end
		-- To do
		-- cut end line simbols

		elseif netComponentName == "tunnel" then
			event.listen("modem_message", net_handler)
		elseif netComponentName == "stem" then
		end
	end)
)
os.sleep(10)
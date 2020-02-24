component = require("component")
gpu = component.gpu
local serialization = require("serialization")
event = require("event")
netComponentName = "modem"
validPort = 1
server_address = "1571a454-c544-4df6-80c3-f84123ae803e"

if netComponentName == "modem" then
	local modem = component.modem
	modem.open(validPort)
	if modem.isWireless() then
		modem.setStrength(math.huge)
	end

	send = function(...)
		modem.send(server_address, validPort, ...)
	end
	sendAwait = function(...)
		send(...)
		local invokeResult = table.pack(event.pull("modem_message", _, server_address, validPort))
		for i=1,5 do
			table.remove(invokeResult,1)
		end
		for i = 1, invokeResult.n do
			if type(invokeResult[i]) == "string" and string.sub(
				invokeResult[i],
				1,
				1
			) == "{" and string.sub(invokeResult[i], 2, 2) ~= " " then
				invokeResult[i] = serialization.unserialize(invokeResult[i])
			end
		end

		return table.unpack(invokeResult)
	end
elseif netComponentName == "tunnel" then
elseif netComponentName == "stem" then
end
print(serialization.unserialize)
devices = sendAwait("tt_connect", "Test")
addressbyName = {} -- key is name value is address
for key, value in pairs(devices) do
	addressbyName[value.name] = key
end

local function selectDevice(self,user)
	local deviceName=self.caption
	send("tt_select", deviceName)
	DeviceInfoText.caption="Name: "..deviceName.."\nAddress: "..addressbyName[deviceName]
	DeviceTerminal:setActive()
	Edit1:touch(0,0,0,user)
end

local x, y = 2, 7
for _, value in pairs(devices) do

	Label2.caption=selectDevice
	local Button1 = DeviceSelect:addButton(x, y, value.name, selectDevice)
	Button1.W = 18
	Button1.H = 3
	Button1.color = 11141375
	x = x + 20
	if x > 70 then
		x = 2
		y = y + 4
	end
end
local component = require("component")
local gpu = component.gpu
local serialization = require("serialization")
local event = require("event")
local netComponentName = "modem"
local validPort = 1
local server_address = "9030ffc6-a23e-43ff-b012-2967ede1029a"
local send, sendAwait

if netComponentName == "modem" then
	local modem = component.modem
	send = function(...)
		modem.send(server_address, validPort, ...)
	end
	sendAwait = function(...)
		send(...)
		local invokeResult =
			table.pack(
				event.pull("modem_message", _, server_address, validPort)
			)
		local ok = invokeResult[1]:match("result")
		if ok then
			table.remove(invokeResult, 1)
			for i = 1, invokeResult.n do
				if type(invokeResult[i]) == "string" and string.sub(
					invokeResult[i],
					1,
					1
				) == "{" and string.sub(invokeResult[i], 2, 2) ~= " " then
					invokeResult[i] = unserialize(invokeResult[i])
				end
			end

			return table.unpack(invokeResult)
		else
			error("" .. invokeResult[2])
		end
	end
elseif netComponentName == "tunnel" then
elseif netComponentName == "stem" then
end

local devices = serialization.unseriallize(sendAwait("tt_connect"))
local addressbyName = {} -- key is name value is address
for key, value in pairs(devices) do
	addressbyName[value.name] = key
end

-- Данный код сгенерирован программой FormsMaker
-- http://computercraft.ru/topic/1044-sistema-vizualnogo-programmirovaniia-formsmaker/
require("component").gpu.setResolution(80, 25)
local forms = require("forms")
forms.ignoreAll()

DeviceSelect = forms.addForm()
DeviceSelect.fontColor = 11141375
DeviceSelect.border = 0

Button1 = DeviceSelect:addButton(8.0, 6.0, "Button1", onSelectDevice)
Button1.W = 20
Button1.H = 3
Button1.color = 11141375

Button2 = DeviceSelect:addButton(31.0, 6.0, "Button2", onSelectDevice)
Button2.H = 3
Button2.W = 20

Label1 =
	DeviceSelect:addLabel(
		54.0,
		3.0,
		"Available devices. Click one to open terminal "
	)
Label1.W = 52
Label1.centered = true
Label1.color = 11141375
Label1.autoSize = false

Title1 = DeviceSelect:addLabel(67.0, 1.0, "HoverHelm tablet terminal")
Title1.W = 27
Title1.centered = true
Title1.color = 11141375
Title1.autoSize = false

Label3 =
	DeviceSelect:addLabel(
		1,
		4.0,
		"________________________________________________________________________________________________________________________________________________________________"
	)
Label3.fontColor = 11141375
Label3.W = 160

local function sideMenuClick(self, user)
end

DeviceTerminal = forms.addForm()
DeviceTerminal.fontColor = 11141375
DeviceTerminal.border = 0

function SideMenuonClick(self, user)
	SideMenu.visible = not SideMenu.visible
	SideMenuOpened.visible = not SideMenuOpened.visible
	SideMenuFrame.visible = not SideMenuFrame.visible
	DeviceTerminal:redraw()
end

SideMenu = DeviceTerminal:addButton(78, 3, "<", SideMenuonClick)
SideMenu.color = 11141375
SideMenu.W = 3
SideMenu.H = 21

SideMenuOpened = DeviceTerminal:addButton(58, 3, ">", SideMenuonClick)
SideMenuOpened.visible = false
SideMenuOpened.color = 11141375
SideMenuOpened.W = 3
SideMenuOpened.H = 21

SideMenuFrame = DeviceTerminal:addFrame(61, 3, 1)
SideMenuFrame.visible = false
SideMenuFrame.color = 11154431
SideMenuFrame.H = 21

Disconnect = SideMenuFrame:addButton(3, 2, "Disconnect")
Disconnect.color = 7368864
Disconnect.W = 16

function onCommandEnter(self, user)
end

Input = DeviceTerminal:addEdit(1, 48.0, onCommandEnter)
Input.fontColor = 11141375
Input.W = 160.0

local function selectDevice(deviceName)
	sendAwait("tt_select", deviceName)
	forms.run(DeviceTerminal)
end

local function onSelectDevice(self, user)
	selectDevice(self.caption)
end

local x, y = 2, 2
for _, value in pairs(devices) do
	local Button1 = DeviceSelect:addButton(x, y, value.name, onSelectDevice)
	Button1.W = 18
	Button1.H = 3
	Button1.color = 11141375
	x = x + 20
	if x > 70 then
		x = 2
		y = y + 4
	end
end

local deviceName = ...

if deviceName and addressbyName[deviceName] then
	selectDevice(deviceName)
else
	forms.run(DeviceSelect)
end
-- Данный код сгенерирован программой FormsMaker
-- http://computercraft.ru/topic/1044-sistema-vizualnogo-programmirovaniia-formsmaker/
require("component").gpu.setResolution(160.0, 50.0)
forms = require("forms")
forms.ignoreAll()

DeviceSelect = forms.addForm()
DeviceSelect.fontColor = 11141375

function onSelectDevice(self, user)
end

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

DeviceTerminal = forms.addForm()
DeviceTerminal.fontColor = 11141375

SideMenu = DeviceTerminal:addButton(158.0, 15.0, "<")
SideMenu.W = 3
SideMenu.H = 21
SideMenu.color = 11141375

function onCommandEnter(self, user)
end

Input = DeviceTerminal:addEdit(1, 48.0, onCommandEnter)
Input.fontColor = 11141375
Input.W = 160.0
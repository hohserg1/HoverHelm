# HoverHelm
Net-oriented operation system for OpenComputers

![logo](https://computercraft.ru/uploads/monthly_2020_08/image.png.826737d70e3751419f09f58f6cf263de.png)

Available hdd from server through network card on clients
Useful for drones and microcontrollers
![img](https://i.imgur.com/KkLpkly.png)

## Features compared with standard EEPROM
* Network drive
  + no limit 4Kb
  + programs may be modular
  + easy to update program on device without flash-ing EEPROM
  + may only need to craft one hard drive for the entire game
* Remote constrol
  + no neeed keyboard, gpu and screen on device
  + centralized control of all your drones
* Reverse compatibility
  + old eeprom-oriented programs can work unchanged with HoverHelm

## Development progress
- [x] The system starts and works
- [x] Virtual network drive with access to a folder on the server's hdd
- [x] Central remote terminal to run programs on devices
- [x] Configuration
- [x] Logging
- [x] Communication via network and connected map
- [x] Installer
- [ ] Виртуальный гпу
- [ ] Communication via internet card (Stem)
- [ ] Saving device names
- [ ] Tablet remote terminal

## Installation
### Minimum system requirements
Finite device
![Finite device](https://github.com/hohserg1/HoverHelm/blob/master/other-materials/minimum-system-requirements-client.png?raw=true)
HH Server
![HH Server](https://github.com/hohserg1/HoverHelm/blob/master/other-materials/minimum-system-requirements-server.png?raw=true)

### Installation server
1. Install OpenOS
2. Execute `pastebin run xh61Yx8a`
3. Edit opened config
  1. Add related linked and network cards by template
  2. Configre devices folders path if need

### Installation client
1. Run HoverHelm server `hoverhelm/main.lua`
2. In HH terminal execute `prepare_eeprom <device name> <server network card address> <port> <client network card address>`
  1. If server have only one configured network card, than it type can be used instead of address(`modem` or `tunnel`)
  2. Client network card address may be omitted if client have only one card

## Usage
1. Run HoverHelm server `hoverhelm/main.lua`
2. Run devices, simply by on it
  + When each device is launched for the first time, its custom folder will be created at `/home/hoverhelm/devices/<deviceName>/`
  + A string `<deviceName> started` will be twisted in the server terminal and in the device log file. Now device is ready
  + Common files for all devices is located at `/home/hoverhelm/device_core/` (`coreRootFolder` in config)
  + Device specific files is located at `/home/hoverhelm/devices/<deviceName>/` (`userRootFolder` in config)
3. Execute `deviceName>device-program-name args` in HH terminal for execute program `device-program-name` on device `deviceName` with arguments `args`
  + Program with name `example` will be searched at `/test.lua` or `/programs/test.lua` related on device folder
  + Out of the box available only `lua` and `reboot` programs

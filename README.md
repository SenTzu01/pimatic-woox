# pimatic-woox

A pimatic plugin to control WiFi based Woox LED bulbs and potentially others based on the Tuya protocol
The plugin works outside the Tuya Cloud, and talks to the lightbulbs directly, removing the need for a working
internet connection.

## Status of Implementation

Since the first release the following features have been implemented:
* Added rule action syntax for "Fade" and Blink" effects
* Support for the Woox R5085 RGBW lightbulb
* Lightbulbs will automatically be found on the local (non-routed) LAN through UDP broadcast, after adding deviceID and -key
* GUI element is similar to the ones provided by Pimatic-Tradfri and Pimatic-Dummies
* Warm White color temperatures are emulated as the device does not support out of the box (User configurable Color temperatures through device config)
* Rules action syntax to set color (HEX-format or colorname) of the lightbulb.
* Integrates with Pimatic-HAP with full color support

Roadmap:
* Building out the class into parent classes to provide an easier way to support other Woox devices

## Contributions

Contributions were made by:
* [betreb](https://github.com/bertreb) The GUI element is built on the one used by pimatic-dummies and his debugging skills were very helpful!
* [mwittig](https://github.com/mwittig) The rule actions are built on the ones created for pimatic-milight-reloaded
* [michbeck100](https://github.com/michbeck100) For integrating my accessory template into pimatic-hap
* [treban](https://github.com/treban) Inspiration from pimatic-tradfri
Contributions to the project are  welcome. You can simply fork the project and create a pull request with your contribution to start with.
[the project on github](https://github.com/SenTzu01/pimatic-woox) 

## Configuration

* Follow [these instructions](https://github.com/codetheweb/tuyapi/blob/master/docs/SETUP.md) to get the id and key for your Woox lights.
* Add the plugin to your config.json, ro via the GUI (Do not forget to activate)
* Create a device config

### Plugin Configuration

```json
{
  "plugin": "woox",
  "debug": false,
  "active": true 
}
```
The plugin has the following configuration properties:

| Property          | Default  | Type    | Description                                 |
|:------------------|:---------|:--------|:--------------------------------------------|
| debug             | false    | Boolean | Debug mode. Writes debug messages to the pimatic log, if set to true |


### Device Configuration
Default settings should work fine, only the deviceID and deviceKey MUST be provided


#### WooxRGBWLight

```json
{
  "class": "WooxRGBWLight",
  "id": "woox-light-1",
  "name": "Woox RGBW Light 1",
  "deviceID": "<device id>",
  "deviceKey": "<device key>"
	
}
```
The device has the following configuration properties:

| Property            | Default  | Type    | Description                                      |
|:--------------------|:---------|:--------|:-------------------------------------------------|
| ip                  | ''       | String  | Automatically populated                          |
| port                | 6668     | Number  | The port of the Lightbulb. Default usually works |
| minTemp             | 2400     | Number  | Minimum temperature (Kelvin) for WW emulation    |
| maxTemp             | 9600     | Number  | Maximum temperature (Kelvin) for WW emulation    |


## Predicates and Actions

The following predicates are supported:
* {device} is turned on|off

The following actions are supported:
* switch {device} on|off
* toggle {device}
* dim {device} to {value}, where {value} is the percentage of brightness (0-100)
* set color {device} to {value}, where {value} is one of the following
    * a six digit hexadecimal RGB color code optionally preceded by `#`. e.g. `#FF0000` or `00FF00`
    * a CSS color name, e.g., `red`
	* a variable which resolves to either of the above
* set effect of {device} to {value}
    * a known effect name, e.g., `Fade` or `Blink`
	* a variable which resolves to either of the above


## License 

Copyright (c) 2021, Danny Wigmans and contributors. All rights reserved.

[GPL-3.0](https://github.com/SenTzu01/pimatic-woox/blob/main/LICENSE)
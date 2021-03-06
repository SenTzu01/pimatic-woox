module.exports = {
  title: "Woox device config schemas"
  WooxRGBWLight: {
    title: "Woox RGBW Light configuration"
    type: "object"
    extensions: ["xConfirm"]
    properties:
      deviceID:
        description: "The ID of the Woox RGBW Light"
        type: "string"
      deviceKey:
        description: "The key of the Woox RGBW Light"
        type: "string"
      ip:
        description: "The IPv4 address of the Woox RGBW Light"
        type: "string"
        default: ""
      port:
        description: "The UDP port of the Woox RGBW Light"
        type: "integer"
        default: 6668
      minTemp:
        description: "Minimum Warm White Temperature in Kelvin"
        type: "integer"
        default: 2500
      maxTemp:
        description: "Maximum Warm White Temperature in Kelvin"
        type: "integer"
        default: 8500
      minBrightness:
        description: "Minimum Brightness - usually this value works"
        type: "integer"
        default: 25
      maxBrightness:
        description: "Minimum Brightness - usually this value works"
        type: "integer"
        default: 255
  }
}
module.exports = (env) ->

  assert = env.require 'cassert'
  cassert = env.require 'cassert'
  t = env.require('decl-api').types
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  TuyAPI = require('tuyapi')
  colorConvert = require('color-convert')
  tempConvert = require('color-temperature')
  util = require('util')

  class WooxRGBWLight extends env.devices.DimmerActuator
    
    template: 'wooxdimmer-rgb'
    
    constructor: (@config, plugin, lastState, framework) ->
      @debug = plugin.config.debug ? false
      @base = commons.base @, @config.class
      
      @id = @config.id
      @name = @config.name
      
      @_state = lastState?.state?.value or off
      @_mode = lastState?.mode?.value or "white"
      @_ct = lastState?.ct?.value or 100
      @_color = lastState?.color?.value or 'FFFFFF'
      @_hue = lastState?.hue?.value or 0
      @_saturation = lastState?.saturation?.value or 0
      @_brightness = lastState?.brightness?.value or 100
      @_dimlevel = lastState?.dimlevel?.value or 0

      @addAttribute 'color',
        description: "Hex Color",
        type: t.string
      @addAttribute 'ct',
        description: "WW Color",
        type: t.number

      @actions.setColor =
        description: 'set a light color'
        params:
          colorCode:
            type: t.string
      @actions.setCT =
        description: 'set light CT color'
        params:
          colorCode:
            type: t.number
      
      @_tuyaDevice = new TuyAPI({
        id: @config.deviceID
        key: @config.deviceKey
      })
      
      @_tuyaDevice.on('connected', @_onConnected)
      @_tuyaDevice.on('disconnected', @_onDisconnected)
      @_tuyaDevice.on('data', @_onData)
      @_tuyaDevice.on('error', @_onError)
      
      process.nextTick( () =>
        @_tuyaDevice.find().then( () =>
          @config.ip = @_tuyaDevice.device.ip # Set each time as the devices only support DHCP
          @config.port = @_tuyaDevice.device.port # Port may change with firmware updates
          @_tuyaDevice.connect({issueGetOnConnect: false})
        ).catch( (error) =>
          @base.error(error)
        )
      )
      
      super()
      
      @base.debug "deviceID: #{@config.deviceID}"
      @base.debug "deviceKey: #{@config.deviceKey}"
    
    getTemplateName: -> "wooxdimmer-rgb"
    getCt: -> Promise.resolve(@_ct)
    getColor: -> Promise.resolve(@_color)
    getHsb: -> Promise.resolve([@_hue, @_saturation, @_brightness])
    getMode: -> Promise.resolve(@_mode)
    getHue: () -> Promise.resolve @_hue
    getSaturation: () -> Promise.resolve @_saturation
    getBrightness: () -> Promise.resolve @_brightness

    turnOn: -> @changeDimlevelTo(100)
    turnOff: -> @changeDimlevelTo(0)

    changeDimlevelTo: (dimlevel) ->
      @base.debug("Setting Dimlevel: #{dimlevel}")
      
      @_setDimlevel(dimlevel)
      
      settings = {1: @_state}
      if @_state
        settings[2] = 'white'
        settings[3] = Math.floor((@config.maxBrightness-@config.minBrightness)*dimlevel/100)+@config.minBrightness
      
      @_updateDevice(settings).then( (result) =>
        @_setMode('white')
        @_setColor(@_convertHSBToHEX([0, 0, dimlevel]))
        
        return Promise.resolve(result)
        
      ).catch( (error) =>
        return Promise.reject(error)
      )
    
    changeHueTo: (hue) ->
      @base.debug("Homekit is setting hue: #{hue}")
      
      @_setHue(hue)
      @_setColor(@_convertHSBToHEX([hue, @_saturation, @_brightness]))
      @_setState(true)
      settings = {
        1: true
        2: 'colour'
        5: @_convertHSBToTuyaHex([hue, @_saturation, @_brightness])
      }
      @_updateDevice(settings)

    changeSaturationTo: (saturation) ->
      @base.debug("Homekit is setting saturation: #{saturation}")
      
      @_setSaturation(saturation)
      @_setColor(@_convertHSBToHEX([@_hue, saturation, @_brightness]))
      @_setState(true)
      settings = {
        1: true
        2: 'colour'
        5: @_convertHSBToTuyaHex([@_hue, saturation, @_brightness])
      }
      @_updateDevice(settings)

    changeBrightnessTo: (brightness) ->
      @base.debug("Homekit is setting brightness: #{brightness}")
      
      @_setBrightness(brightness)
      @_setColor(@_convertHSBToHEX([@_hue, @_saturation, brightness]))
      @_setDimlevel(brightness)
      
      settings = {1: @_state}
      if @_state
        settings['2'] = 'colour'
        settings['5'] = @_convertHSBToTuyaHex([@_hue, @_saturation, brightness])
      
      @_updateDevice(settings)
    
    setCT: (color) =>
      kelvin = @config.maxTemp-(Math.floor((@config.maxTemp-@config.minTemp)*color/100))
      @setColor(@_convertKelvinToHEX(kelvin))
      return Promise.resolve(true)
    
    setColor: (hex) =>
      @_validateHEX(hex)
      @base.debug("Received HEX color value: #{hex}")
            
      hex = hex.toUpperCase()
      hsb = @_convertHEXToHSB(hex)
      @_setHSB(hsb)
      @_setColor(hex)
      @_setDimlevel(hsb[2])
    
      settings = {1: @_state}
      if @_state
        settings['2'] = 'colour'
        settings['5'] = @_convertHSBToTuyaHex(hsb)   

      @_updateDevice(settings)
      return Promise.resolve()
    
    _onConnected: () =>
      @base.info "Connected to #{@name}"
    
    _onDisconnected: () =>
      @base.info "Disconnected from #{@name}"
    
    _onData: (data) =>
      @base.debug "Data received from #{@name}: "
      @base.debug util.inspect(data)
      
      if data.dps['1']? then @_setState(data.dps['1'])
      if @_state
        if data.dps['2']? then @_setMode(data.dps['2'])
        if data.dps['3']? then @_setDimlevel(Math.round( ((data.dps['3']-@config.minBrightness)/(@config.maxBrightness-@config.minBrightness))*100))
        if data.dps['5']?
          hex = data.dps['5'].match(/([a-fA-F\d]{6})/)[1].toUpperCase()
          @_validateHEX(hex)
          @_setColor(hex)
          @_setHSB(@_convertTuyaHexToHSB(data.dps['5']))
     
    _onError: (error) =>
      @base.error "#{error}"
    
    _setMode: (mode) =>
      if @_mode is mode then return
      @base.debug("Set @_mode to: #{mode}")
      @_mode = mode
      @emit "mode", mode
    
    _setColor: (value) =>
      if @_color is value then return
      @base.debug("Setting @_color to: #{value}")
      @_color = value
      @emit "color", value
      
    _setCt: (color) =>
      @_validateNumber(color)
      if @_ct is color then return
      
      @base.debug("Setting @_ct to: #{color}")
      @_ct = color
      @emit "ct", color
    
    _setHSB: (hsb) =>
      @_setHue(hsb[0])
      @_setSaturation(hsb[1])
      @_setBrightness(hsb[2])
    
    _setHue: (hue) =>
      @_validateNumber(hue, 0, 360)
      if @_hue is hue then return
      
      @base.debug("Setting @_hue to: #{hue}")
      @_hue = hue
      @emit "hue", hue
    
    _setSaturation: (saturation) =>
      @_validateNumber(saturation)
      if @_saturation is saturation then return
      
      @base.debug("Setting @_saturation to: #{saturation}")
      @_saturation = saturation
      @emit "saturation", saturation

    _setBrightness: (brightness) =>
      @_validateNumber(brightness)
      if @_brightness is brightness then return
      
      @base.debug("Setting @_brightness to: #{brightness}")
      @_setDimlevel(brightness)
      @_brightness = brightness
      @emit "brightness", brightness
    
    _validateNumber: (value, min = 0, max = 100) =>
      value = parseFloat(value)
      assert(not isNaN(value))
      cassert min <= value <= max
    
    _validateHEX: (value) =>
      assert( typeof(value is 'string' ))
      assert( typeof(value.match(/([a-fA-F\d]{6})/)[1].toString() is 'string' ) )
    
    _convertKelvinToHEX: (kelvin) =>
      rgb = tempConvert.colorTemperature2rgb(kelvin)
      return colorConvert.rgb.hex([rgb.red, rgb.green, rgb.blue])
    
    _convertHSBToHEX: (hsb) =>
      return colorConvert.hsv.hex(hsb)
    
    _convertHEXToHSB: (hex) =>
      return colorConvert.hex.hsv(hex)
    
    _convertHEXToTuyaHex: (value) =>
      return @_convertHSBToTuyaHex(@_convertHEXToHSB(value))
      
    _convertHSBToTuyaHex: (value) =>
      h = value[0]
      s = value[1]
      b = value[2]
      
      hsb = h.toString(16).padStart(4, '0') + Math.round(2.55 * s).toString(16).padStart(2, '0') + Math.round(2.55 * b).toString(16).padStart(2, '0')
      h /= 60
      s /= 100
      b *= 2.55
      
      i = Math.floor(h)
      f = h - i
      p = b * (1 - s)
      q = b * (1 - s * f)
      t = b * (1 - s * (1 - f))
      
      rgb = ( () =>
        switch 
          when (i % 6) is 0 then return [b, t, p]
          when (i % 6) is 1 then return [q, b, p]
          when (i % 6) is 2 then return [p, b, t]
          when (i % 6) is 3 then return [p, q, b]
          when (i % 6) is 4 then return [t, p, b]
          when (i % 6) is 5 then return [b, p, q]
      )().map( (c) => Math.round(c).toString(16).padStart(2, '0'))
      
      hex = rgb.join('')
      return hex + hsb
    
    _convertTuyaHexToHSB: (value) =>
      hsb = (value || '0000000000ffff').match(/^.{6}([0-9a-f]{4})([0-9a-f]{2})([0-9a-f]{2})$/i) || [0, '0', 'ff', 'ff']
      h = hsb[1]
      s = hsb[2]
      b = hsb[3]
      return [ parseInt(h, 16), Math.round(parseInt(s, 16) / 2.55), Math.round(parseInt(b, 16) / 2.55) ]
    
    _updateDevice: (settings) =>
      @_tuyaDevice.set({
        multiple: true
        data: settings
      })
    
    destroy: ->
      @_tuyaDevice.disconnect() if @_tuyaDevice.isConnected
      @_tuyaDevice.removeListener('connected', @_onConnected)
      @_tuyaDevice.removeListener('disconnected', @_onDisconnected)
      @_tuyaDevice.removeListener('data', @_onData)
      @_tuyaDevice.removeListener('error', @_onError)
      super()
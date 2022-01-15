module.exports = (env) ->
  # test
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
    
    constructor: (@config, lastState, plugin, framework) ->
      @debug = plugin.config.debug ? false
      @base = commons.base @, @config.class
      
      @id = @config.id
      @name = @config.name
      
      @addAttribute 'color',
        description: "Hex Color",
        type: 'string'
      @addAttribute 'ct',
        description: "WW Color",
        type: 'number'

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
      @actions.setEffect = 
        description: 'set light effect'
        params:
          effect:
            type: t.string
          color:
            type: t.string
            
      @_state = lastState?.state?.value or off
      @_mode = lastState?.mode?.value or "white"
      @_ct = lastState?.ct?.value or 0
      @_color = lastState?.color?.value or 'FFFFFF'
      @_hue = lastState?.hue?.value or 0
      @_saturation = lastState?.saturation?.value or 0
      @_brightness = lastState?.brightness?.value or 100
      @_dimlevel = lastState?.dimlevel?.value or 100
      @_connected = false
      
      super()
      
      @_tuyaDevice = new TuyAPI({
        id: @config.deviceID
        key: @config.deviceKey
      })
      
      @_tuyaDevice.on('connected', @_onConnected)
      @_tuyaDevice.on('disconnected', @_onDisconnected)
      @_tuyaDevice.on('data', @_onData)
      @_tuyaDevice.on('error', @_onError)
      
      process.nextTick( () => @_connectDevice())
      
      @base.debug "deviceID: #{@config.deviceID}"
      @base.debug "deviceKey: #{@config.deviceKey}"
    
    getTemplateName: -> "wooxdimmer-rgb"
    
    getCt: -> Promise.resolve(@_ct)
    getColor: -> Promise.resolve(@_color)
    getHsb: -> Promise.resolve([@_hue, @_saturation, @_brightness])
    getMode: -> Promise.resolve(@_mode)
    getHue: () -> Promise.resolve(@_hue)
    getSaturation: () -> Promise.resolve(@_saturation)
    getBrightness: () -> Promise.resolve(@_brightness)

    turnOn: -> @changeDimlevelTo(100)
    turnOff: -> @changeDimlevelTo(0)

    changeDimlevelTo: (dimlevel) =>
      @_validateNumber(dimlevel)
      state = dimlevel > 0
      settings = {1: state}
      if state
        settings[2] = 'white'
        settings[3] = @_convertDimlevelToTuyaDimlevel(dimlevel)
      
      @_updateDevice(settings)
        .catch( (error) =>
          @base.error "#{error}"
        
        )
      return Promise.resolve()
    
    changeHueTo:        (hue)        -> @setColor(@_convertHSBToHEX([hue, @_saturation, @_brightness]))
    changeSaturationTo: (saturation) -> @setColor(@_convertHSBToHEX([@_hue, saturation, @_brightness]))
    changeBrightnessTo: (brightness) -> @setColor(@_convertHSBToHEX([@_hue, @_saturation, brightness]))
    setCT:              (color)      -> @setColor(@_convertCTToHEX(color))
    
    setEffect: (effect, color = @_color) =>
      @base.debug("Received effect value: #{effect} with color #{color}")
      settings = {
        1: true
        2: effect.scene
      }
      settings[effect.dps] = effect.value + color
      
      @_updateDevice(settings)
        .catch( (error) =>
          @base.error "#{error}"
        )
      return Promise.resolve()
    
    setColor: (hex) =>
      @_validateHEX(hex)
      hex = hex.toUpperCase()
      @base.debug("Received HEX color value: #{hex}")
      
      state = @_convertHEXToHSB(hex)[2] > 0
      settings = {1: state}
      
      if state
        settings['2'] = 'colour'
        settings['5'] = @_convertHEXToTuyaHex(hex)
      
      @_updateDevice(settings)
        .catch( (error) =>
          @base.error "#{error}"
        )
      return Promise.resolve()
    
    _onConnected: () => 
      @base.debug "Connected to device."
      @_connected = true
    
    _onDisconnected: () => 
      @base.debug "Disconnected from device."
      @_connected = false
    
    _onData: (data, commandByte) =>
      @base.debug "Updated settings received from Woox device: #{commandByte}"
      @base.debug(util.inspect(data))

      if data.dps['1']? then @_setState(data.dps['1'])
      #if commandByte is 8
      #  @base.debug "commandByte: #{commandByte}, not processing update."
      #  return true
      
      if data.dps['2']? then @_setMode(data.dps['2'])
      
      if data.dps['3']? and @_mode is 'white'
        dimlevel = @_convertTuyaDimlevelToDimlevel(data.dps['3'])
        @_setColor('FFFFFF')
        @_setHue(0)
        @_setSaturation(0)
        @_setBrightness(dimlevel)
        @_setDimlevel(dimlevel)
        
      if data.dps['5']? and @_mode is 'colour'
        hsb = @_convertTuyaHexToHSB(data.dps['5'])
        @_setColor(@_convertHSBToHEX(hsb).toUpperCase())
        @_setHue(hsb[0])
        @_setSaturation(hsb[1])
        @_setBrightness(hsb[2])
        @_setDimlevel(hsb[2])

    _onError: (error) -> return true # Workaround on tuyapi module, if event is not handled exception is thrown.
    
    _setMode: (mode) =>
      if @_mode is mode then return
      @base.debug("Set @_mode to: #{mode}")
      @_mode = mode
      @emit "mode", mode
    
    _setColor: (value) =>
      @_validateHEX(value)
      if @_color is value then return
      
      @base.debug("Setting @_color to: #{value}")
      @_color = value.toString()
      @emit "color", value.toString()
      
    _setCt: (color) =>
      @_validateNumber(color)
      if @_ct is color then return
      
      @base.debug("Setting @_ct to: #{color}")
      @_ct = color
      @emit "ct", color
    
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
      @_brightness = brightness
      @emit "brightness", brightness
    
    _validateNumber: (value, min = 0, max = 100) =>
      value = parseFloat(value)
      assert(not isNaN(value))
      cassert min <= value <= max
    
    _validateHEX: (value) =>
      assert( typeof(value.match(/([a-fA-F\d]{6})/)[1] is 'string' ) )
    
    _convertCTToHEX: (ct) =>
      ct = @config.maxTemp-(Math.floor((@config.maxTemp-@config.minTemp)*ct/100))
      rgb = tempConvert.colorTemperature2rgb(ct)
      return colorConvert.rgb.hex([rgb.red, rgb.green, rgb.blue])
    
    _convertHSBToHEX: (hsb) => colorConvert.hsv.hex(hsb)
    _convertHEXToHSB: (hex) => colorConvert.hex.hsv(hex)
    _convertHEXToTuyaHex: (value) => @_convertHSBToTuyaHex(@_convertHEXToHSB(value))
    _convertTuyaHexToHEX: (value) => colorConvert.hsv.hex(@_convertTuyaHexToHSB(value))
    
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
      return [ parseInt(h, 16).toString(), Math.round(parseInt(s, 16) / 2.55).toString(), Math.round(parseInt(b, 16) / 2.55).toString() ]
    
    _convertDimlevelToTuyaDimlevel: (value) => Math.round(2.55 * value)
    _convertTuyaDimlevelToDimlevel: (value) => Math.round(value / 2.55)
    
    _cancelReconnect: () =>
      clearTimeout(@_reconnect)
      @_reconnect = undefined
    
    _connectDevice: (count = 1) =>
      #if !@_connected
      @base.debug("Connection attempt #{count}") 
      @_tuyaDevice.find().then( () =>
        @config.ip = @_tuyaDevice.device.ip # Set each time as the devices only support DHCP
        @config.port = @_tuyaDevice.device.port # Port may change with firmware updates
        @_tuyaDevice.connect()
        
      ).then( () =>
        @_cancelReconnect()
        
      ).catch( (error) =>
        @base.debug("Connection attempt #{count} failed...")
        if count < 3
          @_reconnect = setTimeout(@_connectDevice, 5000, ++count)
        
        else
          @_cancelReconnect()
          @base.error("Error connecting to the device. Is the device powered on?")
      
      )
      
      return Promise.resolve()
    
    _updateDevice: (settings) =>
      @base.debug("Sending update to device:")
      @base.debug(util.inspect(settings))
      #@_connectDevice()
      #  .then( () =>
      @_tuyaDevice.set({
        multiple: true
        data: settings
      
      }).catch( (error) =>
        @base.error("Error updating device: #{error}")
      )
    
    destroy: ->
      @_cancelReconnect()
      @_tuyaDevice.disconnect()
      @_tuyaDevice.removeListener('connected', @_onConnected)
      @_tuyaDevice.removeListener('disconnected', @_onDisconnected)
      @_tuyaDevice.removeListener('data', @_onData)
      @_tuyaDevice.removeListener('error', @_onError)
      @_tuyaDevice = undefined

      super()
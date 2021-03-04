module.exports = (env) ->

  assert = env.require 'cassert'
  cassert = env.require 'cassert'
  t = env.require('decl-api').types
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  TuyAPI = require('tuyapi')
  convert = require('color-convert')
  util = require('util')

  class WooxRGBWLight extends env.devices.DimmerActuator
    
    template: 'wooxdimmer-rgb'
    _presence: false
    
    constructor: (@config, plugin, lastState) ->
      @debug = plugin.config.debug ? false
      @base = commons.base @, @config.class
      
      @id = @config.id
      @name = @config.name
      
      @addAttribute 'presence',
        description: "online status",
        type: t.boolean
      @addAttribute 'mode',
        description: "RGB or White",
        type: t.string
      @addAttribute 'rgb',
        description: "RGB Color",
        type: t.string
      @addAttribute 'color',
        description: "WW Color",
        type: t.number
      @addAttribute 'hue',
        description: "Hue value",
        type: t.number
      @addAttribute 'saturation',
        description: "Saturation value",
        type: t.number
      @addAttribute 'brightness',
        description: "Brightness value",
        type: t.number
      @actions = _.cloneDeep @actions
      @actions.setColor =
        description: 'set light color'
        params:
          colorCode:
            type: t.number
      @actions.setRgb =
        description: 'set light color'
        params:
          r:
            type: t.number
          g:
            type: t.number
          b:
            type: t.number
      @actions.changeHueTo =
        description: "Sets the hue value"
        params:
          hue:
            type: t.number
      
      super()
      
      @_presence = false
      @_state = lastState?.state?.value or off
      @_mode = lastState?.mode?.value or "white"
      @_rgb = lastState?.rgb?.value or '255,255,255'
      @_hue = lastState?.hue?.value or 0
      @_saturation = lastState?.saturation?.value or 0
      @_brightness = lastState?.brightness?.value or 0
      @_dimlevel = lastState?.dimlevel?.value or 0
      
      @_tuyaDevice = null
      @base.debug "deviceID: #{@config.deviceID}"
      @base.debug "deviceKey: #{@config.deviceKey}"
      @_tuyaDevice = new TuyAPI({
        id: @config.deviceID
        key: @config.deviceKey
      })

      process.nextTick( () =>
        @_tuyaDevice.find().then( () =>
          @config.ip = @_tuyaDevice.device.ip
          @config.port = @_tuyaDevice.device.port
          @_tuyaDevice.connect()
          #@base.debug util.inspect(@_tuyaDevice)
        )
      )
      
      @_tuyaDevice.on('connected', @_onConnected)
      @_tuyaDevice.on('disconnected', @_onDisconnected)
      @_tuyaDevice.on('data', @_onData)
      @_tuyaDevice.on('error', @_onError)
    
    
    getTemplateName: -> "wooxdimmer-rgb"
    getColor: -> Promise.resolve(0)
    getRgb: -> Promise.resolve(@_rgb)
    getHsb: -> Promise.resolve([@_hue, @_saturation, @_brightness])
    getPresence: -> Promise.resolve(@_presence)
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
        console.log("result:")
        console.log(util.inspect(result))
        @_setMode('white')
        @_setHSB([@_hue, @_saturation, dimlevel])
        @_setRGB(@_convertHSBToRGB([@_hue, @_saturation, dimlevel]))
        
        return Promise.resolve(result)
        
      ).catch( (error) =>
        return Promise.reject(error)
      )
    
    changeHueTo: (hue) ->
      @base.debug("Homekit is setting hue: #{hue}")
      
      @_setHue(hue)
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
      @_setDimlevel(brightness)
      
      settings = {1: @_state}
      if @_state
        settings['2'] = 'colour'
        settings['5'] = @_convertHSBToTuyaHex([@_hue, @_saturation, brightness])
      
      @_updateDevice(settings)
    
    setColor: (color) =>
      return Promise.resolve()
    
    setRGB: (r, g, b) =>
      validate = (value) => cassert(not isNaN(value)) && cassert(0 >= value <= 255)
      validate(r)
      validate(b)
      validate(g)
      
      hsb = @_convertRGBToHSB([r, g, b])
      @_setHSB(hsb)
      @_setRGB([r, g, b])
      @_setDimlevel(hsb[2])
      
      settings = {1: @_state}
      if @_state
        settings['2'] = 'colour'
        settings['5'] = @_convertHSBToTuyaHex(hsb)   

      @_updateDevice(settings)
      
    setHex: (hex) =>
      color = hex.match(/([a-fA-F\d]{6})/)
      if color?
        rgb = @_convertHEXToRGB(color)
        @setRGB(rgb[0], rgb[1], rgb[2])
        return Promise.resolve()
      else
        return Promise.reject()
    
    _onConnected: () =>
      @base.info "Connected to #{@name}"
      @_setPresence(true)
    
    _onDisconnected: () =>
      @base.info "Disconnected from #{@name}"
      @_setPresence(false)
    
    _onData: (data) =>
      @base.debug "Data received from #{@name}: "
      @base.debug util.inspect(data)
      
      @_setPresence(true)
      if data.dps['1']? then @_setState(data.dps['1'])
      if @_state
        if data.dps['2']? then @_setMode(data.dps['2'])
        if data.dps['3']? then @_setDimlevel(Math.round( ((data.dps['3']-@config.minBrightness)/(@config.maxBrightness-@config.minBrightness))*100))
        if data.dps['5']?
          hsb = @_convertTuyaHexToHSB(data.dps['5'])
          @_setRGB(@_convertHSBToRGB(hsb))
          @_setHSB(hsb)
     
    _onError: (error) =>
      @base.error "Error: #{error}"
  
    _setPresence: (value) ->
      if @_presence is value then return
      @base.debug("Set @_presence to: #{value}")
      @_presence = value
      @emit 'presence', value
      
    _setMode: (mode) =>
      if @_mode is mode then return
      @base.debug("Set @_mode to: #{mode}")
      @_mode = mode
      @emit "mode", mode
    
    _setRGB: (array) =>
      rgb = array.join()
      if @_rgb is rgb then return
      @base.debug("Setting @_rgb to: #{rgb}")
      @_rgb = rgb
      @emit "rgb", rgb
    
    _setHSB: (hsb) =>
      @_setHue(hsb[0])
      @_setSaturation(hsb[1])
      @_setBrightness(hsb[2])
    
    _setHue: (hue) =>
      @base.debug("Setting @_hue to: #{hue}")
      
      hue = parseFloat(hue)
      assert(not isNaN(hue))
      cassert hue >= 0
      cassert hue <= 360
      if @_hue is hue then return
      
      @_hue = hue
      @emit "hue", hue
      
    _setSaturation: (saturation) =>
      @base.debug("Setting @_saturation to: #{saturation}")
      
      saturation = parseFloat(saturation)
      assert(not isNaN(saturation))
      cassert saturation >= 0
      cassert saturation <= 100
      if @_saturation is saturation then return
      
      @_saturation = saturation
      @emit "saturation", saturation

    _setBrightness: (brightness) =>
      @base.debug("Setting @_brightness to: #{brightness}")
      
      brightness = parseFloat(brightness)
      assert(not isNaN(brightness))
      cassert brightness >= 0
      cassert brightness <= 100
      if @_brightness is brightness then return
      
      @_setDimlevel(brightness)
      @_brightness = brightness
      @emit "brightness", brightness
    
    _convertHEXToRGB: (value) =>
      return convert.hex.rgb(value)
    
    _convertRGBToHSB: (rgb) =>
      return convert.rgb.hsv(rgb)
      
    _convertHSBToRGB: (hsb) =>
      return convert.hsv.rgb(hsb)
      
    _convertRGBToTuyaHex: (rgb) =>
      return @_convertHSBToTuyaHex(@_convertRGBToHSB(rgb))
    
    _convertTuyaHexToRGB: (tuyaHex) =>
      return @_convertHSBToRGB(@_convertTuyaHexToHSB(tuyaHex))
    
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
      @_tuyaDevice = null
      super()
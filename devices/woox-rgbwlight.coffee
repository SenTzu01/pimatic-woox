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
      
      @addAttribute  'presence',
        description: "online status",
        type: t.boolean
      @addAttribute  'rgb',
        description: "RGB Color",
        type: t.string
      @addAttribute  'color',
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
      
      @_dimlevel = lastState?.dimlevel?.value or 0
      @_oldDimlevel = if @_dimlevel > 0 then @_dimlevel else 100
      @_state = lastState?.state?.value or off
      @_presence=false
      @_mode = lastState?.mode?.value or "white"
      @_rgb = lastState?.rgb?.value or '255,255,255'
      @_hue = lastState?.hue?.value or 0
      
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
          @base.debug util.inspect(@_tuyaDevice)
        )
      )
      
      @_tuyaDevice.on('connected', @_onConnected)
      @_tuyaDevice.on('disconnected', @_onDisconnected)
      @_tuyaDevice.on('data', @_onData)
      @_tuyaDevice.on('error', @_onError)
    
    
    getTemplateName: -> "wooxdimmer-rgb"
    getColor: -> Promise.resolve(0)
    getRgb: -> Promise.resolve(@_rgb)
    getPresence: -> Promise.resolve(@_presence)
    getHue: () -> Promise.resolve @_hue
    getSaturation: () -> Promise.resolve @_saturation
    getBrightness: () -> Promise.resolve @_brightness

    turnOn: -> 
      @_updateDevice({
          '1': true
      }).then( () =>  
        @_setDimlevel(@_dimlevel)
        return Promise.resolve()
      
      ).catch( (error) =>
        return Promise.reject(error)
      
      )

    turnOff: ->
      @_lastdimlevel = @_dimlevel
      @_updateDevice({
        '1': false
      }).then( () =>
        @_setDimlevel(0)
        return Promise.resolve()
      
      ).catch( (error) =>
        return Promise.reject(error)
      
      )

    changeDimlevelTo: (level) ->
      if @_dimlevel is level then return Promise.resolve true
      
      if level > 0
        @_updateDevice({
          '1': true
          '2': 'white'
          '3': Math.floor((@config.maxBrightness-@config.minBrightness)*level/100)+@config.minBrightness
        }).then( () =>
          @_setDimlevel(level)
          return Promise.resolve()
          
        ).catch( (error) =>
          return Promise.reject(error)
        )
      
      else
        return @turnOff()

    changeHueTo: (hue) ->
      validate = (v) => cassert(not isNaN(v)) && cassert(0 >= v <= 360)
      validate(hue)
      
      @_updateDevice({
          '1': true
          '2': 'colour'
          '5': @_convertHSBToTuyaHex([hue, @_saturation, @_brightness])
      }).then( () =>
        @_setHue(hue)
        return Promise.resolve()
      
      ).catch( (error) =>
        return Promise.reject(error)
      
      )
    
    setColor: (color) =>
      return Promise.resolve()
    
    setRGB: (r, g, b) =>
      validate = (v) => cassert(not isNaN(v)) && cassert(0 >= v <= 255)
      validate(r)
      validate(b)
      validate(g)
      
      @_updateDevice({
        '1': true
        '2': 'colour'
        '5': @_convertRGBToTuyaHex([r, g, b])
      }).then( () =>
        @_setRGB([r, g, b])
        return Promise.resolve()
      
      ).catch( (error) =>
        return Promise.reject(error)
      
      )
      
    setHex: (hex) =>
      color = hex.match(/([a-fA-F\d]{6})/)
      if color?
        rgb = @_convertHEXToRGB(color)
        @setRGB(rgb[0], rgb[1], rgb[2])
        return Promise.resolve()
      else
        return Promise.reject()
    
    _setPresence: (value) ->
      if @_presence is value then return
      @_presence = value
      @emit 'presence', value
    
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
      
      @_setDimlevel(Math.round( ((data.dps['3']-@config.minBrightness)/(@config.maxBrightness-@config.minBrightness))*100)) if data.dps['3']?
      @_setState(data.dps['1']) if data.dps['1']?
      if data.dps['5']?
        hsb = @_convertTuyaHexToHSB(data.dps['5'])
        @_setRGB(@_convertHSBToRGB(hsb))
        @_setHue(hsb[0])
        @_setSaturation(hsb[1])
        @_setBrightness(hsb[2])
     
    _onError: (error) =>
      @base.error "Error: #{error}"
    
    _setMode: (mode) =>
      if @_mode is mode then return
      @_mode = mode
      @emit "color", mode
    
    _setRGB: (array) =>
      rgb = array.join()
      if @_rgb is rgb then return
      console.log("Would set @_rgb to: #{rgb}")
      @_rgb = rgb
      @emit "rgb", rgb
    
    _setHSB: (hsb) =>
      @_setHue(hsb[0])
      @_setSaturation(hsb[1])
      @_setBrightness(hsb[2])
    
    _setHue: (hue) =>
      if @_hue is hue then return
      console.log("Would set @_hue to: #{hue}")
      @_hue = hue
      @emit "hue", hue
      
    _setSaturation: (saturation) =>
      if @_saturation is saturation then return
      console.log("Would set @_saturation to: #{saturation}")
      @_saturation = saturation
      @emit "saturation", saturation

    _setBrightness: (brightness) =>
      if @_brightness is brightness then return
      console.log("Would set @_brightness to: #{brightness}")
      @_brightness = brightness
      @emit "brightness", brightness
    
    _convertHEXToRGB: (value) =>
      return convert.hex.rgb(value)
    
    _convertRGBToHSB: (array) =>
      return convert.rgb.hsv(array)
      
    _convertHSBToRGB: (array) =>
      return convert.hsv.rgb(array)
      
    _convertRGBToTuyaHex: (array) =>
      return @_convertHSBToTuyaHex(@_convertRGBToHSB(array))
    
    _convertTuyaHexToRGB: (value) =>
      return @_convertHSBToRGB(@_convertTuyaHexToHSB(value))
    
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
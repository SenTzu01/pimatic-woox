module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  M = env.matcher
  
  effects = require './effects.json'
  
  class WooxSceneActionHandler extends env.actions.ActionHandler
    constructor: (@provider, @device, @effect, @variable) ->
      @_variableManager = @provider.framework.variableManager
      super()
      
    setup: ->
      @dependOnDevice(@device)
      super()

    executeAction: (simulate) =>
      if @variable?
        @_variableManager.evaluateStringExpression([@variable])
        .then (value) =>
          effect = value
          if effect?
            @setMode(effect, simulate)
          else
            Promise.reject new Error __("variable value #{effect} is not a valid effect")
      else
        @setMode(@effect, simulate)

    setMode: (effect, simulate) =>
      if simulate
        return Promise.resolve(__("Would set #{@device.name} to #{effect}"))
      else
        @device.setEffect(effects[effect])
        return Promise.resolve(__("Setting #{@device.name} to #{effect}"))

  class WooxSceneActionProvider extends env.actions.ActionProvider
    constructor: (@framework) ->
      super()

    parseAction: (input, context) =>
      wooxColorDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => _.includes ['WooxRGBWLight'], device.config.class
      ).value()

      # Try to match the input string with: set ->
      m = M(input, context).match(['set effect of '])
      
      
      device = null
      effect = null
      match = null
      variable = null

      m.matchDevice wooxColorDevices, (m, d) ->
        # Already had a match with another device?
        if device? and device.id isnt d.id
          context?.addError(""""#{input.trim()}" is ambiguous.""")
          return
        device = d
        
        m.match [ ' to '], (m) ->
          m.or [
            # Effect name
            (m) -> m.match Object.keys(effects), (m, s) ->
              effect = s
              match = m.getFullMatch()

            # a variable holding the effect name
            (m) -> m.matchVariable (m, s) ->
              variable = s
              match = m.getFullMatch()
          ]

      if match?
        assert device?
        # either variable or effect should be set
        assert variable? ^ effect?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new WooxSceneActionHandler(@, device, effect, variable)
        }
      else
        return null

  return WooxSceneActionProvider

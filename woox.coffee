deviceConfigTemplates =
  "WooxRGBWLight":
    name: "Woox RGBW Light"
    class: "WooxRGBWLight"


actionProviders = [
  'woox-color-action'
  #'woox-white-action'
]

# ##The plugin code
module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'

  os = require 'os'
  commons = require('pimatic-plugin-commons')(env)


  class WooxPlugin extends env.plugins.Plugin
  
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      @base.info("Woox plugin started")

      deviceConfigDef = require("./device-config-schema")
      for own templateName of deviceConfigTemplates
        do (templateName) =>
          device = deviceConfigTemplates[templateName]
          className = device.class
          # convert camel-case classname to kebap-case filename
          filename = className.replace(/([a-z])([0-9]|[A-Z])/g, '$1-$2').toLowerCase()
          classType = require('./devices/' + filename)(env)
          @base.debug "Registering device class #{className}"
          @framework.deviceManager.registerDeviceClass(className, {
            configDef: deviceConfigDef[className],
            createCallback: (config, lastState) =>
              return new classType(config, @, lastState)
          })

      for provider in actionProviders
        className = provider.replace(/(^[a-z])|(\-[a-z])/g, ($1) -> $1.toUpperCase().replace('-','')) + 'Provider'
        classType = require('./predicates_and_actions/' + provider)(env)
        @base.debug "Registering action provider #{className}"
        @framework.ruleManager.addActionProvider(new classType @framework)


      @framework.on "after init", =>
        # Check if the mobile-frontend was loaded and get a instance
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js', "pimatic-woox/app/woox-template.coffee"
          mobileFrontend.registerAssetFile 'html', "pimatic-woox/app/woox-template.jade"
          mobileFrontend.registerAssetFile 'css', "pimatic-woox/app/woox-template.css"
          mobileFrontend.registerAssetFile 'js', "pimatic-woox/app/spectrum.js"
          mobileFrontend.registerAssetFile 'css', "pimatic-woox/app/spectrum.css"
        else
          env.logger.warn 'Plugin could not find the mobile-frontend. No GUI will be available'


  # ###Finally
  # Create a instance of my plugin
  wooxPlugin = new WooxPlugin
  # and return it to the framework.
  return wooxPlugin
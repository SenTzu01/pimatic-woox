$(document).on "templateinit", (event) ->

##############################################################
# WooxDimmerSliderItem - Only Dimmer
##############################################################
  class WooxDimmerSliderItem extends pimatic.SwitchItem

    constructor: (templData, @device) ->
      super(templData, @device)
      #DIMMER
      @getAttribute('presence').value.subscribe( =>
        @updateClass()
      )
      @dsliderId = "dimmer-#{templData.deviceId}"
      dimAttribute = @getAttribute('dimlevel')
      unless dimAttribute?
        throw new Error("A dimmer device needs an dimlevel attribute!")
      dimlevel = dimAttribute.value
      @dsliderValue = ko.observable(if dimlevel()? then dimlevel() else 0)
      dimAttribute.value.subscribe( (newDimlevel) =>
        @dsliderValue(newDimlevel)
        pimatic.try => @dsliderEle.slider('refresh')
      )

    onSliderStop: ->
      @dsliderEle.slider('disable')
      @device.rest.changeDimlevelTo( {dimlevel: @dsliderValue()}, global: no).done(ajaxShowToast)
      .fail( =>
        pimatic.try => @dsliderEle.val(@getAttribute('dimlevel').value()).slider('refresh')
      ).always( =>
        pimatic.try( => @dsliderEle.slider('enable'))
      ).fail(ajaxAlertFail)

    afterRender: (elements) ->
      super(elements)
      @presenceEle = $(elements).find('.attr-presence')
      @updateClass()
      @dsliderEle = $(elements).find('#' + @dsliderId)
      @dsliderEle.slider()
      $(elements).find('.ui-slider').addClass('no-carousel-slide')
      $('#index').on("slidestop", " #item-lists #"+@dsliderId , (event) ->
          ddev = ko.dataFor(this)
          ddev.onSliderStop()
          return
      )

    updateClass: ->
      value = @getAttribute('presence').value()
      if @presenceEle?
        switch value
          when true
            @presenceEle.addClass('value-present')
            @presenceEle.removeClass('value-absent')
          when false
            @presenceEle.removeClass('value-present')
            @presenceEle.addClass('value-absent')
          else
            @presenceEle.removeClass('value-absent')
            @presenceEle.removeClass('value-present')
        return

##############################################################
# WooxDimmerTempSliderItem
##############################################################
  class WooxDimmerTempSliderItem extends WooxDimmerSliderItem
    constructor: (templData, @device) ->
      super(templData, @device)
      #COLOR
      @csliderId = "color-#{templData.deviceId}"
      colorAttribute = @getAttribute('color')
      unless colorAttribute?
        throw new Error("A dimmer device needs an color attribute!")
      color = colorAttribute.value
      @csliderValue = ko.observable(if color()? then color() else 0)
      colorAttribute.value.subscribe( (newColor) =>
        @csliderValue(newColor)
        pimatic.try => @csliderEle.slider('refresh')
      )

    onSliderStop2: ->
      @csliderEle.slider('disable')
      @device.rest.setColor( {colorCode: @csliderValue()}, global: no).done(ajaxShowToast)
      .fail( =>
        pimatic.try => @csliderEle.val(@getAttribute('color').value()).slider('refresh')
      ).always( =>
        pimatic.try( => @csliderEle.slider('enable'))
      ).fail(ajaxAlertFail)

    afterRender: (elements) ->
      @csliderEle = $(elements).find('#' + @csliderId)
      @csliderEle.slider()
      super(elements)
      $('#index').on("slidestop", " #item-lists #"+@csliderId, (event) ->
          cddev = ko.dataFor(this)
          cddev.onSliderStop2()
          return
      )

##############################################################
# WooxDimmerTempSliderItem
##############################################################
  class WooxDimmerRGBItem extends WooxDimmerSliderItem
    constructor: (templData, @device) ->
      super(templData, @device)
      @_colorChanged = false
      #COLOR
      @csliderId = "color-#{templData.deviceId}"
      colorAttribute = @getAttribute('color')
      unless colorAttribute?
        throw new Error("A dimmer device needs a color attribute!")
      color = colorAttribute.value
      @csliderValue = ko.observable(if color()? then color() else 0)
      colorAttribute.value.subscribe( (newColor) =>
        @csliderValue(newColor)
        pimatic.try => @csliderEle.slider('refresh')
      )
      @pickId = "pick-#{templData.deviceId}"

    onSliderStop2: ->
      @csliderEle.slider('disable')
      @device.rest.setColor( {colorCode: @csliderValue()}, global: no).done(ajaxShowToast)
      .fail( =>
        pimatic.try => @csliderEle.val(@getAttribute('color').value()).slider('refresh')
      ).always( =>
        pimatic.try( => @csliderEle.slider('enable'))
      ).fail(ajaxAlertFail)

    afterRender: (elements) ->
      @csliderEle = $(elements).find('#' + @csliderId)
      @csliderEle.slider()
      super(elements)
      $('#index').on("slidestop", " #item-lists #"+@csliderId, (event) ->
          cddev = ko.dataFor(this)
          cddev.onSliderStop2()
          return
      )
      $(elements).on("dragstop.spectrum","#"+@pickId, (color) =>
          @_changeColor(color)
      )
      @colorPicker = $(elements).find('.light-color')
      @colorPicker.spectrum
        preferredFormat: 'rgb'
        showButtons: false
        allowEmpty: true
      $('.sp-container').addClass('ui-corner-all ui-shadow')

    _changeColor: (color) ->
      r = @colorPicker.spectrum('get').toRgb()['r']
      g = @colorPicker.spectrum('get').toRgb()['g']
      b = @colorPicker.spectrum('get').toRgb()['b']
      return @device.rest.setRGB(
          {r: r, g: g, b: b}, global: no
        ).then(ajaxShowToast, ajaxAlertFail)

##############################################################
# WooxDimmerTempSliderItem
##############################################################
  class WooxDimmerTempButtonItem extends WooxDimmerSliderItem
    constructor: (templData, @device) ->
      super(templData, @device)
      @warmId = "wbutton-#{templData.deviceId}"
      @normalId = "nbutton-#{templData.deviceId}"
      @coldId = "cbutton-#{templData.deviceId}"

    afterRender: (elements) ->
      super(elements)
      @warmButton = $(elements).find('[name=warmButton]')

    setWarm: -> @setColor "warm"

    setCold: -> @setColor "cold"

    setNormal: -> @setColor "normal"

    setColor: (temp) ->
        @device.rest.setColorFix({colorCode: temp}, global: no)
          .done(ajaxShowToast)
          .fail(ajaxAlertFail)


  class WooxHubItem extends pimatic.PresenceItem
    constructor: (templData, @device) ->
      super(templData, @device)
      @rbutID = "rbutton-#{templData.deviceId}"
      @dbutID = "dbutton-#{templData.deviceId}"

    getItemTemplate: => 'wooxhub'

    afterRender: (elements) ->
      super(elements)

    setReboot: ->
      if confirm __("Do you really want to restart the hub")
        @device.rest.setReboot(global: no)
          .done(ajaxShowToast)
          .fail(ajaxAlertFail)

    setDiscovery: ->
      @device.rest.setDiscovery(global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

  pimatic.templateClasses['wooxdimmer-dimmer'] = WooxDimmerSliderItem
  pimatic.templateClasses['wooxdimmer-temp'] = WooxDimmerTempSliderItem
  pimatic.templateClasses['wooxdimmer-temp-buttons'] = WooxDimmerTempButtonItem
  pimatic.templateClasses['wooxdimmer-rgb'] = WooxDimmerRGBItem
  pimatic.templateClasses['wooxhub'] = WooxHubItem

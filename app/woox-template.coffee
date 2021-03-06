$(document).on "templateinit", (event) ->

  class WooxDimmerItem extends pimatic.SwitchItem

    constructor: (templData, @device) ->
      super(templData, @device)
      @dsliderId = "dimmer-#{templData.deviceId}"
      dimAttribute = @getAttribute('dimlevel')
      dimlevel = dimAttribute.value
      @dsliderValue = ko.observable(if dimlevel()? then dimlevel() else 0)
      dimAttribute.value.subscribe( (newDimlevel) =>
        @dsliderValue(newDimlevel)
        pimatic.try => @dsliderEle.slider('refresh')
      )

    getItemTemplate: => 'light-dimmer'

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
      return
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

  class WooxDimmerRGBItem extends WooxDimmerItem
    constructor: (templData, @device) ->
      super(templData, @device)
      @_colorChanged = false
      @csliderId = "color-#{templData.deviceId}"
      ctAttribute = @getAttribute('ct')
      unless ctAttribute?
        throw new Error("A dimmer device needs an ct attribute!")
      ct = ctAttribute.value
      @csliderValue = ko.observable(if ct()? then ct() else 0)
      ctAttribute.value.subscribe( (newCt) =>
        @csliderValue(newCt)
        pimatic.try => @csliderEle.slider('refresh')
      )
      @pickId = "pick-#{templData.deviceId}"

    getItemTemplate: => 'light-rgbct'

    onSliderStop2: ->
      @csliderEle.slider('disable')
      @device.rest.setCT( {colorCode: @csliderValue()}, global: no).done(ajaxShowToast)
      .fail( =>
        pimatic.try => @csliderEle.val(@getAttribute('ct').value()).slider('refresh')
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
        preferredFormat: 'hex'
        showButtons: false
        allowEmpty: true
        showInput: true

      $('.sp-container').addClass('ui-corner-all ui-shadow')

      @colorPicker.on 'change', (e, payload) =>
        return if payload?.origin unless 'remote'
        @colorPicker.spectrum 'set', $(e.target).val()
      @_onRemoteChange 'color', @colorPicker
      @colorPicker.spectrum 'set', @color()

    _onRemoteChange: (attributeString, el) ->
      attribute = @getAttribute(attributeString)
      unless attributeString?
        throw new Error("An RGBCT-Light device needs an #{attributeString} attribute!")

      @[attributeString] = ko.observable attribute.value()
      attribute.value.subscribe (newValue) =>
        @[attributeString] newValue
        el.val(@[attributeString]()).trigger 'change', [origin: 'remote']

    _changeColor: (color) ->
      color = @colorPicker.spectrum('get').toHex()
      return @device.rest.setColor(
          {colorCode: color}, global: no
        ).then(ajaxShowToast, ajaxAlertFail)
        
  pimatic.templateClasses['wooxdimmer-rgb'] = WooxDimmerRGBItem
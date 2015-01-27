class Collection
  changeStack = []
  saveStack = []
  autoSaveValue: false
  data = []
  doSave = ->
    for item in changeStack
      # todo: proper ajax
      $.ajax
      .done (response)->
        item.call item, "success"
      .fail ->
        item.call item, "error"
  constructor: (@element, options = {})->
    $el = $ @element
    @el = $el.get 0

    @autoSave = options.autoSave if options.autoSave
    @name = $el.attr "name"
  ready: (callback)->
    setTimeout =>
      data = @el.data
      unless data && data.json
        @ready.call @, callback
      else
        @data = @el.data.json
        # todo: schema
        @schema = {}
        callback.apply @, [@data, @name, changeStack, @autoSave, @doSave]
    , 100

  @getter 'length', (value)   -> @data.length
  @getter 'autoSave', (value) -> @autoSaveValue
  @setter 'autoSave', (value) ->
    if typeof value isnt "boolean"
      throw new Error "Collection: autoSave should be a `boolean` value"
    if value is true
      @save()
  find: (where, callback)->
    result = _.where @data, where
    err = false
    callback.call @, err, result if callback
    return result
  findByPath: (path)->
    jom.collections.findByPath path, @data
  on: (type, path, callback)->
    switch type
      when "change"
        @change.call @, callback
      when "save"
        @save.call @, callback
      else
        throw new Error "Collection: Event not found `#{type}`"
    @

  change: (callback)-> changeStack.push callback
  save: (callback)->
    saveStack.push callback
    throw new Error "should save now!!!!"

class Collections
  stack = {}
  @getter 'collections', ->
    Object.keys stack

  element_to_collection= (all_plain_elements)->
    all_plain_elements.each (i,n)->
      n.collection = true
      collection = new Collection n
      collection.ready (data, name, changeStack, autoSave, doSave)->
        stack[name] = collection
        Observe stack[name].data, (changes)->
          console.log("Observer: change detected")
          for item in changeStack
            item.call item, changes
          if autoSave is true
            doSave.call collection
        , null, name

  constructor: ->
    all = $ 'script[type="text/collection"]'

    plain = all.filter    -> not ("collection" of @)
    existing = all.filter -> ("collection" of @)

    element_to_collection.call @, plain if plain.length > 0

  list: -> stack
  model : (collection, data = [], options={}) ->
    if arguments.length is 0
      return stack
    if arguments.length is 1
      if stack[collection]
        return stack[collection]
      else
        return new Collection()
    return stack

  findByPath : -> @byPath.apply @, arguments
  byPath : (path, data) ->
    regx   = /(\[)(\d+)(\])/g
    text   = path.replace regx, ".$2"
                .replace /^\.*/,""
    split  = text.split "."
    if data then result = data
    else result = stack
    for item in split
      return result if result is undefined
      result = result[item] or undefined

    result

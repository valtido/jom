
# Base class for collections, Collection's behaviour is
# controlled by JOM and only keeps record of itself

class Collection
  # @property [String] Name of the collection from name attr
  @name : ""
  # @property [Array] An array of data for the collection
  @data : []
  # @property [Object] a JSON Schema object describing data
  @schema : {}
  # @property [Object] reported JSON Schema errors when validated is triggered
  @errors : []
  # @property [Boolean] indicates whether the collection observes changes
  @observing : false

  # Constructs a new collection
  # @param [String] name name of collection
  # @option data [Array] data data to attach to collection
  # @option schema [Object] schema JSON Schema to attach to collection
  # @note see json-schema.org for JSON Schema
  constructor: (name, data=[], schema)->
    if name is undefined or not name or typeof name isnt "string"
      throw new Error "jom: collection name is required"

    @name   = name
    @data   = []
    @schema = {}
    @attach_schema schema
    @attach_data data
    @errors = []
    @observing = false

  generate_id: -> new Date().getTime()

  meta : ->
    return {id: @generate_id()}
  # Attaches data to the collection instance
  # @param [Array, Object] data data to attach
  # @option data [Array] data if array, push each element
  # @option data [Object] data if object, push the object
  add : (obj)->
    is_valid = @is_valid obj
    if is_valid
      @data.push obj
    else
      @errors.push "Cannot add the data, is not valid. #{obj.toString()}"


  attach_data: (data = [])->
    length = data.length || Object.keys(data).length
    if length
      if Array.isArray data
        for item in data
          item.meta = @meta()
          Object.defineProperty item, "meta", enumerable: false
          @add item
      else
        data.meta = @meta()
        Object.defineProperty data, "meta", enumerable: false
        @add data

    @is_valid()
    @data

  # Attaches a JSON Schema to the collection instance
  # @note see json-schema.org for JSON Schema
  # @param [Object] schema JSON Schema Object to attach to collection
  attach_schema: (schema)->
    if schema isnt undefined and schema['$schema'] is undefined
      schema['$schema'] = 'http://json-schema.org/draft-04/schema#'
    @schema = schema
    @is_valid()
    @schema

  # returns errors to a string format if any
  # @return [String] A string of errors, using `JSON.stringify`
  errors_to_string: -> JSON.stringify @errors

  # check to see if the schema is valid
  # @note if no schema provided, it will return true
  # @note it uses jjv to do the Schema validation
  # @note jjv see https://github.com/acornejo/jjv
  # @return [Boolean] returns true or false if the schema is valid
  schema_valid: -> @schema.is_valid()

  is_valid: (doc = null)->
    validator = isMyJsonValid
    core = jom.schemas_core
    errors = []

    documentValidator = validator core, verbose: true
    if doc isnt null
      documentValidator doc
      if documentValidator.errors and documentValidator.errors.length
        errors = documentValidator.errors
    else
      for doc in @data
        documentValidator doc
        if documentValidator.errors and documentValidator.errors.length
          errors.push documentValidator.errors

    if errors.length
      console?.error? "Collection: ", @name, errors

    if errors.length
      return false
    else
      return true

    return true if @schema is undefined

    if data isnt null and data.toString() isnt "[object Object]"
      @errors.push "collection: data is wrong"
      return false

    # TODO: make further proper checks

    if @schema["$schema"] is undefined
      throw new Error "jom: $schema is missing"

    env.addSchema @name, @schema
    data = data or @data
    @errors = env.validate @name, data

    return true if not @errors

    return false

  # joines two or more paths together
  # @example join two paths
  #   var c = new Collection("my_coll").join("path","name"); // "path.name"
  # @example join three paths
  #   var c = new Collection("my_coll").join("path","name","[0]"); // "path.name[0]"
  # @param [String] a first string to join
  # @param [String] b second string to join
  # @return [String] A string of a JSON PATH
  join : (a, b) ->
    join = @join
    b      = "#{b}"
    first  = b[0]
    result = if first is "[" then a + b else "#{a}.#{b}"

    if arguments.length > 2
      args = Array.prototype.splice.call arguments, 2
      arr = []

      arr.push result
      arr.push.apply arr, args

      result = @join.apply @, arr


    return result


  # Does a deep search and returns the object if found or else `undefined`
  # @param [String] path a JSON path to search for
  # @example Find name of a person
  #  new Collection("person",{name: "valtid"}).findByPath("[0].name");//"valtid"
  # @return [mixed] returns different types of `undefined` if nothing found
  findByPath : (path) ->
    regx   = /(\[)(\d+)(\])/g
    text   = path.replace regx, ".$2"
                .replace /^\.*/,""
    split  = text.split "."
    result = @data

    for item in split
      return result if result is undefined
      result = result[item]

    result

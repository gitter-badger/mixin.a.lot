_ = require 'underscore'


class Mixin
  ###
    Don't make your own Mixin instances; use the factory method @make_mixin,
    which creates immutable instances for use with mixin methods on Function.prototype.

    The philosophy, more or less, is like:

      - https://javascriptweblog.wordpress.com/2011/05/31/a-fresh-look-at-javascript-mixins/

    The instance property .mixin_keys contains the properties to mix in.
  ###

  @MutabilityError: class MutabilityError extends Error
  @ArgumentError: class ArgumentError extends Error

  @mixinhook_keys: [
    'premixin_hook'
    'postmixin_hook'
  ]

  @validate_mixin: (mixin) ->
    unless mixin instanceof @
      throw new TypeError "Expected a Mixin instance"
    for mixinhook_key in @mixinhook_keys
      hook = mixin[mixinhook_key]
      if hook? && !_.isFunction hook
        throw new TypeError "Expected a function for #{mixinhook_key}"


  @from_obj: (obj) ->
    unless _.isObject(obj) && !_.isArray(obj)
      throw new TypeError "Expected non-empty object"
    unless _.isString(obj.name) && obj.name
      throw new @ArgumentError "Expected String name in options argument"

    mixin = new Mixin(obj.name)
    mkeys = Object.keys(_.omit(obj, 'name')).sort()

    if _.isEmpty(mkeys)
      throw new @ArgumentError "Found nothing to mix in!"

    for key, value of _.extend(obj, mixin_keys: mkeys)
      do (key, value) =>
        Object.defineProperty mixin, key,
          enumerable: true
          get: ->
            value
          set: =>
            throw new @MutabilityError "Cannot change #{key} on #{mixin}"
    mixin

  constructor: (@name) ->

  toString: ->
    string_keys = _.without(@mixin_keys, 'name')
    "Mixin(#{@name}: #{string_keys.join(', ')})"


Object.freeze(Mixin)
Object.freeze(Mixin::)


module.exports = Mixin
_ = require 'underscore'
Utils = require './util'


errors =

  NotImplemented: class NotImplemented extends Error

  NotMutable: class NotMutable extends Error

  BadArgument: class BadArgument extends Error


class Mixin
  ###
    Don't make your own Mixin instances; use the factory method @make_mixin,
    which creates immutable instances for use with mixin methods on Function.prototype.

    The philosophy, more or less, is like:

      - https://javascriptweblog.wordpress.com/2011/05/31/a-fresh-look-at-javascript-mixins/

    The instance property .mixin_keys contains the properties to mix in.
  ###


  @mixing_hooks: [
    'premixing_hook'
    'postmixing_hook'
  ]

  @mixinmethod_hooks: [
    'pre_mixinmethod_hook'
    'post_mixinmethod_hook'
  ]

  @_parse_hooks: (mixin, hooks) ->
    for own hook_key, methods of hooks
      if methods != undefined
        unless Array.isArray(methods) && _.all(methods, Utils.is_nonempty_string)
          throw new BadArgument "#{hook_key}: expected an Array of mixin method names"
        for methodname in methods
          unless _.isFunction mixin[methodname]
            throw new BadArgument "#{methodname} isn't a method on #{mixin}"
      else
        hooks[hook_key] = []
    hooks

  @_parse_omits: (mixin, omits) ->
    if omits != undefined
      unless Array.isArray(omits) && omits.length
        throw new BadArgument "Expected omits option to be a nonempty Array"
      diff = _.difference(omits, mixin.mixin_keys)
      if diff.length
        throw new BadArgument "Some omit keys aren't in mixin: #{diff}"
    (omits?.length && omits) || []

  @parse_mix_opts: (mixin, options) ->
    {omits, hook_before, hook_after} = options

    omits = @_parse_omits(mixin, omits)
    hooks = @_parse_hooks(mixin, {hook_before, hook_after})

    {omits, hooks}

  @validate_mixin: (mixin) ->
    unless mixin instanceof @
      throw new TypeError "Expected a Mixin instance"
    for mixinhook_key in @mixing_hooks
      supplied_hook = mixin[mixinhook_key]
      if supplied_hook? && !_.isFunction supplied_hook
        throw new TypeError "Expected a function for #{mixinhook_key}"

  @from_obj: (obj, freeze = true) ->
    unless _.isObject(obj) && !_.isArray(obj)
      throw new TypeError "Expected non-empty object"
    unless _.isString(obj.name) && obj.name
      throw new BadArgument "Expected String name in options argument"

    mixin = new Mixin
    mkeys = Object.keys(_.omit(obj, 'name')).sort()

    if _.isEmpty(mkeys)
      throw new BadArgument "Found nothing to mix in!"

    for key, value of _.extend(obj, mixin_keys: mkeys)
      do (key, value) =>
        Object.defineProperty mixin, key,
          enumerable: true
          get: ->
            value
          set: =>
            throw new NotMutable "Cannot change #{key} on #{mixin}"
    (freeze && Object.freeze mixin) || mixin

  toString: ->
    string_keys = _.without(@mixin_keys, 'name')
    "Mixin(#{@name}: #{string_keys.join(', ')})"


Object.freeze(Mixin)
Object.freeze(Mixin::)


module.exports = {Mixin, errors}
{Mixin, errors} = require './mixinfactory'
Util = require './util'
_ = require 'underscore'

PARSE =

  _parse_methodhooks: (mixin, hooks) ->
    for own hook_key, methods of hooks
      if methods != undefined
        unless Array.isArray(methods) && _.all(methods, Util.is_nonempty_string)
          throw new errors.ValueError "#{hook_key}: expected an Array of mixin method names"
        for methodname in methods
          unless _.isFunction mixin[methodname]
            throw new errors.ValueError "#{methodname} isn't a method on #{mixin}"
      else
        hooks[hook_key] = []

    {before: hooks.hook_before, after: hooks.hook_after}

  _parse_mixinghooks: (mixin, methodhooks) ->
    for own mixinghook_key, hook of methodhooks
      supplied_hook = mixin[mixinghook_key]
      if supplied_hook? && !_.isFunction supplied_hook
        throw new TypeError "Expected a function for #{mixinghook_key}"

    {premix: methodhooks.premixing_hook, postmix: methodhooks.postmixing_hook}

  _parse_omits: (mixin, omits) ->
    if omits != undefined
      unless Array.isArray(omits) && omits.length
        throw new errors.ValueError "Expected omits option to be a nonempty Array"
      diff = _.difference(omits, mixin.mixin_keys)
      if diff.length
        throw new errors.ValueError "Some omit keys aren't in mixin: #{diff}"
    (omits?.length && omits) || []

  mix: (mixin, options) ->
    {omits} = options
    {hook_before, hook_after} = options
    {premixing_hook, postmixing_hook} = options

    omits = @_parse_omits(mixin, omits)
    {before, after} = @_parse_methodhooks(mixin, {hook_before, hook_after})
    {premix, postmix} = @_parse_mixinghooks(mixin, {premixing_hook, postmixing_hook})

    {omits, methodhooks: {before, after}, mixinghooks: {premix, postmix}}


MIX =

  with_hook: ({context, mixinprop, mixinvalue}, before = false) ->
    hookname = (before && "before_#{mixinprop}") || "after_#{mixinprop}"

    unless _.isFunction(context[hookname])
      throw errors.NotImplemented "Unimplemented hook: #{hookname}"
    if before
      hooked_mixinfunc = _.compose mixinvalue, context[hookname]
    else
      hooked_mixinfunc = _.compose context[hookname], mixinvalue
    context[mixinprop] = hooked_mixinfunc

  standard: ({context, mixinprop, mixinvalue}) ->
    context[mixinprop] = mixinvalue


mixinto_proto = (mixin, options = {}) ->
  Mixin.validate(mixin)
  {omits, methodhooks, mixinghooks} = PARSE.mix(mixin, options)

  [__, __, mixinhook_args] = arguments

  mixinghooks.premix?.call(@::, mixinhook_args)

  mixing_in = _.object(
    [k, v] for k, v of mixin when k in mixin.mixin_keys and k not in omits)

  if _.isEmpty mixing_in
    throw new errors.ValueError "Found nothing to mix in!"
  for mixinprop, mixinvalue of mixing_in
    mixcontent = {context: @::, mixinprop, mixinvalue}

    if not (mixinprop in _.union(methodhooks.before, methodhooks.after))
      MIX.standard mixcontent
    else
      MIX.with_hook mixcontent, (mixinprop in methodhooks.before)

  mixinghooks.postmix?.call(@::, mixinhook_args)
  @

enable_protomixing = ->
  Object.defineProperty Function::, 'mixinto_proto',
    enumerable: false
    value: mixinto_proto

module.exports = enable_protomixing
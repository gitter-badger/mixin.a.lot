UTIL =

  arguments:

    rest_of: ->
      if arguments.length > 1
        return Array::slice.call arguments, 1
      return []

    validate_mixin: (mixin) ->
      if Array.isArray(mixin)
        throw new TypeError("Expected object, got Array")
      else if !mixin?
        throw new TypeError("Expected object, got null-equivalent")
      else if typeof mixin != 'object'
        throw new TypeError("Expected object, got something else")

    ArgumentError: class ArgumentError extends Error

  postmixin_hooks: [
    'post_classmixin'
    'post_protomixin'
  ]


module.exports = UTIL
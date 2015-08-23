describe 'static_mix', ->

  {enable_staticmixing, make_mixin} = require '../index'
  {beforeOnce, MIXINS} = require '../spec-utils'
  errors = require '../errors'
  _ = require 'underscore'

  describe 'enabling static_mix', ->

    it 'should return true when static_mix is first enabled', ->
      expect(enable_staticmixing()).toBe true

    it 'should return false if static_mix is already enabled', ->
      expect(enable_staticmixing()).toBe false

  it 'should attach a non-enumerable, immutable .static_mix to Function.prototype', ->
    expect(_.isFunction Function::static_mix).toBe true
    expect(Object.keys Function::).not.toContain 'static_mix'

    delete Function::static_mix
    expect(_.isFunction Function::static_mix).toBe true

    Function::static_mix = 'bar'
    expect(_.isFunction Function::static_mix).toBe true

  it 'should throw an error when mixing non-Mixins', ->
    for non_Mixin in [1, 'String', [], {}]
      expect(->
        class Example
          @static_mix non_Mixin
      ).toThrow new TypeError 'Expected a Mixin instance'

  it 'should mix into the class', ->
    mixin = MIXINS.default_mixin()
    spyOn(mixin, 'baz').and.returnValue ['baz']

    class Example
      @static_mix mixin

    expect(Example.bar).toBe 1
    expect(Example.baz()).toEqual ['baz']

  it 'should be order-dependent', ->
    mixin_1 = make_mixin name: 'mixin_1', foo: 'bar1', baz: 'qux'
    mixin_2 = make_mixin name: 'mixin_2', foo: 'bar2', qux: 'baz'

    class Example
      @static_mix mixin_1
      @static_mix mixin_2

    expect(Example.foo).toBe 'bar2'
    expect(Example.baz).toBe 'qux'
    expect(Example.qux).toBe 'baz'

  describe 'mixing hooks', ->

    it 'should throw an error with options-supplied non-Function mixing hooks', ->
      @mixin = MIXINS.default_mixin()
      mix_opts = {premix: 1}

      expect(=>
        class Example
        Example.static_mix @mixin, mix_opts
      ).toThrow(new TypeError('Expected a function for premix'))

      mix_opts = {postmix: []}

      expect(=>
        class Example
        Example.static_mix @mixin, mix_opts
      ).toThrow(new TypeError('Expected a function for postmix'))

    it 'should throw an error with mixin-supplied non-Function mixing hooks', ->
      @mixin = MIXINS.default_mixin()
      @mixin.premix = 1

      expect(=>
        class Example
        Example.static_mix @mixin
      ).toThrow(new TypeError('Expected a function for premix'))

      @mixin = MIXINS.default_mixin()
      @mixin.postmix = []

      expect(=>
        class Example
        Example.static_mix @mixin
      ).toThrow(new TypeError('Expected a function for postmix'))

    describe 'pre-mixing hooks', ->

      beforeEach ->
        @mixin = MIXINS.default_mixin()

      it 'should invoke an options pre-mixing hook with the class context', ->
        mix_opts = {premix: ->}
        spyOn(mix_opts, 'premix').and.callThrough()

        class Example
        Example.static_mix @mixin, mix_opts, ['arg1', 'arg2']

        expect(mix_opts.premix).toHaveBeenCalledWith(['arg1', 'arg2'])

        {object, args} = mix_opts.premix.calls.first()

        # test that the right context was used
        expect(object).toBe Example
        expect(args...).toEqual(['arg1', 'arg2'])

      ###
        This is also a good example of pre-mixin hook usage;
        to validate that the mixing class satisfies a certain schema.
      ###
      it 'should invoke a mixin pre-mixing hook with the class context', ->
        @mixin.premix = ->
          unless @special_key?
            throw new errors.NotImplemented "Wanted schema key special_key"

        spyOn(@mixin, 'premix').and.callThrough()

        expect(=>
          class Example
            # special_key is not on the class; schema unsatisfied, hook will throw
          Example.static_mix @mixin, null, ['arg1', 'arg2']
        ).toThrow new errors.NotImplemented('Wanted schema key special_key')

        class Example
          # special_key is on the class; schema satisfied, hook won't throw
          @special_key: 1
        Example.static_mix @mixin, null, ['arg1', 'arg2']

        expect(@mixin.premix).toHaveBeenCalledWith(['arg1', 'arg2'])
        expect(@mixin.premix.calls.count()).toBe 2

        {object, args} = @mixin.premix.calls.mostRecent()

        # test that the right context was used
        expect(object).toBe Example
        expect(args...).toEqual(['arg1', 'arg2'])

      it 'should invoke an options pre-mixing hook before mixing in', ->
        mix_opts = {premix: ->}
        error = new Error
        threw = false

        spyOn(mix_opts, 'premix').and.throwError(error)
        expect(@mixin.foo).toBeDefined()

        class Example

        try
          Example.static_mix @mixin, mix_opts, ['arg1', 'arg2']
        catch error
          threw = true
        finally
          expect(threw).toBe true
          expect(Example.foo).toBeUndefined() # wasn't mixed in!
          expect(mix_opts.premix).toHaveBeenCalledWith(['arg1', 'arg2'])

      it 'should invoke a mixin pre-mixing hook before mixing in', ->
        @mixin.premix = ->
        error = new Error
        threw = false

        spyOn(@mixin, 'premix').and.throwError(error)
        expect(@mixin.foo).toBeDefined()

        class Example

        try
          Example.static_mix @mixin, null, ['arg1', 'arg2']
        catch error
          threw = true
        finally
          expect(threw).toBe true
          expect(Example.foo).toBeUndefined() # wasn't mixed in!
          expect(@mixin.premix).toHaveBeenCalledWith(['arg1', 'arg2'])

      it 'should invoke an options pre-mixing hook before a mixin pre-mixing hook', ->
        call_sequence = []

        mix_opts = {premix: -> call_sequence.push 1}
        @mixin.premix = -> call_sequence.push 2

        spyOn(mix_opts, 'premix').and.callThrough()
        spyOn(@mixin, 'premix').and.callThrough()

        class Example
        Example.static_mix @mixin, mix_opts, ['arg1', 'arg2']

        expect(mix_opts.premix).toHaveBeenCalledWith(['arg1', 'arg2'])
        expect(@mixin.premix).toHaveBeenCalledWith(['arg1', 'arg2'])
        expect(call_sequence).toEqual [1, 2]

    describe 'post-mixing hooks', ->

      beforeEach ->
        @mixin = MIXINS.default_mixin()

      it 'should invoke an options post-mixing hook with the class context', ->
        mix_opts = {postmix: ->}
        spyOn(mix_opts, 'postmix').and.callThrough()

        class Example
        Example.static_mix @mixin, mix_opts, ['arg1', 'arg2']

        expect(mix_opts.postmix).toHaveBeenCalledWith(['arg1', 'arg2'])

        {object, args} = mix_opts.postmix.calls.first()

        # test that the right context was used
        expect(object).toBe Example
        expect(args...).toEqual(['arg1', 'arg2'])

      it 'should invoke a mixin post-mixing hook with the class context', ->
        @mixin.postmix = ->
        spyOn(@mixin, 'postmix').and.callThrough()

        class Example
        Example.static_mix @mixin, null, ['arg1', 'arg2']

        expect(@mixin.postmix).toHaveBeenCalledWith(['arg1', 'arg2'])

        {object, args} = @mixin.postmix.calls.first()

        # test that the right context was used
        expect(object).toBe Example
        expect(args...).toEqual(['arg1', 'arg2'])

      it 'should invoke an options post-mixing hook after mixing in', ->
        mix_opts = {postmix: ->}
        error = new Error
        threw = false

        spyOn(mix_opts, 'postmix').and.throwError(error)
        expect(@mixin.bar).toBe 1

        class Example

        try
          Example.static_mix @mixin, mix_opts, ['arg1', 'arg2']
        catch error
          threw = true
        finally
          expect(threw).toBe true
          expect(Example.bar).toBe 1 # was mixed in!

      it 'should invoke a mixin post-mixing hook after mixing in', ->
        @mixin.postmix = ->
        error = new Error
        threw = false

        spyOn(@mixin, 'postmix').and.throwError(error)
        expect(@mixin.bar).toBe 1

        class Example

        try
          Example.static_mix @mixin, null, ['arg1', 'arg2']
        catch error
          threw = true
        finally
          expect(threw).toBe true
          expect(Example.bar).toBe 1 # was mixed in!

      it 'should invoke an options post-mixing hook before a mixin post-mixing hook', ->
        call_sequence = []

        mix_opts = {postmix: -> call_sequence.push 1}
        @mixin.postmix = -> call_sequence.push 2

        spyOn(mix_opts, 'postmix').and.callThrough()
        spyOn(@mixin, 'postmix').and.callThrough()

        class Example
        Example.static_mix @mixin, mix_opts, ['arg1', 'arg2']

        expect(mix_opts.postmix).toHaveBeenCalledWith(['arg1', 'arg2'])
        expect(@mixin.postmix).toHaveBeenCalledWith(['arg1', 'arg2'])
        expect(call_sequence).toEqual [1, 2]

  describe 'static_mix options', ->

    beforeEach ->
      @mixin = MIXINS.default_mixin()

    describe 'omitting mixin methods', ->

      it 'should omit some mixin keys', ->
        class Example
        Example.static_mix @mixin, omits: ['bar']

        expect(Example.bar).toBeUndefined()
        expect(Example.baz).toBeDefined()

      it 'should throw an error when the omit request is a non-Array or empty Array', ->
        bad_omits_values = [
          []
          {}
          null
          1
          'String'
        ]

        for bad_omits_value in bad_omits_values
          expect(=>
            class Example
            Example.static_mix @mixin, omits: bad_omits_value
          ).toThrow new errors.ValueError "Expected omits option to be a nonempty Array"

      it 'should throw an error when omitting a non-existing mixin key', ->
        expect(=>
          class Example
          Example.static_mix @mixin, omits: ['non_mixin_key']
        ).toThrow new errors.ValueError "Some omit keys aren't in mixin: non_mixin_key"

      it 'should not mangle the class hierarchy when omitting keys', ->
        class Super
          bar: ->
            'bar'

        class Example extends Super
        Example.static_mix @mixin, omits: ['bar']

        e = new Example

        expect(e.bar).toBeDefined()
        expect(e.bar()).toBe('bar')

      it 'should not omit all mixin keys', ->
        expect(=>
          class Example
          Example.static_mix @mixin, omits: ['bar', 'baz', 'foo']
        ).toThrow new errors.ValueError "Found nothing to mix in!"

    describe 'mixin method hooks', ->

      it 'should throw an error when the hook request is not an Array of Strings', ->
        bad_hook_values = [
          'String'
          1
          null
          {}
          true
        ]

        for bad_hook_value in bad_hook_values
          expect(=>
            class Example
            Example.static_mix @mixin, before_hook: bad_hook_value
          ).toThrow new TypeError "before_hook: expected an Array of mixin method names"

      it 'should throw an error when the hook request contains a non-string or empty string', ->
        bad_hook_requests = [
          [
            'mixinmethod_1'
            false
          ]
          [
            null
            'mixinmethod_1'
            'mixinmethod_2'
          ]
          [
            {}
            'mixinmethod_1'
          ]
          [
            'mixinmethod_1'
            1
          ]
          [
            'mixinmethod_1'
            ''
          ]
        ]

        for bad_hook_request in bad_hook_requests
          expect(=>
            class Example
            Example.static_mix @mixin, before_hook: bad_hook_request
          ).toThrow new TypeError "before_hook: expected an Array of mixin method names"

      it 'should throw an error when the hook request contains a non-existent mixin method', ->
        bad_hook_requests = [
          before_hook: [
            'baz'                   # valid method
            'non_existent_method_1' # invalid
            'non_existent_method_2' # invalid
          ], bad_method: 'non_existent_method_1'
          before_hook: [
            'baz' # valid method
            'foo' # non-method property
          ], bad_method: 'foo'
        ]

        for {before_hook, bad_method} in bad_hook_requests
          expect(=>
            class Example
            Example.static_mix @mixin, {before_hook}
          ).toThrow new errors.ValueError "#{bad_method} isn't a method on #{@mixin}"

      it 'should require that a before_hook be implemented when before_hooks are requested', ->
        expect(=>
          class Example
          Example.static_mix @mixin, before_hook: ['baz']
        ).toThrow new errors.NotImplemented "Unimplemented hook: before_baz"

        expect(=>
          class Example
            @before_baz: ->

          Example.static_mix @mixin, before_hook: ['baz']
        ).not.toThrow()

      it 'should require that an after_hook be implemented when after_hooks are requested', ->
        expect(=>
          class Example
          Example.static_mix @mixin, after_hook: ['baz']
        ).toThrow new errors.NotImplemented "Unimplemented hook: after_baz"

        expect(=>
          class Example
            @after_baz: ->

          Example.static_mix @mixin, after_hook: ['baz']
        ).not.toThrow()

      it 'should call the before_hook before the mixin method and pass the return value', ->
        spyOn(@mixin, 'baz').and.callFake (before_value) ->
          [before_value]

        class Example
          @before_baz: ->
            'before_baz'
        Example.static_mix @mixin, before_hook: ['baz']

        expect(Example.baz()).toEqual(['before_baz'])

      it 'should call the after_hook after the mixin method and take the return value', ->
        spyOn(@mixin, 'baz').and.returnValue ['baz']

        class Example
          @after_baz: (baz) ->
            baz.concat ['after_baz']
        Example.static_mix @mixin, after_hook: ['baz']

        expect(Example.baz()).toEqual(['baz', 'after_baz'])
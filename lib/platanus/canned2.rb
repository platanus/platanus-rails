# canned2.rb : User profiling and authorization.
#
# Copyright October 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  # User profiling and authorization module
  module Canned2

    class Interrupt < Exception; end
    class Error < StandardError; end
    class AuthError < Error; end
    class SetupError < Error; end

    # Controller extension, include this in the the base application
    # controller and use the canned_setup method seal it.
    module Controller

      def self.included(klass)
        class << klass
          # Excluded actions and callbacks are defined in per class basis
          attr_accessor :brk_excluded
          attr_accessor :brk_before
        end
        klass.extend ClassMethods
      end

      module ClassMethods

        ## Setups the controller user profile definitions and profile provider block (or proc)
        #
        # The passed method or block must return a list of profiles to be validated
        # by the definition.
        #
        # @param [Definition] _def Profile definitions
        # @param [Symbol] _provider Profile provider method name
        # @param [Block] _block Profile provider block
        #
        def canned_setup(_def, _provider=nil, &_block)
          self.before_filter do

            # no auth if action is excluded
            next if self.class.brk_excluded == :all
            next if !self.class.brk_excluded.nil? and self.class.brk_excluded.include? params[:action].to_sym

            # call initializer block
            profiles = if _provider.nil? then self.instance_eval(&_block) else self.send(_provider) end
            raise AuthError if profiles.nil?
            profiles = [profiles] unless profiles.is_a? Array

            # call resource loader
            brk_before = self.class.brk_before
            unless brk_before.nil?
              if brk_before.is_a? Symbol; self.send(brk_before)
              else self.instance_eval &(brk_before) end
            end

            # execute authentication
            # TODO: Add forbidden begin - rescue
            result = profiles.collect do |profile|
              _def.can?(self, profile, params[:controller]) or
                _def.can?(self, profile, params[:controller] + '#' + params[:action])
            end
            raise AuthError unless result.any?
          end
        end

        ## Removes protection for all controller actions.
        def uncan_all()
          self.brk_excluded = :all
        end

        ## Removes protection for the especified controller actions.
        #
        # @param [splat] _excluded List of actions to be excluded.
        #
        def uncanned(*_excluded)
          self.brk_excluded ||= []
          self.brk_excluded.push(*_excluded)
        end

        ## Specifies a block or method to be called before tests are ran.
        #
        # **IMPORTANT** Resources loaded here are avaliable to tests.
        #
        def before_auth(_callback=nil, &pblock)
          self.brk_before = (_callback || pblock)
        end
      end
    end

    ## Holds all rules associated to a single user profile.
    #
    # This class describes the avaliable DSL when defining a new profile.
    # TODO: example
    class Profile

      attr_reader :rules
      attr_reader :def_matcher
      attr_reader :def_resource

      # The initializer takes another profile as rules base.
      def initialize(_base, _def_matcher, _def_resource)
        @rules = Hash.new { |h, k| h[k] = [] }
        _base.rules.each { |k, tests| @rules[k] = tests.clone } unless _base.nil?
        raise Error.new 'Must provide a default test' if _def_matcher.nil?
        @def_matcher = _def_matcher
        @def_resource = _def_resource
      end

      ## Adds an "allowance" rule
      def allow(_action, _upon=nil, &_block)
        @rules[_action] << (_upon || _block)
      end

      ## Adds a "forbidden" rule
      def forbid(_action)
        # TODO
      end

      ## Clear all rules related to an action
      def clear(_action)
        @rules[_action] = []
      end

      ## SHORT HAND METHODS

      def upon(_expr=nil, &_block)
        Proc.new { upon(_expr, &_block) }
      end

      def upon_one(_expr, &_block)
        Proc.new { upon_one(_expr, &_block) }
      end

      def upon_all(_expr, &_block)
        Proc.new { upon_all(_expr, &_block) }
      end
    end

    ## Rule block context
    class RuleContext

      def initialize(_ctx, _tests, _def_matcher, _def_resource)
        @ctx = _ctx
        @tests = _tests
        @def_matcher = _def_matcher
        @def_resource = UponContext.load_value_for(@ctx, _def_resource)
        @passed = nil
      end

      def passed?; @passed end

      def upon(_res=nil, &_block)
        return if @passed == false
        res = if _res.nil? then @def_resource else UponContext.load_value_for(@ctx, _res) end
        @passed = UponContext.new(res, @ctx, @tests, @def_matcher).instance_eval(&_block)
      end

      def upon_one(_res, &_block)
        return if @passed == false
        coll = if _res.nil? then @def_resource else UponContext.load_value_for(@ctx, _res) end
        # TODO: Check coll type
        @passed = coll.any? { |res| UponContext.new(res, @ctx, @tests, @def_matcher).instance_eval &_block }
      end

      def upon_all(_res, &_block)
        return if @passed == false
        coll = if _res.nil? then @def_resource else UponContext.load_value_for(@ctx, _res) end
        # TODO: Check coll type
        @passed = coll.all? { |res| UponContext.new(res, @ctx, @tests, @def_matcher).instance_eval &_block }
      end

    end

    ## Upon block context.
    # allows '' do
    #   upon(:user_data) { matches(:site_id, using: :equals_int) or matches(:section_id) and passes(:is_owner) }
    #   upon { matches('current_user.site_id', with: :site_id) or matches(:section_id) }
    #   upon(:user) { matches(:site_id) or matches(:section_id) and passes(:test) or holds('user.is_active?') }
    #   upon { holds('@raffle.id == current_user.id') }
    # end
    class UponContext

      def self.load_value_for(_ctx, _key_or_expr)
        return _ctx if _key_or_expr.nil?
        return _ctx[_key_or_expr] if _ctx.is_a? Hash
        return _ctx.send(_key_or_expr) if _key_or_expr.is_a? Symbol
        return _ctx.instance_eval(_key_or_expr)
      end

      def initialize(_res, _ctx, _tests, _def_matcher)
        @res = _res
        @ctx = _ctx
        @tests = _tests
        @def_matcher = _def_matcher
      end

      ## Tests for a match between one of the request's parameters and a resource expression.
      #
      # **IMPORTANT** if no resource is provided the current controller instance is used instead.
      #
      # @param [Symbol] _what parameter name.
      # @param [Symbol] :using matcher (:equals|:equals_int|:higher_than|:lower_than),
      #   uses profile default matcher if not provided.
      # @param [Symbol|String] :on key or expression used to retrieve
      #   the matching value for current resource, if not given then _what is used.
      # @param [Mixed] :value if given, this value is matched against parameter instead of resource's.
      #
      def matches(_what, _options={})
        matcher = _options.fetch(:using, @def_matcher)

        param = @ctx.params[_what]
        return (matcher == :nil) if param.nil? # :nil matcher

        if _options.has_key? :value
          user_value = _options[:value]
        else
          user_value = self.class.load_value_for(@res, _options.fetch(:on, _what))
          return false if user_value.nil?
          return true if user_value == :wildcard
        end

        case matcher
        when :equals; user_value == param
        when :equals_int; user_value.to_i == param.to_i
        when :higher_than; param > user_value
        when :lower_than; param < user_value
        else
          # TODO: use custom matcher.
          false
        end
      end
      alias :match :matches

      ## Test whether the current resource passes a given test.
      #
      # **IMPORTANT** Tests are executed in the current controller context.
      #
      # @param [Symbol] _test test identifier.
      # @param [Symbol|String] :on optional key or expression used to retrieve
      #   from the resource the value to be passed to the test instead of the resource.
      #
      def certifies(_test, _options={})
        test = @tests[_test]
        raise SetupError.new "Invalid test identifier '#{_test}'" if test.nil?
        if test.arity == 1
          user_value = self.class.load_value_for(@res, _options[:on])
          @ctx.instance_exec(user_value, &test)
        else @ctx.instance_eval &test end
      end
      alias :checks :certifies

      ## Tests whether a given expression evaluated in the resource context returns true.
      #
      # **IMPORTANT** if no resource is provided the current controller instance is used instead.
      #
      # @param [Symbol|String] _what if symbol, then send is used to call a context's
      #   function with that name, if a string, then instance_eval is used to evaluate it.
      def holds(_what)
        _what.is_a? Symbol ? @res.send(_what) : @res.instance_eval(_what.to_s)
      end

    end

    ## Definition module
    #
    # This module is used to generate a canned definition that can later
    # be refered when calling "canned_setup".
    #
    # TODO: Usage
    #
    module Definition

      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods

        @@tests = {}
        @@profiles = {}

        ## Defines a new test that can be used in "certifies" instructions
        #
        # **IMPORTANT** Tests are executed in the controller's context and
        # passed the tested resource as parameter (only if arity == 1)
        #
        # @param [Symbol] _name test identifier
        # @param [Block] _block test block
        #
        def test(_name, &_block)
          raise SetupError.new "Invalid test arity for '#{_name}'" if _block.arity > 1
          raise SetupError.new "Duplicated test identifier" if @@tests.has_key? _name
          @@tests[_name] = _block
        end

        ## Creates a new profile and evaluates the given block using the profile context.
        #
        # @param [String|Symbol] _name Profile name.
        # @param [String|Symbol] :inherits Name of profile to inherit rules from.
        # @param [Symbol] :matcher Default matcher for matches tests
        # @param [Symbol] :resource Default resource for upon expressions
        #
        def profile(_name, _options={}, &_block)
          profile = @@profiles[_name.to_s] = Profile.new(
            @@profiles[_options.fetch(:inherits, nil).to_s],
            _options.fetch(:matcher, :equals),
            _options.fetch(:resource, nil)
          )
          profile.instance_eval &_block
        end

        # @api callback
        def can?(_ctx, _profile, _action)
          profile = @@profiles[_profile.to_s]
          return if profile.nil?
          profile.rules[_action].any? do |rule|
            next true if rule.nil?
            rule_ctx = RuleContext.new _ctx, @@tests, profile.def_matcher, profile.def_resource
            rule_ctx.instance_eval(&rule)
            rule_ctx.passed?
          end
        end
      end
    end
  end
end
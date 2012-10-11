# canned.rb : User profiling and authorization.
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  # User profiling and authorization module
  module Canned

    class Interrupt < Exception; end
    class Error < StandardError; end
    class AuthError < Error; end

    # Controller extension, include this in the the base application
    # controller and use the barracks_setup method to define the profiles
    # definition object and the user profile provider block.
    module ControllerExt

      attr_accessor :brk_tag

      def self.included(klass)
        class << klass
          # Excluded actions are defined in per class basis
          attr_accessor :brk_excluded
        end
        protected
        # Definition and role provider are shared with subclasses
        klass.cattr_accessor :brk_definition
        klass.cattr_accessor :brk_provider
        public
        klass.extend ClassMethods
      end

      # Wraps a controller instance and provides the profile
      # testing enviroment used by the role provider function.
      class ActionWrapper

        attr_reader :tag

        # Loads the testing enviroment.
        def initialize(_owner, _action, _actions_feats)
          @owner = _owner
          @action = _action
          @feats = _actions_feats
          @tag = nil
        end

        # Test if a profile can execute the current action, raises a
        # Interrupt exception if conditions are met.
        def test(_profile, _user_feats, _tag=nil)
          if @owner.class.brk_definition.can?(_profile, @action, @feats, _user_feats)
            @tag = _tag
            raise Interrupt
          end
        end

        # Since we need to provide with all of controller functionality
        # to provider, then proxy al failed method calls to it.
        def method_missing(_method, *_args, &_block)
          @owner.send(_method, *_args, &_block)
        end
      end

      # Test if an action can be executed using the currently loaded roles.
      def can?(_action, _action_feat)
        wrapper = ActionWrapper.new(self, _action, _action_feat)
        begin
          provider = if brk_provider.is_a? Symbol then self.method(brk_provider) else brk_provider end
          wrapper.instance_eval &provider
          return false
        rescue Interrupt
          return (if wrapper.tag.nil? then true else wrapper.tag end)
        end
      end

      module ClassMethods

        # Setups the controller user profile definitions and
        # profile provider block (or proc)
        def canned_setup(_definition, _provider=nil, &pblock)
          self.brk_definition = _definition
          self.brk_provider = _provider || pblock
          self.before_filter do
            # Before filter is an instance_eval?
            break if self.class.brk_excluded == :all
            break if !self.class.brk_excluded.nil? and self.class.brk_excluded.include? params[:action].to_sym
            tag = self.can?(params[:controller], params)
            tag ||= self.can?(params[:controller] + '#' + params[:action], params)
            raise AuthError unless tag
            self.brk_tag = tag
          end
        end

        # Removes protection for all controller actions.
        def uncan_all()
          self.brk_excluded = :all
        end

        # Removes protection for the especified controller actions.
        def uncanned(*_excluded)
          self.brk_excluded ||= []
          self.brk_excluded.push(*_excluded)
        end
      end
    end

    # Profile DSL
    module ProfileManager

      # Auxiliary class used by profile manager to store profiles.
      class BProfile

        attr_reader :rules
        attr_reader :def_test

        # The initializer takes another profile as rules base.
        def initialize(_owner, _base, _def_test)
          @owner = _owner
          @rules = Hash.new { |h, k| h[k] = [] }
          _base.each { |k, tests| @rules[k] = tests.clone } unless _base.nil?
          @def_test = _def_test
        end

        # Adds a new ability.
        def ability(*_args)
          tests = {}
          if _args.last.is_a? Hash
            _args[1...-1].each { |sym| tests[sym] = @def_test }
            tests.merge!(_args.last)
          else
            _args[1..-1].each { |sym| tests[sym] = @def_test }
          end
          @rules[_args.first] << tests
        end

        # Removes an action by its name.
        def clean(_name)
          @rules.delete(_name)
        end

        # Test an action agaist this profile
        def test(_action, _action_feats, _user_feats)
          return false unless tests.has_key? _action

          # if any of the test groups passes, then test is passed.
          @rules[_action].each do |tests|
            return true if self.test_aux(tests, _action_feats, _user_feats)
          end

          return false
        end

        # Run a test group over a set of features
        def test_aux(_tests, _action_feats, _user_feats)

          _tests.each do |sym, test|

            # Analize test.
            if test.is_a? Hash
              test_name = test.fetch(:name, @def_test)
              test_transform = test[:transform]
              user_sym = test.fetch(:key, sym)
            else
              test_name = test
              test_transform = nil
              user_sym = sym
            end

            # Extract user and action features.
            action_feat = _action_feats[sym]
            return false if action_feat.nil?
            user_feat = _user_feats[user_sym]
            return false if user_feat.nil?
            next if user_feat == :wildcard # Wildcard matches always

            # Compare features.
            action_feat = @owner.send(test_transform,action_feat) unless test_transform.nil?
            case test_name
            when :equals
              return false unless user_feat == action_feat
            when :equals_int
              return false unless user_feat.to_i == action_feat.to_i
            when :if_higher
              return false unless user_feat > action_feat
            when :if_lower
              return false unless user_feat < action_feat
            else
              # TODO: Check that method exists first.
              if @owner.method_defined? test_name
                return false unless @owner.send(test_name, action_feat, user_feat)
              end
            end
          end

          return true
        end
      end

      def self.included(base)
        class << base
          # Add a profile property to extended class
          attr_accessor :profiles
        end
        base.profiles = {}
        base.extend ClassMethods
      end

      module ClassMethods

        # Creates a new profile and passes it to the given block.
        # This can optionally take an inherit parameter to use
        # another profile as base for the new one.
        def profile(_name, _options={})
          yield self.profiles[_name.to_s] = BProfile.new(
            self,
            self.profiles[_options.fetch(:inherits, nil)],
            _options.fetch(:default, :equals)
          )
        end

        # Test if a user (profile + user data) can execute a given
        # action (action name + action data).
        def can?(_profile, _action, _action_feat, _user_feat)
          profile = self.profiles[_profile.to_s]
          return false if profile.nil?
          return profile.test(_action, _action_feat, _user_feat)
        end
      end
    end
  end
end
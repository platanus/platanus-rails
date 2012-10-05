# stacked.rb : Stackable attributes for ActiveRecord
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  ## Adds the has_stacked association to an ActiveRecord model.
  #
  # TODO
  #
  module StackedAttr

    class NotSupportedError < StandardError; end

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      # Adds an stacked attribute to the model.
      def has_stacked(_name, _options={})

        # check option support
        raise NotSupportedError.new('Only autosave mode is supported') if _options[:autosave] == false
        raise NotSupportedError.new('has_many_through is not supported yet') if _options.has_key? :through

        # prepare names
        tname = _name.to_s
        tname_single = tname.singularize
        tname_class = _options.fetch(:class_name, tname_single.camelize)

        # generate top_value property
        top_value_prop = "top_#{tname_single}"
        if _options.has_key? :top_value_key
          belongs_to top_value_prop.to_sym, class_name: tname_class, foreign_key: _options.delete(:top_value_key)
        elsif self.column_names.include? "#{top_value_prop}_id"
          belongs_to top_value_prop.to_sym, class_name: tname_class
        else
          send :define_method, top_value_prop do
            # Storing the last stacked value will not prevent race conditions
            # when simultaneous updates occur.
            return @_stacked_last unless @_stacked_last.nil?
            @_stacked_last = self.send(tname).first
          end
          send :define_method, "#{top_value_prop}=" do |_top|
            @_stacked_last = _top
          end
        end
        send :private, "#{top_value_prop}="

        # prepare cached attributes
        to_cache = _options.delete(:cached)
        to_cache_prf = if _options[:cache_prf].nil? then 'last_' else _options.delete(:cache_prf) end # TODO: deprecate

        unless to_cache.nil?
          to_cache = to_cache.map do |cache_attr|
            unless cache_attr.is_a? Hash
              name = cache_attr.to_s
              # attr_protected(to_cache_prf + name)
              send :define_method, name do self.send(to_cache_prf + name) end # generate read-only aliases without prefix. TODO: deprecate
              { to: to_cache_prf + name, from: name }
            else
              # TODO: Test whether options are valid.
              cache_attr
            end
          end
        end

        # callbacks
        on_stack = _options.delete(:on_stack)

        # limits and ordering
        # TODO: Support other kind of ordering, this would require to reevaluate top on every push
        _options[:order] = 'created_at DESC, id DESC'
        _options[:limit] = 10 if _options[:limit].nil?

        # setup main association
        has_many _name, _options

        cache_step = ->(_ctx, _top) {
          # cache required fields
          return if to_cache.nil?
          to_cache.each do |cache_attr|
            value = if cache_attr.has_key? :from
              _top.nil? ? _top : _top.send(cache_attr[:from])
            else
              _ctx.send(cache_attr[:virtual], _top)
            end
            _ctx.send(cache_attr[:to].to_s + '=', value)
          end
        }

        after_step = ->(_ctx, _top) {
          # update top value property
          _ctx.send("#{top_value_prop}=", _top)

          # execute after callback
          _ctx.send(on_stack, _top) unless on_stack.nil?
        }

        send :define_method, "push_#{tname_single}!" do |obj|
          self.class.transaction do

            # cache, then save if new, then push and finally process state
            cache_step.call(self, obj)
            self.save! if self.new_record? # make sure there is an id BEFORE pushing
            raise ActiveRecord::RecordInvalid.new(obj) unless send(tname).send('<<',obj)
            after_step.call(self, obj)

            self.save! if self.changed? # Must save again, no other way...
          end
        end

        send :define_method, "push_#{tname_single}" do |obj|
          begin
            return send("push_#{tname_single}!", obj)
          rescue ActiveRecord::RecordInvalid
            return false
          end
        end

        send :define_method, "restore_#{tname}!" do
          self.class.transaction do

              # find current top, then restore stack state
              top = self.send(_name).first
              cache_step.call(self, top)
              after_step.call(self, top)

              self.save! if self.changed?
          end
        end

        send :define_method, "restore_#{tname}" do
          begin
            return send("restore_#{tname}!")
          rescue ActiveRecord::RecordInvalid
            return false
          end
        end
      end
    end
  end
end
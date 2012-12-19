# stacked.rb : Stackable attributes for ActiveRecord
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  ## Adds the has_stacked association to an ActiveRecord model.
  #
  # TODO: Investigate how to turn this into an authentic association.
  #
  module StackedAttr2

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
        tname_class = _options.fetch :class_name, tname_single.camelize
        stacked_model = tname_class.constantize
        prefix = if _options[:cache_prf].nil? then 'last_' else _options.delete(:cache_prf) end # TODO: deprecate?

        # Generate top_value property
        #
        # How this property is generated can vary depending on given parameters or table structure:
        # * If a top_value_key is provided in options, then a belongs_to association is created using it as foreign key.
        # * If a top_xxx_id column is present, then a belongs_to association is created using if as foreign key.
        # * If no key is provided, then a shorcut method that retrieves the stack's top is generated
        #
        top_value_prop = "top_#{tname_single}"
        top_value_key = if _options.has_key? :top_value_key
          belongs_to top_value_prop.to_sym, class_name: tname_class, foreign_key: _options[:top_value_key], autosave: true
          _options.delete(:top_value_key)
        elsif self.column_names.include? "#{top_value_prop}_id"
          belongs_to top_value_prop.to_sym, class_name: tname_class, autosave: true
          "#{top_value_prop}_id"
        else
          top_value_var = "@_stacked_#{tname}_top".to_sym
          send :define_method, top_value_prop do
            # Storing the last stacked value will not prevent race conditions
            # when simultaneous updates occur.
            last = instance_variable_get top_value_var
            return last unless last.nil?
            instance_variable_set(top_value_var, self.send(tname).first)
          end
          nil
        end

        # Prepare cached attributes
        #
        # Attribute caching allows the parent model to store the top value for
        # some of the stacked model attributes (defined in options using the cached key)
        #
        to_cache = _options.delete(:cached)
        if to_cache
          to_cache = to_cache.map do |cache_attr|
            unless cache_attr.is_a? Hash
              name = cache_attr.to_s
              # attr_protected(prefix + name)
              { to: prefix + name, from: name }
            else
              # TODO: Test whether options are valid.
              cache_attr
            end
          end
        end

        # Generate mirroring attributes (if mirroring is active)
        #
        # Mirroring allows using the top value attributes in the parent model,
        # it also allows modifying the attributes in the parent model, if the model is
        # then saved, the modified attributes are wrapped in a new stack model object and put
        # on top.
        #
        mirror_cache_var = "@_stacked_#{tname}_mirror".to_sym
        if _options.delete(:mirroring)
          stacked_model.accessible_attributes.each do |attr_name|

            unless self.method_defined? "#{attr_name}="
              send :define_method, "#{attr_name}=" do |value|
                mirror = instance_variable_get(mirror_cache_var)
                mirror = instance_variable_set(mirror_cache_var, {}) if mirror.nil?
                mirror[attr_name] = value
              end
            else
              Rails.logger.warn "stacked: failed to mirror setter for #{attr_name} in #{self.to_s}"
            end

            unless self.method_defined? attr_name
              send :define_method, attr_name do
                mirror = instance_variable_get(mirror_cache_var)
                return mirror[attr_name] if !mirror.nil? and mirror.has_key? attr_name

                return self.send(prefix + attr_name) if self.respond_to? prefix + attr_name # return cached value if avaliable
                top = self.send top_value_prop
                return nil if top.nil?
                return top.send attr_name
              end

              attr_accessible attr_name
            else
              Rails.logger.warn "stacked: failed to mirror getter for #{attr_name} in #{self.to_s}"
            end
          end
        end

        # setup main association
        # TODO: Support other kind of ordering, this would require to reevaluate top on every push
        _options[:order] = 'created_at DESC, id DESC'
        _options[:limit] = 10 if _options[:limit].nil?
        has_many _name, _options

        # register callbacks
        define_callbacks "stack_#{tname_single}"

        # push logic
        __push = ->(_ctx, _top, _top_is_new, _save_top, _proc) do
          _ctx.run_callbacks "stack_#{tname_single}", _top, _top_is_new do

            # cache required fields
            if to_cache
              to_cache.each do |cache_attr|
                value = if cache_attr.has_key? :from
                  _top.nil? ? _top : _top.send(cache_attr[:from])
                else
                  _ctx.send(cache_attr[:virtual], _top, _top_is_new)
                end
                _ctx.send(cache_attr[:to].to_s + '=', value)
              end
            end

            _proc.call if _proc

            if _top_is_new
              # Save if new
              raise ActiveRecord::RecordInvalid.new(_top) unless send(tname).send('<<', _top)

              if top_value_key
                if _save_top
                  self.update_column(top_value_key, _top.id)
                  _ctx.send(top_value_prop, false) # reset belongs_to cache
                else
                  _ctx.send("#top_value_prop}=", _top)
                end
              else
                instance_variable_set(top_value_var, _top)
              end
            end
          end
        end

        # before saving model, load changes from virtual attributes.
        set_callback :save, :around do

          mirror = instance_variable_get(mirror_cache_var)
          if !mirror.nil? and mirror.count > 0

            # propagate non cached attributes (only if record is not new and there is a top state)
            unless self.new_record?
              top = self.send top_value_prop
              unless top.nil?
                stacked_model.accessible_attributes.each do |attr_name|
                  mirror[attr_name] = top.send(attr_name) unless mirror.has_key? attr_name
                end
              end
            end

            obj = stacked_model.new(mirror)
            instance_variable_set(mirror_cache_var, {}) # reset mirror changes
            __push.call(self, obj, true, true, Proc.new { yield })

          else yield end
        end

        send :define_method, "push_#{tname_single}!" do |obj|
          self.class.transaction do
            __push.call(self, _top, true, false, Proc.new { self.save! if self.new_record? })
            self.save! if self.changed?
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
            __push.call(self, self.send(_name).first, false, false, nil)
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
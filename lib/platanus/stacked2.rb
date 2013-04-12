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
            return last unless last.nil? or !last.persisted?
            instance_variable_set(top_value_var, self.send(tname).all.first)
          end
          nil
        end

        # When called inside callbacks, returns the new value being put at top of the stack.
        new_value_var = "@_stacked_#{tname}_new"
        send :define_method, "#{top_value_prop}_will" do
          instance_variable_get(new_value_var)
        end

        # When called inside callbacks, will return the top value unless a new value is
        # being pushed, in that case it returns the new value
        last_value_var = "@_stacked_#{tname}_last"
        send :define_method, "#{top_value_prop}_is" do
          instance_variable_get(last_value_var)
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

        # register callbacks
        define_callbacks "stack_#{tname_single}"

        # push logic
        __update_stack = ->(_ctx, _top, _new_top, _save_quiet, &_block) do
          begin
            # make xx_top_value avaliable for event handlers
            _ctx.instance_variable_set(new_value_var, _top) if _new_top
            _ctx.instance_variable_set(last_value_var, _top)

            _ctx.run_callbacks "stack_#{tname_single}" do

              # cache required fields
              # TODO: improve cache: convention over configuration!
              # cache should be automatic given certain column names and should include aliased attribues and virtual attributes.
              # has_stacked :things, cache: { prefix: '', aliases: { xx => xx }, exclude: [], virtual: { xx => xx } }
              if to_cache
                to_cache.each do |cache_attr|
                  value = if cache_attr.has_key? :from
                    _top.nil? ? nil : _top.send(cache_attr[:from])
                  else
                    _ctx.send(cache_attr[:virtual])
                  end
                  _ctx.send(cache_attr[:to].to_s + '=', value)
                end
              end

              _block.call if _block

              if _new_top
                # TODO: this leaves the invalid record on top of the stack and invalid cached values,
                # maybe validation should ocurr before caching...
                raise ActiveRecord::RecordInvalid.new(_top) unless _ctx.send(tname) << _top
              end

              # reset top_value_prop to top
              if top_value_key
                if _save_quiet
                  top_id = if _top.nil? then nil else _top.id end
                  if _ctx.send(top_value_key) != top_id
                    _ctx.update_column(top_value_key, top_id)
                    _ctx.send(top_value_prop, false) # reset belongs_to cache
                  end
                else
                  _ctx.send("#{top_value_prop}=", _top)
                end
              else
                _ctx.instance_variable_set(top_value_var, _top)
              end
            end
          ensure
            _ctx.instance_variable_set(new_value_var, nil)
            _ctx.instance_variable_set(last_value_var, nil)
          end
        end

        # Attribute mirroring
        #
        # Mirroring allows using the top value attributes in the parent model,
        # it also allows modifying the attributes in the parent model, if the model is
        # then saved, the modified attributes are wrapped in a new stack model object and put
        # on top.
        #
        mirror_cache_var = "@_stacked_#{tname}_mirror".to_sym
        if _options.delete(:mirroring)
          stacked_model.accessible_attributes.each do |attr_name|

            if self.method_defined? "#{attr_name}="
              Rails.logger.warn "stacked: overriding setter for #{attr_name} in #{self.to_s}"
            end

            if self.method_defined? attr_name
              Rails.logger.warn "stacked: overriding getter for #{attr_name} in #{self.to_s}"
            end

            send :define_method, "#{attr_name}=" do |value|
              mirror = instance_variable_get(mirror_cache_var)
              mirror = instance_variable_set(mirror_cache_var, {}) if mirror.nil?
              mirror[attr_name] = value
            end

            send :define_method, attr_name do
              mirror = instance_variable_get(mirror_cache_var)
              return mirror[attr_name] if !mirror.nil? and mirror.has_key? attr_name

              return self.send(prefix + attr_name) if self.respond_to? prefix + attr_name # return cached value if avaliable
              top = self.send top_value_prop
              return nil if top.nil?
              return top.send attr_name
            end

            send :define_method, "#{attr_name}_changed?" do
              mirror = instance_variable_get(mirror_cache_var)
              return true if !mirror.nil? and mirror.has_key? attr_name
              return self.send(prefix + attr_name + '_changed?') if self.respond_to? prefix + attr_name + '_changed?' # return cached value if avaliable
              return true # for now just return true for non cached attributes
            end

            attr_accessible attr_name
          end

          # before saving model, load changes from virtual attributes.
          set_callback :save, :around do |&_block|

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
              __update_stack.call(self, obj, true, true, &_block)

            else _block.call end
          end
        end

        # Push methods

        send :define_method, "push_#{tname_single}!" do |obj|
          self.class.transaction do
            __update_stack.call(self, obj, true, false) { self.save! if self.new_record? }
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

        # Restore methods

        send :define_method, "restore_#{tname}!" do
          self.class.transaction do
            top = self.send(tname).all.first
            __update_stack.call(self, top, false, false)
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

        # setup main association
        # TODO: Support other kind of ordering, this would require to reevaluate top on every push
        _options[:order] = 'created_at DESC, id DESC'
        _options[:limit] = 1 if _options[:limit].nil?
        _options.delete(:limit) if _options[:limit] == :no_limit
        has_many _name, _options
      end
    end
  end
end
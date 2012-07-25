# stacked.rb : Stackable attributes for ActiveRecord
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  # Adds the has_stacked association to an ActiveRecord model.
  #
  module StackedAttr

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      # Adds an stacked attribute to the model.
      def has_stacked(_name, _options={}, &block)

        tname = _name.to_s
        to_cache = _options.delete(:cached)
        to_cache_prf = if _options[:cache_prf].nil? then 'last_' else _options.delete(:cache_prf) end
        stack_key = if _options[:stack_key].nil? then 'created_at DESC, id DESC' else _options.delete(:stack_key) end

        # Retrieve callbacks
        before_push = _options.delete(:before_push)
        after_push = _options.delete(:after_push)

        _options[:order] = stack_key
        _options[:limit] = 10 if _options[:limit].nil?

        # Protect cached attributes.
        unless to_cache.nil?
          to_cache = to_cache.map { |name| name.to_s }
          to_cache.each { |name| attr_protected(to_cache_prf + name) }
        end

        private
        has_many(_name,_options)
        public

        send :define_method, 'push_' + tname[0...-1] + '!' do |obj|
          self.class.transaction do

            # Execute before callbacks
            self.send(before_push, obj) unless before_push.nil?
            block.call(self, obj) unless block.nil?

            # Cache required fields
            unless to_cache.nil?
              to_cache.each { |name| send(to_cache_prf + name + '=', obj.send(name)) }
            end

            # Save model and push attribute, cache last stacked attribute.
            self.save! if _options.fetch(:autosave, true) and (self.new_record? or self.changed?)
            raise ActiveRecord::RecordInvalid.new(obj) unless self.send(tname).send('<<',obj)
            @_stacked_last = obj

            # Execute after callback
            self.send(after_push, obj) unless after_push.nil?
          end
        end

        send :define_method, 'push_' + tname[0...-1] do |obj|
          begin
            return self.send('push_' + tname[0...-1] + '!', obj)
          rescue ActiveRecord::RecordInvalid
            return false
          end
        end

        send :define_method, 'top_' + tname[0...-1] do
          # Storing the last stacked value will not prevent race conditions
          # when simultaneous updates occur.
          return @_stacked_last unless @_stacked_last.nil?
          self.send(_name).first
        end

        # Generate shorcut properties for cached attributes.
        unless to_cache.nil?
          to_cache.each do |name|
            send :define_method, name.to_s do
              self.send(to_cache_prf + name)
            end
          end
        end
      end
    end
  end
end
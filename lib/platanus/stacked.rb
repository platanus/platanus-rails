# stacked.rb : Stackable attributes for ActiveRecord
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus

  # Adds the has_stacked association to an ActiveRecord model.
  #
  module StackedAttr

    class NotSupportedError < StandardError; end

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      # Adds an stacked attribute to the model.
      def has_stacked(_name, _options={}, &block)

        tname = _name.to_s
        tname_single = tname.singularize

        to_cache = _options.delete(:cached)
        to_cache_prf = if _options[:cache_prf].nil? then 'last_' else _options.delete(:cache_prf) end

        # Retrieve callbacks
        before_push = _options.delete(:before_push)
        after_push = _options.delete(:after_push)

        raise NotSupportedError.new('Only autosave mode is supported') if _options[:autosave] == false

        _options[:order] = 'created_at DESC, id DESC'
        _options[:limit] = 10 if _options[:limit].nil?

        # Prepare cached attributes, generate read-only aliases without prefix.
        unless to_cache.nil?
          to_cache = to_cache.map do |name|
            name = name.to_s; fullname = to_cache_prf + name
            attr_protected(fullname)
            send :define_method, name { self.send(fullname) }
            fullname
          end
        end

        private
        has_many _name, _options
        public

        send :define_method, "push_#{tname_single}!" do |obj|
          self.class.transaction do

            # execute before callbacks
            self.send(before_push, obj) unless before_push.nil?
            block.call(self, obj) unless block.nil?

            # cache required fields
            unless to_cache.nil?
              to_cache.each { |name| send(name + '=', obj.send(name)) }
            end

            # push attribute, this will save the model if new.
            raise ActiveRecord::RecordInvalid.new(obj) unless self.send(tname).send('<<',obj)

            # update inverse association if posible
            if self.attributes.has_key? "top_#{tname_single}_id"
              self["top_#{tname_single}_id"] = obj.id
            else
              @_stacked_last = obj
            end

            # execute after callback
            self.send(after_push, obj) unless after_push.nil?

            self.save! if self.changed? # Must save again, no other way...
          end
        end

        send :define_method, "push_#{tname_single}" do |obj|
          begin
            return self.send("push_#{tname_single}!", obj)
          rescue ActiveRecord::RecordInvalid
            return false
          end
        end

        unless self.column_names.include? "top_#{tname_single}_id"
          send :define_method, "top_#{tname_single}" do
            # Storing the last stacked value will not prevent race conditions
            # when simultaneous updates occur.
            return @_stacked_last unless @_stacked_last.nil?
            @_stacked_last = self.send(_name).first
          end
        end
      end
    end
  end
end
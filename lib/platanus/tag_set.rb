# tag_set_attr.rb : searchable tag sets.
#
# usage:
#
#     class Model
#       include Platanus::TagSetAttr
#
#       attr_tagset :demo
#     end
#
#     t = Model.create
#     t.demo << 'tag1'
#     t.demo << 'tag2'
#     t.save!
#
#     t.demo # returns ['tag1', 'tag2']
#
#     #searching
#     Model.search_by_demo(all: 'tag1') # returns [t]
#     Model.search_by_demo(all: 'tag1', none: 'tag2') # returns []
#
# # TODO: provide fulltext search support.
#
# Copyright February 2013, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus::TagSetAttr

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods

    # Adds a tag list attribute to the model.
    def attr_tagset(_name, _options={})

      _name = _name.to_s

      send :serialize, _name, Platanus::Serializers::TagSet

      klass = class << self; self; end

      klass.send :define_method, "search_by_#{_name.singularize}" do |_opt={}|

        target = self

        # The 'any' filter matches if one of the tokens match
        if _opt.has_key? :any
          params = []; any_sql = []
          Array(_opt[:any]).collect do |token|
            params << "%::#{token}::%"
            any_sql << "#{_name} LIKE ?"
          end
          target = target.where("(#{or_sql.join(' OR ')})", *params) if params.length > 0
        end

        # The 'all' filter matches if all of the tokens match
        if _opt.has_key? :all
          params = []; and_sql = []
          Array(_opt[:all]).each do |token|
            params << "%::#{token}::%"
            and_sql << "#{_name} LIKE ?"
          end
          target = target.where("#{and_sql.join(' AND ')}", *params) if params.length > 0
        end

        # The 'none' filter matches if none of the tokens match
        if _opt.has_key? :none
          params = []; ex_sql = []
          Array(_opt[:none]).each do |token|
            params << "%::#{token}::%"
            ex_sql << "#{_name} NOT LIKE ?"
          end
          target = target.where("#{_name} is NULL OR (#{ex_sql.join(' AND ')})", *params) if params.length > 0
        end

        return target
      end
    end
  end
end

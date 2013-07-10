# tag_set.rb : word search optimized list serialization
#
# TODO: make notation compatible with fulltext-search.
#
# Copyright October 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

module Platanus
  module Serializers
    class TagSet

      def self.load(_str)
        return [] if _str.nil?
        return [] if _str == '::::'
        _str.split('::')[1..-1]
      end

      def self.dump(_data)
        "::#{_data.join('::')}::"
      end
    end
  end
end
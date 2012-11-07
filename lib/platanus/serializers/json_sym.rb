# json_sym.rb : Symbolized keys json serializer.
#
# Copyright October 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

class JSONSym

  def self.load(_str)
    return nil if _str.nil? or str == "null"
    MultiJson.load(_str, symbolize_keys: true)
  end

  def self.dump(_data)
    MultiJson.dump(_data)
  end

end
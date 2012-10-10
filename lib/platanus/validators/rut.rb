# validators/rut.rb : Chilean rut validator for active record
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

## Adds the "rut" validation to active record models
#
# Usage:
#
#   validates :rut_col, rut: true
#
class RutValidator < ActiveModel::EachValidator

  def validate_each(_record, _attribute, _value)
    return if _value.nil?
    begin
      t = _value.gsub(/[^0-9K]/i,'').[0...-1].to_i
      m, s = 0, 1
      while t > 0
        s = (s + t%10 * (9 - m%6)) % 11
        m += 1
        t /= 10
      end
      v = if s > 0 then (s-1).to_s else 'K' end
      r = (v == _value.last.upcase)
    rescue Exception => e
      r = false
    end
    _record.errors[_attribute] << (options[:message] || "is invalid") unless r
  end

end
# validators/email.rb : Email validator for active record
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.us+.

require 'mail'

## Adds the "email" validation to active record
#
# Usage:
#
#   validates :email_col, email: true
#
class EmailValidator < ActiveModel::EachValidator
  def validate_each(_record, _attribute, _value)
    return if _value.nil?
    begin
      mail = Mail::Address.new(_value)
      # We must check that value contains a domain and that value is an email address
      res = mail.domain && mail.address == _value
      tree = mail.__send__(:tree)
      # We need to dig into treetop
      # A valid domain must have dot_atom_text elements size > 1
      # user@localhost is excluded
      # treetop must respond to domain
      # We exclude valid email values like <user@localhost.com>
      # Hence we use mail.__send__(tree).domain
      res &&= (tree.domain.dot_atom_text.elements.size > 1)
    rescue Exception => e
      res = false
    end
    _record.errors[_attribute] << (options[:message] || "is invalid") unless res
  end
end
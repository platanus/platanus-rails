# spreadsheet.rb : Spreadsheet - Rails Templates integration.
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.ius+.

require 'spreadsheet'

Mime::Type.register 'application/vnd.ms-excel', :xls

module Platanus

  # Template Handler, just exposes a spreadsheet's Workbook to a template.
  class ExcelBuilder

    class_attribute :default_format
    self.default_format = Mime::XLS

    def self.call(template)
      "book = ::Spreadsheet::Workbook.new;" + template.source + ";io=StringIO.new('');book.write io;io.close;io.string;"
    end
  end
end

# Register the template handler for the .spreadsht extension
ActionView::Template.register_template_handler :spreadsht, Platanus::ExcelBuilder
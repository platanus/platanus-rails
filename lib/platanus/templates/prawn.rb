# prawn.rb : Prawn - Rails Templates integration.
#
# Copyright April 2012, Ignacio Baixas +mailto:ignacio@platan.ius+.

require 'prawn'

Mime::Type.register 'application/pdf', :pdf

module Platanus

  # Template Handler, just exposes prawn to a template.
  class PrawnBuilder

    class_attribute :default_format
    self.default_format = Mime::PDF

    def self.call(template)
      # Create a new pdf doc object using a block, populate the block using
      # the template contents.
      "pdf = Prawn::Document.new(:skip_page_creation => true);" + template.source + ";pdf.render;"
    end
  end
end

# Register the template handler for the .prawn extension.
ActionView::Template.register_template_handler :prawn, Platanus::PrawnBuilder
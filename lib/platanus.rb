require "platanus/version"

require 'platanus/canned'     # TODO: deprecated, remove

# Serializers
require 'platanus/serializers/tag_set'
require 'platanus/serializers/json_sym'

# active record behaviors
require 'platanus/stacked'    # TODO: deprecated, remove
require 'platanus/activable'
require 'platanus/traceable'
require 'platanus/layered'    # TODO: deprecated, remove

# active record attribute related
require 'platanus/tag_set'
require 'platanus/enum'
require 'platanus/model_shims'
# require 'platanus/onetime'  # TODO: deprecated, remove

# boilerplate
require 'platanus/http_helpers' # TODO: deprecate in favor of api_boilerplate => first improve boilerplate

# require 'platanus/gcontroller'

# Template engines connectors
# require 'platanus/template/spreadsheet'
# require 'platanus/template/prawn'

module Platanus
  # Your code goes here...
end

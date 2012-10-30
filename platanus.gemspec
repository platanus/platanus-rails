# -*- encoding: utf-8 -*-
require File.expand_path('../lib/platanus/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ignacio Baixas"]
  gem.email         = ["ignacio@platan.us"]
  gem.description   = %q{Platan.us utility gem}
  gem.summary       = %q{This gem contains various ruby classes used by Platanus in our rails proyects}
  gem.homepage      = "http://www.platan.us"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "platanus"
  gem.require_paths = ["lib","lib/platanus"]
  gem.version       = Platanus::VERSION

  gem.add_runtime_dependency "multi_json", [">= 1.3.2"]
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'harbor/version'

Gem::Specification.new do |spec|
  spec.name          = "harbor_cli"
  spec.version       = Harbor::VERSION
  spec.authors       = ["Adrian Pike"]
  spec.email         = ["adrian@adrianpike.com"]
  spec.summary       = %q{harbor_cli is the CLI for interacting with Harbor.}
#  spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = "http://adrianpike.github.io/harbor"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end

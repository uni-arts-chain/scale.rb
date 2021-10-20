lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "scale/version"

Gem::Specification.new do |spec|
  spec.name = "scale.rb"
  spec.version = Scale::VERSION
  spec.authors = ["Wu Minzhe"]
  spec.email = ["wuminzhe@gmail.com"]

  spec.summary = "Ruby SCALE Codec Library"
  spec.description = "Ruby implementation of the parity SCALE data format"
  spec.homepage = "https://github.com/itering/scale.rb"
  spec.license = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"

    spec.metadata["homepage_uri"] = spec.homepage
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "blake2b_rs", "~> 0.1.2"
  spec.add_dependency "xxhash"
  spec.add_dependency "base58"
  spec.add_dependency "json", "~> 2.3.0"
  spec.add_dependency "faye-websocket"
  spec.add_dependency "thor", '~> 0.19'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "ffi", "~> 1.15.0"
end

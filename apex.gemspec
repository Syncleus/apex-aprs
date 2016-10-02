# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aprs/app_info'

Gem::Specification.new do |spec|
    spec.name = 'aprs'
    spec.version = Aprs::VERSION
    spec.authors = ['Jeffrey Phillips Freeman']
    spec.email = ['jeffrey.freeman@syncleus.com']

    spec.summary = %q{Ruby library for APRS communications.}
    spec.description = %q{Ruby library for APRS communications.}
    spec.homepage = 'https://github.com/Syncleus/aprs'

    # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
    # to allow pushing to a single host or delete this section to allow pushing to any host.
    if spec.respond_to?(:metadata)
        spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
    else
        raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
    end

    spec.files = `git ls-files -z`.split("\x0").reject do |f|
        f.match(%r{^(test|spec|features)/})
    end
    spec.bindir = 'exe'
    spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
    spec.require_paths = ['lib']

    spec.add_dependency 'colorize'
    spec.add_dependency 'abstraction'
    spec.add_dependency 'json'
    spec.add_development_dependency 'bundler'
    spec.add_development_dependency 'rake'
    spec.add_development_dependency 'rdoc'
    spec.add_development_dependency 'aruba'
end

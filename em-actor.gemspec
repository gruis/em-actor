require File.expand_path("../lib/em-actor/version", __FILE__)
require "rubygems"
::Gem::Specification.new do |s|
  s.name                      = "em-actor"
  s.version                   = EmActor::VERSION
  s.platform                  = ::Gem::Platform::RUBY
  s.authors                   = ['Caleb Crane']
  s.email                     = ['em-actor@simulacre.org']
  s.homepage                  = "http://github.com/simulacre/em-actor"
  s.summary                   = 'Actor based concurrency for EventMachine processes'
  s.description               = ''
  s.required_rubygems_version = ">= 1.3.6"
  s.files                     = Dir["lib/**/*.rb", "bin/*", "*.md"]
  s.require_paths             = ['lib']
  s.executables               = Dir["bin/*"].map{|f| f.split("/")[-1] }
  s.license                   = 'MIT'

  # If you have C extensions, uncomment this line
  # s.extensions = "ext/extconf.rb"
  s.add_dependency 'eventmachine'
end

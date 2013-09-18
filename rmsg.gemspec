# encoding: utf-8
require File.expand_path('../lib/rmsg/version', __FILE__)

Gem::Specification.new do |s|
  s.name           = "rmsg"
  s.version        = "0.0.1"
  s.summary        = "Redis Messaging"
  s.description    = "Send crosservice messages get replies"
  s.authors        = ["Alex Gusev"]
  s.email          = "alx.gsv@gmail.com"
  s.files          = `git ls-files`.split("\n")
  s.test_files     = `git ls-files -- test/*`.split("\n")

  s.require_paths  = ["lib"]
  s.version        = Rmsg::VERSION

  s.add_dependency              "redis", ">= 3.0.4"
  s.add_dependency              "json"
  s.add_dependency              "yajl-ruby"
  s.add_development_dependency  "minitest", "~> 5"
  s.add_development_dependency  "rake"
end
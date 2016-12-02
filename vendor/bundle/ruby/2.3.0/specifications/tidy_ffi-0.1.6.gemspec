# -*- encoding: utf-8 -*-
# stub: tidy_ffi 0.1.6 ruby lib

Gem::Specification.new do |s|
  s.name = "tidy_ffi".freeze
  s.version = "0.1.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Eugene Pimenov".freeze]
  s.date = "2015-03-23"
  s.description = "Tidy library interface via FFI".freeze
  s.email = "libc@libc.st".freeze
  s.homepage = "http://github.com/libc/tidy_ffi".freeze
  s.rubyforge_project = "tidy-ffi".freeze
  s.rubygems_version = "2.6.7".freeze
  s.summary = "Tidy library interface via FFI".freeze

  s.installed_by_version = "2.6.7" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ffi>.freeze, ["~> 1.2"])
    else
      s.add_dependency(%q<ffi>.freeze, ["~> 1.2"])
    end
  else
    s.add_dependency(%q<ffi>.freeze, ["~> 1.2"])
  end
end

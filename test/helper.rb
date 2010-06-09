# Setup for all the tests.

require 'test/unit'
require 'rails_pwnerer'

require 'rubygems'
require 'flexmock'


# Shell class for including RailsPwnerer::Base.
class BaseWrapper
  include RailsPwnerer::Base
end

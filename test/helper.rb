# Setup for all the tests.

require 'test/unit'
require 'rails_pwnerer'

require 'rubygems'
require 'flexmock/test_unit'


# Shell class for including RailsPwnerer::Base.
class BaseWrapper
  include RailsPwnerer::Base
end


# Flexmock refuses to mock Kernel.` so we need to trick it.
module Kernel
  class <<self
    alias_method :backquote, "`"
    
    def `(*args)
      backquote(*args)
    end
  end
end

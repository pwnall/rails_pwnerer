require File.expand_path('../helper.rb', __FILE__)

class BasePackageTest < Test::Unit::TestCase
  def setup
    @base = BaseWrapper.new  
  end
  
  def test_package_search
    packages = @base.package_search 'ruby'
    p packages
  end
end
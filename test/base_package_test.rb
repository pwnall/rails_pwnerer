require File.expand_path('../helper.rb', __FILE__)

class BasePackageTest < Test::Unit::TestCase
  def setup
    @base = BaseWrapper.new  
  end
  
  def test_search_packages_with_string
    packages = @base.search_packages 'ruby'
    assert_operator packages, :has_key?, 'ruby1.8'
    assert_operator packages, :has_key?, 'ruby-dev'    
    assert_match '1.8', packages['ruby1.8']
  end

  def test_search_packages_with_regexp
    packages = @base.search_packages /ruby.*\-dev/
    assert_operator packages, :has_key?, 'ruby1.8-dev'    
    assert_operator packages, :has_key?, 'ruby1.9-dev'
  end
  
  def test_best_package_matching
    flexmock(@base).should_receive(:search_packages).with('libmagick++9-dev').
                    and_return({})
    flexmock(@base).should_receive(:search_packages).with('libmagick9-dev').
                    and_return({'first' => '9.1.9', 'second' => '9.0.9'})
    patterns = ['libmagick++9-dev', 'libmagick9-dev']
    golden = { :name => 'first', :version => '9.1.9' }
    assert_equal golden, @base.best_package_matching(patterns)
  end

  def test_best_package_matching_nothing
    flexmock(@base).should_receive(:search_packages).with('libmagick++9-dev').
                    and_return({})
    flexmock(@base).should_receive(:search_packages).with('libmagick9-dev').
                    and_return({})
    patterns = ['libmagick++9-dev', 'libmagick9-dev']
    assert_nil @base.best_package_matching(patterns)
  end
  
  def test_with_new_package_source
    package = 'nvidia-bl-dkms'
    assert @base.search_packages(package).empty?,
           "Found package that no test system should have (#{package})"

    source = 'http://ppa.launchpad.net/mactel-support/ppa/ubuntu'
    repos = ['lucid', 'main']
    @base.with_new_package_source(source, repos) do
      assert !(@base.search_packages(package).empty?),
             "with_new_package_source didn't integrate the new source"
    end

    assert @base.search_packages(package).empty?,
           "with_new_package_source didn't clean up after itself"
  end
end

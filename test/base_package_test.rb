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
                    and_return('first' => '9.1.9', 'libmagick9-dev' => '9.0.9')
    patterns = ['libmagick++9-dev', 'libmagick9-dev']
    golden = { :name => 'libmagick9-dev', :version => '9.0.9' }
    assert_equal golden, @base.best_package_matching(patterns)
  end
  
  def test_best_package_matching_regexp
    flexmock(@base).should_receive(:search_packages).with(/ruby\d+-dev/).
                    and_return('libruby18-dev' => '10.1.0',
                               'ruby18-dev' => '1.8.6',
                               'ruby187-dev' => '1.8.7')
    patterns = /ruby\d+-dev/
    golden = { :name => 'ruby187-dev', :version => '1.8.7' }
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
  
  def test_with_package_source
    package = 'nvidia-bl-dkms'
    assert @base.search_packages(package).empty?,
           "Found package that no test system should have (#{package})"

    source = 'http://ppa.launchpad.net/mactel-support/ppa/ubuntu'
    repos = ['lucid', 'main']
    @base.with_package_source(source, repos) do
      assert !(@base.search_packages(package).empty?),
             "with_new_package_source didn't integrate the new source"
    end

    assert @base.search_packages(package).empty?,
           "with_new_package_source didn't clean up after itself"
  end
  
  def test_update_package_metadata
    command = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get update -qq -y"
    flexmock(Kernel).should_receive(:system).with(command).and_return(true)
    assert @base.update_package_metadata
  end
  
  def test_update_package_metadata_with_blocking_proxy
    command = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get update -qq -y"
    flexmock(Kernel).should_receive(:system).with(command).and_return(false)
    command2 = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get update -qq -y -o Acquire::http::Proxy=false"
    flexmock(Kernel).should_receive(:system).with(command2).and_return(true)
    assert @base.update_package_metadata
  end

  def test_update_package_metadata_without_network
    command = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get update -qq -y"
    flexmock(Kernel).should_receive(:system).with(command).and_return(false)
    command2 = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get update -qq -y -o Acquire::http::Proxy=false"
    flexmock(Kernel).should_receive(:system).with(command2).and_return(false)
    assert !@base.update_package_metadata
  end
  
  def test_install_package
    command = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get install -qq -y hello"
    flexmock(Kernel).should_receive(:system).with(command).and_return(true)
    assert @base.install_package('hello')
  end
  
  def test_install_package_matching
    command = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get install -qq -y hello"
    flexmock(Kernel).should_receive(:system).with(command).and_return(true)
    assert @base.install_package_matching('hello')    
  end
  
  def test_install_package_from_sources
    c1 = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get build-dep -qq -y hello"
    flexmock(Kernel).should_receive(:system).with(c1).and_return(true)
    c2 = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get source -b -qq -y hello"
    flexmock(Kernel).should_receive(:system).with(c2).and_return(true)
    c3 = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  dpkg -i "
    flexmock(Kernel).should_receive(:system).with(c3).and_return(true)
    assert @base.install_package('hello', :source => true)    
  end
  
  def test_remove_package
    command = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get remove -qq -y hello"
    flexmock(Kernel).should_receive(:system).with(command).and_return(true)
    assert @base.remove_package('hello')
  end
  
  def test_install_remove_package_live
    package = 'hello'
    command = 'hello'
    
    assert !Kernel.system(command), 'You have hello installed by default?!'
    assert @base.install_package(package), 'Package install failed'
    assert Kernel.system(command), "Package installation didn't do the job"
    assert @base.remove_package(package), 'Package removal failed'
    assert !Kernel.system(command), "Package removal didn't do the job"
  end
  
  def test_update_all_packages
    command = "env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_TERSE=yes  apt-get upgrade -qq -y"
    flexmock(Kernel).should_receive(:system).with(command).and_return(true)
    assert @base.update_all_packages
  end
end

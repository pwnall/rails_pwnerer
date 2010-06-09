# installs the required OS (read: Ubuntu / Debian) packages

class RailsPwnage::Scaffolds::Packages
  include RailsPwnage::Base
  
  # the packages needed to manage the server remotely and install applications
  def install_management
    # needed to play with the configuration database
    install_packages %w(debconf debconf-utils)
    
    # dpkg-dev allows building from source
    # openssh-server allows us to ssh into the box
    # build-essential is needed to install some gems
    install_packages %w(dpkg-dev openssh-server build-essential)
    
    # subversion is needed to pull code from SVN repositories
    # should work from source, except package author decided to block that
    install_packages %w(subversion)
    
    # rpwn doesn't deal with git yet, but we'd like to offer that, so we'll
    # bring in the git infrastructure during scaffolding
    install_packages %w(git-core)

    # ddclient does dynamic DNS
    # avahi-daemon does mDNS, a.k.a. Bonjour (makes "ping hostname.local" work)
    install_packages %w(ddclient avahi-daemon)
  end
  
  # packages that are needed by popular gems
  def install_tools
    # needed by rmagick which does image processing
    install_packages %w(libmagick9-dev libmagickwand-dev)
    
    # needed by xml parsers
    install_packages %w(libxml2-dev libxslt1-dev)
    
    # needed by curb which does HTTP fetching
    install_packages %w(libcurl4-openssl-dev)
    
    # needed by sqlite-3 ruby gem in tools
    install_packages %w(libsqlite3-0 libsqlite3-dev sqlite3)
    
    # needed for solr and other java-based services
    install_packages %w(openjdk-6-jdk)
    
    # useful to be able to work with compressed data
    install_packages %w(tar zip bzip2 gzip)
  end
  
  # the packages comprising ruby
  def install_ruby
    # Needed to install gems.
    install_packages %w(build-essential g++)
    
    # NOTE: Not wiping ruby anymore, because a lot of stuff depends on it.
    #       Hoping apt will replace it quietly.
    # Wipe the old ruby version (and pray we don't die until we're done,
    # otherwise we're on a ruby-less system)

    # remove_packages %w(ruby1.8 libruby1.8) -- this shouldn't be needed anymore
    
    # install ruby from source
    install_packages %w(ruby1.8 libopenssl-ruby1.8 libreadline-ruby1.8 rdoc
                        libsetup-ruby1.8 ruby-pkg-tools rubygems1.8 rubygems
                        irb ruby1.8-dev)
  end
  
  # the packages for a mysql server and development libraries
  def install_mysql
    # not installing mySQL from source because it's a pain
    install_packages %w(mysql-client mysql-server libmysqlclient15-dev)
  end
  
  # The packages for building postgresql clients.
  #
  # Rails 3 likes having both the mysql and pgsql clients available.
  def install_pgsql_client
    install_packages %w(postgresql-client libpq-dev)    
  end
  
  # the packages for sqlite3
  def install_sqlite3
    install_packages %w(libsqlite3 libsqlite3-dev sqlite3)
  end
  
  # the packager for _the_ load balancer (nginx, from Russia with <3)
  def install_balancer
    remove_packages %w(nginx)
    
    install_packages %w(nginx)
  end
      
  # runner
  def run
    add_package_source 'http://debian.mirrors.tds.net/debian/',
          %w(unstable main non-free contrib)
        
    update_package_metadata
    install_management
    install_tools
    install_ruby
    install_sqlite3
    install_balancer
    install_mysql
    install_pgsql_client
    upgrade_all_packages
  end

  # standalone runner
  def self.go
    self.new.run
  end
end

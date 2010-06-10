# installs the required OS (read: Ubuntu / Debian) packages

class RailsPwnerer::Scaffolds::Packages
  include RailsPwnerer::Base
  
  # Packages needed to manage the server remotely and install applications.
  def install_management
    # Needed to play with the configuration database.
    package 'debconf'
    package 'debconf-utils'
    
    # Keys for Debian packages.
    package 'debian-archive-keyring'
    
    # Fetch files via HTTP.
    package 'curl'
    package 'wget'
    
    package 'dpkg-dev'  # Builds packages from source.
    package 'openssh-server'  # SSH into the box.

    # For gems with native extensions.
    package 'build-essential'
    package 'g++'
    
    # Pull code from version control.
    package 'subversion'    
    package 'git-core'

    package 'avahi-daemon'  # mDNS, a.k.a. Bonjour
    package 'ddclient'  # dynamic DNS
  end
  
  # Packages needed by popular gems.
  def install_tools
    # For rmagick (image processing).
    package 'libmagickwand-dev', /^libmagick\d*-dev$/
    
    # For HTML/XML parsers (nokogiri, hpricot).
    package 'libxml2-dev'
    package 'libxslt1-dev'
    
    # For HTTP fetchers (curb).
    package 'libcurl-dev', 'libcurl-openssl-dev', /^libcurl\d*-dev$/,
            /^libcurl\d*-openssl-dev$/
        
    # needed for solr and other java-based services
    package 'openjdk-6-jdk'
    
    # useful to be able to work with compressed data
    package 'bzip2'
    package 'gzip'
    package 'tar'
    package 'zip'
  end
  
  # Packages for all the database servers we could need.
  def install_databases
    package 'sqlite3'
    package 'libsqlite3-dev'
        
    package 'mysql-client'
    package 'mysql-server'
    package 'libmysql-dev', 'libmysqlclient-dev', /^libmysqlclient\d*-dev$/
    
    package 'postgresql-client'
    package 'libpq-dev'
    
    # TODO: NoSQL stores.
  end  
  
  # The ruby environment (ruby, irb, rubygems).
  def install_ruby
    package = best_package_matching(['ruby1.8', 'ruby'])
    if !package or package[:version] < '1.8.7'
      # This distribution has an old ruby. Work around it.
      deb_source = 'http://debian.mirrors.tds.net/debian/'
      deb_repos = %w(testing main non-free contrib)
      with_package_source deb_source, deb_repos do
        install_ruby
      end
    end

    package 'ruby', 'ruby1.8'

    # Extensions that don't come in the ruby package, but should.
    package 'libdbm-ruby', 'libdbm-ruby1.8'
    package 'libgdm-ruby', 'libgdbm-ruby1.8'
    package 'libopenssl-ruby', 'libopenssl-ruby1.8'
    package 'libreadline-ruby', 'libreadline-ruby1.8'
    package 'libsetup-ruby', 'libsetup-ruby1.8'

    # Ecosystem command-line tools.
    package 'irb', 'irb1.8'
    package 'ruby-dev', 'ruby1.8-dev'
    package 'rubygems', 'rubygems1.8'
  end
        
  # Package for front-end servers.
  def install_frontends
    package 'nginx'
    package 'varnish'
  end
  
  # Implementation of the super-simple package DSL.
  def package(*patterns)
    install_package_matching patterns
  end
      

  # Runner.
  def run
    update_package_metadata
    update_all_packages
    install_management
    install_tools
    install_databases
    install_frontends
    install_ruby
  end

  # Standalone runner.
  def self.go
    self.new.run
  end
end

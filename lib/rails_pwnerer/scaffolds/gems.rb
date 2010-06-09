# installs the required gems

class RailsPwnerer::Scaffolds::Gems
  include RailsPwnerer::Base
  
  def install_self
    # need to reinstall self because ruby gets swapped while the gem is running
    install_gems %w(rails_pwnerer)
  end
  
  def install_servers
    install_gems %w(memcache-client rack rack-test rack-mount unicorn thin)
  end
  
  def install_dbi
    install_gems %w(mysql mysql2 pg sqlite3-ruby)
  end
  
  def install_text_tools
    install_gems %w(tzinfo builder erubis mail text-format i18n)
  end
  
  def install_packagers
    install_gems %w(rake thor bundler)
  end
  
  def install_tools
    # we need this to do controlled app container startups
    install_gems %w(sys-proctable)
    
    # used to determine the number of available CPUs and cores
    install_gems %w(sys-cpu)
    
    # used to get version control passwords
    install_gems %w(highline termios)

    # some code can use this instead of Net::HTTP and be faster
    install_gems %w(curb)
    
    # some code can use one of these for XML / HTML parsing and be faster
    install_gems %w(nokogiri hpricot)    
    
    # useful for building gems and debugging
    install_gems %w(echoe ruby-debug-ide)
        
    # useful for development, testing, monitoring
    install_gems %w(mechanize)
  end
  
  # runner
  def run
    update_gems
    install_self
    install_dbi
    install_packagers
    install_text_tools
    install_servers
    install_gems %w(rails)
    install_tools
  end
  
  # standalone runner
  def self.go
    self.new.run
  end
end

# installs the required gems

class RailsPwnerer::Scaffolds::Gems
  include RailsPwnerer::Base

  def install_self
    # The gem repository gets wiped on new Debian and Ubuntu installs, so we
    # need to reinstall ourselves.
    install_gems %w(rails_pwnerer)

    # Process management.
    install_gems %w(zerg_support)
  end

  def install_databases
    install_gems %w(mysql2 pg sqlite3)
    install_gems %w(memcache-client)
  end

  def install_packagers
    install_gems %w(bundler)
  end

  def install_process_managers
    install_gems %w(foreman)
  end

  def install_servers
    install_gems %w(puma thin unicorn)
  end

  def install_tools
    # Get passwords from admins.
    install_gems %w(highline ruby-termios)

    # Debug gems on production machines.
    install_gems %w(echoe jeweler debugger)

    # Determine number of CPUs and cores.
    install_gems %w(sys-cpu)
  end

  # runner
  def run
    update_gems
    install_self
    install_databases
    install_packagers
    install_process_managers
    install_servers
    install_tools
    install_gems %w(rails)
  end

  # standalone runner
  def self.go
    self.new.run
  end
end

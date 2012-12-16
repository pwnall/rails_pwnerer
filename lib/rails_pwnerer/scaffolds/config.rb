# sets up the configuration repository

class RailsPwnerer::Scaffolds::Config
  include RailsPwnerer::Base

  # runner
  def run
    # paths    
    paths_db = RailsPwnerer::Config.create_db :paths
    # the directory containing the nginx config files
    paths_db[:nginx_configs] = '/etc/nginx/sites-enabled'
    # the directory containing the ddclient configuration
    paths_db[:ddclient_config] = '/etc/ddclient.conf'
    RailsPwnerer::Config.flush_db :paths
    
    # host info    
    host_info = RailsPwnerer::Config.create_db :host
    # the default instance name -- DNS names have dashes, but mySQL hates that
    host_info[:instance] = Socket.gethostname().split('.').first.gsub('-', '_')
    # the computer's name (if we ever do status reports)
    host_info[:name] = Socket.gethostname()
    # username for creating / dropping databases
    host_info[:dbroot_name] = 'root'
    # password for creating / dropping databases
    host_info[:dbroot_pass] = ''
    # the user owning the /prod subtrees
    host_info[:pwnerer_user] = current_user
    
    RailsPwnerer::Config.flush_db :host
    
    # the free port list
    RailsPwnerer::Config.init_ports    
  end

  # standalone runner
  def self.go
    self.new.run
  end
end

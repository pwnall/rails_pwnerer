# hooks up the dynamic dns service

class RailsPwnage::Scaffolds::HookDyndns
  include RailsPwnage::Base

  # patches the ddclient boot script and configuration to enable the daemon
  def enable_daemon      
    boot_script = File.open(path_to_boot_script('ddclient'), 'r') { |f| f.read }
    boot_script.gsub!(/run_daemon\=false/, 'run_daemon=true')
    File.open(path_to_boot_script('ddclient'), 'w') { |f| f.write boot_script }
    
    dd_defaults = File.open(path_to_boot_script_defaults('ddclient'), 'r') { |f| f.read }
    dd_defaults.gsub!(/run_daemon\=\"false\"/, 'run_daemon="true"')
    File.open(path_to_boot_script_defaults('ddclient'), 'w') { |f| f.write dd_defaults } 
  end
  
  # configures ddclient
  def configure(ddns_hostname, ddns_username, ddns_password)
    File.open(RailsPwnage::Config.path_to(:ddclient_config), 'w') do |f|
      f << <<END_CONFIG
pid=/var/run/ddclient.pid
use=web, web=checkip.dyndns.com/, web-skip='IP Address'

protocol=dyndns2
server=members.dyndns.org

login=#{ddns_username}
password='#{ddns_password}'
#{ddns_hostname}
END_CONFIG
    end
  end
  
  # runner
  def run(ddns_hostname, ddns_username, ddns_password)
    control_boot_script 'ddclient', :stop
    configure ddns_hostname, ddns_username, ddns_password
    enable_daemon
    control_boot_script 'ddclient', :start
  end

  # standalone runner
  def self.go(ddns_hostname, ddns_username, ddns_password)
    self.new.run ddns_hostname, ddns_username, ddns_password
  end
end
# configures sshd for tunneling (Facebook apps anyone?)

class RailsPwnage::Scaffolds::Sshd
  include RailsPwnage::Base
    
  # runner
  def run
    ['/etc/ssh/sshd_config', '/etc/sshd_config'].each do |fname|
      next unless File.exists? fname
      File.open(fname, 'a') { |f| f.write "GatewayPorts clientspecified\n" }
      control_boot_script('ssh', :reload)
    end
  end

  # standalone runner
  def self.go
    self.new.run
  end
end

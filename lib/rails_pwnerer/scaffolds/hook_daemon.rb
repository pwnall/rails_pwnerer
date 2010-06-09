# sets up rpwnctl (controlling the yet-to-be-written daemon) to startup at boot time

class RailsPwnage::Scaffolds::HookDaemon
  include RailsPwnage::Base
    
  # runner
  def run
    daemon_ctl = `which rpwnctl`.strip
    hook_boot_script daemon_ctl, 'rpwn', :symlink => true
  end

  # standalone runner
  def self.go
    self.new.run
  end
end

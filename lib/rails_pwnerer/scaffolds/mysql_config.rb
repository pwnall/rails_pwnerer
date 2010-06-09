# installs the required OS (read: Ubuntu) packages

class RailsPwnage::Scaffolds::MysqlConfig
  include RailsPwnage::Base

  # runner
  def run
    # nothing to do anymore, used to configure socket
  end

  # standalone runner
  def self.go
    self.new.run
  end  
end

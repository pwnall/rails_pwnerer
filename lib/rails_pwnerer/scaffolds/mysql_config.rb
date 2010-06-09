# installs the required OS (read: Ubuntu) packages

class RailsPwnerer::Scaffolds::MysqlConfig
  include RailsPwnerer::Base

  # runner
  def run
    # nothing to do anymore, used to configure socket
  end

  # standalone runner
  def self.go
    self.new.run
  end  
end

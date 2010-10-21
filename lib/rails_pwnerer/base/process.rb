# extends Base with process management features 
require 'zerg_support'

module RailsPwnerer::Base  
  # returns information about a process
  def process_info(pid = nil)
    info = Hash.new
    Zerg::Support::ProcTable.ps.each do |process|
      item = { :cmdline => process.cmdline, :pid => process.pid.to_s }

      if pid.nil?
        info[process.pid.to_s] = item
      else
        return item if item.pid.to_s == pid.to_s
      end
    end
    if pid.nil?
      return info
    else
      return nil
    end
  end
  
  def kill_tree
    Zerg::Support::Process.kill_tree pid
  end
end

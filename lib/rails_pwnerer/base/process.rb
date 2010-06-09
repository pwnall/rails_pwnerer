# extends Base with process management features 

begin
  require 'sys/proctable'
rescue Exception
  # the sys-proctable gem isn't available during scaffolding
  # (or if the compilation breaks for some reason); mock it
  
  module Sys
  end

  module Sys::ProcTable
    class ProcInfo
      def initialize(pid, cmdline)
        @pid = pid
        @cmdline = cmdline
      end
      attr_reader :pid, :cmdline
    end
  
    def self.ps
      retval = []
      ps_output = `ps ax`
      ps_output.each_line do |pline|
        pdata = pline.split(nil, 5)
        pinfo = ProcInfo.new(pdata[0].strip, pdata[4].strip)
        retval << pinfo
      end
      return retval
    end
  end
end

module RailsPwnage::Base  
  # returns information about a process
  def process_info(pid = nil)
    info = Hash.new
    Sys::ProcTable.ps.each do |process|
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
end

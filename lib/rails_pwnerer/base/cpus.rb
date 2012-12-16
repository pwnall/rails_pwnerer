if File.exists? '/proc/cpuinfo'
  # safest option: emulate Sys::CPU based on procfs
  module Sys; end

  module Sys::CPU
    def self.processors
      cpuinfo_text = File.read '/proc/cpuinfo'
      cpus_text = cpuinfo_text.split "\n\n"
      cpus = []
      cpus_text.each do |cpu_text|
        cpu = {}
        cpu_text.each_line do |cpu_line|
          key, value = *cpu_line.split(':', 2)
          key.strip!
          key.gsub! /\s/, '_'
          key.downcase!
          value.strip!
          cpu[key.to_sym] = value
        end
        cpus << Struct.new(*cpu.keys).new(*cpu.values)
      end
      
      cpus.each { |cpu| yield cpu } if Kernel.block_given?
      return cpus
    end
  end
  
else
  # no procfs, try to use sys-cpu
  
  begin
    require 'rubygems'
    require 'sys/cpu'
  rescue Exception
    # no gem either, stub sys-cpu
    module Sys; end
      
    module Sys::CPU
      def self.processors
        return []
      end
    end
  end
  
end

module RailsPwnerer::Base
  # returns information for each core in the system
  def cpu_cores
    cpus = []
    Sys::CPU.processors do |p|
      cpus << {
          :freq => p.cpu_mhz.to_f,
          :id => p.processor.to_i,
          :cpu => (p.respond_to?(:physical_id) ? p.physical_id.to_i : 0),
          :core => (p.respond_to?(:core_id) ? p.core_id.to_i : 0),
          :num_cores => (p.respond_to?(:cpu_cores) ? p.cpu_cores.to_i : 1)
      }
    end
    return cpus
  end
end

require 'pp'

class RailsPwnerer::DevExecutor
  include RailsPwnerer::Base
  
  def read_config(instance)
    if instance == '*'
      file = File.join(@config_root, '.yml') 
    else
      file = File.join(@config_root, instance + '.yml')
    end
    
    begin
      File.open(file, 'r' ) { |f| YAML.load f }
    rescue
      return Hash.new
    end
  end
  
  def write_config(config, instance)
    if instance == '*'
      file = File.join(@config_root, '.yml') 
    else
      file = File.join(@config_root, instance + '.yml')
    end

    File.open(file, 'w') { |f| YAML.dump config, f }
  end
  
  def checkin_rails_app(checkin_command, path_base)
    is_empty = true   
    
    Dir.foreach(path_base) do |entry|
      # skip uninteresting entries
      next if ['.', '..'].include? entry
      
      # check in files and subdirectories
      is_empty = false
      path = File.join path_base, entry
      if File.file? path
        Kernel.system "#{checkin_command} add #{path}"
        has_files = true
      else
        checkin_rails_app checkin_command, path
      end
    end
    
    if is_empty
      # workaround to check in blank directory
      path = File.join path_base, '.not_blank'
      File.open(path, 'w') { |f| f.write '' }
      Kernel.system "#{checkin_command} add #{path}"
    end
  end
    
  
  # standalone runner
  def run(args)
    unless check_rails_root '.'
      print "You need to run this at the root of your Rails application\n"
      return
    end
    
    # create the config root unless it exists
    @config_root = 'config/rails_pwnerer' 
    Dir.mkdir @config_root unless File.exists? @config_root
    
    case args[0]
    when 'get', 'getprop'
      property = args[1]
      instance = args[2] || '*'
      config = read_config instance
      pp config[property]
      
    when 'set', 'setprop', 'setnum', 'setpropnum'
      property = args[1]
      if args[0].index 'num'
        value = eval(args[2] || '1')
      else
        value = args[2] || 'true'
      end
      
      instance = args[3] || '*'
      config = read_config instance
      config[property] = value
      write_config config, instance
      
    when 'del', 'delprop', 'delete', 'rm', 'remove'
      property = args[1]
      instance = args[2] || '*'
      config = read_config instance
      config.delete property
      write_config config, instance
      
    when 'checkin'
      unless args[1]
        print "Please provide the checkin command (e.g. git).\n"
        exit
      end
      checkin_rails_app args[1], '.'
      
    else
      print "Unrecognized command #{args[0]}\n"
    end
  end
end

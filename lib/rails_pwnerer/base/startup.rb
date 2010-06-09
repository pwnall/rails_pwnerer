# extends Base with OS startup-related functions

require 'fileutils'

module RailsPwnage::Base
  # TODO: make this work w/o initd (OSX, Windows)

   # returns the filesystem path to a boot script
  def path_to_boot_script(script_name)
    File.join '', 'etc', 'init.d', script_name
  end
  
  # returns the filesystem path to the defaults used by a boot script (or nil if unsupported)
  def path_to_boot_script_defaults(script_name)
    File.join '', 'etc', 'default', script_name
  end
  
  # hooks a script into the boot sequence
  def hook_boot_script(script_location, script_name = File.basename(script_location), options = {})
    # copy the script to /etc/init.d and chmod +x
    target_script = path_to_boot_script script_name
    if options[:symlink]
      FileUtils.ln_s script_location, target_script, :force => true
      exec_file = script_location
    else
      FileUtils.cp script_location, target_script
      exec_file = target_script
    end
    File.chmod 0755, exec_file
    
    # add to boot sequence
    system "update-rc.d #{script_name} defaults"
  end
    
  def control_boot_script(script_name, action = :restart)
    path_to_script = "/etc/init.d/#{script_name}"
    case action
    when :stop
      system "#{path_to_script} stop"
    when :start
      system "#{path_to_script} start"
    when :restart
      system "#{path_to_script} restart"
    when :reload
      system "#{path_to_script} reload"
    end
  end
end

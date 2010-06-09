# checks out and updates the application from a Perforce repository

require 'English'
require 'fileutils'
require 'pathname'
require 'set'

class RailsPwnage::App::Perforce
  include RailsPwnage::Base
  
  # TODO(costan): figure out how to remove unused files in perforce and do it
    
  # remove any files not in client workspace
  def cleanup_app_dir(app_name, instance_name, target_dir, app_name_is_dir = false)
    path_base = app_name_is_dir ? app_name : RailsPwnage::Config[app_name, instance_name][:app_path]
    path_base = File.join path_base, target_dir
    path_base = path_base[0...-1] if path_base[-1] == '/'
    Dir.chdir path_base do
      # get a listing of the files in that directory under version control
      p4_output = `p4 have ...`
      
      # if p4 have failed, we don't have a reliable list, so we must give up
      break if $CHILD_STATUS.exitstatus != 0
      
      client_files = Set.new
      p4_output.each_line do |output_line|
        next unless i = output_line.index(path_base)
        client_files << output_line[(i + path_base.length + 1)..-1].strip
      end
     
      local_files = Dir.glob('**/*')
      local_files.each do |file|
        next if client_files.include? file
        next unless File.file? file
        
        FileUtils.rm_r file
      end
    end
  end
  
  # clean up the application directory by removing caches 
  def cleanup_app_caches(app_name, instance_name, app_name_is_dir = false)
    # TODO: this is almost-duplicated in git.rb -- pull up somewhere
    app_path = app_name_is_dir ? app_name : RailsPwnage::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.p4clientspec'))
    
    # TODO: learn how Rails caches work and kill those too
    ['app', 'lib', 'public/images',
    'public/javascripts', 'public/stylesheets', 'script',
    'test', 'tmp', 'vendor'
    ].each { |dir| cleanup_app_dir app_name, instance_name, dir, app_name_is_dir }
  end
    
  def perforce_config_file
    ENV['P4CONFIG'] = '.p4config' unless ENV['P4CONFIG']
    return ENV['P4CONFIG']
  end
  
  # Asks the user for their passwords and sets it, if that's worth it.
  # Assumes the current directory is the application's directory. 
  def try_prompting_for_perforce_password
    return false if ENV["P4PASSWD"]
    
    p4_config = File.read perforce_config_file
    return false if p4_config.index "P4PASSWD="
    
    p4_password = prompt_user_for_password(
        'Please enter your Perforce password:',
        'Cannot securely obtain your Perforce password')
    return false unless p4_password
    ENV['P4PASSWD'] = p4_password
    return true
  end
    
  def perforce_update(app_name, instance_name)    
    Dir.chdir RailsPwnage::Config[app_name, instance_name][:app_path] do
      perforce_config_file
      
      print "Doing Perforce sync...\n"
      success = Kernel.system 'p4 sync'
      if !success
        Kernel.system 'p4 sync' if try_prompting_for_perforce_password
      end
    end
  end

  def checkout(remote_path, app_name, instance_name)
    app_path = RailsPwnage::Config[app_name, instance_name][:app_path]
    
    # paths look like p4://user@depot:port/path/to/application
    path_regexp = /^p4\:\/\/([^\@\/]*\@)?([^\:\/]*)(:[1-9]+)?\/(.*)$/
    path_match = path_regexp.match remote_path
    return :next unless path_match
    
    # extract path components
    p4_user = path_match[1] ? path_match[1][0...-1] : current_user
    p4_user, p4_password = *p4_user.split(':', 2)
    p4_server = path_match[2]
    p4_port = path_match[3] ? path_match[3][1..-1].to_i : 1666
    p4_path = path_match[4]
    p4_client = "rpwn-#{p4_user}-#{app_name}-#{instance_name}"
    
    # create settings file
    p4_config_file = 
    File.open(File.join(app_path, perforce_config_file), 'w') do |f|
      f.write <<END_SETTINGS
P4PORT=#{p4_server}:#{p4_port}
P4USER=#{p4_user}
P4CLIENT=#{p4_client}
END_SETTINGS
      f.write "P4PASSWD=#{p4_password}\n" if p4_password
    end
    
    # create client spec
    File.open(File.join(app_path, '.p4clientspec'), 'w') do |f|
      f.write <<END_SETTINGS
Client:         #{p4_client}
Owner:          #{p4_user}
Description:    Deployment client for #{app_name} instance #{instance_name} created by rails_pwnerer
Root:           #{app_path}
Options:        noallwrite clobber unlocked nomodtime rmdir
SubmitOptions:  revertunchanged
LineEnd:        share
View:
                //depot/#{p4_path}/... //#{p4_client}/...
END_SETTINGS
    end

    print "Creating Perforce client...\n"
    Dir.chdir RailsPwnage::Config[app_name, instance_name][:app_path] do    
      success = Kernel.system "p4 client -i < .p4clientspec"
      if !success
        Kernel.system "p4 client -i < .p4clientspec" if try_prompting_for_perforce_password
      end
      
      print "Doing Perforce sync...\n"
      Kernel.system 'p4 sync -f'
    end

    # check that we really checked out a Rails app
    return check_rails_root(app_path) ? :ok : false
  end
  
  def update(app_name, instance_name)
    app_path = RailsPwnage::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.p4clientspec'))
    
    # TODO: maybe backup old version before issuing the p4 sync?
    
    perforce_update app_name, instance_name
    cleanup_app_caches app_name, instance_name
  end
  
  def update_prefetch(app_name, instance_name)
    app_path = RailsPwnage::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.p4clientspec'))
    
    # TODO: maybe figure out a way to prefetch Perforce, if it's ever worth it
  end
  
  def remove(app_name, instance_name)
    app_path = RailsPwnage::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.p4clientspec'))
    
    
    print "Deleting Perforce client...\n"
    Dir.chdir RailsPwnage::Config[app_name, instance_name][:app_path] do    
      p4_config = File.read perforce_config_file
      client_match = /^P4CLIENT=(.*)$/.match p4_config
      p4_client = client_match[1]
      
      success = Kernel.system "p4 client -d #{p4_client}"
      if !success
        Kernel.system "p4 client -d #{p4_client}" if try_prompting_for_perforce_password
      end
    end
  end
end

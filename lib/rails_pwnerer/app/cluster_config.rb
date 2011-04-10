# builds the frontend cluster configuration

require 'fileutils'

class RailsPwnerer::App::ClusterConfig
  include RailsPwnerer::Base
  
  def fix_permissions(app_name, instance_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]    
    pwnerer_user = app_config[:pwnerer_user]
    pwnerer_uid = uid_for_username(pwnerer_user)
    pwnerer_group = group_for_username(pwnerer_user)
    
    writable_dirs = %w(log tmp public)
    if app_config[:writable_dirs]      
      writable_dirs += app_config[:writable_dirs].split ','
    end
    
    Dir.chdir app_config[:app_path] do
      writable_dirs.each do |writable_dir|
        FileUtils.mkpath writable_dir unless File.exists? writable_dir
        FileUtils.chown_R(pwnerer_uid, pwnerer_group, writable_dir)
      end
    end
  end
    
  def manage_ports(app_name, instance_name, action)
    app_config = RailsPwnerer::Config[app_name, instance_name]
    return unless frontends = RailsPwnerer::Config.app_frontends(app_name, instance_name)
    
    case action
    when :alloc
      app_config[:port0] = RailsPwnerer::Config.alloc_ports frontends
    when :free
      RailsPwnerer::Config.free_ports app_config[:port0], frontends
      return if app_config[:port0] == 0 # do not release if ports have already been released
      app_config[:port0] = 0
    end
    RailsPwnerer::Config.flush_db RailsPwnerer::Config.app_db_name(app_name, instance_name)
  end

  def stop(app_name, instance_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]
    # silently die if the app was completely busted
    return unless app_config and File.exists? app_config[:app_path]
        
    app_path, first_port = app_config[:app_path], app_config[:port0]
    frontends = RailsPwnerer::Config.app_frontends(app_name, instance_name)

    cmdline_patterns = ['thin', nil]
    
    Dir.chdir app_path do
      # TODO: stop processes in parallel
      frontends.times do |f|
        fe_port = first_port + f
        cmdline = "thin stop -a 127.0.0.1 -p #{fe_port} -d " +
                  "-P tmp/pids/fe.#{fe_port}.pid"
        cmdline = 'bundle exec ' + cmdline if File.exist?('Gemfile')
        cmdline_patterns[1] = "(127.0.0.1:#{fe_port})"
        RailsPwnerer::Util.kill_process_set(cmdline, "tmp/pids/fe.#{fe_port}.pid",
                           cmdline_patterns, :verbose => false, :sleep_delay => 0.2)
      end
      
    end
  end
  
  def start(app_name, instance_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]
    # silently die if the app was completely busted
    return unless app_config and File.exists? app_config[:app_path]

    app_path, pwnerer_user = app_config[:app_path], app_config[:pwnerer_user]
    pwnerer_group = group_for_username(pwnerer_user)    
    frontends = RailsPwnerer::Config.app_frontends(app_name, instance_name)
    first_port, environment = app_config[:port0], app_config[:environment]

    stop app_name, instance_name
    
    # alloc a port if somehow that slipped through the cracks
    if first_port == 0
      manage_ports app_name, instance_name, :alloc
      first_port = app_config[:port0]
      RailsPwnerer::App::NginxConfig.new.update app_name, instance_name
    end
    
    static_cmd = "thin start -a 127.0.0.1 -c #{app_path} -u #{pwnerer_user} " +
                 "-g #{pwnerer_group} -e #{environment} -d " +
                 " --tag rpwn_#{app_name}.#{instance_name} "
    
    # TODO: start the servers simultaneously
    Dir.chdir app_path do
      if File.exist? 'config.ru'
        static_cmd << '-R config.ru '
      else    
        static_cmd << '-A rails '
      end
      static_cmd = 'bundle exec ' + static_cmd if File.exist?('Gemfile')
      
      frontends.times do |f|
        fe_port = first_port + f
        cmd = static_cmd + "-p #{fe_port} -l log/fe.#{fe_port}.log -P tmp/pids/fe.#{fe_port}.pid"
        Kernel.system cmd
      end
    end
  end

  def setup(app_name, instance_name)
    manage_ports app_name, instance_name, :alloc
    fix_permissions app_name, instance_name
    # no need to configure nginx here, it'll be done by the executor
  end
  
  def pre_update(app_name, instance_name, &update_proc)
    manage_ports app_name, instance_name, :free
  end
  def post_update(app_name, instance_name)
    manage_ports app_name, instance_name, :alloc
    fix_permissions app_name, instance_name
  end
  
  def remove(app_name, instance_name)
    manage_ports app_name, instance_name, :free
  end
  
  def manage(app_name, instance_name, action)
    case action
    when :checkpoint
      # nothing to do here
    when :rollback
      fix_permissions app_name, instance_name
    end
  end
  
  def control_all(action)
    RailsPwnerer::Config.all_applications.each do |ai|
      case action
      when :start
        RailsPwnerer::App::ClusterConfig.new.start ai[0], ai[1]
      when :stop
        RailsPwnerer::App::ClusterConfig.new.stop ai[0], ai[1]        
      end
    end 
  end  
end

module RailsPwnerer::App
  # internal method implementing magic instance names
  def self.instance_magic(app_name, instance_name)
    app_name = app_name.gsub /\W/, ''  # Remove weird punctuation.    
    case instance_name
    when '*'
      RailsPwnerer::Config.all_instances app_name { |i| yield app_name, i }
    when '.'
      yield app_name, RailsPwnerer::Config[:host][:instance]
    else
      yield app_name, instance_name
    end
  end
  
  # installs an application given its SVN path
  def self.install(remote_path, instance_name)
    app_name = File.basename remote_path
    app_name = app_name[0, app_name.rindex('#')] if app_name.rindex '#'
    app_name = app_name[0, app_name.rindex('.')] if app_name.rindex '.'
    app_name.gsub! /\W/, ''  # Remove weird punctuation.
    instance_magic(app_name, instance_name) do |app, instance|
      Config.new.alloc app, instance
      
      success = nil
      [Git, Perforce, Svn].each do |vcs|
        success = vcs.new.checkout remote_path, app, instance
        break unless success == :next
      end
      if success == :ok
        [Config, Files, Gems, Database, ClusterConfig, NginxConfig, Scripts].each do |mod|
          mod.new.setup app, instance
        end
      else
        if success == :next
          print "rails_pwange only supports git, subversion, and perforce at this time. \n"
        else
          print "You didn't checkout a Rails application. Check your remote path.\n"
        end
        
        [Files, Config].each do |mod|
          mod.new.remove app, instance
        end
      end     
    end
  end
    
  # updates an application (restart servers if necessary)
  def self.update(app_name, instance_name)
    app_name = app_name.gsub /\W/, ''  # Remove weird punctuation.    
    instance_magic(app_name, instance_name) do |app, instance|
      [Git, Perforce, Svn].each do |mod|
        mod.new.update_prefetch app, instance
      end
      update_app app, instance do
        [Git, Perforce, Svn, Config, Gems, Database, Scripts].each do |mod|
          mod.new.update app, instance
        end
      end    
      NginxConfig.new.update app, instance
    end
  end
  
  # removes an application (and stops its servers)
  def self.remove(app_name, instance_name)    
    app_name = app_name.gsub /\W/, ''  # Remove weird punctuation.    
    instance_magic(app_name, instance_name) do |app, instance|
      Scripts.new.pre_stop app, instance
      ClusterConfig.new.stop app, instance
      Scripts.new.post_stop app, instance
    
      [NginxConfig, ClusterConfig, Database, Perforce, Files, Config].each do |mod|
        mod.new.remove app, instance
      end
    end    
  end

  def self.update_app(app_name, instance_name, &block)
    Scripts.new.pre_stop app_name, instance_name
    ClusterConfig.new.stop app_name, instance_name
    ClusterConfig.new.pre_update app_name, instance_name
    Scripts.new.post_stop app_name, instance_name
    yield
  ensure
    ClusterConfig.new.post_update app_name, instance_name
    NginxConfig.new.update app_name, instance_name    
    Scripts.new.pre_start app_name, instance_name
    ClusterConfig.new.start app_name, instance_name
    Scripts.new.post_start app_name, instance_name
  end

  # performs application management (checkpoint / rollback / console)
  def self.manage(app_name, instance_name, action = :checkpoint)
    instance_magic(app_name, instance_name) do |app, instance|
      # TODO: add backup / restore for the configuration db (easy)
      case action
        when :checkpoint
          ClusterConfig.new.manage app, instance, action
          Files.new.manage app, instance, action
          self.update_app app, instance do          
            Database.new.manage app, instance, action
          end
        when :rollback
          self.update_app app, instance do
            [Files, Database, ClusterConfig].each do |mod|
              mod.new.manage app, instance, action
            end
          end
        when :rollback_db
          self.update_app app, instance do
            [Database, ClusterConfig].each do |mod|
              mod.new.manage app, instance, :rollback
            end
            Database.new.manage app, instance, :update
          end
        when :rekey
          self.update_app app, instance do
            [Config, Database].each do |mod|
              mod.new.manage app, instance, action
            end
          end          
        when :console
          Files.new.manage app, instance, action
        when :db_console
          Files.new.manage app, instance, action
        when :db_reset
          app_config = RailsPwnerer::Config[app, instance]
          self.update_app app, instance do
            Scripts.new.pre_reset app, instance
            Database.new.manage app, instance, action
            Scripts.new.post_reset app, instance
          end
      end    
    end        
  end
  
  # start or stop all apps
  def self.control_all(action = :start)
    case action
    when :start
      Database.new.control_all :start
      Scripts.new.control_all :pre_start
      ClusterConfig.new.control_all :start
      NginxConfig.new.control_all :start
      Scripts.new.control_all :post_start
    when :stop
      Scripts.new.control_all :pre_stop
      NginxConfig.new.control_all :stop
      ClusterConfig.new.control_all :stop
      Scripts.new.control_all :post_stop
      Database.new.control_all :stop
    end
  end
end

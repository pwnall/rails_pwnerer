# syncs the app's internal configuration with the configuration database
require 'yaml'

class RailsPwnerer::App::Config
  include RailsPwnerer::Base
  
  def random_db_password
    (0...16).map { |i| "abcdefghijklmnopqrstuvwxyz"[rand(26),1]}.join
  end

  # fills inexistent keys with their default values
  # setup: this effectively creates the baseline configuration db
  # update: this adds keys that might have been added in new versions of rpwn
  def populate_defaults(app_name, instance_name, app_db)
    # the path to application main files
    app_db[:app_path] = File.join(RailsPwnerer::Config.path_to(:apps), app_name + '.' + instance_name)
    # the path to application backups
    app_db[:backup_path] ||= File.join(RailsPwnerer::Config.path_to(:backups), app_name + '.' + instance_name)
        
    # the user which will receive the "keys" to the production system 
    app_db[:pwnerer_user] ||= RailsPwnerer::Config[:host][:pwnerer_user]
    # the number of frontends for the application instance
    app_db[:frontends] ||= 4 # most computers have 2 cores nowadays
    # the number of frontends per core for the application instance
    app_db[:frontends_per_core] ||= 2 # best practice
    # the first internal port for the application instance
    app_db[:port0] = 0  # will be overwritten during allocation
    # the name of the database for the application instance 
    app_db[:db_name] ||= (app_name + '_' + instance_name + '_prod')[0...60] # avoiding mySQL breakage
    # the datbase user for the given application
    app_db[:db_user] ||= (app_name + '_' + instance_name)[0...16] # mySQL doesn't like long user names
    # the password of the database user for the given application
    app_db[:db_pass] ||= random_db_password
    # a DNS name for server-based filtering (multiple apps on the same box)
    app_db[:dns_name] ||= ''
    # the environment to run the application in
    app_db[:environment] ||= 'production'
    # a port for server-based filtering (multiple apps on the same box)
    app_db[:port] ||= 80
    # the maximum request size (megabytes) to be accepted by an application
    app_db[:max_request_mb] ||= 48
    # comma-separated directories that should be writable by the application user
    app_db[:writable_dirs] ||= ''
    # comma-separated gems that should be installed for the application
    app_db[:gems] ||= ''
    # set to disable accidental db resets (on production vs. staging instances)
    app_db[:enable_db_reset] ||= false
    
    # the number of cores on the platform
    app_db[:detected_cores] ||= cpu_cores.length
  end

  # allocates room for the application and creates the application configuration database
  def alloc(app_name, instance_name)
    app_db_name = RailsPwnerer::Config.app_db_name(app_name, instance_name)
    app_db = RailsPwnerer::Config.create_db app_db_name
    populate_defaults app_name, instance_name, app_db
    
    FileUtils.mkpath app_db[:app_path]
        
    RailsPwnerer::Config.flush_db app_db    
    return app_db[:app_path]
  end
      
  # pushes config changes from the application file to the database
  def update(app_name, instance_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]
    
    db_name, db_user, db_pass = app_config[:db_name], app_config[:db_user], app_config[:db_pass]
    app_config.clear
    # NOTE: we don't restore the password on purpose, to get a new password on the update
    # this is useful so processes that were spawned before the update can't corrupt the db
    app_config[:db_name], app_config[:db_user] = db_name, db_user
    
    populate_defaults app_name, instance_name, app_config
    Dir.chdir app_config[:app_path] do
      # Populate the default SSL configuration if the right files exist.
      ssl_cert = File.expand_path "config/rails_pwnerer/#{instance_name}.cer"
      ssl_key = File.expand_path "config/rails_pwnerer/#{instance_name}.pem"      
      if File.exists?(ssl_cert) and File.exists?(ssl_key)
        app_config[:ssl_cert] = ssl_cert
        app_config[:ssl_key] = ssl_key
        app_config[:port] = 443
      end
      
      ["config/rails_pwnerer/.yml", "config/rails_pwnerer/#{instance_name}.yml"].each do |fname|
        next unless File.exists? fname
        config_update = File.open(fname, 'r') { |f| YAML.load f }
        config_update.each do |key, value|
          app_config[key] = value
        end
      end      
    end
    
    # TODO: if database settings changed, the database should be moved (re-created or re-keyed)
    if db_pass != app_config[:db_pass]
      db_pass = random_db_password if !db_pass || db_pass.empty?
      RailsPwnerer::App::Database.new.manage app_name, instance_name, :rekey
    end
    
    RailsPwnerer::Config.flush_db RailsPwnerer::Config.app_db_name(app_name, instance_name)
  end
  
  def manage(app_name, instance_name, action)    
    case action
    when :rekey
      app_config = RailsPwnerer::Config[app_name, instance_name]
      app_config[:db_pass] = random_db_password
    end
  end

  def setup(app_name, instance_name)
    update app_name, instance_name
  end
  
  def remove(app_name, instance_name)
    app_db_name = RailsPwnerer::Config.app_db_name(app_name, instance_name)
    RailsPwnerer::Config.drop_db app_db_name
  end
end

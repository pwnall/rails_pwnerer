# sets up the application database

require 'yaml'

class RailsPwnerer::App::Database
  include RailsPwnerer::Base

  # creates/drops the mysql database for the application
  def admin_database(app_name, instance_name, action = :create)
    app_config = RailsPwnerer::Config[app_name, instance_name]
    # exit and don't complain if the app is busted
    return unless app_config and File.exists? app_config[:app_path]

    db_name, db_user, db_pass = app_config[:db_name], app_config[:db_user], app_config[:db_pass]
    
    with_temp_dir do
      # put together the admin script
      case action
      when :create
      sql_commands = <<ENDSQL
        CREATE DATABASE #{db_name};
        GRANT ALL ON #{db_name}.* TO '#{db_user}'@'localhost' IDENTIFIED BY '#{db_pass}' WITH GRANT OPTION;
ENDSQL
      when :rekey
      sql_commands = <<ENDSQL
        GRANT ALL ON #{db_name}.* TO '#{db_user}'@'localhost' IDENTIFIED BY '#{db_pass}' WITH GRANT OPTION;
ENDSQL
      
      when :drop
      sql_commands = <<ENDSQL
        DROP DATABASE #{db_name};
ENDSQL
      end
      
      # run it
      File.open('admin_db.sql', 'w') { |f| f.write sql_commands }
      dbroot_name = RailsPwnerer::Config[:host][:dbroot_name]
      dbroot_pass = RailsPwnerer::Config[:host][:dbroot_pass]
      dbpass_arg = dbroot_pass.empty? ? '' : "-p#{dbroot_pass}"
      system "mysql -u#{dbroot_name} #{dbpass_arg} < admin_db.sql"
      
      # cleanup
      File.delete('admin_db.sql')
    end    
  end
  
  def mysql_host_info()
    # try UNIX sockets first, for best performance
    begin
      socket_line = `mysql_config --socket`
      socket_line.strip!
      return {'socket' => socket_line} unless socket_line.empty?
    rescue
    end
      
    # oh well, TCP will have to suffice
    begin
      port_line = `mysql_config --port`
      port = port_line.strip.to_i
      return {'host' => 'localhost', 'port' => port} unless port == 0    
    rescue
    end
    
    # giving up, the mysql gem will have to figure it out
    return {}
  end
    
  # configures rails to use the database in the production environment
  def configure_rails(app_name, instance_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]
    db_name, db_user, db_pass = app_config[:db_name], app_config[:db_user], app_config[:db_pass]
    
    config_file = File.join app_config[:app_path], 'config', 'database.yml'
    configuration = File.open(config_file, 'r') { |f| YAML.load f }
    configuration['production'] ||= {}
    if !configuration['production']['adapter'] or
       !(/mysql/ =~ configuration['production']['adapter'])
      configuration['production']['adapter'] = 'mysql2'
    end
    configuration['production']['encoding'] ||= 'utf-8'
    configuration['production'].merge! 'database' => db_name, 'username' => db_user, 'password' => db_pass
    configuration['production'].merge! mysql_host_info()    
    File.open(config_file, 'w') { |f| YAML.dump(configuration, f) }
    
    # bonus: lock down the database so only the right user can access it
    pwnerer_user = app_config[:pwnerer_user]
    File.chmod(0600, config_file)
    File.chown(uid_for_username(pwnerer_user), gid_for_username(pwnerer_user), config_file)
  end
  
  # migrates the database to the latest schema version
  def migrate_database(app_name, instance_name)
    Dir.chdir RailsPwnerer::Config[app_name, instance_name][:app_path] do
      # now migrate the database
      system "rake db:migrate RAILS_ENV=production"
    end
  end
  
  # creates a database dump in the backup area
  def dump_database(app_name, instance_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]
    db_name, db_user, db_pass = app_config[:db_name], app_config[:db_user], app_config[:db_pass]

    pwnerer_user = app_config[:pwnerer_user]
    pwnerer_uid = uid_for_username(pwnerer_user)
    pwnerer_gid = gid_for_username(pwnerer_user)
    
    timestamp = Time.now.strftime '%Y%m%d%H%M%S'
    dump_file = "db/#{app_name}.#{instance_name}_#{timestamp}.sql"
    Dir.chdir app_config[:backup_path] do
      system("mysqldump --add-drop-database --add-drop-table" +
             " --skip-extended-insert --single-transaction" +
             " -u#{db_user} -p#{db_pass} #{db_name} > #{dump_file}")
      # lockdown the file
      File.chmod(0400, dump_file)
      File.chown(pwnerer_uid, pwnerer_gid, dump_file)
    end
  end
  
  # loads the latest database dump from the backup area
  def load_database(app_name, instance_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]
    db_name, db_user, db_pass = app_config[:db_name], app_config[:db_user], app_config[:db_pass]
    
    Dir.chdir app_config[:backup_path] do
      # find the latest dump and load it in
      dump_file = Dir.glob("db/#{app_name}.#{instance_name}_*").max
      unless dump_file
        dump_file = Dir.glob("db/#{app_name}.*").max
      end
      Kernel.system "mysql -u#{db_user} -p#{db_pass} #{db_name} < #{dump_file}"
    end
  end

  def setup(app_name, instance_name)
    control_boot_script('mysql', :start)
    admin_database app_name, instance_name, :create
    configure_rails app_name, instance_name
    migrate_database app_name, instance_name
  end
  
  def update(app_name, instance_name)
    control_boot_script('mysql', :start)
    configure_rails app_name, instance_name
    migrate_database app_name, instance_name
  end
  
  def remove(app_name, instance_name)
    control_boot_script('mysql', :start)
    admin_database app_name, instance_name, :drop    
  end
  
  # backs up or restores the database
  def manage(app_name, instance_name, action)
    case action
    when :checkpoint
      dump_database app_name, instance_name
    when :rollback
      admin_database app_name, instance_name, :drop
      admin_database app_name, instance_name, :create
      load_database app_name, instance_name
      configure_rails app_name, instance_name
      migrate_database app_name, instance_name
    when :rekey
      admin_database app_name, instance_name, :rekey
      configure_rails app_name, instance_name
    when :db_reset
      admin_database app_name, instance_name, :drop
      admin_database app_name, instance_name, :create
      migrate_database app_name, instance_name
    end
  end
  
  def control_all(action)
    case action
    when :start
      control_boot_script('mysql', :start)
    when :stop
      control_boot_script('mysql', :stop)
    end
  end  
end

require 'pp'

class RailsPwnerer::Executor
  include RailsPwnerer::Scaffolds
  
  # standalone runner
  def run(args)
    case args[0]        
    when 'scaffold', 'den00b'
      case args[1]
      when 'config'
        Config.go
      when 'dirs'
        Dirs.go
      when 'dirs2'
        DirPermissions.go
      when 'gems'
        Gems.go
      when 'daemon'
        HookDaemon.go
      when 'mysql'
        MysqlConfig.go
      when 'packages'
        Packages.go
      when 'rubygems'
        RubyGems.pre_go
        RubyGems.go
      when 'sshd'
        Sshd.go        
      when 'ddns'
        if args.length < 5
          print 'Usage: rpwn scaffold ddns host_name user_name user_password'
        else
          HookDyndns.go args[2], args[3], args[4]
        end
      when nil
        RubyGems.pre_go
        Packages.go
        Sshd.go
        RubyGems.go
        Gems.go
        Dirs.go
        Config.go
        DirPermissions.go
        MysqlConfig.go
        HookDaemon.go
      else
        print "Unrecognized scaffold command #{args[1]}\n"        
      end
      
    when 'install', 'micro'
      svn_path = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.install svn_path, instance_name
      
    when 'update', 'ubermicro'
      app_name = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.update app_name, instance_name
      
    when 'uninstall', 'remove'
      app_name = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.remove app_name, instance_name
      
    when 'go'
      case args[1]
      when 'live', 'pwn'
        RailsPwnerer::App.control_all :start
      when 'down', 'panic'
        RailsPwnerer::App.control_all :stop
      else
        print "Unrecognized go command #{args[1]}\n"
      end
      
    when 'backup', 'checkpoint', 'save'
      app_name = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.manage app_name, instance_name, :checkpoint
    when 'restore', 'rollback'
      app_name = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.manage app_name, instance_name, :rollback
    when 'restoredb', 'rollbackdb', 'restore_db', 'rollback_db'
      app_name = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.manage app_name, instance_name, :rollback_db
    when 'console'
      app_name = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.manage app_name, instance_name, :console
    when 'dbconsole', 'db_console'
      app_name = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.manage app_name, instance_name, :db_console
    when 'dbreset', 'db_reset', 'resetdb', 'reset_db'
      app_name = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.manage app_name, instance_name, :db_reset
    when 'rekey'
      app_name = args[1]
      instance_name = args[2] || '.'
      RailsPwnerer::App.manage app_name, instance_name, :rekey
     
    when 'showconfig', 'configshow', 'show_config', 'config_show', 'showconf'
      if args.length < 2
        # dump all databases
        RailsPwnerer::Config.databases.each do |db|
          print "Database: #{db}\n"          
          pp RailsPwnerer::Config[db] 
        end
      else
        pp RailsPwnerer::Config[args[1]]             
      end     
    else
      print "Unrecognized command #{args[0]}\n"
    end
  end  
end

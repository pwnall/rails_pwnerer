class RailsPwnerer::CtlExecutor  
  # standalone runner
  def run(args)
    case args[0]
    when 'start'
      RailsPwnerer::App::ClusterConfig.new.control_all :start      
    when 'stop'
      RailsPwnerer::App::ClusterConfig.new.control_all :stop
    when 'restart'
      RailsPwnerer::App::ClusterConfig.new.control_all :stop
      RailsPwnerer::App::ClusterConfig.new.control_all :start      
    when 'reload'
      RailsPwnerer::App::ClusterConfig.new.control_all :stop
      RailsPwnerer::App::ClusterConfig.new.control_all :start      
    else
      print "Unrecognized command #{args[0]}\n"
    end
  end
end

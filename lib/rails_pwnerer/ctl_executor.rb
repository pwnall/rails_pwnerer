class RailsPwnage::CtlExecutor  
  # standalone runner
  def run(args)
    case args[0]
    when 'start'
      RailsPwnage::App::ClusterConfig.new.control_all :start      
    when 'stop'
      RailsPwnage::App::ClusterConfig.new.control_all :stop
    when 'restart'
      RailsPwnage::App::ClusterConfig.new.control_all :stop
      RailsPwnage::App::ClusterConfig.new.control_all :start      
    when 'reload'
      RailsPwnage::App::ClusterConfig.new.control_all :stop
      RailsPwnage::App::ClusterConfig.new.control_all :start      
    else
      print "Unrecognized command #{args[0]}\n"
    end
  end
end

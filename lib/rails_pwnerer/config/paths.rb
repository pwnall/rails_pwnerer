# important paths in the filesystem

module RailsPwnerer::Config
  # the path to something important (e.g. :apps --> path to all production applications)
  def self.path_to(what = :prod, app_name = nil)
    # need to hardcode path to config to avoid endless recursion
    if what == :config
      return '/prod/config/'
    end
        
    # first try the paths in the database
    return self[:paths][what] if self[:paths] and self[:paths].has_key? what

    # then try the global paths
    static_path = static_path_to what
    return static_path unless static_path.nil?  
  end  
  
  # hardcoded paths
  def self.static_path_to(what)
    case what
    when :config
      # the directory containing the config files
      '/prod/config'
    when :prod
      # the directory containing all the production data
      '/prod'
    when :apps
      # the directory containing the production apps
      '/prod/apps'
    when :backups
      '/prod/backups'
    else
      return
    end
  end
end

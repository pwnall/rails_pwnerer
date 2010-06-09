# extends Base with gem-related functions

module RailsPwnage::Base
  # TODO: use the Gem API instead of the command line

  def install_gem(gem_name)
    system "gem install #{gem_name}"
  end
  
  def upgrade_gem(gem_name)
    system "gem update #{gem_name.nil ? '' : gem_name}" 
  end
  
  # update the metadata for all the gems 
  def update_gems()
    system "gem update --system"
  end

  # checks if a gem exists
  def gem_exists?(gem_name)
    begin
      output = `gem specification --local #{gem_name} 2> /dev/null`
      return output =~ /^\-\-\- \!ruby\/object\:Gem\:\:Specification/
    rescue
      # we get here if gem exits with an error code
      return false
    end
  end
  
  # locates the main file in a gem (used to locate the gem)
  def path_to_gem(gem_name, discard_suffix = '')
    # TODO: use the rubygems API instead of this hack
    
    # method 1: peek inside rubygems' treasure chest
    begin
      gem_pattern = (File.join `gem environment gemdir`.strip, 'gems', gem_name) + '-'
      gem_path = Dir.glob(gem_pattern + '*').max
    rescue
      gem_path = nil
    end    
    return gem_path unless gem_path.nil? or gem_path.empty?
    
    # method 2: look for the main file in the gem
    gem_path = `gem which '#{gem_name}'`.strip
    # discard the given suffix
    if gem_path[-(discard_suffix.length)..-1] == discard_suffix
      gem_path[-(discard_suffix.length)..-1] = ''
    end
    return gem_path
  end
end

module RailsPwnage::Base  
  def install_gems(gem_names)
    unroll_collection(gem_names) { |n| install_gem(n) }
  end
  
  def upgrade_gems(gem_names)
    unroll_collection(gem_names) { |n| upgrade_gem(n) }
  end
end

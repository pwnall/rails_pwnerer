# extends Base with gem-related functions

module RailsPwnerer::Base
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
  def path_to_gemdir (gem_name, discard_suffix = '')
    # TODO: use the rubygems API instead of this hack

    `gem environment gemdir`.strip
  end
end

module RailsPwnerer::Base
  def install_gems(gem_names)
    unroll_collection(gem_names) { |n| install_gem(n) }
  end

  def upgrade_gems(gem_names)
    unroll_collection(gem_names) { |n| upgrade_gem(n) }
  end
end

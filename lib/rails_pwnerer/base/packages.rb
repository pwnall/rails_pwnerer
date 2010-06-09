# extends Base with OS package-related functions

require 'English'

module RailsPwnage::Base
  # TODO: this works for debian-only

  # Builds apt-get parameters for a set of options.
  def apt_params_for(options = {})
    # try to make debconf shut up for the general case
    # HACK: this getter has side-effects because it's used for
    #       install_package_impl and update_package_impl, and they don't have
    #       handy command-line flags for these options that we'd like
    ENV['DEBIAN_FRONTEND'] = 'noninteractive'
    ENV['DEBIAN_PRIORITY'] = 'critical'
    ENV['DEBCONF_TERSE'] = 'yes'    
    
    params = ""
    params << "-o Acquire::http::Proxy=false" if options[:no_proxy]
  end
  
  def install_package_impl(package_name, options)    
    apt_params = apt_params_for options
    if options[:source]
      with_temp_dir(:root => true) do
        Kernel.system "apt-get build-dep -y #{apt_params} #{package_name}"
        return false unless $CHILD_STATUS.success?
        Kernel.system "apt-get source -b  #{apt_params} #{package_name}"
        return false unless $CHILD_STATUS.success?        
        Kernel.system "dpkg -i #{Dir.glob('*.deb', File::FNM_DOTMATCH).join(' ')}"
        return false unless $CHILD_STATUS.success?
      end
    else
      Kernel.system "apt-get install -y  #{apt_params} #{package_name}"
      return false unless $CHILD_STATUS.success?
    end
    return true
  end
  
  # Searches for a package by name.
  #
  # Returns of hash where the keys are matching package names, and the values
  # are version numbers.
  def package_search(name_string)
    output = Kernel.` "apt-cache search --full #{name_string}"
    package_infos = output.split("\n\n").map do |package|
      info = Hash[*(split(/\n(?=\w)/).map { |s| s.split(':', 2) }.flatten)]
      [info['Name'], info['Version']]
    end
  end
  
  # Installs a package.
  # Returns true for success, false for failure.   
  def install_package(package_name, options = {})
    return true if install_package_impl(package_name, options)
    if options[:source]
      if options[:no_proxy]
        # already bypassing proxy, fall back to binary package
        return install_package(package_name, options.merge(:source => false))
      else
        # try bypassing proxy
        return install_package(package_name, options.merge(:no_proxy => true))
      end
    else
      if options[:no_proxy]
        # out of alternatives
        return false
      else
        # 
        return install_package(package_name, options.merge(:no_proxy => true))        
      end
    end
  end

  def upgrade_package_impl(package_name, options)
    apt_params = apt_params_for options    
    Kernel.system "apt-get upgrade -y #{apt_params} #{package_name.nil ? '' : package_name}"
    return $CHILD_STATUS.success?
  end
  
  # Upgrades a package to the latest version.
  def upgrade_package(package_name, options = {})
    return install_package(package_name, options) if options[:source]
    return true if upgrade_package_impl(package_name, options)
      
    if options[:no_proxy]
      # out of alternatives
      return false
    else
      # 
      return upgrade_package(package_name, options.merge(:no_proxy => true))        
    end
  end
  
  def upgrade_all_packages_impl(options)
    apt_params = apt_params_for options    
    Kernel.system "apt-get upgrade -y #{apt_params} < /dev/null"
    return $CHILD_STATUS.success?
  end

  def upgrade_all_packages(options = {})
    return true if upgrade_all_packages_impl(options)
    
    if options[:no_proxy]
      # out of alternatives
      return false
    else
      # 
      return upgrade_all_packages(options.merge(:no_proxy => true))
    end    
  end
  
  def remove_package(package_name, options = {})
    system "apt-get remove -y #{package_name}" unless package_name.nil?      
  end
  
  def update_package_metadata_impl(options)
    apt_params = apt_params_for options
    Kernel.system "apt-get update -y #{apt_params} < /dev/null"
    return $CHILD_STATUS.success?
  end
  
  # Updates the metadata for all the packages.
  # Returns true for success, false for failure. 
  def update_package_metadata(options = {})
    return true if update_package_metadata_impl options
    
    if options[:no_proxy]
      # out of alternatives
      return false
    else
      # try bypassing proxy
      return update_package_metadata(options.merge(:no_proxy => true))
    end
  end
  
  # add a source to the package system
  def add_package_source(source_url, source_repos = [], options = {})
    source_prefix = options[:source] ? 'deb-src' : 'deb'
    source_patterns = [source_prefix, source_url] + source_repos    
    
    # grab the sources
    sources = File.open('/etc/apt/sources.list', 'r') { |f| f.read }.split(/(\r|\n)+/)
    
    # see if the source we are trying to add is already there
    source_exists = sources.any? do |source_line|
      source_frags = source_line.split(' ')
      source_patterns.all? { |pattern| source_frags.any? { |frag| frag == pattern } }
    end
    return if source_exists

    # the source does exist, add it
    File.open('/etc/apt/sources.list', 'a') do |f|
      f.write "#{source_prefix} #{source_url} #{source_repos.join(' ')}\n"
    end
  end
end

module RailsPwnage::Base  
  def install_packages(package_names, options = {})
    unroll_collection(package_names) { |n| install_package(n, options) }
  end
  
  def upgrade_packages(package_names, options = {})
    unroll_collection(package_names) { |n| upgrade_package(n, options) }
  end

  def remove_packages(package_names)
    unroll_collection(package_names) { |n| remove_package(n) }
  end
end

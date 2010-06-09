# extends Base with OS package-related functions

require 'English'
require 'fileutils'
require 'shellwords'

module RailsPwnerer::Base
  # TODO: this works for debian-only

  # Executes the given block in the context of having new package sources.
  #
  # Args:
  #   source_url:: the source URL, e.g. http://security.ubuntu.com/ubuntu
  #   repositories:: the package repositories to use, e.g. ['main', 'universe']
  #   options:: supports the following keys:
  #             :source:: if true, will use source-form packages from the new
  #                       sources; by default, binary packages will be used
  #
  # Returns the block's return value.
  #
  # After adding the new package source, the package metadata is refreshed, so
  # the block can focus on installing new packages.
  #
  # If the package source already exists, the given block is yielded without
  # making any changes to the package configuration. 
  def with_new_package_source(source_url, source_repos = [], options = {})
    source_prefix = options[:source] ? 'deb-src' : 'deb'
    source_patterns = [source_prefix, source_url] + source_repos    
    
    source_contents = File.read '/etc/apt/sources.list'
    sources = source_contents.split(/(\r|\n)+/)
    source_exists = sources.any? do |source_line|
      source_frags = source_line.split(' ')
      source_patterns.all? { |pattern| source_frags.any? { |frag| frag == pattern } }
    end

    unless source_exists
      File.open('/etc/apt/sources.list', 'a') do |f|
        f.write "#{source_prefix} #{source_url} #{source_repos.join(' ')}\n"
      end
      update_package_metadata
    end
    
    begin
      yield
    ensure
      unless source_exists
        File.open('/etc/apt/sources.list', 'w') { |f| f.write source_contents }
        update_package_metadata        
      end
    end
  end
    
  # Updates the metadata for all the packages.
  # Returns true for success, false if something went wrong. 
  def update_package_metadata(options = {})
    if update_package_metadata_impl(options)
      # Reset the metadata cache.
      RailsPwnerer::Base.instance_variable_set :@packages, nil
      return true
    end
    
    if options[:no_proxy]
      # out of alternatives
      return false
    else
      # try bypassing proxy
      return update_package_metadata(options.merge(:no_proxy => true))
    end
  end
  
  #
  def update_package_metadata_impl(options)
    apt_params = apt_params_for options
    Kernel.system("apt-get update -qq -y #{apt_params} < /dev/null") ?
       true :false
  end  
  
  # Package info for the best package matching a pattern or set of patterns.
  #
  # Args:
  #   patterns:: a String or Regexp, or an array of such Strings or Regexps
  #
  # Returns a hash with the following keys:
  #   :name:: the package name
  #   :version:: the package version
  #
  # Each pattern is searched for in turn. Once there are packages matching a
  # pattern, the 
  def best_package_matching(patterns)
    patterns = [patterns] unless patterns.kind_of?(Enumerable)
    patterns.each do |pattern|
      packages = search_packages(pattern)
      next if packages.empty?
      best = packages.sort_by { |key, value| value }.last      
      return { :name => best.first, :version => best.last }
    end
    nil
  end

  # Searches for packages matching a name.
  #
  # Args:
  #   pattern:: a String or Regexp containing a pattern that should be matched
  #             by the package names
  #
  # Returns a hash where the keys are matching package names, and the values
  # are version numbers.
  def search_packages(pattern)
    Hash[*(RailsPwnerer::Base.all_packages.select { |key, value|
      pattern.kind_of?(Regexp) ? (pattern =~ key) : key.index(pattern)
    }.flatten)]
  end

  # A hash of all the packages in the system, associated with their versions.
  @packages = nil
  def self.all_packages
    @packages ||= all_packages_without_caching
  end
  
  # A hash of all the packages in the system, associated with their versions.
  #
  # This method is slow as hell, so it's memoized in all_packages.
  def self.all_packages_without_caching
    output = Kernel.` "apt-cache search --full ."
    versions = output.split("\n\n").map(&:strip).reject(&:empty?).map { |info|
      info_hash = Hash[*(info.split(/\n(?=\w)/).
                              map { |s| s.split(': ', 2) }.flatten)]
      [info_hash['Package'], info_hash['Version']]
    }
    Hash[*(versions.flatten)]    
  end
  
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
        deb_files = Dir.glob '*.deb', File::FNM_DOTMATCH
        Kernel.system "dpkg -i #{deb_files.join(' ')}"
        return false unless $CHILD_STATUS.success?
      end
    else
      Kernel.system "apt-get install -y  #{apt_params} #{package_name}"
      return false unless $CHILD_STATUS.success?
    end
    return true
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
end

module RailsPwnerer::Base  
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

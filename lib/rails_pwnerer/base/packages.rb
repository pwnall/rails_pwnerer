# extends Base with OS package-related functions

require 'English'
require 'fileutils'
require 'shellwords'

module RailsPwnerer::Base
  # TODO: this works for debian-only

  # Installs a package matching a pattern or list of patterns.
  #
  # Args:
  #   patterns:: same as for best_package_matching
  #   options:: same as for install_package
  #
  # Returns true for success, false if something went wrong. 
  def install_package_matching(patterns, options = {})
    package = best_package_matching patterns    
    package ? install_package(package[:name], options) : false
  end

  # Installs a package.
  #
  # Args:
  #   package_name:: the exact name of the package to be installed
  #   options:: accepts the following:
  #     :source:: if true, a source package is installed and built
  #     :skip_proxy:: if true, apt is instructed to bypass any proxy that might
  #                   be 
  #
  # Returns true for success, false if something went wrong. 
  def install_package(package_name, options = {})
    return true if install_package_impl(package_name, options)
    if options[:source]
      if options[:no_proxy]
        install_package package_name, options.merge(:source => false)
      else
        install_package package_name, options.merge(:no_proxy => true)
      end
    else
      return false unless options[:no_proxy]
      install_package package_name, options.merge(:no_proxy => true)
    end
  end
  
  # Removes a package.
  #
  # Args:
  #   package_name:: the exact name of the package to be installed
  #
  # Returns true for success, false if something went wrong. 
  def remove_package(package_name, options = {})
    prefix, params = apt_params_for options
    del_cmd = "#{prefix } apt-get remove #{params} #{package_name}"
    Kernel.system(del_cmd) ? true : false
  end  

  # Internals for install_package.
  def install_package_impl(package_name, options)
    prefix, params = apt_params_for options
    if options[:source]
      with_temp_dir(:root => true) do
        dep_cmd = "#{prefix} apt-get build-dep #{params} #{package_name}"
        return false unless Kernel.system(dep_cmd)
        fetch_cmd = "#{prefix} apt-get source -b #{params} #{package_name}"
        return false unless Kernel.system(fetch_cmd)
        deb_files = Dir.glob '*.deb', File::FNM_DOTMATCH
        build_cmd = "#{prefix} dpkg -i #{deb_files.join(' ')}"
        return false unless Kernel.system(build_cmd)
      end
    else
      install_cmd = "#{prefix} apt-get install #{params} #{package_name}"
      return false unless Kernel.system(install_cmd)
    end
    return true
  end
  
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
  def with_package_source(source_url, source_repos = [], options = {})
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
  #
  # Options:
  #   :skip_proxy:: if true, apt is instructed to bypass the proxy
  #
  # Returns true for success, false if something went wrong. 
  def update_package_metadata(options = {})
    if update_package_metadata_impl(options)
      # Reset the metadata cache.
      RailsPwnerer::Base.instance_variable_set :@packages, nil
      return true
    end
    
    return false if options[:skip_proxy]
    update_package_metadata options.merge(:skip_proxy => true)
  end
  
  # Internals for update_package_metadata.
  def update_package_metadata_impl(options)
    prefix, params = apt_params_for options
    Kernel.system("#{prefix} apt-get update #{params}") ?
        true : false
  end
  private :update_package_metadata_impl
  
  # Builds apt-get parameters for an option hash.
  #
  # Args:
  #   options:: an option hash, as passed to install_package, update_package,
  #             or update_package_metadata
  #
  # Returns prefix, args, where prefix is a prefix for the apt- command, and
  # args is one or more command-line arguments.
  def apt_params_for(options = {})
    prefix = 'env DEBIAN_FRONTEND=noninteractive '
    prefix += 'DEBIAN_PRIORITY=critical '
    prefix += 'DEBCONF_TERSE=yes '
    
    params = "-qq -y"
    params += " -o Acquire::http::Proxy=false" if options[:skip_proxy]
    return prefix, params
  end
  private :apt_params_for  
  
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
      best = packages.sort_by { |key, value|
        [
          pattern.kind_of?(Regexp) ? ((key.index(pattern) == 0) ? 1 : 0) :
              ((key == pattern) ? 1 : 0),
          value.split(/[.-]/)
        ]
      }.last      
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
  
  # Upgrades a package to the latest version.
  def upgrade_package(package_name, options = {})
    return install_package(package_name, options) if options[:source]
    
    return true if upgrade_package_impl(package_name, options)
      
    return false if options[:no_proxy]
    upgrade_package package_name, options.merge(:no_proxy => true)
  end

  # Internals for upgrade_package.
  def upgrade_package_impl(package_name, options)
    prefix, params = apt_params_for options
    update_cmd = "#{prefix} apt-get upgrade #{params} #{package_name}"
    Kernel.system(update_cmd) ? true : false
  end
  
  # Upgrades all the packages on the system to the latest version.
  def update_all_packages(options = {})
    return true if update_all_packages_impl(options)
    
    return false if options[:no_proxy]
    update_all_packages options.merge(:no_proxy => true)
  end  
  
  # Internals for upgrade_all_packages.
  def update_all_packages_impl(options)
    prefix, params = apt_params_for options    
    success = Kernel.system "#{prefix} apt-get upgrade #{params}"
    success ? true : false
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

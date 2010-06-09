# extends Base with directory-related functions

require 'etc'
require 'fileutils'

module RailsPwnage::Base  
  # gets the UID associated with the username
  def uid_for_username(name)
    passwd_entry = Etc.getpwnam(name)
    return (passwd_entry.nil?) ? nil : passwd_entry.uid
  end
  
  # gets the GID associated with the username
  def gid_for_username(name)
    passwd_entry = Etc.getpwnam(name)
    return (passwd_entry.nil?) ? nil : passwd_entry.gid    
  end
  
  # gets the main group of the given user
  def group_for_username(name)
    gid = gid_for_username(name)
    return nil if gid.nil?
    group_entry = Etc.getgrgid(gid)
    return (group_entry.nil?) ? nil : group_entry.name 
  end
  
  # gets the currently logged on user
  def current_user
    Etc.getpwuid.name
  end
  
  # executes a block in a temporary directory
  def with_temp_dir(options = {})
    temp_dir = "#{options[:root] ? '/' : ''}rbpwn_#{(Time.now.to_f * 1000).to_i}"
    Dir.mkdir temp_dir
    Dir.chdir(temp_dir) { yield }  
    FileUtils.rm_r temp_dir
  end
  
  # the distribution of the OS
  def os_distro
    if RUBY_ARCH =~ /win/
      return "Windows"
    else
      File.open('/etc/issue', 'r') { |f| f.read }.split(/(\r|\n)+/, 2)[0]
    end     
  end
end

# extends Base with atomic read/write functions

require 'digest/md5'
require 'fileutils'
require 'yaml'

module RailsPwnerer::Base
  # reads the content of one file
  # returns nil if the file is corrupted, otherwise returns [file data, timestamp]
  def atomic_read_internal(file_name)
    begin
      raw_data = File.open(file_name, 'r') { |f| YAML::load f }
      ts_checksum = Digest::MD5.hexdigest("#{raw_data[1]}.#{raw_data[2]}")
      return [nil, Time.at(0, 0)] unless ts_checksum == raw_data[3]
      return [raw_data[0], Time.at(raw_data[1], raw_data[2])]
    rescue Exception
      # fail if the YAML can't be processed or something else goes wrong
      return [nil, Time.at(0, 0)]
    end
  end
  private :atomic_read_internal
  
  # reads the data in a repository
  def atomic_read(path, name)
    main_file = File.join(path, name) + '.yml'
    dup_file = File.join(path, name) + '.yml2'
    
    # choose the single good file or, if both are good, use the latest timestamp
    # this works as long as the time on a box doesn't go back (it's ok to have it skewed)
    results = [main_file, dup_file].map { |file| atomic_read_internal file }
    results.sort { |a, b| b[1] <=> a[1] } 
    return results.first[0]
  end
  
  # writes data to a repository
  def atomic_write(data, path, name, options = {})
    main_file = File.join(path, name) + '.yml'
    dup_file = File.join(path, name) + '.yml2'
    
    # append verification info at the end of the file to guard from incomplete writes
    ts = Time.now
    ts_checksum = Digest::MD5.hexdigest("#{ts.tv_sec}.#{ts.tv_usec}")
    if options[:owner]
      # secure the file
      File.open(dup_file, 'w').close
      uid = uid_for_username options[:owner]
      gid = gid_for_username options[:owner]
      File.chown uid, gid, dup_file
      File.chmod options[:permissions] || 0660, dup_file
    end
    File.open(dup_file, 'w') { |f| YAML::dump [data, ts.tv_sec, ts.tv_usec, ts_checksum], f }
  
    # move the file atomically to the main copy
    FileUtils.mv(dup_file, main_file)
  end

  # erases a repository
  def atomic_erase(path, name)
    main_file = File.join(path, name) + '.yml'
    dup_file = File.join(path, name) + '.yml2'
    [main_file, dup_file].each do |file|
      File.delete file if File.exists? file      
    end
  end
end
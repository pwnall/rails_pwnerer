# implements the configuration repository

module RailsPwnage::Config
  class << self
    include RailsPwnage::Base
  end
    
  # maps each database name to its contents
  @@db_cache = Hash.new
  # maps each database name to its dirty flag
  @@db_dirty = Hash.new
  
  # called when a database is dirty
  def self.mark_db_dirty(db_name)
    @@db_dirty[db_name] = true
  end
  
  # installs the database hooks into a Hash
  def self.install_db_hooks(db_contents, db_name)
    # hooks:
    #  (1) automatically convert keys to strings
    #  (2) flip the dirty flag on writes
    class << db_contents      
      def [](key)
        super(key.to_s)
      end
      def []=(key, value)
        super(key.to_s, value)
        RailsPwnage::Config.mark_db_dirty @db_name
      end
      def has_key?(key)
        super(key.to_s)
      end
    end
    db_contents.instance_variable_set :@db_name, db_name
    return db_contents
  end
  
  # creates a new database
  def self.create_db(db_name)
    db_name = db_name.to_s
    raise "Configuration database #{db_name} already exists" if get_db(db_name)
    
    db_contents = install_db_hooks Hash.new, db_name
    @@db_cache[db_name] = db_contents
    @@db_dirty[db_name] = true
    flush_db db_name
    return db_contents
  end

  # drops a database
  def self.drop_db(db_name)
    @@db_cache[db_name] = nil
    @@db_dirty[db_name] = true
    flush_db db_name
  end
  
  # retrieves the contents of a db (from cache if necessary)
  def self.get_db(db_name)
    db_name = db_name.to_s
    unless @@db_cache.has_key? db_name    
      db_path = RailsPwnage::Config.path_to :config
      db_contents = atomic_read(db_path, db_name)
    
      if db_contents.nil?
        @@db_cache[db_name] = nil
      else
        @@db_cache[db_name] = install_db_hooks db_contents, db_name 
      end
      @@db_dirty[db_name] = false
    end
    
    return @@db_cache[db_name]
  end
  
  # flushes the contents of the given db from cache
  def self.flush_db(db_name)
    db_name = db_name.to_s
    return unless @@db_dirty[db_name]
    db_path = RailsPwnage::Config.path_to :config
    if @@db_cache[db_name].nil?
      atomic_erase db_path, db_name
    else
      host_config = get_db :host
      atomic_write @@db_cache[db_name], db_path, db_name,
                   :owner => (host_config && host_config[:pwnerer_user])
    end
    @@db_dirty[db_name] = false
  end
  
  # flushes the entire database cache (used when exiting)
  def self.flush_db_cache
    @@db_dirty.each do |db_name, is_dirty|
      next unless is_dirty
      flush_db db_name      
    end
  end
  
  # override [] to make the global DB look like a Hash
  def self.[](db_or_app_name, instance_name = nil)
    if instance_name.nil?
      db_name = db_or_app_name
    else
      db_name = app_db_name(db_or_app_name, instance_name)
    end
    get_db(db_name)
  end
  
  def self.databases()
    entries = Dir.entries RailsPwnage::Config.path_to(:config)
    databases = []
    entries.each do |entry|      
      next unless entry =~ /\.yml(2)?$/ 
      databases << entry.gsub(/\.yml(2)?$/, '')
    end
    return databases
  end
  
  # ensures all databases are flushed when the script exits
  Kernel.at_exit { RailsPwnage::Config.flush_db_cache }  
end

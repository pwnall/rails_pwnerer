# manages an application's file system

class RailsPwnage::App::Files
  include RailsPwnage::Base
  
  # dump the application files to the backup area
  def dump_files(app_name, instance_name)
    pwnerer_user = RailsPwnage::Config[app_name, instance_name][:pwnerer_user]
    pwnerer_uid = uid_for_username(pwnerer_user)
    pwnerer_gid = gid_for_username(pwnerer_user)
    
    timestamp = Time.now.strftime '%Y%m%d%H%M%S'
    dump_file = "files/#{app_name}.#{instance_name}_#{timestamp}.tar.gz"
    
    backup_path = RailsPwnage::Config[app_name, instance_name][:backup_path]
    app_path = RailsPwnage::Config[app_name, instance_name][:app_path]
    Dir.chdir backup_path do
      # create a cold copy of the application files
      cold_copy = File.join('tmp', File.basename(app_path))
      FileUtils.rm_r cold_copy if File.exists? cold_copy
      FileUtils.cp_r app_path, 'tmp'
      
      # remove the garbage in the cold copy
      [RailsPwnage::App::Git, RailsPwnage::App::Svn].each do |mod|
        mod.new.cleanup_app_caches cold_copy, instance_name, true
      end
      
      # pack and protect the cold copy
      Dir.chdir 'tmp' do
        system "tar -czf ../#{dump_file} #{File.basename(app_path)}"
      end
      File.chmod(400, dump_file)
      File.chown(pwnerer_uid, pwnerer_gid, dump_file)
      
      # clean up
      FileUtils.rm_r cold_copy
    end    
  end
  
  # creates the directory scaffold in the application's backup dir
  def scaffold_backup(app_name, instance_name)
    pwnerer_user = RailsPwnage::Config[app_name, instance_name][:pwnerer_user]
    pwnerer_uid = uid_for_username(pwnerer_user)
    pwnerer_gid = gid_for_username(pwnerer_user)

    backup_path = RailsPwnage::Config[app_name, instance_name][:backup_path]
    FileUtils.mkpath backup_path unless File.exists? backup_path
    File.chown(pwnerer_uid, pwnerer_gid, backup_path)
    
    Dir.chdir(backup_path) do
      ['db', 'files', 'tmp'].each do |subdir|
        Dir.mkdir subdir unless File.exists? subdir
        File.chown pwnerer_uid, pwnerer_gid, subdir
      end
    end
  end
  
  # loads the latest file dump from the backup area
  def load_files(app_name, instance_name)
    backup_path = RailsPwnage::Config[app_name, instance_name][:backup_path]
    app_path = RailsPwnage::Config[app_name, instance_name][:app_path]
    
    dump_file = Dir.glob(File.join(backup_path, "files/#{app_name}.#{instance_name}_*")).max
    unless dump_file
      dump_file = Dir.glob(File.join(backup_path, "files/#{app_name}.*")).max
    end
    restore_path = Pathname.new(File.join(app_path, '..')).cleanpath.to_s
    Dir.chdir restore_path do
      # find the latest dump and load it in
      system "tar -xzf #{dump_file}"
    end
  end  
  
  # remove the application files
  def drop_files(app_name, instance_name)
    app_config = RailsPwnage::Config[app_name, instance_name]
    # exit and don't complain if the app is busted
    return unless app_config and File.exists? app_config[:app_path]

    app_path = app_config[:app_path]
    FileUtils.rm_r app_path if File.exists? app_path
  end
  
  def manage(app_name, instance_name, action)
    case action
    when :checkpoint
      dump_files app_name, instance_name      
    when :rollback
      drop_files app_name, instance_name
      load_files app_name, instance_name      
    when :console
      Dir.chdir(RailsPwnage::Config[app_name, instance_name][:app_path]) do
        if File.exist? 'script/rails'
          Kernel.system 'rails console production'
        else
          Kernel.system 'ruby script/console production'
        end
      end
    when :db_console
      Dir.chdir(RailsPwnage::Config[app_name, instance_name][:app_path]) do
        if File.exist? 'script/rails'
          Kernel.system 'rails dbconsole production --include-password'
        else
          Kernel.system 'ruby script/dbconsole production --include-password'
        end
      end      
    end
  end

  def setup(app_name, instance_name)
    scaffold_backup(app_name, instance_name)
  end
  
  def remove(app_name, instance_name)
    drop_files(app_name, instance_name)
  end
  
  def update(app_name, instance_name)
    scaffold_backup(app_name, instance_name)    
  end
end
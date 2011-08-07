# runs custom scripts on app events

class RailsPwnerer::App::Scripts
  include RailsPwnerer::Base
  
  def run_script(app_name, instance_name, script_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]    
    pwnerer_user = app_config[:pwnerer_user]
    pwnerer_uid = uid_for_username(pwnerer_user)
    pwnerer_gid = gid_for_username(pwnerer_user)
        
    return unless app_path = app_config[:app_path]  
    
    return unless File.exist?(app_config[:app_path])
    Dir.chdir app_path do
      script_file = Dir.glob(File.join('script/rails_pwnerer', script_name + '*')).first
      return if script_file.nil?
      # run as super-user if the script ends in _su or in _su.extension (e.g. _su.rb)
      su_mode = (script_file =~ /\_su$/) || (script_file =~ /\_su\.[^.]*$/)
      # make sure the script is executable
      mode = File.stat(script_file).mode
      File.chmod((mode | 0100) & 0777, script_file)
      File.chown(pwnerer_uid, pwnerer_gid, script_file)
      
      # run the script under the app's user
      pid = Process.fork do
        unless su_mode
          Process.uid = pwnerer_uid        
          Process.gid = pwnerer_gid
          Process.egid = pwnerer_gid
          Process.euid = pwnerer_uid
        end
        Dir.chdir app_path do
          script_prefix = (script_file[0] == ?/) ? '' : './'
          Kernel.system %Q|#{script_prefix}#{script_file} "#{app_name}" "#{instance_name}"|
        end
      end
      Process.wait pid
    end
  end
  
  def setup(app_name, instance_name)
    run_script app_name, instance_name, 'setup'
  end
  
  def update(app_name, instance_name)
    run_script app_name, instance_name, 'update'
  end

  def remove(app_name, instance_name)
    run_script app_name, instance_name, 'remove'
  end

  def pre_start(app_name, instance_name)
    run_script app_name, instance_name, 'pre_start'
  end
  def post_start(app_name, instance_name)
    run_script app_name, instance_name, 'post_start'
  end
  def pre_stop(app_name, instance_name)
    run_script app_name, instance_name, 'pre_stop'
  end
  def post_stop(app_name, instance_name)
    run_script app_name, instance_name, 'post_stop'
  end
  def pre_reset(app_name, instance_name)
    run_script app_name, instance_name, 'pre_reset'
  end
  def post_reset(app_name, instance_name)
    run_script app_name, instance_name, 'post_reset'
  end

  def control_all(action)
    RailsPwnerer::Config.all_applications.each do |ai|
      run_script ai[0], ai[1], (case action
      when :pre_start then 'pre_start'
      when :post_start then 'post_start'
      when :pre_stop then 'pre_stop'
      when :post_stop then 'post_stop'
      when :pre_reset then 'pre_reset'
      when :post_reset then 'post_reset'
      end)
    end 
  end
end
# application-specific configuration functions

module RailsPwnerer::Config
  # the name of the database storing an app's configuration
  def self.app_db_name(app_name, instance_name)
    return "#{app_name}.#{instance_name}"
  end
  
  # the instances of an application installed on this box
  def self.app_instances(app_name)
    self.databases().select { |db| db.include? ?. }.map { |db| db[0...(db.rindex ?.)] }
  end
  
  # all instances of all applications installed on this box
  def self.all_applications()
    self.databases().select { |db| db.include? ?. }.map do |db|
      lastdot = db.rindex ?.
      [db[0...lastdot], db[(lastdot + 1)..-1]]
    end
  end
end

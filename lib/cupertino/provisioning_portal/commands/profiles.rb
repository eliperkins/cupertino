command :'profiles:list' do |c|
  c.syntax = 'ios profiles:list [development|distribution]'
  c.summary = 'Lists the Provisioning Profiles'
  c.description = ''

  c.action do |args, options|
    type = args.first.downcase.to_sym rescue nil
    profiles = try{agent.list_profiles(type ||= :development)}

    say_warning "No #{type} provisioning profiles found." and abort if profiles.empty?

    table = Terminal::Table.new do |t|
      t << ["Profile", "App ID", "Status"]
      t.add_separator
      profiles.each do |profile|
        status = case profile.status
                 when "Invalid"
                   profile.status.red
                 else
                   profile.status.green
                 end

        t << [profile.name, profile.app_id, status]
      end
    end

    puts table
  end
end

alias_command :profiles, :'profiles:list'

command :'profiles:add' do |c|
  c.syntax = 'ios profiles:add [options] NAME'
  c.summary = 'Add/Create a provisioning profile'
  c.description = ''

  c.option '-t', '--type TYPE', 'Type of provisioning profile, development or distribution'
  c.option '-a', '--appId APP_ID', 'App ID for provisioning profile'

  c.action do |args, options|
    name = args.first
    say_error "No profile name specified" and abort if args.nil? or args.empty? or name.nil?

    type = options.type || 'development'
    say_error "No type specified" and abort if type.nil?

    app_id = options.appId
    say_error "No type specified" and abort if app_id.nil?

    profile = ProvisioningProfile.new
    profile.type = type
    profile.name = name
    profile.app_id = app_id
    agent.add_profile(profile)

    say_ok "Successfully added profile"
  end

end

command :'profiles:manage:devices' do |c|
  c.syntax = 'ios profiles:manage:devices'
  c.summary = 'Manage active devices for a development provisioning profile'
  c.description = ''

  c.action do |args, options|
    type = args.first.downcase.to_sym rescue nil
    profiles = try{agent.list_profiles(type ||= :development)}

    say_warning "No #{type} provisioning profiles found." and abort if profiles.empty?

    profile = choose "Select a provisioning profile to manage:", *profiles

    agent.manage_devices_for_profile(profile) do |on, off|
      lines = ["# Comment / Uncomment Devices to Turn Off / On for Provisioning Profile"]
      lines += on.collect{|device| "#{device}"}
      lines += off.collect{|device| "# #{device}"}
      result = ask_editor lines.join("\n")

      devices = []
      result.split(/\n+/).each do |line|
        next if /^\#/ === line
        components = line.split(/\s+/)
        device = Device.new
        device.udid = components.pop
        device.name = components.join(" ")
        devices << device
      end

      devices
    end

    say_ok "Successfully managed devices"
  end
end

alias_command :'profiles:manage', :'profiles:manage:devices'

command :'profiles:download' do |c|
  c.syntax = 'ios profiles:download'
  c.summary = 'Downloads the Provisioning Profiles'
  c.description = ''

  c.action do |args, options|
    type = args.first.downcase.to_sym rescue nil
    profiles = try{agent.list_profiles(type ||= :development)}
    profiles = profiles.find_all{|profile| profile.status == 'Active'}

    say_warning "No active #{type} profiles found." and abort if profiles.empty?
    profile = choose "Select a profile to download:", *profiles
    if filename = agent.download_profile(profile)
      say_ok "Successfully downloaded: '#{filename}'"
    else
      say_error "Could not download profile"
    end
  end
end

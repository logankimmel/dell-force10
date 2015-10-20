#Provide for force10 'VLAN' Type

require 'puppet/provider/dell_ftos'
require 'pry'
require 'pry-debugger'

Puppet::Type.type(:force10_vlan).provide :dell_ftos, :parent => Puppet::Provider::Dell_ftos do

  desc "Dell Force10 switch provider for vlan configuration."

  mk_resource_methods

  def self.get_current(name)
    transport.switch.vlan(name).params_to_hash
  end

  def flush
    transport.switch.vlan(name).update(former_properties, properties)
    super
  end

  def exists?
    @vlan = name.dup
    vlan_info = get_vlan_info[name.to_s]
    !vlan_info.nil?
  end

  def get_vlan_info
    @vlan_info ||= JSON.parse(transport.switch.all_vlans)
    @vlan_info
  end

  def get_vlan
    @vlan.to_s
  end

  def create
    # Placeholder (noop)
  end

  def destroy
    vlan = get_vlan
    vlan_info = get_vlan_info[vlan.to_s]
    Puppet.debug("VLAN to destroy: #{vlan_info}")
    iface_map = {
        'tengigabit' => 'tengigabitethernet',
        'fortygigabit' => 'fortyGigE',
        'gigabit' => 'gigabitethernet',
        'portchannel' => 'port-channel'
    }
    transport.session.command('configure', :prompt => /\(conf\)#\s?\z/n)
    transport.session.command("interface vlan #{vlan}", :prompt => /\(conf-if-vl-#{vlan}\)#\s?\z/n)
    # Remove port associations first
    vlan_info.each do |k,v|
      if v.is_a? String
        type = k.split('_')[0]
        speed = iface_map[k.split('_')[1]]
        command_str = "no #{type} #{speed} #{v}"
        transport.session.command(command_str)
      end
    end
    transport.session.command('exit')
    #remove complete vlan
    transport.session.command("no interface vlan #{vlan}")
    transport.session.command('exit')
  end


end

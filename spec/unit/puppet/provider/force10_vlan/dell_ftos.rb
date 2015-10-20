require 'rspec/expectations'
require 'json'
require 'puppet'

describe Puppet::Type.type(:force10_vlan).provider(:dell_ftos) do
  let(:resource) {Puppet::Type.type(:force10_vlan).new(
      {
          :name => '18',
          :vlan_name => 'VLAN_18',
          :desc => 'VLAN 18 created by ASM',
          :shutdown => false,
          :ensure => 'absent'

      })}
  let(:provider) {resource.provider}

  before :each do
    @fixture_dir = File.join(Dir.pwd, 'spec', 'fixtures')
    vlan_info = {
        "18" => {
            "tagged_tengigabit" => "0/1-6,8-9,12,15-16",
            "untagged_tengigabit" => {},
            "tagged_fortygigabit" => {},
            "untagged_fortygigabit" => {},
            "tagged_portchannel" => "1",
            "untagged_portchannel" => {}
        }
    }
    provider.stub(:get_vlan_info).and_return(vlan_info)
  end

  describe '#exists?' do
    context 'when vlan exists' do
      it 'returns true' do
        expect(provider.exists?).to eq(true)
      end
    end
    context 'when vlan does not exist' do
      it 'returns false' do
        vlan_info = {
            "16" => {
                "tagged_tengigabit" => "0/1-6,8-9,12,15-16",
                "untagged_tengigabit" => {},
                "tagged_fortygigabit" => {},
                "untagged_fortygigabit" => {},
                "tagged_portchannel" => "1",
                "untagged_portchannel" => {}
            }
        }
        provider.stub(:get_vlan_info).and_return(vlan_info)
        expect(provider.exists?).to eq(false)
      end
    end
  end

  describe '#destroy' do
    it 'issues vlan teardown commands' do

      provider.stub(:get_vlan).and_return('18')
      session = double('session')
      transport = double('transport')
      provider.stub(:transport).and_return(transport)
      transport.stub(:session).and_return(session)
      session.should_receive(:command).once.ordered.with('configure', {:prompt=>/\(conf\)#\s?\z/n})
      session.should_receive(:command).once.ordered.with('interface vlan 18', :prompt => /\(conf-if-vl-18\)#\s?\z/n)
      session.should_receive(:command).once.ordered.with('no tagged tengigabitethernet 0/1-6,8-9,12,15-16')
      session.should_receive(:command).once.ordered.with('no tagged port-channel 1')
      session.should_receive(:command).once.ordered.with('exit')
      session.should_receive(:command).once.ordered.with('no interface vlan 18')
      session.should_receive(:command).once.ordered.with('exit')

      provider.destroy
    end
  end
end
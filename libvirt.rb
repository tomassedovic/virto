#!/usr/bin/env ruby
$: << File.expand_path(File.dirname(__FILE__))

require 'thor'
require 'virt_manager'

LIBVIRT_URI = "qemu:///system"
MAC_PREFIX = '52:33:'

class App < Thor
  def initialize(*args)
    network_name = nil  # Use the default network for now
    @virt = VirtManager.new(LIBVIRT_URI, MAC_PREFIX, network_name)
    super(*args)
  end

  desc "setup-network", "Sets up the default libvirt network's DHCP"
  def setup_network()
    puts "Setting up the network #{@virt.network_name}"
    @virt.setup_network()
    ip_addresses = @virt.all_ip_addresses
    puts "Network set up for IP addresses: #{ip_addresses.first} - #{ip_addresses.last}"
  end


  desc "images", "List the base images to launch VMs from"
  def images
    puts @virt.images
  end


  desc "create IMAGE NAME", "Launches a new virtual machine from the given image"
  def create(image_name, vm_name)
    # alias: launch?

    new_ip = @virt.available_ip_addresses.first
    unless new_ip
      raise Thor::Error.new("There are no more IP addresses available. Shut down some of your VMs.")
    end

    new_mac = @virt.mac_from_ip_address(new_ip)
    begin
      @virt.clone_vm(image_name, vm_name, new_mac)
      vm = @virt.find_vm_by_name(vm_name)
      vm.create
      puts "#{vm_name} was successfully launched. It's IP address is: #{new_ip}"
    rescue VirtManager::UnknownImage
      raise Thor::Error.new("Unknown image: #{image_name}")
    rescue VirtManager::InvalidName
      raise Thor::Error.new("The VM name must contain letters, numbers, underscores and dashes only.")
    rescue VirtManager::NameAlreadyTaken
      raise Thor::Error.new("Virtual machine '#{vm_name}' already exists. Pick another name.")
    end
  end


  desc "list", "Lists all the virtual machines (running and stopped)"
  def list
    known_vms = @virt.all_vms.select do |vm|
      @virt.known_mac?(@virt.mac_address_from_vm(vm))
    end

    if known_vms.empty?
      puts "(there are no know virtual machines)"
    else
      states_descriptions = {
        1 => 'running',
        5 => 'stopped'
      }
      states_descriptions.default = 'TODO: not implemented yet'
      table = known_vms.map do |vm|
        "#{vm.name}\t\t#{states_descriptions[vm.state.first]}"
      end
      puts table
    end
  end


  desc "ssh NAME USER", "SSH into the given VM"
  def ssh(name, user='root')
    vm = @virt.find_vm_by_name(name)
    raise Thor::Error.new("Unknown VM: '#{name}'") unless vm
    raise Thor::Error.new("#{name} is not running") unless (vm.state.first == 1)

    ip = @virt.ip_address_from_mac(@virt.mac_address_from_vm(vm))
    puts "IP address of #{name}: #{ip}"
    exec %Q(ssh #{user}@#{ip} -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null")
  end


  desc "mount NAME", "Mount the VM's filesystem using sshfs"
  def mount(name)
    puts "TODO: sshfs the VM's disk"
  end


  desc "stop NAME", "Stop the running VM"
  def stop(name)
    vm = @virt.find_vm_by_name(name)
    raise Thor::Error.new("Unknown VM: '#{name}'") unless vm
    raise Thor::Error.new("#{name} is not running") unless (vm.state.first == 1)
    vm.destroy
    puts "#{name} was stopped."
  end


  desc "start NAME", "Start a stopped VM"
  def start(name)
    # alias: launch?
    puts "TODO"
  end


  desc "restart NAME", "Restart the running VM"
  def restart(name)
    # alias: reboot?
    puts "TODO"
  end

  desc "destroy NAME", "Delete the VM and its image"
  def destroy(name)
    # alias: delete, remove?
    puts "TODO"
    # - get the domain's image path
    # - undefine the domain
    # - delete the image
    # - refresh the pool (otherwise subsequent creating fails)
  end
end

App.start
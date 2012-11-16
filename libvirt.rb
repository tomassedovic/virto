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
    puts "TODO"
  end


  desc "create IMAGE", "Launches a new virtual machine from the given image"
  def create(image)
    puts 'TODO: clone the image and launch a new VM'
  end


  desc "list", "Lists all the virtual machines (running and stopped)"
  def list
    puts "TODO"
  end


  desc "ssh NAME", "SSH into the given VM"
  def ssh(name)
    puts "TODO: get the VM's IP and SSH into it"
  end


  desc "mount NAME", "Mount the VM's filesystem using sshfs"
  def mount(name)
    puts "TODO: sshfs the VM's disk"
  end


  desc "stop NAME", "Stop the running VM"
  def stop(name)
    # alias: shutdown?
    puts "TODO"
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
end

App.start
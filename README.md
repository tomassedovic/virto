virto
=====

You need to build your base VMs first. Use `virt-install`, `Oz`, `virt-manager` or anything else you prefer.

Currently the only reliable way of getting an IP address from a VM I know about is to have libvirt's DHCP assign a known IP to a known MAC.

That means 2 things:

1. You need to setup your libvirt network to add that MAC-IP mapping
2. Instances with unknown MAC addresses won't get an IP and if they do, `virto` won't be able to see it.


Commands:

setup-network, images, create, start, stop, reboot, ssh


setup-network
-------------

This sets up the default network automatically. All the VMs must be stopped (TODO: verify this is a real libvirt requirement).

It will add the IP-MAC mapping
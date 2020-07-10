---
layout: post
title: "Install Debian Stretch on VMWare with Custom Iptables NAT"
author: "brinkt"
date: 2018-11-09
tags: debian linux vmware nat iptables
---

This guide installs Debian 9.5 on *VMWare* using a virtual network bridge and NAT within iptables to isolate the virtual machine from connecting to other machines on local network, while still allowing outside connectivity. Only *udp* DNS requests are allowed from virtual machine to local network.

### Step 1: Setup virtual network bridge

Create a virtual network bridge:

    $ sudo apt-get install bridge-utils
    $ sudo brctl addbr vnet1

List network bridges:

    $ brctl show

Setup network interface:

    $ sudo nano /etc/network/interfaces

Add the following:

```
auto vnet1
iface vnet1 inet static
    address 172.17.0.1
    netmask 255.255.255.0
    bridge_ports none
    bridge_maxwait 0
    bridge_fd 1
```

Start the virtual network interface:

    $ sudo ifup vnet1

Check network status using:

    $ ifconfig

Local network `eth0` configured as follows:

  - IP: 192.168.1.100
  - Gateway: 192.168.1.1

### Step 2: Configure iptables forwarding

Enable forwarding:

    $ sudo echo 1 > /proc/sys/net/ipv4/ip_forward

Add the following to iptables rules:

```
# vnet1: drop new connections to local machine
-A INPUT -s 172.17.0.0/24 -m conntrack --ctstate NEW -j DROP

# vnet1: accept solicited packets in
-A FORWARD -i eth0 -o vnet1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# vnet1: forward related packets out
-A FORWARD -i vnet1 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# vnet1: forward packets (except those going to local network)
-A FORWARD -i vnet1 -o eth0 ! -d 192.168.1.0/24 -j ACCEPT

# vnet1: forward dns requests (to local interface)
-A FORWARD -i vnet1 -o eth0 -p udp --dport 53 -j ACCEPT

# reject everything else
-A FORWARD -j REJECT
```

Within `nat` section of iptables rules:

```
-A POSTROUTING -j MASQUERADE
```

### Step 3: Install Debian 9.5 netinst

Grab the latest `amd64` image from [https://www.debian.org/CD/netinst/](https://www.debian.org/CD/netinst/).

Within *VMWare Workstation*, open `Edit => Virtual Network Editor`, click `Add Network...`, choose `Bridged`, click `Add`.

For `vmnet3` adapter, created above, set bridged to `vnet1`, click `Save`.

Within *VMWare Workstation*, open `File => New Virtual Machine`, choose `I will install the operating system later`, click `Next`.

Choose `Linux` as operating system, specifying the latest `Debian` version, click `Next`.

Choose *Name* and *Location* of virtual machine, click `Next`, use defaults for disk, click `Next`, click `Customize Hardware...`.

Under *Device* choose `New CD/DVD (IDE)`. Change `Use a physical drive` to `Use ISO image`, click `Browse...` and select the install image downloaded above.

Under *Device* choose `Network Adapter`. Change `NAT` to `Custom: Specify virtual network`, select `/dev/vmnet3`.

Click, `Close`, click `Finish`.

Power on and complete the installation, creating a new user account `anon`, then reboot.

### Step 4: Setup network interface

Determine network interface:

    $ sudo ifconfig

Stop network interface:

    $ sudo ifdown ens33

Since no DHCP server was installed, setup network interface with static IP:

    $ sudo nano /etc/network/interfaces

Add the following:

```
auto ens33
iface ens33 inet static
    address 172.17.0.10
    netmask 255.255.255.0
    broadcast 172.17.0.255
    gateway 172.17.0.1
```

Update `resolv.conf` to reflect correct DNS server:

    $ sudo nano /etc/resolv.conf

Change `nameserver` to correct IP address:

    nameserver 192.168.1.1

This is the router on the local network which we forward DNS traffic from the virtual machine to.

Start network interface:

    $ sudo ifup ens33

That's it!

### Extra: System packages & commands

```
$ apt-get install lsof vim ca-certificates ssh
```

To show listening programs:

```
$ lsof -i
```

To see local network ip:

```
$ ip route show
```

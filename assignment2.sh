#!/bin/bash

# Assignment 2: System Modification Script
# Determine what modifications are necessary by conducting testing before implementing a change
# Make sure to provide updates and notify the user of changes being made
# Should produce human-friendly error information should errors occur

##### NETWORK CONFIGURATION #####

static_ip="192.168.16.21/24"
gateway_ip="192.168.16.1"
dnsserver_ip="192.168.16.1"
dns_searchdomain="home.arpa localdomain"

# Get the name of the second interface (host-only) and make sure it exists
hostonly_interface=$(ip a | grep "ens" | awk 'FNR==3 {print $2}' | sed 's/://')
if [ -n "$hostonly_interface" ]; then
    echo "Changing IP address of $hostonly_interface"
else
    echo "No second network interface found. Unable to make changes to IP address. Exiting script."
    exit 1
fi

#Check if .yaml file exists
yaml_hostonly="01-network-$hostonly_interface.yaml"

if [ -f /etc/netplan/"$yaml_hostonly"]; then
    echo "Skipping configuration for $hostonly_interface. YAML file for $hostonly_interface already exists!"
else
    #If yaml file does not exist, create a new yaml file for the host-only interface
    cat > "$yaml_hostonly" <<EOF
    network:
      version: 2
      renderer: networkd
      ethernets:
        $hostonly_interface:
          addresses: [$static_ip]
          gateway4: [$gateway_ip]
          nameservers:
            search: [home.arpa, localdomain]
            addresses: [$dnsserver_ip]
EOF
    echo "Changed network configuration file for interface: $hostonly_interface"
fi

#Apply network configuration changes to system

if netplan apply > /dev/null; then
    echo "Netplan configuration changes to $hostonly_interface have been applied!"
else
    echo "Failed to apply netplan configuration changes to $hostonly_interface. Exiting script."
    exit 1
fi

#Check if hostonly_interface IP address was set correctly
new_hostip=$(ip a | grep "ens" | awk 'FNR==4 {print $2}')

if ["$new_hostip" == "$static_ip" ]; then
    echo "$hostonly_interface interface IP address was configured correctly."
else
    echo "Failed to change $hostonly_interface IP address. Exiting script"
    exit 1
fi

##### INSTALL AND CONFIGURE REQUIRED SOFTWARE #####










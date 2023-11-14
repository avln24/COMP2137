#!/bin/bash

# Assignment 2: System Modification Script
# Determine what modifications are necessary by conducting testing before implementing a change
# Make sure to provide updates and notify the user of changes being made
# Should produce human-friendly error information should errors occur

##### Checking for Sudo #####
#echo "Checking for sudo"
#[ "$(id -u)" -eq 0 ] 

##### NETWORK CONFIGURATION #####

static_ip="192.168.16.21/24"
gateway_ip="192.168.16.1"
dnsserver_ip="192.168.16.1"
dns_searchdomain="home.arpa localdomain"

# Get the name of the second interface (host-only) and make sure it exists
hostonly_interface=$(ip a | grep -E "ens|eth" | grep "inet" | awk 'FNR==2 {print $7}')
old_hostonlyip=$(ip a | grep -E "ens|eth" | grep "inet" | awk 'FNR==2 {print $2}')

if [ -n "$hostonly_interface" ]; then
    echo "Host only interface found: $hostonly_interface"
else
    echo "No second network interface found. Unable to make changes to IP address. Exiting script."
    exit 1
fi

#Check if .yaml file exists
yaml_hostonly="01-network-$hostonly_interface.yaml"
echo "Checking if netplan YAML file already exists for $hostonly_interface"

if [ -f "/etc/netplan/$yaml_hostonly" ]; then
    echo "Skipping configuration for $hostonly_interface. YAML file for $hostonly_interface already exists!"
else
    echo "Checking if configuration for $hostonly_interface exists in another YAML file."
    #Check if configuration for $hostonly_interface exists in another YAML file and remove it if it does
    existing_yamlfile=$(find /etc/netplan/ -type f -name '*.yaml')
    sed -Ei "/[[:space:]]$hostonly_interface/,/        ./d" $existing_yamlfile

    #If yaml file does not exist, create a new yaml file for the host-only interface
    echo "Creating netplan YAML file for $hostonly_interface with proper network configurations"
    cat > "/etc/netplan/$yaml_hostonly" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $hostonly_interface:
      addresses: [$static_ip]
      routes:
        - to: 0.0.0.0
          via: $gateway_ip
      nameservers:
        search: [home.arpa, localdomain]
        addresses: [$dnsserver_ip]
EOF
    echo "Created netplan YAML file /etc/netplan/$yaml_hostonly with for interface: $hostonly_interface"
    
    #Apply network configuration changes to system
    echo "Applying network configuration changes to system"
    sudo netplan apply > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Netplan configuration changes to $hostonly_interface have been applied!"
    else
        echo "Failed to apply netplan configuration changes to $hostonly_interface. Exiting script."
        exit 1
    fi
fi

#Check if hostonly_interface IP address was set correctly
new_hostonlyip=$(ip a | grep -E "ens|eth" | grep "inet" | awk 'FNR==2 {print $2}')

if [ "$static_ip" = "$new_hostonlyip" ]; then
    echo "$hostonly_interface interface IP address is configured correctly."
else
    echo "$hostonly_interface does not have the correct static IP address. Exiting script"
    exit 1
fi

#Change IP address for hostonly_interface in /etc/hosts file
echo "Checking if IP address for server1-mgmt in /etc/hosts needs to be changed."
server1mgmt_oldip=$(grep "server1-mgmt" /etc/hosts | awk '{print $1}')
server1mgmt_newip=$(ip a | grep -E "ens|eth" | grep "inet" | awk 'FNR==2 {print $2}' | sed 's/[/]..//')

if [ "$server1mgmt_oldip" != "$old_hostonlyip" ]; then
    echo "Changing IP address for server1-mgmt in /etc/hosts file"
    sed -Ei "s/$server1mgmt_oldip/$server1mgmt_newip/" /etc/hosts
    echo "Checking if IP address was changed for server1-mgmt"
    if [ $(grep "server1-mgmt" /etc/hosts | awk '{print $1}') = server1mgmt_newip ];
        then echo "IP address for server1-mgmt in /etc/hosts file was changed!"
    fi
else
    echo "IP address for server1-mgmt in /etc/hosts is already correct."
fi

##### INSTALL AND CONFIGURE REQUIRED SOFTWARE #####










#!/bin/bash

# Assignment 2: System Modification Script
# Determine what modifications are necessary by conducting testing before implementing a change
# Make sure to provide updates and notify the user of changes being made
# Should produce human-friendly error information should errors occur

##### Checking for Sudo #####
echo "Checking for sudo"
if [ "$(id -u)" -eq 0 ]; then
    echo "Running system modification script."
else
    echo "User does not have sudo permissions. Cannot run script."
    exit 1
fi

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

#Change IP address for hostonly_interface in /etc/hosts file
echo "Checking if IP address for server1-mgmt in /etc/hosts needs to be changed."
server1mgmt_oldip=$(grep "server1-mgmt" /etc/hosts | awk '{print $1}')
server1mgmt_newip=$(ip a | grep -E "ens|eth" | grep "inet" | awk 'FNR==2 {print $2}' | sed 's/[/]..//')

if [ "$server1mgmt_oldip" != "$old_hostonlyip" ]; then
    echo "Changing IP address for server1-mgmt in /etc/hosts file"
    sed -Ei "s/$server1mgmt_oldip/$server1mgmt_newip/" /etc/hosts
    echo "Checking if IP address was changed for server1-mgmt"
    if [ "$(grep "server1-mgmt" /etc/hosts | awk '{print $1}')" = "$server1mgmt_newip" ];
        then echo "IP address for server1-mgmt in /etc/hosts file was changed!"
    fi
else
    echo "IP address for server1-mgmt in /etc/hosts is already correct."
fi

#Check if hostonly_interface IP address was set correctly
new_ip=$(ip a | grep -E "ens|eth" | grep "inet" | awk 'FNR==2 {print $2}')

if [ "$new_ip" = "$static_ip" ]; then
    echo "$hostonly_interface interface IP address is configured correctly."
else
    echo "$hostonly_interface does not have the correct static IP address. Exiting script"
    exit 1
fi

##### INSTALL AND CONFIGURE REQUIRED SOFTWARE #####

#Check if openssh, apache2, and squid web proxy are already installed
#If package is not installed, install it

packages="openssh-server apache2 squid"

for package in $packages; do
    dpkg-query -s $package 2> /dev/null | grep "installed" > /dev/null 2>&1  
    if [ $? -ne 0 ]; then
        echo "Installing package: $package"
        sudo apt install -y $package > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Package: $package was successfully installed!"
        else
            echo "Installation of package: $package failed. Exiting script."
            exit 1
        fi
    else
        echo "Package: $package is already installed! Skipping installation of $package."
    fi
done

#CONFIGURE OPENSSH-SERVER
#Openssh-server allowing ssh key authentication and not allowing password authentication

ssh_config="/etc/ssh/sshd_config"
echo "Checking if OpenSSH server public key authentication is enabled"
if [ $(grep -i "PubkeyAuthentication" $ssh_config | awk '{print $2}') = "yes" ]; then
    #Check if PubkeyAuthentication is uncommented
    grep -i "#PubkeyAuthentication" $ssh_config
    if [ $? -eq 0  ]; then
        echo "Uncommenting PubkeyAuthentication in $ssh_config"
        sed -i.bak '/PubkeyAuthentication/ s/#//' $ssh_config
    else
        echo "Public key authentication is already enabled for OpenSSH-server. Skipping this step."
    fi
else
    echo "Enabling public key authentication for OpenSSH-server."
    #Uncomment PubKeyAuthentication and change to yes in /etc/ssh/sshd_config
    sed -i.bak '/PubkeyAuthentication/ s/#//;s/no/yes/' $ssh_config 
    #Uncomment AuthorizedKeysFile in /etc/ssh/sshd_config
    sed -i.bak '/AuthorizedKeysFile/ s/#//' $ssh_config 

    #Check if change to /etc/ssh/sshd_config was successfully made
    if [ $(grep -i "PubkeyAuthentication" $ssh_config | awk '{print $2}') = "yes" ]; then
        echo "Public key authentication successfully enabled for OpenSSH-server."
    else
        echo "Failed to enable public key authentication for OpenSSH-server. Exiting script."
        exit 1
    fi
fi

echo "Checking if OpenSSH server password authentication is disabled"
if [ $(grep -i "PasswordAuthentication" $ssh_config | awk 'FNR==1 {print $2}') = "no" ]; then
    echo "Password authentication is already disabled for OpenSSH-server. Skipping this step"
else
    echo "Disabling password authentication for OpenSSH-server."
    #Change PasswordAuthentication from yes to no in /etc/ssh/sshd_config
    sed -i.bak '/PasswordAuthentication/ s/yes/no/' $ssh_config 
    if [ $(grep -i "PasswordAuthentication" $ssh_config | awk 'FNR==1 {print $2}') = "no" ]; then
        echo "Password authentication successfully disabled for OpenSSH-server."
    else
        echo "Failed to disable password authentication for OpenSSH-server. Exiting script."
        exit 1
    fi
fi

#Restart SSH service to apply changes made to /etc/ssh/sshd_config
sudo systemctl restart ssh && echo "Restarted SSH service."

#CONFIGURE APACHE2
#Apache2 web server listening for http on port 80 and https on port 443
#Check /etc/apache2/ports.conf if Apache2 web server is listening to port 80
grep -iw 'Listen 80' /etc/apache2/ports.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Apache2 web server is already listening to port 80"
else
    echo "Adding 'Listen 80' to /etc/apache2/ports.conf"
    sed -i '/<IfModule ssl_module>/i Listen 80\n' /etc/apache2/ports.conf
fi

#Check /etc/apache2/sites-enabled/000-default.conf if <VirtualHost: *:80>
grep -iw '<VirtualHost \*:80>' /etc/apache2/sites-available/000-default.conf > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Changing VirtualHost port in /etc/apache2/sites-available/000-default.conf to port 80."
    sed -i '/VirtualHost \*:/ s/:.*/:80>/' /etc/apache2/sites-available/000-default.conf
else
    echo "/etc/apache2/sites-available/000-default.conf is already configured with the correct port."
fi

#Check /etc/apache2/ports.conf if Apache2 web server is listening to port 443
grep -iw 'Listen 443' /etc/apache2/ports.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Apache2 web server is already listening to port 443"
else
    echo "Adding 'Listen 443' to /etc/apache2/ports.conf"
    sed -i '/<IfModule ssl_module>/a \ \ \ \ \ \ \ \ Listen 443' /etc/apache2/ports.conf
fi

#Check /etc/apache2/sites-enabled/default-ssl.conf if <VirtualHost _default_:443>
grep -iw '<VirtualHost _default_:443>' /etc/apache2/sites-available/default-ssl.conf > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Changing VirtualHost port in /etc/apache2/sites-available/default-ssl.conf to port 443."
    sed -i '/VirtualHost _default_:/ s/:.*/:443>/' /etc/apache2/sites-available/default-ssl.conf
else
    echo "/etc/apache2/sites-available/default-ssl.conf is already configured with the correct port."
fi

#Enable Apache2 SSL module (HTTPS)
echo "Enabling SSL for Apache2 web server"
a2enmod ssl > /dev/null 2>&1 && a2ensite default-ssl > /dev/null 2>&1 && echo "SSL enabled for Apache2 web server"
echo "Reloading Apache2 web service"
systemctl reload apache2

#CONFIGURE SQUID WEB PROXY
#Squid web proxy listening on port 3128
grep -iw 'http_port 3128' /etc/squid/squid.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Squid web proxy is already listening to port 3128"
else
    echo "Changing listening port on Squid web proxy to port 3128"
    sed -i 's/http_port .*/http_port 3128/' /etc/squid/squid.conf
fi

##### ENABLE FIREWALL AND ADD UFW RULES #####
#Check if firewall is enabled:
ufw status | grep "Status: active"
if [ $? -eq 0 ]; then
    echo "Firewall is already active. Skipping to next step."
else
    echo "Enabling firewall."
    ufw --force enable 
fi

#Check if ufw rule already exists, if it does not exist then add it.
ports="22 80 443 3128"

for port in $ports; do
    ufw status | grep "$port" | grep "ALLOW" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "UFW ALLOW $port already exists."
    else
        echo "Adding UFW ALLOW $port..."
        ufw allow $port/tcp
    fi
done
    






#!/bin/bash

# Assignment 3: Automated Configuration

#NOTE: your script must only use ssh to access the target1 and target2 machines

##### Configuring Target1-mgmt (172.16.1.10) #####

echo "Configuring Server1"

#Change system name from target1 to loghost (both hostname and /etc/hosts file)
#Check if hostname is already set to loghost, and change it if is not
cat > server1-config.sh << EOF

echo "Checking hostname..."
if [ "$(hostname)" = "loghost" ]; then
    echo "System name is already configured as "loghost", skipping step"
else
    echo "Changing system name to 'loghost'..."
    hostnamectl set-hostname loghost 
    grep "loghost" /etc/hostname
    if [ $? -eq 0 ]; then
        echo "System name was successfully changed to loghost."
    else
        echo "Failed to change system name to loghost."
        exit 1
    fi
fi
EOF

#Check if "loghost" exists inside /etc/hosts file and add it if it does not
cat >> server1-config.sh << EOF

echo "Checking for loghost entry inside /etc/hosts file..."
grep -w "loghost" /etc/hosts > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "hostname already configured to loghost within /etc/hosts file"
else
    echo "Changing hostname to loghost within /etc/hosts file..."
    grep "$(hostname -I | awk '{ print $1 }')" /etc/hosts | sed -i '0,/server1/ s/server1/loghost/' /etc/hosts 
    grep "loghost" /etc/hosts
    if [ $? -eq 0 ]; then 
        echo "Hostname was changed to loghost within /etc/hosts!"
    else
        echo "Failed to change hostname to loghost in /etc/hosts."
        exit 1
    fi
fi   
EOF

#Change IP Address from host 10 to host 3 on the LAN
cat >> server1-config.sh << EOF

echo "Checking IP address: if current host is host 3 on LAN..."
lan_netip=$(hostname -I | awk '{ print $1 }' | sed 's/.10$//') 
yaml_file=$(find /etc/netplan -type f -name '*.yaml')

grep "$lan_netip.10/24" $yaml_file | sed -i "s/$lan_netip.10/$lan_netip.3/" $yaml_file
netplan apply > /dev/null 2>&1

grep "$lan_netip.3" $yaml_file > /dev/null
if [ $? -eq 0 ]; then
    echo "IP address was successfully configured to host 3 on LAN"
else
    echo "Failed to change IP address to host 3 on LAN"
    exit 1
fi
EOF

#Add a machine named webhost to the /etc/hosts file as host 4 on the LAN
cat >> server1-config.sh << EOF

echo "Checking if webhost exists within /etc/hosts..."
lan_netip=$(hostname -I | awk '{ print $1 }' | sed 's/.3$//')

grep "webhost" /etc/hosts
if [ $? -eq 0 ]; then
    echo "webhost already exists within /etc/hosts file. Checking if IP address is configured correctly..."
    grep "$lan_netip.4" /etc/hosts > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "IP address for webhost is already configured correctly."
    else
        grep "webhost" /etc/hosts | sed -i "s/.*webhost/$lan_netip.4 webhost/" /etc/hosts 
        grep "$lan_netip.4 webhost" /etc/hosts > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "webhost exists in /etc/hosts."
        else
            echo "Failed to add correct webhost IP address to /etc/hosts file"
            exit 1
        fi
    fi
else
    echo "$lan_netip.4 webhost" >> /etc/hosts
    grep "$lan_netip.4 webhost" /etc/hosts > /dev/null 2>&1 
    if [ $? -eq 0 ]; then
        echo "webhost added to /etc/hosts."
    else
        echo "Failed to add webhost to /etc/hosts file"
        exit 1
    fi
fi
EOF

# Install UFW (if necessary) and allow connections to port 514/udp from the MGMT network
cat >> server1-config.sh << EOF

echo "Checking if UFW is installed..."
dpkg-query -s ufw 2> /dev/null | grep "installed" > /dev/null 2>&1  
if [ $? -ne 0 ]; then
    echo "Installing UFW"
    apt update > /dev/null 2>&1
    apt install -y ufw > /dev/null 2>&1
else
    echo "UFW already installed."
fi

ufw_status=$(ufw status | grep "Status:" | awk '{ print $2 }')
if [ "$ufw_status" = "active" ]; then
    echo "UFW already enabled!"
else
    ufw --force enable
fi

ufw status | grep "514/udp" | grep "ALLOW" | grep "172.16.1.0"
if [ $? -eq 0 ]; then
    echo "UFW Rule already exists: allow connections to 514/udp from MGMT network"
else
    echo "Adding UFW Rule: allow connections to port 514/UDP from MGMT network!"
    ufw allow from 172.16.1.0/24 to any port 514 proto udp
fi

EOF

#Configure rsyslog to listen for UDP connections
# Look in /etc/rsyslog.conf for the configuration settings lines that say imudp
#Uncomment both of the lines
#Restart the rsyslog service using systemctl restart rsyslog

#PROBLEM: After running this step: problems trying to connect to server1-mgmt
cat >> server1-config.sh << EOF

echo "Configuring rsyslog..."
grep "imudp" /etc/rsyslog.conf | grep "#" > /dev/null
if [ $? -ne 0 ]; then
    echo "rsyslog is already listening for UDP connections"
else
    echo "Configuring rsyslog to listen for UDP connections..."
    grep "imudp" /etc/rsyslog.conf | sed -i 's/#//' /etc/rsyslog.conf | systemctl restart rsyslog
    if [ $? -eq 0 ]; then
        echo "Rsyslog configuration successful!"
    else
        echo "Failed to configure rsyslog."
        exit 1
    fi
fi
EOF

echo "Completed Server1 configuration!"

##### Configuring Target2-mgmt (172.16.1.11) #####

ssh remoteadmin@server1-mgmt "echo 'Configuring Server2'"

#Change system name from target 2 to webhost (both hostname and /etc/hosts file)
ssh remoteadmin@server2-mgmt << EOF

if [ "$(hostname)" = "webhost" ]; then
    echo "System name is already configured as "webhost", skipping step"
else
    echo "Changing system name to 'webhost'..."
    hostnamectl set-hostname webhost 
    grep "webhost" /etc/hostname
    if [ $? -eq 0 ]; then
        echo "System name was successfully changed to webhost."
    else
        echo "Failed to change system name to loghost."
        exit 1
    fi
fi

EOF

#Change IP Address from host 11 to host 4 on the LAN
ssh remoteadmin@server2-mgmt << EOF

lan_netip=$(hostname -I | awk '{ print $1 }' | sed 's/.11$//')
yaml_file=$(find /etc/netplan -type f -name '*.yaml')

grep "$lan_netip.11/24" $yaml_file | sed -i "s/$lan_netip.11/$lan_netip.4/" $yaml_file
netplan apply > /dev/null 2>&1
new_ip=$(hostname -I | awk '{ print $1 }')
if [ "$new_ip" = "$lan_netip.4" ]; then
    echo "IP address was successfully configured to host 4 on LAN"
else
    echo "Failed to change IP address to host 4 on LAN"
    exit 1
fi

EOF

#Add a machine named loghost to the /etc/hosts file as host 3 on the LAN

ssh remoteadmin@server2-mgmt << EOF

grep "loghost" /etc/hosts > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "loghost already exists within /etc/hosts file. Checking if IP address is configured correctly..."
    grep "$lan_netip.3" /etc/hosts > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "IP address for loghost is already configured correctly."
    else
        grep "loghost" /etc/hosts | sed -i "s/.*loghost/$lan_netip.3 loghost/" /etc/hosts 
        grep "$lan_netip.3 loghost" /etc/hosts > /dev/null 2>&1 
        if [ $? -eq 0 ]; then
            echo "loghost has the correct IP address in /etc/hosts."
        else
            echo "Failed to add correct loghost IP address to /etc/hosts file"
            exit 1
        fi
    fi
else
    echo "$lan_netip.3 loghost" >> /etc/hosts
    grep "$lan_netip.3 loghost" /etc/hosts > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "loghost added to /etc/hosts."
    else
        echo "Failed to add loghost to /etc/hosts file"
        exit 1
    fi
fi

EOF

#Install UFW (if necessary) and allow connections to port 80/tcp from anywhere

ssh remoteadmin@server2-mgmt << EOF
dpkg-query -s ufw 2> /dev/null | grep "installed" > /dev/null 2>&1  
if [ $? -ne 0 ]; then
    echo "Installing UFW"
    apt update > /dev/null 2>&1
    apt install -y ufw > /dev/null 2>&1
else
    echo "UFW already installed."
fi

ufw_status=$(ufw status | grep "Status:" | awk '{ print $2 }')
if [ "$ufw_status" = "active" ]; then
    echo "UFW already enabled!"
else
    ufw --force enable
fi

ufw status | grep "80/tcp" | grep "ALLOW" | grep "any"
if [ $? -eq 0 ]; then
    echo "UFW Rule already exists: allow connections to 80/tcp from anywhere"
else
    echo "Adding UFW Rule: allow connections to port 80/tcp from anywhere!"
    ufw allow from any to any port 80 proto tcp
fi
EOF

#Install apache2 in its default configuration
ssh remoteadmin@server2-mgmt << EOF
dpkg-query -s apache2 2> /dev/null | grep "installed" > /dev/null 2>&1  
if [ $? -ne 0 ]; then
    echo "Installing Apache2"
    apt update > /dev/null 2>&1
    apt install -y apache2 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Apache2 was succesfully installed!"
    else
        echo "Failed to install Apache2."
        exit 1
    fi
else
    echo "Apache2 already installed."
fi
EOF

#Configure rsyslog on webhost to send logs to loghost by modifying /etc/rsyslog.conf
#Add a line like this to the end of the rsyslog.conf file: *.* @loghost
ssh remoteadmin@server1-mgmt << EOF
grep "\*.\* @loghost" /etc/rsyslog.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "rsyslog is already configured to send logs to loghost!"
else
    echo "Configuring rsyslog to send logs to loghost..."
    echo "*.* @loghost" >> /etc/rsyslog.conf
    grep "\*.\* @loghost" /etc/rsyslog.conf > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Successfully configured rsyslog to send logs to loghost!"
        systemctl restart rsyslog
    else
        "Failed to configure rsyslog to send logs to loghost."
        exit 1
    fi
fi

EOF

##### Configuring NMS #####

echo 'Configuring NMS'

#If the remote changes are successful, update the NMS /etc/hosts file to have the name:
#loghost with 192.168.16.3 and webhost with 192.168.16.4

echo "Updating NMS /etc/hosts file..."
grep "server1" /etc/hosts | awk 'FNR==1' | sed -i 's/.10/.3/;s/server1/loghost/' /etc/hosts 
grep "server2" /etc/hosts | awk 'FNR==1' | sed -i 's/.11/.4/;s/server2/webhost/' /etc/hosts 
lines_hostfile=$(grep -E "loghost|webhost" /etc/hosts | wc -l)
if [ "$lines_hostfile" -eq "2" ]; then
    echo "/etc/hosts file was successfully updated!"
else
    echo "Failed to update /etc/hosts"
    exit 1
fi

#Verify you can retrieve the default apache web page from the NMS using firefox
#With the URL http://webhost

wget -q -O - http://webhost 
if [ $? -eq 0 ]; then
    echo "Successfully retrieved default apache web page!"
else
    echo "Failed to retrieve the default apache web page."
    exit 1
fi

#Verify you can retrieve the logs showing webhost from loghost using the command:
#If the apache server responds properly and the syslog has entries from webhost,
#Let the user know that the configuration update has succeeded
#Otherwise, tell them what did not work in a user-friendly way

webhost_in_log=$(ssh remoteadmin@loghost "grep 'webhost' /var/log/syslog")
if [ -n $webhost_in_log ]; then
    echo "Configuration update succeeded!"
else
    echo "Failed to update configuration. Could not find webhost in logs from loghost."
    exit 1



#!/bin/bash

# Assignment 3: Automated Configuration

#NOTE: your script must only use ssh to access the target1 and target2 machines

##### Configuring Target1-mgmt (172.16.1.10) #####
 
#Change system name from target1 to loghost (both hostname and /etc/hosts file)
#Check if hostname is already set to loghost, and change it if is not
ssh remoteadmin@server1-mgmt << EOF

if [ "$(hostname)" = "loghost" ]; then
    echo "System name is already configured as "loghost", skipping step"
else
    echo "Changing system name to "loghost"..."
    hostnamectl set-hostname loghost 
    grep "loghost" /etc/hostname && echo "System name was successfully changed to loghost." || echo "Failed to change system name to loghost."
fi
EOF

#Check if "loghost" exists inside /etc/hosts file and add it if it does not
ssh remoteadmin@server1-mgmt << EOF
grep -w "loghost" /etc/hosts > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "hostname already configured to loghost within /etc/hosts file"
else
    echo "Changing hostname to loghost within /etc/hosts file..."
    grep "server1" /etc/hosts | sed -i 's/server1/loghost/g' /etc/hosts 
    grep -E "loghost" /etc/hosts && echo "Hostname was changed to loghost within /etc/hosts" || echo "Failed to change hostname to loghost in /etc/hosts"
fi   
EOF

#Change IP Address from host 10 to host 3 on the LAN
ssh remoteadmin@server1-mgmt << EOF

yaml_file=$(find /etc/netplan -type f -name '*.yaml')

grep "192.168.16.10/24" $yaml_file | sed -i 's/192.168.16.10/192.168.16.3/' $yaml_file
netplan apply > /dev/null 2>&1
new_ip=$(hostname -I | awk '{print $1}')
if [ "$new_ip" = "192.168.16.3" ]; then
    echo "IP address was successfully configured to: 192.168.16.3"
else
    echo "Failed to change IP address to host 3 on LAN"
fi

EOF

#Add a machine named webhost to the /etc/hosts file as host 4 on the LAN
ssh remoteadmin@server1-mgmt << EOF

grep "webhost" /etc/hosts
if [ $? -eq 0 ]; then
    echo "webhost already exists within /etc/hosts file. Checking if IP address is configured correctly..."
    
    grep "192.168.16.4" /etc/hosts > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "IP address for webhost is already configured correctly."
    else
        grep "webhost" /etc/hosts | sed -i 's/.*webhost/192.168.16.4 webhost/' /etc/hosts 
        grep "192.168.16.4 webhost" /etc/hosts > /dev/null 2>&1 && echo "webhost exists in /etc/hosts." || echo "Failed to add correct webhost IP address to /etc/hosts file"
    fi

else
    echo "192.168.16.4 webhost" >> /etc/hosts
    grep "192.168.16.4 webhost" /etc/hosts > /dev/null 2>&1 && echo "webhost added to /etc/hosts." || echo "Failed to add webhost to /etc/hosts file"
fi

EOF

# Install UFW (if necessary) and allow connections to port 514/udp from the MGMT network
ssh remoteadmin@server1-mgmt << EOF

ufw status 
#if disabled
ufw enable
ufw allow udp

dpkg-query -s ufw 2> /dev/null | grep "installed" > /dev/null 2>&1  
if [ $? -ne 0 ]; then
    echo "Installing UFW"
    apt update > /dev/null 2>&1
    apt install -y ufw > /dev/null 2>&1
else
    echo "UFW already installed."

EOF

#Configure rsyslog to listen for UDP connections
# Look in /etc/rsyslog.conf for the configuration settings lines that say imudp
#Uncomment both of the lines
#Restart the rsyslog service using systemctl restart rsyslog

##### Configuring Target2-mgmt (172.16.1.11) #####

#Change system name from target 2 to webhost (both hostname and /etc/hosts file)

#Change IP Address from host 11 to host 4 on the LAN

#Add a machine named loghost to the /etc/hosts file as host 3 on the LAN

#Install UFW (if necessary) and allow connections to port 80/tcp from anywhere

#Install apache2 in its default configuration

#Configure rsyslog on webhost to send logs to loghost by modifying /etc/rsyslog.conf
#Add a line like this to the end of the rsyslog.conf file: *.* @loghost

##### Configuring NMS #####

#If the remote changes are successful, update the NMS /etc/hosts file to have the name:
#loghost with 172.16.1.3 and webhost with 172.16.1.4

#Verify you can retrieve the default apache web page from the NMS using firefox
#With the URL http://webhost

#Verify you can retrieve the logs showing webhost from loghost using the command:
#ssh remoteadmin@loghost grep webhost /var/log/syslog

#If the apache server responds properly and the syslog has entreies from webhost,
#Let the user know that the configuration update has succeeded
#Otherwise, tell them what did not work in a user-friendly way

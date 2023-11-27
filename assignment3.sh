#!/bin/bash

# Assignment 3: Automated Configuration

#NOTE: your script must only use ssh to access the target1 and target2 machines

##### Configuring Target1-mgmt (172.16.1.10) #####
 
#Change system name from target1 to loghost (both hostname and /etc/hosts file)
#Check if hostname is already set to loghost, and change it if is not
ssh remoteadmin@target1-mgmt << EOF

if [ "$(hostname)" = "loghost" ]; then
    echo "System name is already configured as "loghost", skipping step"
else
    echo "Changing system name to "loghost"..."
    hostnamectl set-hostname loghost
    grep "loghost" /etc/hostname
    if [ $? -eq 0 ]; then
        echo "System name was successfully changed to loghost."
    else
        echo "Failed to change system name to "loghost"."
fi

#Check if "loghost" exists inside /etc/hosts file and add it if it does not

grep -w "loghost" /etc/hosts
if [ $? -eq 0 ]; then
    echo "/etc/hosts already contains loghost"
else
    echo "Changing hostname to loghost within /etc/hosts file..."
    grep "server1" /etc/hosts | sed -i 's/server1/loghost/g' /etc/hosts 
    grep -E "loghost|loghost-mgmt" && echo "Hostname was changed to loghost within /etc/hosts" || echo "Failed to change hostname to loghost in /etc/hosts"
fi    

EOF

#Change IP Address from host 10 to host 3 on the LAN

#Add a machine named webhost to the /etc/hosts file as host 4 on the LAN

# Install UFW (if necessary) and allow connections to port 514/udp from the MGMT network

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

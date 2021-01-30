#!/bin/sh

username='ws'

yum -y install findutils ||:
yum -y install git ||:
yum -y install jq ||:
yum -y install openssl ||:
yum -y install procps-ng ||:
yum -y install sudo ||:
yum -y install systemd ||:
yum -y install tar ||:
yum -y install vim-enhanced ||:

echo "Defaults:${username} !requiretty" >> /etc/sudoers
echo "${username} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
useradd -b /home -G wheel -m -c "Workstation User" -s /bin/bash -U ${username}
rm -rf /etc/security/limits.d/*.conf

chown -R ${username}:${username} /home/${username}

# Enable this if it exists so that journald will start
systemctl enable container_safe_services.path ||:

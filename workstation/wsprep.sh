#!/bin/sh

username='ws'

yum -y install systemd ||:
yum -y install git ||:
yum -y install jq ||:
yum -y install openssl ||:
yum -y install sudo ||:
yum -y install vim-enhanced ||:

echo "Defaults:${username} !requiretty" >> /etc/sudoers
echo "${username} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
useradd -b /home -G wheel -m -c "Workstation User" -s /bin/bash -U ${username}
rm -rf /etc/security/limits.d/*.conf

chown -R ${username}:${username} /home/${username}

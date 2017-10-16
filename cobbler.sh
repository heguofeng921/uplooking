#!/bin/bash

hostnamectl set-hostname cobbler
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 
setenforce 0

sed -i 's/ONBOOT=yes/ONBOOT=no/' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '$a GATEWAY=192.168.0.10' /etc/sysconfig/network-scripts/ifcfg-eth1
systemctl restart network

wget -r ftp://172.25.254.250/notes/project/software/cobbler_rhel7/
mv 172.25.254.250/notes/project/software/cobbler_rhel7/ cobbler
cd cobbler/
rpm -ivh python2-simplejson-3.10.0-1.el7.x86_64.rpm
rpm -ivh python-django-1.6.11.6-1.el7.noarch.rpm python-django-bash-completion-1.6.11.6-1.el7.noarch.rpm
yum -y  localinstall cobbler-2.8.1-2.el7.x86_64.rpm cobbler-web-2.8.1-2.el7.noarch.rpm

systemctl start cobblerd
systemctl start httpd
systemctl start xinetd
systemctl enable httpd
systemctl enable cobblerd
systemctl enable xinetd

sed -i 's/^server:.*/server:\ 192.168.0.14/' /etc/cobbler/settings
sed -i 's/^next_server:.*/next_server:\ 192.168.0.14/' /etc/cobbler/settings
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config && echo '永久关闭selinux'
echo "/sbin/setenforce 0" >> /etc/rc.local
chmod +x /etc/rc.local
source  /etc/rc.local

sed -i 's/disable.*/disable\ =\ no/' /etc/xinetd.d/tftp
yum -y install syslinux
systemctl start rsyncd
systemctl enable rsyncd
netstat -tnlp |grep :873

yum -y install pykickstart
sed -i 's/^default_password_crypted:.*/default_password_crypted:\ "$1$random-p$MvGDzDfse5HkTwXB2OLNb."/' /etc/cobbler/settings

yum -y install fence-agents

mkdir /yum
mount -t nfs 172.25.254.250:/content /mnt/
mount -o loop /mnt/rhel7.2/x86_64/isos/rhel-server-7.2-x86_64-dvd.iso /yum/
cobbler import --path=/yum --name=rhel-server-7.2 --arch=x86_64

yum -y install dhcp
cat > /etc/cobbler/dhcp.template <<END
subnet 192.168.0.0 netmask 255.255.255.0 {
     option routers             192.168.0.10;
     option domain-name-servers 172.25.254.254;
     option subnet-mask         255.255.255.0;
     range dynamic-bootp        192.168.0.100 192.168.0.150;
     default-lease-time         21600;
     max-lease-time             43200;
     next-server                $next_server;
     class "pxeclients" {
          match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
          if option pxe-system-type = 00:02 {
                  filename "ia64/elilo.efi";
          } else if option pxe-system-type = 00:06 {
                  filename "grub/grub-x86.efi";
          } else if option pxe-system-type = 00:07 {
                  filename "grub/grub-x86_64.efi";
          } else {
                  filename "pxelinux.0";
          }
     }
}
END

sed -i 's/^manage_dhcp:.*/manage_dhcp:\ 1/' /etc/cobbler/settings
systemctl restart cobblerd
cobbler sync
systemctl restart xinetd

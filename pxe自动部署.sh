#!bin/bash

#关闭桥接网络
sed -i 's/ONBOOT=yes/ONBOOT=no/' /etc/sysconfig/network-scripts/ifcfg-eth0  && echo '关闭eth0网卡'
sed -i '$a GATEWAY=192.168.0.10' /etc/sysconfig/network-scripts/ifcfg-eth1  && echo '添加192.168.0.10网关'
systemctl restart network && echo '重启网络成功'

#关闭selinux并永久关闭
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config && echo '永久关闭selinux'
echo "/sbin/setenforce 0" >> /etc/rc.local 
chmod +x /etc/rc.local 
source  /etc/rc.local 

#网络源
find  /etc/yum.repos.d/ -regex '.*\.repo$' -exec mv {} {}.back \; && echo '备份repo成功'

mount -t nfs 172.25.254.250:/content /mnt/   && echo 'nfs挂载成功'

mkdir -p /yum

mkdir -p  /rhel6u5

cat > /etc/yum.repos.d/base.repo << EOT
[base]
baseurl=file:///yum
gpgcheck=0
EOT

cat >> /etc/fstab <<EOT
172.25.254.250:/content /mnt/  nfs ro 0 0
/mnt/rhel7.2/x86_64/isos/rhel-server-7.2-x86_64-dvd.iso  /yum iso9660 ro 0 0
/mnt/rhel6.5/x86_64/isos/rhel-server-6.5-x86_64-dvd.iso /rhel6u5 iso9660 ro 0 0
EOT

mount -a  && echo '刷新永久挂载'

yum clean all  &>/dev/null && echo '清空yum缓存'
yum repolist  &>/dev/null && echo '建立yum缓存'

#本地源
#find  /etc/yum.repos.d/ -regex '.*\.repo$' -exec mv {} {}.back \;
#mkdir /yum
#mount -o loop /download/7u2.iso  /yum/
#cat > /etc/yum.repos.d/local.repo << EOT
#[base]
#baseurl=file:///yum
#gpgcheck=0
#EOT
#cat >> /etc/fstab <<EOT
#/download/7u2.iso /yum iso9660 ro 0 0
#EOT

#搭建DHCP
yum -y install dhcp  && echo 'dhcp安装成功'
\cp /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example  /etc/dhcp/dhcpd.conf

cat > /etc/dhcp/dhcpd.conf <<EOT
allow booting;
allow bootp;

log-facility local7;

subnet 192.168.0.0 netmask 255.255.255.0 {
  range 192.168.0.100 192.168.0.150;
  option domain-name-servers 172.25.254.254;
  option domain-name "pod6.example.com";
  option routers 192.168.0.10;
  option broadcast-address 192.168.0.255;
  default-lease-time 600;
  max-lease-time 7200;
  next-server 192.168.0.14;
  filename "pxelinux.0";
}
  next-server 192.168.0.14;
  filename "pxelinux.0";
EOT

systemctl start dhcpd
netstat -unpl | grep :67

#搭建tftp服务
yum -y install xinetd
yum -y install tftp-server &>/dev/null && echo'tftp安装成功'
yum -y install syslinux &>/dev/null && echo'syslinux安装成功'
\cp /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot/
mkdir  -p /var/lib/tftpboot/pxelinux.cfg
touch /var/lib/tftpboot/pxelinux.cfg/default

cat > /var/lib/tftpboot/pxelinux.cfg/default <<END
default vesamenu.c32
timeout 60
display boot.msg
menu background splash.jpg
menu title Welcome to Global Learning Services Setup!

label local
        menu label Boot from ^local drive 
        menu default
        localhost 0xffff

label install
        menu label Install rhel7
        kernel vmlinuz
        append initrd=initrd.img ks=http://192.168.0.14/myks.cfg

label install6
        menu label Install rhel6u5
        kernel rhel6u5/vmlinuz
        append initrd=rhel6u5/initrd.img ks=http://192.168.0.14/rhel6u5_ks.cfg

label install6
        menu label Install trouble
        kernel rhel6u5/vmlinuz
        append initrd=rhel6u5/initrd.img ks=http://192.168.0.14/trouble.cfg
END

cd /yum/isolinux/
\cp splash.png vesamenu.c32 vmlinuz initrd.img /var/lib/tftpboot/

mkdir  -p /var/lib/tftpboot/rhel6u5
cd /rhel6u5/isolinux/
\cp vmlinuz initrd.img /var/lib/tftpboot/rhel6u5/


sed -i s/disable.*/disable\ =\ no/ /etc/xinetd.d/tftp
systemctl start xinetd
netstat -unlp |grep :69

#yum -y install system-config-kickstart &>/dev/null  && echo 'kickstart安装成功'
yum -y install httpd  &>/dev/null   && echo 'httpd安装成功'

#生成KS文件
cat > /var/www/html/myks.cfg <<EOT
#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
# Reboot after installation 
reboot
# Use network installation
url --url="http://192.168.0.14/rhel7u1/"
# Use graphical install
#graphical 
text
# Firewall configuration
firewall --enabled --service=ssh
firstboot --disable 
ignoredisk --only-use=vda
# Keyboard layouts
# old format: keyboard us
# new format:
keyboard --vckeymap=us --xlayouts='us'
# System language 
lang en_US.UTF-8
# Network information
network  --bootproto=dhcp
network  --hostname=localhost.localdomain
#repo --name="Server-ResilientStorage" --baseurl=http://download.eng.bos.redhat.com/rel-eng/latest-RHEL-7/compose/Server/x86_64/os//addons/ResilientStorage
# Root password
rootpw --iscrypted nope 
# SELinux configuration
selinux --disabled
# System services
services --disabled="kdump,rhsmcertd" --enabled="network,sshd,rsyslog,ovirt-guest-agent,chronyd"
# System timezone
timezone Asia/Shanghai --isUtc
# System bootloader configuration
bootloader --append="console=tty0 crashkernel=auto" --location=mbr --timeout=1 --boot-drive=vda 
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=6144
%post
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
# workaround anaconda requirements
%end

%packages
@core
%end
EOT

cat > /var/www/html/rhel6u5_ks.cfg <<END
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use network installation
url --url="http://192.168.0.14/rhel6u5"
# Root password
rootpw --plaintext redhat
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# System keyboard
keyboard us
# System language
lang en_US
# SELinux configuration
selinux --disabled
# Installation logging level
logging --level=info
# Reboot after installation
reboot
# System timezone
timezone --isUtc Asia/Shanghai
# Network information
network  --bootproto=dhcp --device=eth0 --onboot=on
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel 
# Disk partitioning information
part /boot --fstype="ext4" --size=200
part / --fstype="ext4" --size=9000
part swap --fstype="swap" --size=1024

%pre
clearpart --all
part /boot --fstype ext4 --size=100
part pv.100000 --size=10000
part swap --size=512
volgroup vg --pesize=32768 pv.100000
logvol /home --fstype ext4 --name=lv_home --vgname=vg --size=480
logvol / --fstype ext4 --name=lv_root --vgname=vg --size=8192
%end


%post
touch /tmp/abc
%end

%packages
@base
@chinese-support
tigervnc
openssh-clients

%end
END


cat > /var/www/html/trouble.cfg <<EOT
text
key --skip
keyboard us
lang en_US.UTF-8
network --bootproto dhcp
url --url "http://192.168.0.14/rhel6u5"

%include /tmp/partitioning

#mouse genericps/2 --emulthree
#mouse generic3ps/2
#mouse genericwheelusb --device input/mice
timezone Asia/Shanghai --utc
#timezone US/Central --utc
#timezone US/Mountain --utc
#timezone US/Pacific --utc
# When probed, some monitors return strings that wreck havoc (not
# Pennington) with the installer.  You can indentify this condition
# by an early failure of the workstation kickstart just prior to when
# it would ordinarily raise the installer screen after probing.  There
# will be some nasty python spew.
# In this situation, comment the xconfig line below, then uncomment
# the skipx line.  Next, uncomment the lines beneath #MY X IS BORKED
#xconfig --resolution=1024x768 --depth=16 --startxonboot
#skipx
rootpw redhat 
authconfig --enableshadow --passalgo=sha512
firewall --disabled
reboot

%packages
@ Desktop
#@ Console internet tools
#@ Desktop Platform
#@ Development Tools
#@ General Purpose Desktop
#@ Graphical Administration Tools
#@ Chinese Support
#@ Graphics Creation Tools
#@ Internet Browser
# KDE is huge...install it if you wish
#@ KDE
#@ Network file system client
#@ Printing client
#@ X Window System
#mutt
lftp
ftp
#ntp
#libvirt-client
#qemu-kvm
#virt-manager
#virt-viewer
#libvirt
#nss-pam-ldapd
#tigervnc
#policycoreutils-python
#logwatch
#-biosdevname

%pre
echo "Starting PRE" > /dev/tty2
# Forget size-based heuristics. Check for removable drives.
# Look at both scsi and virtio disks.
for disk in {s,v}d{a..z} ; do
    if ( [ -e /sys/block/${disk}/removable ] && \
       	 egrep -q 0 /sys/block/${disk}/removable ); then
       disktype=$disk
       diskfound='true';
       break
    fi
done

# Add a bootloader directive that specifies the right boot drive
echo "bootloader --append="biosdevname=0" --driveorder=${disktype}" > /tmp/partitioning

cat >> /tmp/partitioning <<END
zerombr
clearpart --drives=${disktype} --all
part swap --size 512 --ondisk=${disktype}
part /boot --size 256 --ondisk=${disktype}
part pv.01 --size 15000 --ondisk=${disktype}
volgroup vol0 pv.01
logvol / --vgname=vol0 --size=12000 --name=root
logvol /home --vgname=vol0 --size=500 --name=home
END

echo disktype=${disktype} > /tmp/disktype

%post
##########
useradd student
echo student | passwd student --stdin
dd if=/dev/zero of=/dev/vda bs=446 count=1
dd if=/dev/zero of=/dev/sda bs=446 count=1
dd if=/dev/zero of=/dev/hda bs=446 count=1
rm -rf /etc/fstab
rm -rf /bin/mount
chmod 755 /tmp
rm -rf /boot/grub/grub.conf
usermod -L root
/bin/cp /bin/ls /bin/bash
chmod 400 /etc/passwd
chmod 600 /etc/group
chattr +a /etc/rc.local
sed -i "s/id:3:initdefault:/id::initdefault:/"  /etc/inittab
sed -i "s#rc [2,3,4,5]#rc 6#" /etc/inittab 
cat >> /etc/rc.d/rc.sysinit <<ENDF
echo "reboot" >>/etc/rc.d/rc.local
EOT

ln -s /yum/     /var/www/html/rhel7u1
ln -s /rhel6u5/ /var/www/html/rhel6u5

systemctl start  httpd
systemctl enable xinetd
systemctl enable httpd
systemctl enable dhcpd

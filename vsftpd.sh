#!/bin/bash
iptables -F
setenforce 0
rpm -e vsftpd &> /dev/null
rm -rf /etc/vsftpd/vsftpd.conf.rpmsave 

rpm -q vsftpd
[ $? -eq 0 ]  || yum -y install vsftpd &> /dev/null && echo "ftp安装成功"

cd /etc/vsftpd
cp vsftpd.conf vsftpd.conf.back 
sed -i '/local_enable=YES/clocal_enable=NO' vsftpd.conf
sed -i '/listen=NO/clisten=YES' vsftpd.conf
sed -i 's/^listen_/#&/' vsftpd.conf
sed -i 's/^#anon/anon/' vsftpd.conf
sed -i 's/^local_u/anon_u/' vsftpd.conf
#sed -i '/anon_mk.*/aanon_max_rate=512000' vsftpd.conf
sed -i '/anon_max.*/aanon_other_write_enable=YES' vsftpd.conf
sed -i '/anon_oth.*/aanon_world_readable_only=NO' vsftpd.conf
sed -r '/^#|^$/d' vsftpd.conf

chmod 777 /var/ftp/pub/
systemctl restart vsftpd 
netstat -tnpl | grep ftp

systemctl enable vsftpd &> /dev/null
systemctl list-unit-files | grep ftp

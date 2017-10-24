#!/bin/bash

read -p "请输入zabbix服务端的IP:" ser
read -p "请输入web端的IP:" web
read -p "请输入数据库端的IP:" mysql

yum -y install expect lftp

#推送密钥
expect <<EOF
spawn ssh-keygen -t rsa
expect "sa):"
send "\r"
expect "se):"
send "\r"
expect "ain:"
send "\r"
expect eof
EOF

expect <<EOF
spawn ssh-copy-id -i root@$ser
expect "no)?"
send "yes\r"
expect "password"
send "uplooking\r"
expect "#"
send "exit\r"
expect eof
EOF

expect <<EOF
spawn ssh-copy-id -i root@$web
expect "no)?"
send "yes\r"
expect "password"
send "uplooking\r"
expect "#"
send "exit\r"
expect eof
EOF

expect <<EOF
spawn ssh-copy-id -i root@$mysql
expect "no)?"
send "yes\r"
expect "password"
send "uplooking\r"
expect "#"
send "exit\r"
expect eof
EOF

timedatectl set-timezone Asia/Shanghai
ntpdate -u 172.25.254.254;setenforce 0


cat > /root/zabser.sh <<EOOT
#!/bin/bash
timedatectl set-timezone Asia/Shanghai;ntpdate -u 172.25.254.254;setenforce 0

yum -y install lftp
lftp 172.25.254.250:/notes/project/software/zabbix <<EOF
mirror zabbix3.2
exit
EOF

cd zabbix3.2
tar -xf zabbix-3.2.7.tar.gz -C /usr/local/src/
yum install -y gcc gcc-c++ mariadb-devel libxml2-devel net-snmp-devel libcurl-devel

cd /usr/local/src/zabbix-3.2.7/
./configure --prefix=/usr/local/zabbix --enable-server --with-mysql --with-net-snmp --with-libcurl --with-libxml2 --enable-agent --enable-ipv6
make
make install
useradd zabbix

sed -i "s/^\# DBHost.*/DBHost=$mysql/" /usr/local/zabbix/etc/zabbix_server.conf
sed -i "s/^\# DBPassword.*/DBPassword=uplooking/" /usr/local/zabbix/etc/zabbix_server.conf

yum -y install expect
cd /usr/local/src/zabbix-3.2.7/database/mysql/

expect <<EOF
spawn ssh-keygen -t rsa
expect "sa):"
send "\r"
expect "se):"
send "\r"
expect "ain:"
send "\r"
expect eof
EOF

expect <<EOF
spawn ssh-copy-id -i root@$mysql
expect "no)?"
send "yes\r"
expect "password"
send "uplooking\r"
expect "#"
send "exit\r"
expect eof
EOF

rsync /usr/local/src/zabbix-3.2.7/database/mysql/*  $mysql:/root/
EOOT

cat > /root/zabweb.sh <<EOOT
#!/bin/bash
timedatectl set-timezone Asia/Shanghai;ntpdate -u 172.25.254.254;setenforce 0
yum -y install lftp
lftp 172.25.254.250:/notes/project/software/zabbix <<EOe
mirror zabbix3.2
exit
EOe

cd /root/zabbix3.2
yum -y install httpd php php-mysql
yum -y localinstall php-mbstring-5.4.16-23.el7_0.3.x86_64.rpm php-bcmath-5.4.16-23.el7_0.3.x86_64.rpm
yum -y localinstall zabbix-web-3.2.7-1.el7.noarch.rpm zabbix-web-mysql-3.2.7-1.el7.noarch.rpm

sed -i "s/.*date.time.*/php\_value date.timezone Asia\/Shanghai/" /etc/httpd/conf.d/zabbix.conf

cd /root/
yum -y install wqy-microhei-fonts
wget ftp://172.25.254.250/notes/project/software/zabbix/simkai.ttf
cp /root/simkai.ttf /usr/share/zabbix/fonts/
sed -i "s/graphfont/simkai/g" /usr/share/zabbix/include/defines.inc.php
EOOT

cat > /root/zabmysql.sh <<EOOT
#!/bin/bash
timedatectl set-timezone Asia/Shanghai;ntpdate -u 172.25.254.254;setenforce 0

yum -y install mariadb-server mariadb
systemctl start mariadb

mysql <<EOF
create database zabbix default charset utf8;
grant all on zabbix.* to zabbix@'%' identified by 'uplooking';
flush privileges;
exix
EOF

mysql zabbix < /root/schema.sql
mysql zabbix < /root/images.sql
mysql zabbix < /root/data.sql
systemctl restart mariadb
EOOT

lftp 172.25.254.250:/notes/project/software/zabbix <<EOOE
mirror zabbix3.2
exit
EOOE

cd zabbix3.2
rpm -ivh zabbix-agent-3.2.7-1.el7.x86_64.rpm
yum -y install net-snmp net-snmp-utils

sed -i "s/^Server=.*/Server=$ser/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^ServerActive=.*/ServerActive=$ser/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/.*Parameters=.*/UnsafeUserParameters=1/" /etc/zabbix/zabbix_agentd.conf

systemctl restart zabbix-agent
systemctl enable zabbix-agent

rsync -avz /root/zabser.sh   $ser:/root/
rsync -avz /root/zabweb.sh   $web:/root/
rsync -avz /root/zabmysql.sh $mysql:/root/
ssh root@$ser "bash -x /root/zabser.sh" 
ssh root@$web "bash -x /root/zabweb.sh"
ssh root@$mysql "bash -x /root/zabmysql.sh"
ssh root@$ser "/usr/local/zabbix/sbin/zabbix_server"
ssh root@$web "systemctl restart httpd"

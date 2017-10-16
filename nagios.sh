#!/bin/bash

read -p "请输入被监控服务器的IP:" IP
i=`ifconfig eth0|awk 'NR==2{print $0}'|awk -F\  '{print $2}'`

setenforce 0
sed -i "s/^SELINUX=.*/SELINUX=disabled/" /etc/selinux/config
iptables -F  && echo "防火墙已经关闭"

yum -y install lftp &>/dev/null
lftp 172.25.254.250:/notes/project/UP200/UP200_nagios-master/ <<EOF
mirror pkg/
exit
EOF

cd pkg/
yum -y install *.rpm  #&> /dev/null  && echo "nagios及依赖环境安装完毕"
yum -y install expect
htpasswd -cmb  /etc/nagios/passwd nagiosadmin  123456

systemctl restart httpd  && echo "httpd已经启动成功"
systemctl enable httpd
systemctl satrt nagios   && echo "nagios已经启动成功"
chkconfig nagios on

cat > /root/nagios1.sh <<EOOT
#!/bin/bash

setenforce 0
sed -i "s/^SELINUX=.*/SELINUX=disabled/" /etc/selinux/config
iptables -F  && echo "防火墙已经关闭"

useradd nagios
echo nagios |passwd  --stdin nagios

wget ftp://172.25.254.250/notes/project/software/nagios/nagios-plugins-1.4.14.tar.gz

tar xf nagios-plugins-1.4.14.tar.gz
yum -y install gcc openssl-devel

cd nagios-plugins-1.4.14/
./configure
make
make install
chown nagios.nagios /usr/local/nagios
chown -R nagios.nagios /usr/local/nagios/libexec

yum -y install xinetd
yum -y install lftp

cd ..
lftp 172.25.254.250:/notes/project/software/nagios <<EOT
get nrpe-2.12.tar.gz
exit
EOT

tar xf  nrpe-2.12.tar.gz
cd nrpe-2.12/
./configure
make all
make install-plugin
make install-daemon
make install-daemon-config
make install-xinetd

sed -i "s/only\_from.*/only_from       = 127.0.0.1 $i/" /etc/xinetd.d/nrpe

sed -i "s/.*check_disk -w 20%.*/command\[check_vda1\]=\/usr\/local\/nagios\/libexec\/check_disk -w 20% -c 10% -p \/dev\/vda1/"  /usr/local/nagios/etc/nrpe.cfg

echo "command[check_swap]=/usr/local/nagios/libexec/check_swap -w 20% -c 10%" >> /usr/local/nagios/etc/nrpe.cfg

echo "nrpe            5666/tcp                # nrpe" >> /etc/services 

systemctl restart  xinetd
netstat -tnlp |grep :5666
/usr/local/nagios/libexec/check_nrpe -H localhost
EOOT

expect <<EOF
spawn rsync -av /root/nagios1.sh  $IP:/root/
expect "no)?"
send "yes\r"
expect "password"
send "uplooking\r"
expect eof
EOF

expect <<EOF
spawn  ssh root@$IP
expect "password"
send "uplooking\r"
expect "#"
send "bash -x /root/nagios1.sh"
expect eof
EOF

cat >> /etc/nagios/objects/commands.cfg <<EOY
define command{
        command_name check_nrpe
        command_line \$USER1\$/check_nrpe -H \$HOSTADDRESS\$ -c \$ARG1\$
}
EOY

cat > /etc/nagios/objects/serverb.cfg <<EOOT
define host{
        use                     linux-server                                                         
        host_name               serverb.pod6.example.com
        alias                   serverb1
        address                 $IP
        }
define hostgroup{
        hostgroup_name  uplooking-servers 
        alias           uplooking 
        members         serverb.pod6.example.com     
        }
# 定义监控服务
define service{
        use generic-service
        host_name serverb.pod6.example.com
        service_description load
        check_command check_nrpe!check_load
}
define service{
        use generic-service
        host_name serverb.pod6.example.com
        service_description user
        check_command check_nrpe!check_users
}

define service{
        use generic-service
        host_name serverb.pod6.example.com
        service_description disk
        check_command check_nrpe!check_vda1
}

define service{
        use generic-service
        host_name serverb.pod6.example.com
        service_description zombie
        check_command check_nrpe!check_zombie_procs
}



define service{
        use generic-service
        host_name serverb.pod6.example.com
        service_description total
        check_command check_nrpe!check_total_procs
}


define service{
        use generic-service
        host_name serverb.pod6.example.com
        service_description swap
        check_command check_nrpe!check_swap
}
EOOT

echo "cfg_file=/etc/nagios/objects/serverb.cfg" >> /etc/nagios/nagios.cfg

nagios -v /etc/nagios/nagios.cfg

systemctl restart nagios

#!/bin/bash

#关闭防火墙
setenforce 0
iptables -F  && echo "防火墙已经关闭"

wget 172.25.254.250:/notes/project/UP200/UP200_cacti-master/pkg/*

#安装cacti及依赖软件
yum -y install httpd php php-mysql mariadb-server mariadb 
yum -y localinstall cacti-0.8.8b-7.el7.noarch.rpm php-snmp-5.4.16-23.el7_0.3.x86_64.rpm

#启动数据库
systemctl start mariadb
systemctl enable mariadb

#配置数据库
mysql -e "create database cacti;grant all on cacti.* to cactidb@'localhost' identified by '123456';flush privileges;"

sed -i  's/^\$database_username.*/\$database_username = \"cactidb\"\;/'  /etc/cacti/db.php
sed -i  's/^\$database_password.*/\$database_password = \"123456\"\;/'  /etc/cacti/db.php

mysql -ucactidb -p123456 cacti < /usr/share/doc/cacti-0.8.8b/cacti.sql

sed -i 's/Require host localhost$/Require all granted/'  /etc/httpd/conf.d/cacti.conf

timedatectl set-timezone Asia/Shanghai

sed  -i  "s/^\;date.timezone.*/date\.timezone = \'Asia\/Shanghai\'/" /etc/php.ini

sed  "s/#//" /etc/cron.d/cacti

systemctl restart httpd  && echo "httpd启动成功"
systemctl enable httpd
systemctl restart snmpd  && echo "snmpd启动成功"
systemctl enable snmpd

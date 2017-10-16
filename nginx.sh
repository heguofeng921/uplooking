#!/bin/bash

#关闭防火墙
iptables -F 
setenforce 0

#servera免密登陆其他服务器
yum -y install expect &>/dev/null && echo "软件安装成功"

passwd=uplooking
keydir=$HOME/.ssh
skey=$keydir/id_rsa
#公钥
pkey=$keydir/id_rsa.pub
#私钥
[ -f $skey -a -f $pkey ] || $(ssh-keygen -q -f $skey -N "")
for i in {11..13}
do
        expect <<EOF
       spawn ssh-copy-id root@172.25.6.$i
       expect {
      		"*(yes/no)*" { send  "yes\r";exp_continue}
      		"*password:" { send "$passwd\r";exp_continue}
        	eof{exit}
              }
EOF
done
ssh-add

#配置servera
rpm -e nginx
rm -rf /etc/nginx/conf.d/default.conf.rpmsave

rpm -ivh ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/nginx-1.8.0-1.el7.ngx.x86_64.rpm &> /dev/null && echo "nginx安装成功"
yum -y install httpd-tools
cat > /etc/nginx/conf.d/default.conf << EOT
server {
    listen       80;
    server_name  www.text.com;
    charset utf-8;
    access_log  /var/log/nginx/www.test.com.access.log  main;

    location / {
        root   /usr/share/nginx/text;
        index  index.html index.htm;
    }
    

    location ~ ^/text\.html$ {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
 }
    location ~* /status {
        stub_status on;
	auth_basic "info";
        auth_basic_user_file /usr/share/nginx/passwd.db;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

}
EOT

expect << EOT &> /dev/null
spawn htpasswd -cm /usr/share/nginx/passwd.db user01
expect "password:"
send "redhat\r"
expect "password:"
send "redhat\r"
expect eof
EOT

mkdir -p /usr/share/nginx/text
mkdir -p /usr/share/nginx/joy/news
mkdir -p /usr/share/nginx/linux/10/20/30/

echo welcom to text > /usr/share/nginx/text/index.html
echo text > /usr/share/nginx/html/text.html
echo joy > /usr/share/nginx/joy/index.html
echo building > /usr/share/nginx/joy/news/index.html
echo 10-20-30 > /usr/share/nginx/linux/10/20/30.html

cd /usr/share/nginx/joy/news/
touch new1.html new2.html

cat > /etc/nginx/conf.d/www.joy.com.conf << EOT
server {
listen 80;
server_name www.joy.com;
access_log /var/log/nginx/joy.access.log main1;
root /usr/share/nginx/joy;
index index.html index.htm;
location ~* /news/ {
rewrite ^/news/.* /news/index.html break;
 }
location ~* /linux {
rewrite  ^/linux/([0-9]+)-([0-9]+)-([0-9]+)\.html$ /uplook/$1/$2/$3.html last;
}
}
EOT

sed -i "21alog_format  main1 '\$remote_addr \$remote_port \$host \$server_name \$server_port \$request \$status \$document_root \$request_filename \$query_string \$scheme \$server_protocol \$document_uri\';"  /etc/nginx/nginx.conf


ulimit -HSn 65535
nginx -t

systemctl restart nginx
systemctl enable nginx


#配置serverb
cat > /serverb.sh << EOF
#!/bin/bash
iptables -F
setenforce 0

rpm -ivh ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/nginx-1.8.0-1.el7.ngx.x86_64.rpm &> /dev/null && echo "nginx安装成功"

mkdir -p /usr/share/nginx/joy/tom

cat > /etc/nginx/conf.d/default.conf << EOT
server {
    listen       80;
    server_name  localhost;

    location / {
        proxy_pass http://172.25.6.12;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}

EOT

cat > /etc/nginx/nginx.conf << EOT
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\\\$remote_addr - \\\$remote_user [\$time_local] "\\\$request" '
                      '\\\$status \\\$body_bytes_sent "\\\$http_referer" '
                      '"\\\$http_user_agent" "\\\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;

    keepalive_timeout  65;
    proxy_temp_path /usr/share/nginx/proxy_temp_dir 1 2;
    proxy_cache_path /usr/share/nginx/proxy_cache_dir levels=1:2 keys_zone=cache_web:50m inactive=1d max_size=30g;

    upstream apache_pool {
    server 172.25.6.12 weight=2;
    server 172.25.6.13 weight=2;
    }

    include /etc/nginx/conf.d/*.conf;
}

EOT
mkdir -p /usr/share/nginx/proxy_temp_dir /usr/share/nginx/proxy_cache_dir
chown nginx /usr/share/nginx/proxy_temp_dir/ /usr/share/nginx/proxy_cache_dir/

cat > /etc/nginx/conf.d/www.joy.com.conf << EOT
 server {
 	listen 80;
 	server_name *.joy.com;
 	root /usr/share/nginx/joy;
 	index index.html index.htm;
 	if ( \\\$http_host ~* ^www\.joy\.com$ ) {    
 		break;
 		}
 	if ( \\\$http_host ~* ^(.*)\.joy\.com$ ) {    
 		set \\\$domain \\\$1;	
 		rewrite /.* /\\\$domain/index.html break;
 	}
 }
EOT

cat > /etc/nginx/conf.d/default.conf << EOT
server {
    listen       80;
    server_name  www.proxy.com;
location / {
proxy_pass http://apache_pool;
proxy_set_header Host \\\$host;
proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_404;
proxy_set_header X-Real-IP \\\$remote_addr;
proxy_redirect off;
client_max_body_size 10m;
client_body_buffer_size 128k;
proxy_connect_timeout 90;
proxy_send_timeout 90;
proxy_read_timeout 90;
proxy_cache cache_web;
proxy_cache_valid 200 302 12h;
proxy_cache_valid 301 1d;
proxy_cache_valid any 1h;
proxy_buffer_size 4k;
proxy_buffers 4 32k;
proxy_busy_buffers_size 64k;
proxy_temp_file_write_size 64k;
}
}
EOT

cd /usr/share/nginx/joy/
echo tom > tom/index.html
ulimit -HSn 65535
nginx -t

systemctl restart nginx
systemctl enable nginx
EOF

#serverb远程运行脚本
chmod +x /serverb.sh
rsync -a /serverb.sh 172.25.6.11:/
ssh root@172.25.6.11 "bash -x /serverb.sh"

#serverc的运行脚本
cat > /serverc.sh << EOF
#!/bin/bash
iptables -F
setenforce 0

yum -y install httpd &> /dev/null && echo "httpd安装成功"
echo serverc1-webserver > /var/www/html/index.html
systemctl restart httpd
EOF

#serverc远程运行脚本
chmod +x /serverc.sh
rsync -a /serverc.sh 172.25.6.12:/
ssh root@172.25.6.12 "bash -x /serverc.sh"

#serverd的脚本
cat > /serverd.sh << EOF
#!/bin/bash
iptables -F
setenforce 0
yum -y install httpd &> /dev/null && echo "httpd安装成功"
echo serverd1-webserver > /var/www/html/index.html
systemctl restart httpd
systemctl enable httpd
EOF

#serverd远程运行脚本
chmod +x /serverd.sh
rsync -a /serverd.sh 172.25.6.13:/
ssh root@172.25.6.13 "bash -x /serverd.sh"




#!/bin/bash

#read -p "请输入你从服务器的IP地址:" IP

iptables -F
setenforce 0

yum -y install bind  bind-chroot expect

cat > /etc/named.conf <<EOT
include "/etc/dx.cfg";
include "/etc/wt.cfg";

options {
	listen-on port 53 { 127.0.0.1; any; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	allow-query     { localhost; any; };
	recursion no;
	dnssec-enable no;
	dnssec-validation no;
	dnssec-lookaside auto;
	bindkeys-file "/etc/named.iscdlv.key";
	managed-keys-directory "/var/named/dynamic";
	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};
logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

view  dx {
        match-clients { dx; 172.25.6.19; !192.168.0.19; !192.168.1.19; };
	zone "." IN {
		type hint;
		file "named.ca";
	};
	zone "hff.com" IN {
		type master;
		file "hff.com.dx.zone";	
	};
	include "/etc/named.rfc1912.zones";
};

view  wt {
        match-clients { wt; !172.25.6.19; 192.168.0.19; !192.168.1.19; };
        zone "." IN {
                type hint;
                file "named.ca";
        };
        zone "hff.com" IN {
                type master;
                file "hff.com.wt.zone";
        };
	include "/etc/named.rfc1912.zones";
};

view  other {
        match-clients { any; !172.25.6.19; !192.168.0.19; 192.168.1.19; };
        zone "." IN {
                type hint;
                file "named.ca";
        };

        zone "hff.com" IN {
                type master;
                file "hff.com.other.zone";
        };
        include "/etc/named.rfc1912.zones";
};

include "/etc/named.root.key";

EOT

cat > /etc/dx.cfg << EOT
acl "dx" {
        172.25.6.11;
};
EOT

cat > /etc/wt.cfg << EOT
acl "wt" {
        172.25.6.12;
};
EOT

cd  /var/named/

\cp -a /var/named/named.localhost  hff.com.dx.zone
cat > /var/named/hff.com.dx.zone <<EOT
\$TTL 1D
@       IN SOA  ns1.hff.com rname.invalid. (
                                        10      ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       NS      ns1.hff.com.
ns1     A       172.25.6.10
www     A       192.168.88.88
EOT

\cp -a cp hff.com.dx.zone  hff.com.wt.zone 
cat > /var/named/hff.com.wt.zone <<EOT
\$TTL 1D
@       IN SOA  ns1.hff.com rname.invalid. (
                                        10      ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       NS      ns1.hff.com.
ns1     A       172.25.6.10
www     A       222.122.221.222
EOT

\cp -a cp hff.com.dx.zone  hff.com.other.zone 
cat > /var/named/hff.com.other.zone <<EOT
\$TTL 1D
@       IN SOA  ns1.hff.com rname.invalid. (
                                        10      ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       NS      ns1.hff.com.
ns1     A       172.25.6.10
www     A       111.111.111.111
EOT

chgrp named hff.com.*

named-checkzone  hff.com /var/named/hff.com.dx.zone
named-checkzone  hff.com /var/named/hff.com.wt.zone
named-checkzone  hff.com /var/named/hff.com.other.zone

systemctl restart named

tar czvf /tmp/dns_slave.tar.gz  /etc/dx.cfg /etc/wt.cfg /etc/named.conf

> /root/.ssh/known_hosts

expect <<EOF
spawn rsync -av /tmp/dns_slave.tar.gz  172.25.6.19:/root/
expect "no)?"
send "yes\r"
expect "password"
send "uplooking\r"
expect eof
EOF

expect <<EOF
spawn rsync -av /root/CDN/cdn_slave.sh  172.25.6.19:/root/
expect "password"
send "uplooking\r"
expect eof
EOF

expect <<EOF
spawn  ssh  root@172.25.6.19 "bash -x /root/cdn_slave.sh"
expect "password"
send "uplooking\r"
expect eof
EOF

expect <<EOF
spawn  ssh  root@172.25.6.19 "bash -x /root/cdn_slave.sh"
expect "password"
send "uplooking\r"
expect eof
EOF


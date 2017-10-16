#!/bin/bash

iptables -F
setenforce 0
yum -y install bind bind-chroot
tar -xf dns_slave.tar.gz -C /

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
	transfer-source 172.25.6.19;
	zone "." IN {
		type hint;
		file "named.ca";
	};
	zone "hff.com" IN {
		type slave;
		masters { 172.25.6.10; };
		file "slaves/hff.com.dx.zone";	
	};
	include "/etc/named.rfc1912.zones";
};
view  wt {
        match-clients { wt; !172.25.6.19; 192.168.0.19; !192.168.1.19; };
        transfer-source 192.168.0.19;
        zone "." IN {
                type hint;
                file "named.ca";
        };
        zone "hff.com" IN {
                type slave;
                masters { 192.168.0.10; };
                file "slaves/hff.com.wt.zone";
        };
	include "/etc/named.rfc1912.zones";
};
view  other {
        match-clients { any; !172.25.6.19; !192.168.0.19; 192.168.1.19; };
        transfer-source 192.168.1.19;
        zone "." IN {
                type hint;
                file "named.ca";
        };
        zone "hff.com" IN {
                type slave;
                masters { 192.168.1.10; };
                file "slaves/hff.com.other.zone";
        };
        include "/etc/named.rfc1912.zones";
};
include "/etc/named.root.key";
EOT

systemctl restart named
systemctl enable named


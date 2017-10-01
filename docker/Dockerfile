FROM ubuntu:trusty
LABEL authors="Daniel Cesario <dcesario@redhat.com>"

RUN apt-get update && apt-get install -y \
	kvm \
	qemu-kvm \
	libvirt-bin \
	bridge-utils \
	libguestfs-tools \
	libmojolicious-perl \
	libauthen-passphrase-perl \
	libdbd-mysql-perl \
	libdbi-perl \
	libdbix-connector-perl \
	libipc-run3-perl \
	libnet-ldap-perl \
	libproc-pid-file-perl \
	libxml-libxml-perl \
	libconfig-yaml-perl \
	libmoose-perl \
	libjson-xs-perl \
	qemu-utils \
	perlmagick \
	libmoosex-types-netaddr-ip-perl \
	libsys-statistics-linux-perl \
	libio-interface-perl \
	libiptables-chainmgr-perl \
	libnet-dns-perl \
	wget \
	liblocale-maketext-lexicon-perl \
	libmojolicious-plugin-i18n-perl \
	libdbd-sqlite3-perl \
	git\
	make\
 && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/frankiejol/Test-SQL-Data.git /opt/ravada/Test-SQL-Data \
	&& cd /opt/ravada/Test-SQL-Data \
	&& perl Makefile.PL \
	&& make install

COPY ../ /opt/ravada

WORKDIR /opt/ravada

RUN perl Makefile.PL \
	&& make test
#ENTRYPOINT ["/opt/ravada/entrypoint.sh"]

#!/bin/bash
# this script will remove Kolab, and DELETE all YOUR data!!!
# it will reinstall Kolab, from Kolab 16
# you can optionally install the patches from TBits.net, see bottom of script reinstall.sh

#check that dirsrv will have write permissions to /dev/shm
if [[ $(( `stat --format=%a /dev/shm` % 10 & 2 )) -eq 0 ]]
then
	# it seems that group also need write access, not only other; therefore a+w
	echo "please run: chmod a+w /dev/shm"
	exit 1
fi

if [[ "`sestatus | grep -E 'disabled|permissive'`" == "" ]];
then
        echo "SELinux is active, please set it to permissive"
        exit 1
fi

echo "this script will remove Kolab, and DELETE all YOUR data!!!"
read -p "Are you sure? Type y or Ctrl-C " -r
echo 
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

if [ -z $1 ]
then
  echo "please call $0 <distribution version as on OBS>"
  exit 1
fi
OBS_repo_OS=$1_$RELEASE

systemctl stop kolabd
systemctl stop kolab-saslauthd
systemctl stop cyrus-imapd
systemctl stop dirsrv.target
systemctl stop wallace
systemctl stop clamd@amavisd
systemctl stop amavisd
systemctl stop httpd
systemctl stop mariadb
systemctl stop guam

dirsrvinstance=$(find /var/lib/dirsrv -type d -name slapd-*)
if [ ! -z "$dirsrvinstance" ]
then
    dirsrvinstance=$(basename $dirsrvinstance)
    # Does not exist in EL9, 
    #remove-ds.pl -a -i $dirsrvinstance
fi

dnf -y remove 389\* cyrus-imapd\* postfix\* mariadb-server\* guam\* roundcube\* pykolab\* kolab\* libkolab\* httpd php-Net-LDAP3 up-imapproxy nginx stunnel

echo "deleting files..."
rm -Rf \
    /etc/dirsrv \
    /etc/kolab \
    /etc/postfix \
    /etc/pki/tls/private/example* \
    /etc/pki/tls/certs/example* \
    /etc/roundcubemail \
    /usr/lib64/dirsrv \
    /usr/share/kolab-webadmin \
    /usr/share/roundcubemail \
    /usr/share/kolab-syncroton \
    /usr/share/kolab \
    /usr/share/dirsrv \
    /var/cache/dirsrv \
    /var/cache/kolab-webadmin \
    /var/lock/dirsrv \
    /var/log/kolab* \
    /var/log/dirsrv \
    /var/log/roundcube \
    /var/log/maillog \
    /var/lib/dirsrv \
    /var/lib/imap \
    /var/lib/kolab \
    /var/lib/mysql \
    /tmp/*-Net_LDAP2_Schema.cache \
    /var/spool/imap \
    /var/spool/postfix


if [[ $OBS_repo_OS == EL* ]]
then
  dnf -y install epel-release 
  dnf -y install 'dnf-command(config-manager)'
  dnf -y install openssh-server
  systemctl enable sshd --now
  dnf -y config-manager --set-enabled crb 
fi

# could use environment variable obs=http://my.proxy.org/obs.kolabsys.com 
# see http://kolab.org/blog/timotheus-pokorra/2013/11/26/downloading-obs-repo-php-proxy-file
if [[ "$obs" = "" ]]
then
  export obs=http://obs.kolabsys.com/repositories/
fi
if [[ "$repo" = "" ]]
then
    export repo=$obs/Kolab:/16/$OBS_repo_OS/noarch/kolab-16-release-16.9-17.25.el9.kolab_16.noarch.rpm
fi

#rm -f /etc/yum.repos.d/Kolab*.repo /etc/yum.repos.d/lbs-tbits.net-kolab-nightly.repo
if [[ $OBS_repo_OS == EL* ]]
then
    dnf -y install $repo
elif [[ $OBS_repo_OS == Fedora* ]]
then
  dnf config-manager --add-repo $repo
fi

#rpm --import "https://ssl.kolabsys.com/community.asc"
#rpm --import "http://obs.kolabsys.com/repositories/Kolab:/16/CentOS_7/repodata/repomd.xml.key"
# https://keyserver.ubuntu.com/pks/lookup?search=devel%40lists.kolab.org&op=vindex
#rpm --import "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x830C2BCF446D5A45"

# add priority = 1 to kolab repo files
#for f in /etc/yum.repos.d/Kolab*.repo /etc/yum.repos.d/tpokorra-Kolab*.repo
#do
#    sed -i "s#enabled=1#enabled=1\npriority=1#g" $f
#    sed -i "s#http://obs.kolabsys.com:82/#$obs/#g" $f
#done

if [[ $OBS_repo_OS == EL* ]]
then
  dnf clean metadata

  tryagain=0
  dnf -y install kolab kolab-freebusy patch unzip aspell nmap-ncat || tryagain=1
  if [ $tryagain -eq 1 ]; then
    # yum clean metadata
    sleep 30
    dnf -y install kolab kolab-freebusy patch unzip nmap-ncat || exit -1
  fi
  if [ -z $WITHOUTSPAMFILTER ]
  then
    dnf -y install clamav-update || exit -1
  fi
elif [[ $OBS_repo_OS == Fedora* ]]
then
  dnf clean metadata
  dnf -y install kolab kolab-freebusy patch unzip aspell nmap-ncat || exit -1
  if [ -z $WITHOUTSPAMFILTER ]
  then
    dnf -y install clamav-update || exit -1
  fi
fi

if [ -z $WITHOUTSPAMFILTER ]
then
  sed -i "s/^Example/#Example/g" /etc/freshclam.conf
  sed -i "s/#DatabaseMirror db.XY.clamav.net/DatabaseMirror db.de.clamav.net/g" /etc/freshclam.conf
  # Problem with clamav 0.99.1 in Epel: https://bugzilla.redhat.com/show_bug.cgi?id=1325717
  if [ -f ~/.ssh/main.cld ]
  then
    # use our cached files
    cp -f ~/.ssh/*.c*d /var/lib/clamav/
  else
    freshclam
  fi
fi

if [ ! -z $WITHOUTSPAMFILTER ]
then
  ./disableSpamFilter.sh || exit -1
fi

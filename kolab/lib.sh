#!/bin/bash

patchesurl=https://raw.github.com/TBits/KolabScripts/master/kolab/patches

function DetermineOS
{
  export OS=
  if [ -f /etc/centos-release ]
  then
    release=`cat /etc/centos-release`
    if [[ $release == CentOS\ Linux\ release\ 6* ]]
    then
      export OS=CentOS_6
      export RELEASE=6
    elif [[ $release == CentOS\ Linux\ release\ 7* ]]
    then
      export OS=CentOS_7
      export RELEASE=7
    fi
  elif [ -f /etc/redhat-release ]
  then
    release=`cat /etc/redhat-release`
    if [[ $release == Fedora\ release\ 25\ * ]]
    then
      export OS=Fedora_25
      export RELEASE=25
    elif [[ $release == Fedora\ release\ 26\ * ]]
    then
      export OS=Fedora_26
      export RELEASE=26
    fi
  elif [ -f /etc/lsb-release ]
  then
    . /etc/lsb-release
    if [ $DISTRIB_ID == "Ubuntu" -a $DISTRIB_CODENAME == "precise" ]
    then
      export OS=Ubuntu_12.04
      export RELEASE=1204
    elif [ $DISTRIB_ID == "Ubuntu" -a $DISTRIB_CODENAME == "trusty" ]
    then
      export OS=Ubuntu_14.04
      export RELEASE=1404
    elif [ $DISTRIB_ID == "Ubuntu" -a $DISTRIB_CODENAME == "xenial" ]
    then
      export OS=Ubuntu_16.04
      export RELEASE=1604
    fi
  elif [ -f /etc/debian_version ]
  then
    release=`cat /etc/debian_version`
    if [[ $release == 7* ]]
    then
      export OS=Debian_7.0
      export RELEASE=7
    elif [[ $release == 8* ]]
    then
      export OS=Debian_8.0
      export RELEASE=8
    fi
  fi
  if [[ -f /etc/os-release ]]
  then
      . /etc/os-release
      if [[ $PLATFORM_ID == "platform:el9" ]]
      then
	  export OS=EL
	  export RELEASE=9
	  
      fi
  fi
}

function InstallWgetAndPatch()
{
    if [[ $OS == CentOS* || $OS == Fedora* ]]
    then
	if [[ -z "`rpm -qa | grep wget`" || -z "`rpm -qa | grep patch`" ]]; then
	    yum -y install wget patch
	fi
    elif [[ $OS == EL9 ]]; then
	if [[ -z "`rpm -qa | grep wget`" || -z "`rpm -qa | grep patch`" ]]; then
	    dnf install -y wget patch
	fi
    elif [[ $OS == Ubuntu* || $OS == Debian* ]]; then
	dpkg -l wget patch
	if [ $? -ne 0 ]; then
	    apt-get -y install wget patch;
	fi
    fi
}

# different paths in debian and centOS
DeterminePythonPath()
{
    export pythonDistPackages=/usr/lib/python2.7/dist-packages
    # Debian
    if [ ! -d $pythonDistPackages ]; then
	# centOS
	export pythonDistPackages=/usr/lib/python2.6/site-packages
	if [ ! -d $pythonDistPackages ]; then
	    # centOS7
	    export pythonDistPackages=/usr/lib/python2.7/site-packages
	    if [ ! -d $pythonDistPackages ]; then
		# EL9
		export pythonDistPackages=//usr/lib/python3.9/site-packages/
	    fi
	fi
    fi
}

# function to start/stop/restart the Kolab Service, define action as first parameter!
function KolabService()
{
  action=$1
  if [ -f /bin/systemctl -a -f /etc/debian_version ]
  then
    /bin/systemctl $action kolab-server
  elif [ -f /bin/systemctl ]
  then
    /bin/systemctl $action kolabd.service
  elif [ -f /sbin/service ]
  then
    service kolabd $action
  elif [ -f /usr/sbin/service ]
  then
    service kolab-server $action
  fi
}

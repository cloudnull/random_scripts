#!/usr/bin/env bash
# =============================================================================
# Copyright [2013] [Kevin Carter]
# License Information :
# This software has no warranty, it is provided 'as is'. It is your
# responsibility to validate the behavior of the routines and its accuracy
# using the code provided. Consult the GNU General Public license for further
# details (see GNU General Public License).
# http://www.gnu.org/licenses/gpl.html
# =============================================================================

# Uncomment to enable Debug
# set -x

# Get the latest OVS Built for Precise from the Icehouse repositories
# The script will place all of the OVS deb that are required for 
# Openstack in the directory "/opt/build_ovs" and then install the 
# new version of OVS, "2.0.1". This will do an inplace upgrade if OVS 
# is already installed.

# NOTICE:
# Upgrade OVS to Version 2.0.1 on Ubuntu Precise "12.04". This is useful 
# when upgrading OVS from version 1.10 on Precise running Openstack Havana 
# and or Grizzly where OVS 2.0.1 is not an option for installation out of the 
# base repos.  Being that this is an "out of band" package updates for this 
# package will likely never be available from the base repositories.  
# Additionally this installation process is dependent on the availability of 
# the package name from within the repo that we are downloading it from. 

set -e -u -v 

# Set the full path to the repo that we are getting the packages from
REPO="http://ubuntu-cloud.archive.canonical.com/ubuntu/pool/main/o/openvswitch"

# Define the directory that will be used to download and install the packages
BUILD_DIR="/opt/build_ovs"

# Set the name of the user that is executing the script
WHOAMI=$(whoami)

# These are the three packages that we are going to download
OVS_COMMON="openvswitch-common_2.0.1+git20140120-0ubuntu2~cloud1_amd64.deb"
OVS_SWITCH="openvswitch-switch_2.0.1+git20140120-0ubuntu2~cloud1_amd64.deb"
OVS_DATAPA="openvswitch-datapath-dkms_2.0.1+git20140120-0ubuntu2~cloud1_all.deb"

# Declare a failure function
function failure() {
  echo "FAIL - $1. "
  exit 1
}

# make sure we are root and or have root privileges
if [ "$(id -u ${WHOAMI})" != 0 ];then
  failure "You are not Root Please try again; with \"sudo\" maybe?"
fi

# make sure we have ``wget``
if [ ! "$(which wget)" ];then
  failure "wget was not found on the \"$PATH\" and is required."
fi

# make sure we have the build directory on the system
if [ ! -d "$BUILD_DIR" ];then
  mkdir "$BUILD_DIR"
else
  $(which rm) -rf "$BUILD_DIR"
  mkdir "$BUILD_DIR"
fi

# Download OVS packages from the repos
for pkg in $OVS_COMMON $OVS_SWITCH $OVS_DATAPA;
do
  PACKAGE="$(echo $pkg | awk -F'+' '{print $1}')"
  wget -O $BUILD_DIR/$(echo $pkg | awk -F'+' '{print $1}').deb ${REPO}/$pkg
done

# Make sure that the kernel headers are installed
apt-get -y install linux-headers-$(uname -r)

# install the OVS packages.
pushd $BUILD_DIR
set +e
dpkg -i *.deb
set -e
popd

# Make sure that we are not missing dependencies after installing these debs.
apt-get -y install -f

# Exit cleanly
$(which rm) -rf "$BUILD_DIR"

# Reload the Kernel Module
if [ "$(lsmod | grep openvswitch)" ];then
  modprobe -r openvswitch
fi
modprobe openvswitch

# Wait for the module to be loaded
sleep 2

# Restart OVS
service openvswitch-switch restart

# Give the new OVS just a moment to rebuild the flows
sleep 5

# Restart the Neutron Agent
if [ -f "/etc/init.d/quantum-plugin-openvswitch-agent" ];then
  service quantum-plugin-openvswitch-agent restart
elif [ -f "/etc/init.d/neutron-plugin-openvswitch-agent" ];then
  service neutron-plugin-openvswitch-agent restart
fi

exit 0

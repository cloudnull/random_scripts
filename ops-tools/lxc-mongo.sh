#!/usr/bin/env bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Create an LXC Container to run the latest MongoDB 
# This uses a 10.0.3.x/24 network by default, and assumes the network exists
# Password is set as "secrete"
# Username is set as "openstack"
# The name of the LXC Container is "mongo1"
# Assumes that you have LXC_Defiant template installed

# Variables:
#    LXC_NAME=""                # Name of the container,  default "mongo1"
#    LXC_PASSWORD=""            # Password for unix user, default "secrete"
#    LXC_USERNAME=""            # username for unix user, default "openstacl"
#    LXC_NET_PREFIX=""          # first three octets of IP address, default "10.0.3"
#    LXC_NETMASK=""             # subnet mask, default "255.255.255.0"
#    LXC_IP_ADDR=""             # last octet of IP for LXC container, default "200"
#    LXC_GATEWAY=""             # Default gateway, default "10.0.3.1"
#    MONGO_BIND=""              # Bind address for MongoDB, default "0.0.0.0"
#    MONGO_PORT=""              # Default port for MongoDB, default "27017"
#    MONGO_ADMIN_PASSWORD=""    # Password for default Mongo Admin user, default "secrete"

# Enable Debug
# set -x

set -e -u -v



LXC_NAME=${LXC_NAME:-"mongo1"}
LXC_PASSWORD=${LXC_PASSWORD:-"secrete"}
LXC_USERNAME=${LXC_USERNAME:-"openstack"}
LXC_NET_PREFIX=${LXC_NET_PREFIX:-"10.0.3"}
LXC_NETMASK=${LXC_NETMASK:-"255.255.255.0"}
LXC_IP_ADDR=${LXC_IP_ADDR:-$LXC_NET_PREFIX.200}
LXC_GATEWAY=${LXC_GATEWAY:-$LXC_NET_PREFIX.1}

MONGO_BIND=${MONGO_BIND:-"0.0.0.0"}
MONGO_PORT=${MONGO_PORT:-"27017"}
MONGO_ADMIN_PASSWORD=${MONGO_ADMIN_PASSWORD:-"secrete"}

lxc-create -n ${LXC_NAME} \
           -t defiant \
           -f /etc/lxc/lxc-defiant.conf \
           -- \
           -o curl,wget,iptables,python-dev,sshpass,git-core \
           -I eth0=${LXC_IP_ADDR}=${LXC_NETMASK}=${LXC_GATEWAY} \
           -S /root/.ssh/id_rsa.pub \
           -P ${LXC_PASSWORD} \
           -U ${LXC_USERNAME} \
           -M 4096 \
           --sudo-no-password \
           -L /var/log/${LXC_NAME}_logs=var/log

echo "lxc.start.auto = 1" | tee -a /var/lib/lxc/${LXC_NAME}/config
echo "lxc.group = mongo" | tee -a /var/lib/lxc/${LXC_NAME}/config
lxc-start -d -n ${LXC_NAME}

echo "Resting Post build/startup"
sleep 5

USER_SSH="ssh -o StrictHostKeyChecking=no ${LXC_USERNAME}@${LXC_IP_ADDR}"

echo "Adding Mongo Repo"
${USER_SSH} <<EOL
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
EOL

echo "Installing Mongo and starting it"
${USER_SSH} <<EOL
sudo apt-get update
sudo apt-get -y install mongodb-org
EOL

echo "Installing Mongo and starting it"
${USER_SSH} <<EOL
sudo sed -i '/^bind_ip/ s/^/#\ /g' /etc/mongod.conf
sudo sed -i '/^port/ s/^/#\ /g' /etc/mongod.conf
echo "bind_ip = ${MONGO_BIND}" | sudo tee -a /etc/mongod.conf
echo "port = ${MONGO_PORT}" | sudo tee -a /etc/mongod.conf
sudo /etc/init.d/mongod restart
EOL

echo "Installing Mongo and starting it"
${USER_SSH} <<EOL
sudo mongo<<EOH
use admin
db.createUser(
  {
    user: "siteUserAdmin",
    pwd: "${MONGO_ADMIN_PASSWORD}",
    roles:
    [
      {
        role: "userAdminAnyDatabase",
        db: "admin"
      }
    ]
  }
)
EOH

sudo /etc/init.d/mongod restart
EOL

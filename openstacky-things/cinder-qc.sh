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

# Generating a new Keystone User, upon completion of the script the user
# rc file will be stored in the executing users $HOME directory.

# Variables:
#   GLANCE_IMAGE_NAME=""     Name of image for testing, default "cirros-image"
#   CINDER_VOLUME_TIMEOUT="" Timeout for volume create, default "300" sec
#   CINDER_VOLUME_NAME=""    Name of the volumes, default test-volume-RANDOM
#   CINDER_TYPE_NAME=""      Name of the volume types, default test-type-RANDOM
#   NOVA_INSTANCE_NAME=""    Nova Instance name, default "test-instance-RANDOM"
#   NOVA_INSTANCE_FLAVOR=""  Flavor Name, default "m1.tiny"

set -e -v

function get_id() {
  echo "$1 | grep -w id | awk '{print $4}'"
}

function type_id() {
  echo "$1 | awk '{print $2}'"
}

function failure() {
  echo "$1"
  exit 1
}

OPENRC=${OPENRC:-"openrc"}

if [ ! -f "$HOME/$OPENRC" ];then
  echo "No $OPENRC File found"
  exit 1
else
  source "$HOME/$OPENRC"
fi

# Max time to wait for volume operations (specifically create and delete)
ACTIVE_TIMEOUT="300"
SUPERTEST_HASH=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 9)
CINDER_VOLUME_TIMEOUT=${CINDER_VOLUME_TIMEOUT:-$ACTIVE_TIMEOUT}

# Default volume name
CINDER_VOLUME_NAME=${CINDER_VOLUME_NAME:-test-volume-${SUPERTEST_HASH}}

# Default volume name
CINDER_TYPE_NAME=${CINDER_TYPE_NAME:-test-type-${SUPERTEST_HASH}}

# Boot this image, use first AMi image if unset
GLANCE_IMAGE_NAME=${GLANCE_IMAGE_ID:-"cirros-image"}
IMAGE=$(nova image-list | grep -w ${GLANCE_IMAGE_NAME} | awk '{print $2}')

# Instance Name
NOVA_INSTANCE_NAME=${NOVA_INSTANCE_NAME:-test-instance-${SUPERTEST_HASH}}

# Instance type to create
NOVA_INSTANCE_FLAVOR=${NOVA_INSTANCE_FLAVOR:-m1.tiny}

# Find the instance type ID
INSTANCE_TYPE=$(type_id $(nova flavor-list | grep -w $NOVA_INSTANCE_FLAVOR | head -1))
NET_ID=$(neutron net-list | grep -A2 id | tail -n 1 | awk '{print $2}')

# Create a new Volume Type
if ! TYPE_ID=$(type_id $(cinder type-create ${CINDER_TYPE_NAME}| grep -w ${CINDER_TYPE_NAME})); then
    failure "could not create volume type ${CINDER_TYPE_NAME}"
fi

# Wait actions
VOLCREATE="while ! cinder list | grep ${CINDER_VOLUME_NAME} | grep available; do sleep 1; done"
VOLCHECK="while ! cinder list | grep -w ${VOLUME_ID} | grep in-use; do sleep 1; done"
VOLAVAIL="while ! cinder list | grep -w ${VOLUME_ID} | grep available; do sleep 1; done"
VOLGONE="while cinder show ${VOLUME_ID} ; do sleep 1; done"
NOVACREATE="while ! nova list | grep -w ${INSTANCE_ID} | grep ACTIVE; do sleep 1; done"


# Create a new Volume
VOLUME_ID=$(get_id $(cinder create --display-name ${CINDER_VOLUME_NAME} --volume-type ${CINDER_TYPE_NAME} 1))
if $VOLUME_ID; then
    if ! timeout ${CINDER_VOLUME_TIMEOUT} sh -c $VOLCREATE; then
        failure "volume ${CINDER_VOLUME_NAME} was not available after ${CINDER_VOLUME_TIMEOUT} seconds"
    fi
else
    echo "Unable to create volume ${CINDER_VOLUME_NAME}"
    exit 1
fi

NOVABOOT="$(nova boot --flavor ${INSTANCE_TYPE} --image ${IMAGE} --nic net-id=${NET_ID} ${NOVA_INSTANCE_NAME})"
INSTANCE_ID="$(get_id $NOVABOOT)"
echo "New Instance $INSTANCE_ID"


if ! timeout $ACTIVE_TIMEOUT sh -c $NOVACREATE; then
    failure "Instance ${NOVA_INSTANCE_NAME} failed to go active after ${ACTIVE_TIMEOUT} seconds"
fi

# Attach Volume
echo "nova volume-detatch ${INSTANCE_ID} ${VOLUME_ID} \"/dev/sdx\""
nova volume-attach ${INSTANCE_ID} ${VOLUME_ID} "/dev/sdx" 
if ! timeout $ACTIVE_TIMEOUT sh -c $VOLCHECK; then
    echo "Instance ${NOVA_INSTANCE_NAME} failed to go active after ${ACTIVE_TIMEOUT} seconds"
    exit 1
fi

# Detatch Volume
echo "nova volume-detatch ${INSTANCE_ID} ${VOLUME_ID}"
nova volume-detach ${INSTANCE_ID} ${VOLUME_ID}
if ! timeout $ACTIVE_TIMEOUT sh -c $VOLAVAIL; then
    echo "Instance ${NOVA_INSTANCE_NAME} failed to go active after ${ACTIVE_TIMEOUT} seconds"
    exit 1
fi

# Delete a Cinder Volume
if cinder delete ${VOLUME_ID}; then
    if ! timeout ${CINDER_VOLUME_TIMEOUT} sh -c $VOLGONE; then
        echo "volume did not get deleted properly within ${CINDER_VOLUME_TIMEOUT} seconds"
        exit 1
    fi
else
    echo "could not delete volume ${VOLUME_ID}"
    exit 1
fi

# Delete Volume Type
cinder type-delete $(cinder type-list|grep ${CINDER_TYPE_NAME} | cut -d'|' -f2)

# Delete Instance
nova delete ${INSTANCE_ID}

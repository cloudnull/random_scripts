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

# This is the SUPER SUBMODULE UPDATEERATRO!
# To use this you HAVE TO BE IN THE "rcbops/chef-cookbooks" directory.

# Variables: 
#     BRANCH="coobook_version" # Defaults to "master"

set -e -u -v

BRANCH=${BRANCH:-master}
if [ "$(pwd | grep 'chef-cookbooks$')" ];then
  git submodule init && git submodule sync && git submodule update
  if [ -d "cookbooks" ];then
    pushd cookbooks
    for obj in *;do
      if [ -d "${obj}" ];then
        pushd ${obj}
        if [ -d ".git" ] || [ -f ".git" ];then
          RCB=$(git remote -v | grep -i rcbops | awk '/fetch/ {print $1}')
          if [ "${RCB}" ];then
            echo "Updating ${obj} repo from ${BRANCH}"
            git checkout ${BRANCH}
            git pull ${RCB} ${BRANCH}
          fi
        else
          echo "Not a Git repo"
        fi
        popd
      fi
    done
    popd
  else
    echo "You need to be in the \"cookbooks\" directory found, check that you cloned the correct repo"
  fi
else
  echo "You need to be in the chef-cookbooks directory"
fi

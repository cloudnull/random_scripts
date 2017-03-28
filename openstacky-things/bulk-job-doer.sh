#!/usr/bin/env bash
# Copyright 2017, Kevin Carter <kevin@cloudnull.com>
#
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


# This is a simple script to do bulk operations on all projects we support
# Operation:
#   The script clones project config from OpenStack infra then parses the gerrit
#   projects for all of our known projects. Known projects are determined by the
#   group name or the docimpact-groups. Once all projects are discovered a
#   string is printed with the "${GITHUB-URL}". The script then clones
#   all projects into the workspace and runs the ``bulk_function``. When complete
#   the script commits the changes using the message provided by the "MESSAGE"
#   constant submits everything for review using the *git-review* plugin.


###############################################################
#
# Create your bulk Message here
# Note this should be built in correct git commit message form.
#
###############################################################
MESSAGE="Bulk job commit message

This is a commit message from your friendly neighborhood bulk job runner  
Please replace this message with something more appropriate for the thing  
you are doing.  
"

BULK_JOB_TOPIC="bulk_job_name"


###############################################################
#
# Add your job here. This can be anything you want or need to
# do within a given repository that we support
#
###############################################################
function bulk_function {

    echo "This should be replaced with your actual job."

    # When complete commit your changes and submit them for review
    git commit -a -s -S -m "${MESSAGE}"
    git review -t "${BULK_JOB_TOPIC}"

}


WORKSPACE=${WORKSPACE:-/tmp/workspace}

mkdir -p "${WORKSPACE}"

git clone https://github.com/openstack-infra/project-config "${WORKSPACE}/project-config"

pushd "${WORKSPACE}/project-config"

PROJECTS=$(  
python <<EOR  
PROJECT_GROUP="${PROJECT_GROUP_NAME}"  # This should be set to your project group.

import yaml  # Note this will need to be present on the system.

with open('gerrit/projects.yaml') as f:  
    projects = yaml.load(f.read())

for project in projects:  
    pgs = project.get('groups', list())
    dig = project.get('docimpact-group', 'unknown')
    if PROJECT_GROUP in pgs or PROJECT_GROUP in dig:
        project_entry = project['project']
        project_github = 'https://github.com/%s' % project['project']
        print(project_github)
EOR  
)


for project in ${PROJECTS}; do  
    PROJECT_NAME="$(basename ${project})"
    PROJECT_PATH="${WORKSPACE}/${PROJECT_NAME}"
    git clone "${project}" "${PROJECT_PATH}"

    pushd "${PROJECT_PATH}"
    bulk_function
    popd
done

popd

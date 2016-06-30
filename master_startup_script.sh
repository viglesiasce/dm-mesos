#!/bin/bash -xe
# Copyright 2016 Google Inc. All rights reserved.
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
# Adapted from https://open.mesosphere.com/getting-started/install/

export PREFIX=mesos-master
export SERVER_ID=`hostname -s | awk -F- '{print $NF}'`
export HOSTNAME=`curl "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" -H "Metadata-Flavor: Google"`

# Setup repository key
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

# Add the repository, does not work on Ubuntu 16.04 due to weak signing of repos
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | \
  sudo tee /etc/apt/sources.list.d/mesosphere.list
apt-get -y update

apt-get -y install mesos marathon

echo ${SERVER_ID} > /var/lib/zookeeper/myid

cat > /etc/zookeeper/conf/zoo.cfg <<EOF
tickTime=2000
dataDir=/var/lib/zookeeper/
clientPort=2181
initLimit=5
syncLimit=2
server.1=${PREFIX}-1:2888:3888
server.2=${PREFIX}-2:2888:3888
server.3=${PREFIX}-3:2888:3888
EOF

service zookeeper restart

echo zk://${PREFIX}-1:2181,${PREFIX}-2:2181,${PREFIX}-3:2181/mesos > /etc/mesos/zk

echo 2 > /etc/mesos-master/quorum

echo ${HOSTNAME} > /etc/mesos-master/hostname

service mesos-slave stop
update-rc.d -f mesos-slave remove

service mesos-master restart
service marathon restart

# Install StackDriver Agents
curl -O https://repo.stackdriver.com/stack-install.sh
bash stack-install.sh --write-gcm
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash install-logging-agent.sh

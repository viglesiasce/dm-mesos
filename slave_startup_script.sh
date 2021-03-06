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

export HOSTNAME=`curl "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" -H "Metadata-Flavor: Google"`
export PREFIX=mesos-master
export MESOS_DNS_VERSION=v0.5.2
export ZOOKEEPER_URL=zk://${PREFIX}-1:2181,${PREFIX}-2:2181,${PREFIX}-3:2181/mesos

# Install StackDriver Agents
curl -O https://repo.stackdriver.com/stack-install.sh
bash stack-install.sh --write-gcm
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash install-logging-agent.sh

# Setup repository key
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

# Add the repository, does not work on Ubuntu 16.04 due to weak signing of repos
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | \
  tee /etc/apt/sources.list.d/mesosphere.list
apt-get -y update

# Install mesos
apt-get -y install mesos apt-transport-https ca-certificates

# Install docker-engine
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo debian-jessie main" | \
  tee /etc/apt/sources.list.d/docker.list
apt-get -y update
apt-get -y install docker-engine

service zookeeper stop
update-rc.d -f zookeeper remove

echo ${ZOOKEEPER_URL} > /etc/mesos/zk

echo ${HOSTNAME} > /etc/mesos-slave/hostname
echo 'docker,mesos' > /etc/mesos-slave/containerizers
echo '5mins' > /etc/mesos-slave/executor_registration_timeout

# Mesos DNS
curl -sLO https://github.com/mesosphere/mesos-dns/releases/download/${MESOS_DNS_VERSION}/mesos-dns-${MESOS_DNS_VERSION}-linux-amd64
mv mesos-dns-${MESOS_DNS_VERSION}-linux-amd64 /usr/local/bin/mesos-dns
chmod +x /usr/local/bin/mesos-dns
cat > /lib/systemd/system/mesos-dns.service <<EOF
[Unit]
Description=Mesos DNS

[Service]
ExecStart=/usr/local/bin/mesos-dns -config=/etc/mesos/dns.json

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/mesos/dns.json <<EOF
{
  "zk": "${ZOOKEEPER_URL}",
  "masters": ["mesos-master-1:5050", "mesos-master-2:5050", "mesos-master-3:5050"],
  "refreshSeconds": 60,
  "ttl": 60,
  "domain": "mesos",
  "port": 53,
  "resolvers": ["169.254.169.254"]
}
EOF

systemctl daemon-reload
systemctl enable mesos-dns.service
systemctl start mesos-dns.service

sed -i '1s/^/nameserver 127.0.0.1\n /' /etc/resolv.conf

service mesos-master stop
update-rc.d -f mesos-master remove

service mesos-slave restart

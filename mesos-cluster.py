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

"""Creates a Mesos cluster with 3 Masters and N slaves."""

import copy

COMPUTE_URL_BASE = 'https://www.googleapis.com/compute/v1/'


def GlobalComputeUrl(project, collection, name):
  return ''.join([COMPUTE_URL_BASE, 'projects/', project,
                  '/global/', collection, '/', name])


def ZonalComputeUrl(project, zone, collection, name):
  return ''.join([COMPUTE_URL_BASE, 'projects/', project,
                  '/zones/', zone, '/', collection, '/', name])


def GenerateConfig(context):
  """Generate configuration."""

  base_name = context.env['deployment'] + '-' + context.env['name']

  # Properties for the container-based instance.
  master_instance_properties = {
      'zone': context.properties['zone'],
      'machineType': ZonalComputeUrl(
          context.env['project'], context.properties['zone'], 'machineTypes',
          # TODO make instance type configureable
          context.properties['masterMachineType']),
      'metadata': {'items': [{'key': 'startup-script', 'value': context.imports['master_startup_script.sh']}]},
      'disks': [{
          'deviceName': 'boot',
          'type': 'PERSISTENT',
          'autoDelete': True,
          'boot': True,
          'initializeParams': {
              'sourceImage': GlobalComputeUrl(
                  'debian-cloud', 'images',
                  ''.join(['debian', '-8-jessie-v20160606']))
              },
          }],
      'networkInterfaces': [{
          'accessConfigs': [{
              'name': 'external-nat',
              'type': 'ONE_TO_ONE_NAT'
              }],
          'network': GlobalComputeUrl(
          # TODO make network configureable
              context.env['project'], 'networks', 'default')
          }]
      }

  master_instances = []
  for i in xrange(1,4):
     master_instances.append({
        'name': 'mesos-master-{0}'.format(i),
        'type': 'compute.v1.instance',
        'properties': copy.deepcopy(master_instance_properties)
        })

  slave_instance_properties = copy.deepcopy(master_instance_properties)
  slave_instance_properties['metadata'] = {'items': [{'key': 'startup-script', 'value': context.imports['slave_startup_script.sh']}]}
  slave_instance_properties['machineType'] = context.properties['slaveMachineType']
  slave_template = { 'name': 'mesos-slave-template',
                     'type': 'compute.v1.instanceTemplate',
                     'properties': {'properties': slave_instance_properties}
                     }
  slave_instance_group = { 'name': 'mesos-slave-igm',
                           'type': 'compute.v1.instanceGroupManagers',
                           'properties': {
                                'baseInstanceName': 'mesos-slave',
                                'instanceTemplate': '$(ref.mesos-slave-template.selfLink)',
                                'targetSize': context.properties['numberOfSlaves'],
                                'zone': context.properties['zone']
                               }
                           }
  # Resources to return.
  resources = {
      'resources': master_instances + [slave_template, slave_instance_group]
      }

  return resources

#! /bin/bash
mkdir -p certs
for i in 1 2 3
do
	multipass launch --name node-cluster-$i -c 2 -m 6G -d 10GiB --cloud-init ${PWD}/multipass-cloudinit-docker.yml 20.04
	multipass mount certs node-cluster-$i:/opt/consul/certs
	multipass launch --name node-client-$i -c 2 -m 6G -d 10GiB --cloud-init ${PWD}/multipass-cloudinit-docker.yml 20.04
	multipass mount certs node-client-$i:/opt/consul/certs
done

multipass launch --name node-monitor -c 2 -m 8G -d 10GiB --cloud-init ${PWD}/multipass-cloudinit-docker.yml 20.04
multipass mount certs node-monitor:/opt/consul/certs

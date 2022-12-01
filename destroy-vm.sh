#! /bin/bash
for i in 1 2 3
do
	multipass stop node-cluster-$i && multipass delete node-cluster-$i
	multipass stop node-client-$i && multipass delete node-client-$i
done
multipass stop node-monitor && multipass delete node-monitor
multipass purge

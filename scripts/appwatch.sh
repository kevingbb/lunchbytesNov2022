#!/bin/bash

RESOURCEGROUP=$1
DATAURL=$2

if [ -z "$RESOURCEGROUP" ]; then
echo "Usage: appwatch.sh resource_group_name"
exit 1
fi

sudo apt update
sudo apt install tmux -y

tmux new-session -d -s containerapps
tmux set-option mouse on
tmux select-window -t containerapps:0
tmux split-window -h
tmux split-window -v
tmux split-window -v

tmux send-keys -t 0 "hey -m POST -n 10000 -c 10 $DATAURL?message=loadtest" C-m

tmux send-keys -t 1 "watch 'az containerapp revision list -g $RESOURCEGROUP -n queuereader --query [].{Revision:name,Replicas:properties.replicas,Active:properties.active,Created:properties.createdTime} -o table' 2\>\/dev\/null" C-m

tmux send-keys -t 2 "watch 'az containerapp revision list -g $RESOURCEGROUP -n httpapi --query [].{Revision:name,Replicas:properties.replicas,Active:properties.active,Created:properties.createdTime} -o table' 2\>\/dev\/null" C-m

tmux send-keys -t 3 "watch 'curl -s $DATAURL'" C-m

tmux attach-session -t containerapps
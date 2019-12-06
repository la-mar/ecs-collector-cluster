#!/bin/bash
/root/.deploy.sh

# ECS_AVAILABLE_LOGGING_DRIVERS=["json-file"]

# Write ECS config file
cat << EOF > /etc/ecs/ecs.config
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
ECS_LOGLEVEL=info
ECS_CLUSTER=${cluster_name}
ECS_UPDATES_ENABLED=true
EOF

cloud-init-per once docker_options echo 'OPTIONS="$${OPTIONS} --storage-opt dm.basesize=40G"' >> /etc/sysconfig/docker

# yum update -y
# yum install -y awslogs jq

# Inject the CloudWatch Logs configuration file contents
# cat > /etc/awslogs/awslogs.conf <<- EOF
# [general]
# state_file = /var/lib/awslogs/agent-state

# [/var/log/dmesg]
# file = /var/log/dmesg
# log_group_name = /var/log/dmesg
# log_stream_name = {cluster}/{container_instance_id}

# [/var/log/messages]
# file = /var/log/messages
# log_group_name = /var/log/messages
# log_stream_name = {cluster}/{container_instance_id}
# datetime_format = %b %d %H:%M:%S

# [/var/log/docker]
# file = /var/log/docker
# log_group_name = /var/log/docker
# log_stream_name = {cluster}/{container_instance_id}
# datetime_format = %Y-%m-%dT%H:%M:%S.%f

# [/var/log/ecs/ecs-init.log]
# file = /var/log/ecs/ecs-init.log
# log_group_name = /var/log/ecs/ecs-init.log
# log_stream_name = {cluster}/{container_instance_id}
# datetime_format = %Y-%m-%dT%H:%M:%SZ

# [/var/log/ecs/ecs-agent.log]
# file = /var/log/ecs/ecs-agent.log.*
# log_group_name = /var/log/ecs/ecs-agent.log
# log_stream_name = {cluster}/{container_instance_id}
# datetime_format = %Y-%m-%dT%H:%M:%SZ

# [/var/log/ecs/audit.log]
# file = /var/log/ecs/audit.log.*
# log_group_name = /var/log/ecs/audit.log
# log_stream_name = {cluster}/{container_instance_id}
# datetime_format = %Y-%m-%dT%H:%M:%SZ


# EOF

# Write the awslogs bootstrap script to /usr/local/bin/bootstrap-awslogs.sh
# cat > /usr/local/bin/bootstrap-awslogs.sh <<- EOF
# exec 2>>/var/log/ecs/cloudwatch-logs-start.log
# set -x

# until curl -s http://localhost:51678/v1/metadata
# do
# 	sleep 1
# done

# # Set the region to send CloudWatch Logs data to (the region where the container instance is located)
# cp /etc/awslogs/awscli.conf /etc/awslogs/awscli.conf.bak
# region=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
# sed -i -e "s/region = .*/region = $region/g" /etc/awslogs/awscli.conf

# # Grab the cluster and container instance ARN from instance metadata
# cluster=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .Cluster')
# container_instance_id=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .ContainerInstanceArn' | awk -F/ '{print $3}' )

# # Replace the cluster name and container instance ID placeholders with the actual values
# cp /etc/awslogs/awslogs.conf /etc/awslogs/awslogs.conf.bak
# sed -i -e "s/{cluster}/$cluster/g" /etc/awslogs/awslogs.conf
# sed -i -e "s/{container_instance_id}/$container_instance_id/g" /etc/awslogs/awslogs.conf
# EOF

# Write the bootstrap-awslogs systemd unit file to /etc/systemd/system/bootstrap-awslogs.service
# cat > /etc/systemd/system/bootstrap-awslogs.service <<- EOF
# [Unit]
# Description=Bootstrap awslogs agent
# Requires=ecs.service
# After=ecs.service
# Before=awslogsd.service

# [Service]
# Type=oneshot
# RemainAfterExit=yes
# ExecStart=/usr/local/bin/bootstrap-awslogs.sh

# [Install]
# WantedBy=awslogsd.service
# EOF

# start everything
# chmod +x /usr/local/bin/bootstrap-awslogs.sh
systemctl daemon-reload
# systemctl enable bootstrap-awslogs.service
# systemctl enable awslogsd.service
# systemctl start awslogsd.service --no-block
ecs start
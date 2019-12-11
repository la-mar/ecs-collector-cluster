

# %% ECS Optimized AMI
data "aws_ami" "latest_ecs" {
  most_recent = true
  owners      = ["591542846629"] # AWS

  filter {
    name   = "name"
    values = ["*amazon-ecs-optimized"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_appautoscaling_target" "spot_fleet_target" {
  min_capacity = var.asg_min_capacity
  max_capacity = var.asg_max_capacity
  resource_id  = "spot-fleet-request/${aws_spot_fleet_request.main.id}"
  # role_arn           = var.ecs_iam_role
  scalable_dimension = "ec2:spot-fleet-request:TargetCapacity"
  service_namespace  = "ec2"
}

resource "aws_appautoscaling_policy" "ecs_cluster_autoscale_out" {
  name               = "${var.service_name}-autoscale-out"
  policy_type        = "StepScaling" # "StepScaling" #  "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.spot_fleet_target.resource_id
  scalable_dimension = aws_appautoscaling_target.spot_fleet_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.spot_fleet_target.service_namespace


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    # step_adjustment {
    #   // scale down
    #   metric_interval_lower_bound = 1.0
    #   metric_interval_upper_bound = 2.0
    #   scaling_adjustment          = -1
    # }

    step_adjustment {
      // scale up
      metric_interval_lower_bound = 1.0
      # metric_interval_upper_bound = 3.0
      scaling_adjustment = 1
    }
  }


  # target_tracking_scaling_policy_configuration {
  #   customized_metric_specification {
  #     namespace   = "AWS/ECS"
  #     metric_name = "CPUUtilization"
  #     statistic   = "Average"
  #     unit        = "Percent"

  #     dimensions {
  #       name  = "ClusterName"
  #       value = aws_ecs_cluster.main.name
  #     }

  #   }

  #   target_value       = "90"
  #   scale_in_cooldown  = "300" # seconds
  #   scale_out_cooldown = "60"  # seconds
  # }

  depends_on = [aws_appautoscaling_target.spot_fleet_target, aws_cloudwatch_metric_alarm.service_cpu_scale_up]

}

resource "aws_appautoscaling_policy" "ecs_cluster_autoscale_in" {
  name               = "${var.service_name}-autoscale-in"
  policy_type        = "StepScaling" # "StepScaling" #  "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.spot_fleet_target.resource_id
  scalable_dimension = aws_appautoscaling_target.spot_fleet_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.spot_fleet_target.service_namespace


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      // scale down
      metric_interval_lower_bound = 1.0
      # metric_interval_upper_bound = 2.0
      scaling_adjustment = -1
    }

    # step_adjustment {
    #   // scale up
    #   metric_interval_lower_bound = 2.0
    #   # metric_interval_upper_bound = 3.0
    #   scaling_adjustment = 1
    # }
  }

  depends_on = [aws_appautoscaling_target.spot_fleet_target, aws_cloudwatch_metric_alarm.service_cpu_scale_up]

}

resource "aws_cloudwatch_metric_alarm" "service_cpu_scale_down" {
  alarm_name          = "ServiceCPUScaleDown"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_description = "Monitors CPU Utilization for ${var.service_name}"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cluster_autoscale_in.arn]
}

resource "aws_cloudwatch_metric_alarm" "service_cpu_scale_up" {
  alarm_name          = "ServiceCPUScaleUp"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_description = "Monitors CPU Utilization for ${var.service_name}"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cluster_autoscale_out.arn]
}

resource "random_shuffle" "subnets" {
  input        = data.terraform_remote_state.vpc.outputs.private_subnets
  result_count = 1
}

### Spot Fleet Request ###
resource "aws_spot_fleet_request" "main" {
  iam_fleet_role                      = aws_iam_role.fleet.arn
  target_capacity                     = var.desired_capacity
  terminate_instances_with_expiration = true
  wait_for_fulfillment                = true
  replace_unhealthy_instances         = true
  valid_until                         = "2025-12-04T20:44:20Z"
  fleet_type                          = "maintain"
  instance_pools_to_use_count         = 3

  timeouts {
    create = "3m"
  }

  depends_on = [aws_iam_role.fleet, aws_iam_role_policy_attachment.fleet]



  dynamic "launch_specification" {
    for_each = var.instance_types

    content {
      ami           = data.aws_ami.latest_ecs.id
      instance_type = launch_specification.value
      # subnet_id              = random_shuffle.subnets.result
      subnet_id              = data.terraform_remote_state.vpc.outputs.private_subnets[0]
      vpc_security_group_ids = [aws_security_group.ecs_instance.id]
      iam_instance_profile   = aws_iam_instance_profile.ecs.name
      key_name               = var.key_name
      tags                   = merge(local.tags, { Name = var.service_name })

      root_block_device {
        volume_type = "gp2"
        volume_size = var.root_volume_size
      }

      ebs_block_device {
        # docker
        device_name = "/dev/xvdcz"
        volume_type = "gp2"
        volume_size = var.docker_volume_size
      }

      # user data adds the spot instances to the ecs cluster
      user_data = templatefile("templates/user_data.sh", { cluster_name = aws_ecs_cluster.main.name })
    }
  }
}

### Security ###

data "aws_iam_policy_document" "fleet_assume_role" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "spotfleet.amazonaws.com",
        "ec2.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "fleet" {
  name               = "${local.full_service_name}-fleet"
  assume_role_policy = data.aws_iam_policy_document.fleet_assume_role.json
  tags               = local.tags
}

data "aws_iam_policy_document" "describe_ec2" {

  statement {
    sid       = ""
    effect    = "Allow"
    actions   = ["ec2.Describe*"]
    resources = ["*"]
  }
}


resource "aws_iam_policy" "fleet" {
  name        = "${local.full_service_name}-fleet"
  description = "Fleet Policy Attachment"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF

  # policy = data.aws_iam_policy_document.describe_ec2.json
}

resource "aws_iam_role_policy_attachment" "fleet" {
  role       = aws_iam_role.fleet.name
  policy_arn = aws_iam_policy.fleet.arn
}

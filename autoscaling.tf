resource "aws_appautoscaling_target" "spot_fleet_target" {
  min_capacity       = var.asg_min_capacity
  max_capacity       = var.asg_max_capacity
  resource_id        = "spot-fleet-request/${aws_spot_fleet_request.main.id}"
  scalable_dimension = "ec2:spot-fleet-request:TargetCapacity"
  service_namespace  = "ec2"
}

resource "aws_appautoscaling_policy" "ecs_cluster_autoscale_out" {
  name               = "${var.service_name}-autoscale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.spot_fleet_target.resource_id
  scalable_dimension = aws_appautoscaling_target.spot_fleet_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.spot_fleet_target.service_namespace


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      // scale up
      metric_interval_lower_bound = 1.0
      scaling_adjustment          = 1
    }
  }

  depends_on = [aws_appautoscaling_target.spot_fleet_target]

}

resource "aws_appautoscaling_policy" "ecs_cluster_autoscale_in" {
  name               = "${var.service_name}-autoscale-in"
  policy_type        = "StepScaling"
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
      scaling_adjustment          = -1
    }

  }

  depends_on = [aws_appautoscaling_target.spot_fleet_target]

}

resource "aws_cloudwatch_metric_alarm" "cpu_util_low" {
  alarm_name          = "${var.service_name}-cpu-utilization-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_description = "Scale down if the cpu utilization is belows 90% for 10 minutes"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cluster_autoscale_in.arn]

  lifecycle {
    create_before_destroy = true
  }


}

resource "aws_cloudwatch_metric_alarm" "cpu_util_high" {
  alarm_name          = "${var.service_name}-cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_description = "Scale up if the cpu utilization is above 90% for 10 minutes"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cluster_autoscale_out.arn]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = [aws_cloudwatch_metric_alarm.cpu_util_low]
}

resource "aws_cloudwatch_metric_alarm" "cpu_res_high" {
  alarm_name          = "${var.service_name}-cpu-reservation-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "90"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_description = "Scale up if the cpu reservation is above 90% for 10 minutes"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cluster_autoscale_out.arn]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = [aws_cloudwatch_metric_alarm.cpu_util_high]
}

resource "aws_cloudwatch_metric_alarm" "memory_res_high" {
  alarm_name          = "${var.service_name}-memory-reservation-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "90"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_description = "Scale up if the memory reservation is above 90% for 10 minutes"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cluster_autoscale_out.arn]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = [aws_cloudwatch_metric_alarm.cpu_res_high]
}

resource "aws_cloudwatch_metric_alarm" "cpu_res_low" {
  alarm_name          = "${var.service_name}-cpu-reservation-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "10"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_description = "Scale down if the cpu reservation is below 10% for 10 minutes"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cluster_autoscale_in.arn]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = [aws_cloudwatch_metric_alarm.memory_res_high]
}

resource "aws_cloudwatch_metric_alarm" "memory_res_low" {
  alarm_name          = "${var.service_name}-memory-reservation-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "10"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_description = "Scale down if the memory reservation is below 10% for 10 minutes"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cluster_autoscale_in.arn]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = [aws_cloudwatch_metric_alarm.cpu_res_low]
}

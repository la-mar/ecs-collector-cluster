output "cluster_arn" {
  description = "ARN of ECS Cluster running collectors"
  value       = aws_ecs_cluster.main.arn
}


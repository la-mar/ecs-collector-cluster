output "cluster_arn" {
  description = "ARN of ECS Cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of ECS Cluster"
  value       = aws_ecs_cluster.main.name
}



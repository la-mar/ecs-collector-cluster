
# %% General
variable "domain" {
  description = "Design domain of this service."
}

variable "environment" {
  description = "Environment Name"
}

variable "service_name" {
  description = "Name of the service"
}

# %% Spot Fleet
variable "instance_types" {
  description = "AWS instance type to use"
  default     = ["t3.nano", "t3.micro", "t3.small"]
}

variable "key_name" {
  description = "SSH key name"
  default     = "ecs-service"
}

variable "root_volume_size" {
  description = "Root volume size"
  default     = 50
}

variable "docker_volume_size" {
  description = "Root volume size"
  default     = 50
}

variable "spot_fleet_target_capacity" {
  default     = 2
  description = "The desired capacity of the cluster"
}

variable "ami_arch" {
  default     = "x86_64"
  type        = string
  description = "Architecture of the ECS optimized AMI (x86_64 or arm64)"
}

variable "autoscaling_min_capacity" {
  default     = 1
  description = "Minimum number of nodes in the cluster"
}

variable "autoscaling_max_capacity" {
  default     = 3
  description = "Maximum number of nodes in the cluster"
}

variable "autoscaling_target_value" {
  default     = 70
  type        = number
  description = "Target value for app autoscaling target tracking policy"
}

variable "autoscaling_scale_in_cooldown" {
  default     = 300
  type        = number
  description = "Minimum time (in seconds) between cluster instance scale-in events"
}

variable "autoscaling_scale_out_cooldown" {
  default     = 300
  type        = number
  description = "Minimum time (in seconds) between cluster instance scale-out events"
}






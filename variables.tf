
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

variable "asg_min_capacity" {
  default     = 1
  description = "Minimum size of the nodes in the cluster"
}

variable "asg_max_capacity" {
  default     = 3
  description = "Maximum size of the nodes in the cluster"
}

variable "desired_capacity" {
  default     = 2
  description = "The desired capacity of the cluster"
}

variable "ami_arch" {
  default     = "x86_64"
  type        = string
  description = "Architecture of the ECS optimized AMI (x86_64 or arm64)"
}






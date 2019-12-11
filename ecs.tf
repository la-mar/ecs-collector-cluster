### ECS Cluster ###

resource "aws_ecs_cluster" "main" {
  name = var.service_name
  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_ecs_service" "datadog" {
  name                    = "datadog"
  cluster                 = aws_ecs_cluster.main.arn
  task_definition         = data.aws_ecs_task_definition.datadog.family
  scheduling_strategy     = "DAEMON"
  enable_ecs_managed_tags = true
  propagate_tags          = "TASK_DEFINITION"
  tags                    = local.tags

  lifecycle {
    # create_before_destroy = true
    ignore_changes = [
      desired_count,
      task_definition,


    ]
  }
}



### Task Definitions ###

# TODO: Find a way to avoid referencing task definition. This creates a hard to anticipate
# error where the task definition must exist before the terraform is applied in a new environment
data "aws_ecs_task_definition" "datadog" {
  task_definition = "datadog"
}


### Security ###

resource "aws_iam_role_policy_attachment" "ecs_service" {
  role       = aws_iam_role.ecs_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

data "aws_iam_policy_document" "ecs_policy" {
  statement {
    sid    = ""
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_service" {
  name               = "${local.full_service_name}-ecs-service"
  assume_role_policy = data.aws_iam_policy_document.ecs_policy.json
  tags               = local.tags
}

resource "aws_security_group" "ecs_instance" {
  name        = "${local.full_service_name}-ecs-instance-sg"
  description = "container security group for ${local.full_service_name}"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  tags        = local.tags

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${local.full_service_name}-ecs-instance"
  role = aws_iam_role.ecs_instance.name
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"

}

data "aws_iam_policy_document" "ecs_instance" {
  statement {
    sid     = "1"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "sqs.amazonaws.com",

      ]
    }
  }
}

resource "aws_iam_role" "ecs_instance" {
  name               = "${local.full_service_name}-ecs-instance"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance.json
  tags               = local.tags
}


### Capacity Provider ###

# resource "aws_launch_configuration" "main" {
#   name_prefix = "${format("%s-", var.name)}"

#   image_id                    = "${var.image_id}"
#   instance_type               = "${var.instance_type}"
#   ebs_optimized               = "${var.instance_ebs_optimized}"
#   iam_instance_profile        = "${var.iam_instance_profile}"
#   key_name                    = "${var.key_name}"
#   security_groups             = ["${aws_security_group.cluster.id}"]
#   user_data                   = "${data.template_cloudinit_config.cloud_config.rendered}"
#   associate_public_ip_address = "${var.associate_public_ip_address}"

#   # root
#   root_block_device {
#     volume_type = "gp2"
#     volume_size = "${var.root_volume_size}"
#   }

#   # docker
#   ebs_block_device {
#     device_name = "/dev/xvdcz"
#     volume_type = "gp2"
#     volume_size = "${var.docker_volume_size}"
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_autoscaling_group" "main" {
#   name = "${var.name}"

#   availability_zones   = ["${var.availability_zones}"]
#   vpc_zone_identifier  = ["${var.subnet_ids}"]
#   launch_configuration = "${aws_launch_configuration.main.id}"
#   min_size             = "${var.min_size}"
#   max_size             = "${var.max_size}"
#   desired_capacity     = "${var.desired_capacity}"
#   termination_policies = ["OldestLaunchConfiguration", "Default"]

#   dynamic "tag" {
#     for_each = merge(local.tags, { Name = var.service_name })

#     key                 = tag.key
#     value               = tag.value
#     propagate_at_launch = true

#   }



#   lifecycle {
#     create_before_destroy = true
#   }
# }




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

resource "random_shuffle" "subnets" {
  input        = data.terraform_remote_state.vpc.outputs.private_subnets
  result_count = 1
}

output "shuffle" {
  value = random_shuffle.subnets.result
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

      # dynamic "tag" {
      #   for_each = merge(local.tags, { Name = var.service_name })

      #   key                 = tag.key
      #   value               = tag.value
      #   propagate_at_launch = true

      # }

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

# data "aws_iam_policy_document" "describe_ec2" {

#   statement {
#     sid       = ""
#     effect    = "Allow"
#     actions   = ["ec2.Describe*"]
#     resources = ["*"]
#   }
# }


resource "aws_iam_policy" "fleet" {
  name        = "${local.full_service_name}-fleet"
  description = "Fleet Policy Attachment"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*",
        "ec2:RequestSpotInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:CreateTags"
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

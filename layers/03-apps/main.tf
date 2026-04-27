# Gateway EIP
resource "aws_eip" "gateway" {
  domain = "vpc"

  tags = {
    Name = "quietchatter-gateway-eip"
  }
}

resource "aws_eip_association" "gateway" {
  instance_id   = aws_instance.gateway.id
  allocation_id = aws_eip.gateway.id
}

# Gateway Node
resource "aws_instance" "gateway" {
  ami           = var.ami_id
  instance_type = "t4g.micro"
  subnet_id     = data.terraform_remote_state.base.outputs.public_subnet_ids[0]
  private_ip    = data.terraform_remote_state.base.outputs.gateway_private_ip

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.gateway_sg_id]
  iam_instance_profile   = data.terraform_remote_state.base.outputs.ssm_profile_name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/gateway_user_data.sh.tftpl", {
    aws_region       = var.aws_region
    s3_bucket_name   = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    k3s_server_ip    = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    k3s_token_secret = data.terraform_remote_state.base.outputs.k3s_token_secret_name
    service_image    = var.api_gateway_image
    instance_name    = "quietchatter-gateway-node"
    loki_url         = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user        = data.terraform_remote_state.base.outputs.grafana_cloud_user
  })

  tags = {
    Name = "quietchatter-gateway-node"
  }
}

# Worker Launch Template (Spot-only)
resource "aws_launch_template" "worker" {
  name_prefix   = "quietchatter-worker-"
  image_id      = var.ami_id
  instance_type = "t4g.small"

  iam_instance_profile {
    name = data.terraform_remote_state.base.outputs.ssm_profile_name
  }

  vpc_security_group_ids = [data.terraform_remote_state.base.outputs.microservices_sg_id]

  user_data = base64encode(templatefile("${path.module}/templates/worker_user_data.sh.tftpl", {
    aws_region       = var.aws_region
    s3_bucket_name   = data.terraform_remote_state.base.outputs.infra_assets_bucket_name
    k3s_server_ip    = data.terraform_remote_state.platform.outputs.controlplane_private_ip
    k3s_token_secret = data.terraform_remote_state.base.outputs.k3s_token_secret_name
    instance_name    = "quietchatter-worker-node"
    loki_url         = data.terraform_remote_state.base.outputs.grafana_cloud_logs_url
    loki_user        = data.terraform_remote_state.base.outputs.grafana_cloud_user
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "quietchatter-worker-node"
    }
  }
}

# Worker ASG (Spot-only)
resource "aws_autoscaling_group" "worker" {
  name                = "quietchatter-worker-asg"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = data.terraform_remote_state.base.outputs.private_subnet_ids

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.worker.id
        version            = "$Latest"
      }
      override {
        instance_type = "t4g.small"
      }
      override {
        instance_type = "t4g.medium"
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "quietchatter-worker-node"
    propagate_at_launch = true
  }
}

# Worker Scale-out Policy (CPU 70% 초과 시)
resource "aws_autoscaling_policy" "worker_scale_out" {
  name                   = "quietchatter-worker-scale-out"
  autoscaling_group_name = aws_autoscaling_group.worker.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

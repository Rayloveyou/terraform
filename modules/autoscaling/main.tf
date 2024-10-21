#Tạo Template cho ASG dùng để tạo EC2s
 #aws_ami: lấy image id của OS
data "aws_ami" "ami" {
  most_recent = true

  filter {
    name = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }

  owners = ["amazon"]
}

# Để Ec2 truy cập được DB -> Gán IAM Role vào EC2
module "iam_instance_profile" {
  source  = "terraform-in-action/iip/aws"
  actions = ["logs:*", "rds:*"]
}

resource "aws_launch_template" "web" {
  name_prefix   = "web-"
  image_id      = data.aws_ami.ami.id #Gán image id vào launch template
  instance_type = "t2.micro"

  vpc_security_group_ids = [var.sg.web]

  user_data = filebase64("${path.module}/run.sh") #đoạn script sẽ chạy khi ec2 được tạo

    #IAM Role cho Ec2
   iam_instance_profile {
        name = module.iam_instance_profile.name
    }
}

#Khai báo LB để truy cập được đến ASG
module "alb" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 7.0"
  name               = var.project
  load_balancer_type = "application"
  vpc_id             = var.vpc.vpc_id
  subnets            = var.vpc.public_subnets
  security_groups    = [var.sg.lb]
  http_tcp_listeners = [
    {
      port               = 80,  
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
  target_groups = [
    {
      name_prefix      = "web",
      backend_protocol = "HTTP",
      backend_port     = 80
      target_type      = "instance"
    }
  ]
}

resource "aws_autoscaling_group" "web" {
 name                = "${var.project}-asg"
  # Độ scaling
  min_size            = 1
  max_size            = 3
  #Nơi các Ec2 được tạo
  vpc_zone_identifier = var.vpc.private_subnets
   #Lấy target_group_arns từ module lb
   target_group_arns   = module.alb.target_group_arns
 #Template cho các EC2
  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }
}
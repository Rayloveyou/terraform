data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" { 
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"
 //Tên VPC + CIDR + AZ
  name = "${var.project}-vpc"
  cidr = var.vpc_cidr
  azs     = data.aws_availability_zones.available.names
  

 //Public + private + DB subnet
  private_subnets = var.private_subnets
  public_subnets = var.public_subnets
  database_subnets = var.database_subnets

 //SG, NAT
  create_database_subnet_group = true
  enable_nat_gateway = true
  single_nat_gateway = true
}

// Tạo SG cho ALB được truy cập từ mọi nơi = 80
module "lb_sg" {
  source = "terraform-in-action/sg/aws"
  vpc_id = module.vpc.vpc_id
   #ingress cho phép truy cập
  ingress_rules = [
    {
        port= 80
        cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

//Tạo SG cho ALB truy cập vào EC2 qua port 80
module "web_sg" {
    source = "terraform-in-action/sg/aws"
    vpc_id = module.vpc.vpc_id
    ingress_rules = [
        {
            port = 80
            security_groups = [module.lb_sg.security_group.id]
        }
    ]
} 

//Tạo SG cho EC2 truy cập vào RDS = port 5432
module "db_sg" {
    source = "terraform-in-action/sg/aws"
    vpc_id = module.vpc.vpc_id
    ingress_rules = [
        {
            port = 5432
            security_groups = [module.web_sg.security_group.id]
        }
    ]
  
}
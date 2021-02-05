# resource "aws_instance" "CentOS_instance" {
# ami = "ami-0affd4508a5d2481b"
# instance_type = "t2.micro"
# subnet_id = aws_subnet.main.id

# associate_public_ip_address = true

# tags = {
#     Name = "test"
#   }

# }

# resource "aws_security_group" "example" {
#   name = "test"

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port = 22
#     to_port   = 22
#     protocol  = "tcp"

#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# output "IP"{
#  value=aws_instance.CentOS_instance.public_ip
# }

# resource "aws_vpc" "main" {
#   cidr_block       = "10.0.0.0/16"
#   instance_tenancy = "default"

#   tags = {
#     Name = "main"
#   }
# }

# resource "aws_subnet" "main" {
#   vpc_id     = aws_vpc.main.id
#   cidr_block = "10.0.1.0/24"

#   tags = {
#     Name = "Main"
#   }
# }
    
# resource "null_resource" "example_provisioner" {
#   triggers = {
#     public_ip = aws_instance.CentOS_instance.public_ip
#   }

#   connection {
#     type  = "ssh"
#     host  = aws_instance.CentOS_instance.public_ip
#     port  = 22
#     agent = true
#   }

#   // change permissions to executable and pipe its output into a new file
#   provisioner "remote-exec" {
#     inline = [
#         "sudo yum install httpd node docker git -y",
#         "sudo git clone https://github.com/CitrineInformatics/sample-service.git",
#         "sudo systemctl start httpd",
#         "sudo systemctl enable httpd",
#         "sudo systemctl start docker",
#         "sudo systemctl enable docker",
#         "cd /home/ubuntu/sample-service",
#         "sudo docker build . -t newimage",
#         "sudo docker run -p 80:5000 -d newimage",
#         ]
#   }

# }

# VPC Creation
resource "aws_vpc" "vpc" {
  cidr_block                     = "10.0.0.0/16"
  enable_dns_hostnames           = true
  enable_dns_support             = true
  enable_classiclink_dns_support = true
  tags = {
    Name = "vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet1" {
  cidr_block              = "10.0.0.0/24"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}
#another subnet
resource "aws_subnet" "public_subnet2" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}
# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name = "gateway"
  }
}

# Public Route Table
resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_subnet_assoc" {
  route_table_id = "${aws_route_table.public_route.id}"
  subnet_id      = "${aws_subnet.public_subnet1.id}"
}


# Application Security Group
resource "aws_security_group" "application_security_group" {
  name        = "application_security_group"
  description = "Allow inbound traffic for application"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    description = "TLS from load balancer"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = ["${aws_security_group.alb_security_group.id}"]
  }

  ingress {
    description = "8080 from load balancer"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = ["${aws_security_group.alb_security_group.id}"]
  }

    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application_security_group"
  }

}

# EC2 instance without autoscaling and load balancer
resource "aws_instance" "web" {
  ami                    = "ami-0affd4508a5d2481b"
  instance_type          = "t2.micro"
  key_name               = "karan"
  vpc_security_group_ids = ["${aws_security_group.application_security_group.id}"]
  subnet_id              = "${aws_subnet.public_subnet1.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.CodeDeployEC2ServiceRole-instance-profile.name}"

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_type = "gp2"
    volume_size = "20"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo yum install httpd node docker git -y
              sudo git clone https://github.com/CitrineInformatics/sample-service.git
              sudo systemctl start httpd
              sudo systemctl enable httpd
              sudo systemctl start docker
              sudo systemctl enable docker
              cd /home/ubuntu/sample-service
              sudo docker build . -t newimage
              sudo docker run -p 80:5000 -d newimage
              EOF

  tags = {
    Name = "Webapp_EC2"
   }
}
# IAM  CodeDeployEC2ServiceRole Profile Instance
resource "aws_iam_instance_profile" "CodeDeployEC2ServiceRole-instance-profile" {
  name = "CodeDeployEC2ServiceRole-instance-profile"
  role = "${aws_iam_role.CodeDeployEC2ServiceRole.name}"
}
# IAM CodeDeployEC2ServiceRole Role
resource "aws_iam_role" "CodeDeployEC2ServiceRole" {
  name = "CodeDeployEC2ServiceRole"

  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
{
"Action": "sts:AssumeRole",
"Principal": {
 "Service": "ec2.amazonaws.com"
},
"Effect": "Allow"
}
]
}
EOF

  tags = {
    tag-key = "CodeDeployEC2ServiceRole"
  }
}
# Taget Group
resource "aws_lb_target_group" "alb-target-group" {
  name        = "alb-target-group"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = "${aws_vpc.vpc.id}"
  deregistration_delay = 20
  
  #   health_check {
  #   interval            = 30
  #   path                = "/"
  #   protocol            = "HTTP"
  #   timeout             = 10
  #   healthy_threshold   = 2
  #   unhealthy_threshold = 6
  #   matcher = "200"
  # }
  # stickiness{
  #   type = "lb_cookie"
  #   enabled = "true"
  # }
}

# Application load balancer
resource "aws_lb" "application_load_balancer" {
  name     = "application-load-balancer"
  internal = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups = ["${aws_security_group.alb_security_group.id}"]
  subnets = ["${aws_subnet.public_subnet1.id}","${aws_subnet.public_subnet2.id}"]

  tags = {
    Name = "application-load-balancer"
  }

 
}

# Alb Security group
 resource "aws_security_group" "alb_security_group" {
  name        = "alb_security_group"
  vpc_id      = "${aws_vpc.vpc.id}"

 ingress {
    description = "80 from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #  ingress {
  #   description = "443 from VPC"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
   
  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   tags = {
    Name = "alb_security_group"
  }

}

# alb listener
resource "aws_lb_listener" "alb-listner" {
  load_balancer_arn = "${aws_lb.application_load_balancer.arn}"
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.alb-target-group.arn}"
  }
}
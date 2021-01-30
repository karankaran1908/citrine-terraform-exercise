resource "aws_instance" "CentOS_instance" {
ami = "ami-0fc61db8544a617ed"
instance_type = "t2.micro"
subnet_id = aws_subnet.main.id

associate_public_ip_address = true

}

resource "aws_security_group" "example" {
  name = aws_instance.CentOS_instance

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "IP"{
 value=aws_instance.CentOS_instance.public_ip
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}
    
resource "null_resource" "example_provisioner" {
  triggers = {
    public_ip = aws_instance.CentOS_instance.public_ip
  }

  connection {
    type  = "ssh"
    host  = aws_instance.CentOS_instance.public_ip
    port  = 22
    agent = true
  }

  // change permissions to executable and pipe its output into a new file
  provisioner "remote-exec" {
    inline = [
        "sudo yum install httpd node docker git -y",
        "sudo git clone https://github.com/CitrineInformatics/sample-service.git",
        "sudo systemctl start httpd",
        "sudo systemctl enable httpd",
        "sudo systemctl start docker",
        "sudo systemctl enable docker",
        "cd /home/ubuntu/sample-service",
        "sudo docker build . -t newimage",
        "sudo docker run -p 80:5000 -d newimage",
        ]
  }

}
resource "aws_instance" "CentOS_instance" {
ami = "ami-0fc61db8544a617ed"
instance_type = "t2.micro"
subnet_id = aws_subnet.main.id

provisioner "remote-exec" {
connection {
host = aws_instance.CentOS_instance.public_ip
}
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
    

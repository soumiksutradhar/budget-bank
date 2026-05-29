provider "aws"{
	region = "ap-south-1"
}

resource "aws_key_pair" "devops_forge_kp"{	# "devops_forge_kp" is a Terraform identifier and hence cannot have hyphens
	key_name = "devops-forge-kp"
	public_key = file("~/.ssh/devops-forge.pub")
}

resource "aws_instance" "d03_server"{
	ami = "ami-0f58b397bc5c1f2e8" # Ubuntu 22.04 image for ap-south-1
	instance_type = "t2.small"
	key_name = aws_key_pair.devops_forge_kp.key_name
	vpc_security_group_ids = [aws_security_group.devops_forge_sg.id]

tags = {
	Name = "DevOps-Forge-EC2"
	}
}

resource "aws_security_group" "devops_forge_sg"{
	name = "devops-forge-sg"
	description = "This security group allows SSH on DevOps-Forge-EC2 instance"
	
	ingress{
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	ingress{
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	egress{
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

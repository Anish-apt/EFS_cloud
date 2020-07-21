provider "aws" {
  region     = "ap-south-1"
  profile    = "Anish"
}

resource "aws_vpc" "task" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "task_vpc"
  }
}


resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.task.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-subnet-1a"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.task.id

  tags = {
    Name = "task-igw"
  }
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.task.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "task_routeTable"
  }
}

resource "aws_route_table_association" "route_asso" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route.id
}

resource "aws_security_group" "allow_nfs" {
  name        = "TerraSg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.task.id
  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "TerraSg"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name      = "AnishKey"
  vpc_security_group_ids = [ aws_security_group.allow_nfs.id ]
  subnet_id = aws_subnet.public.id

  connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("C:/Users/Anish Khandelwal/Downloads/Learning Essentials/AnishKey.pem")
      host     = aws_instance.web.public_ip
    }

    provisioner "remote-exec" {
      inline = [
      "sudo yum install httpd  php git amazon-efs-utils nfs-utils -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"
    ]
  }
  tags = {
    Name = "Project"
  }
}

resource "aws_efs_file_system" "efs" {
  depends_on = [ aws_security_group.allow_nfs, aws_instance.web,  ]
  creation_token = "my-efs"

  tags = {
    Name = "my-efs"
  }
}

resource "aws_efs_mount_target" "alpha" {
  depends_on = [ aws_efs_file_system.efs, ]
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_instance.web.subnet_id
  security_groups = [ aws_security_group.allow_nfs.id ]
}

resource "null_resource" "nullremote" {
    depends_on = [ aws_efs_mount_target.alpha, ]
    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = file("C:/Users/Anish Khandelwal/Downloads/Learning Essentials/AnishKey.pem")
        host     = aws_instance.web.public_ip
      }

      provisioner "remote-exec" {
        inline = [
          "sudo echo ${aws_efs_file_system.efs.dns_name}:/var/www/html/ efs defaults,_netdev 0 0 >> sudo /etc/fstab",
          "sudo mount ${aws_efs_file_system.efs.dns_name}:/ /var/www/html/",
          "sudo rm -rf /var/www/html/*",
          "sudo git clone https://github.com/Anish-apt/Cloud_file.git /var/www/html/"
        ]
      }
}

resource "aws_s3_bucket" "mys3" {
  bucket = "anish2309"
  acl    = "public-read"
  force_destroy = true
  tags = {
    Name = "anishtask1"
  }
  versioning{
    enabled = true

  }
 }

locals {
  s3_origin_id = "myS3Origin"
}



resource "aws_s3_bucket_object" "s3obj" {

depends_on = [
    aws_s3_bucket.mys3,
  ]

  bucket = "anish2309"
  key    = "Terraform.jfif"
  source = "C:/Users/Anish Khandelwal/Desktop/Terraform.jfif"
  acl = "public-read"
  content_type = "image or jpeg"

  }


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "anish2309.s3.amazonaws.com"
    origin_id   = "S3-anish2309"


  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "anish2309.s3.amazonaws.com"
    prefix          = "myprefix"
  }


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-anish2309"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-anish2309"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-anish2309"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"

    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "project_ip" {
  value = aws_instance.web.public_ip
}

provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAW75GPH5TO3JTCFQV"
  secret_key = "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"
}
resource "aws_key_pair" "key" {
  key_name   = "mykey"
  public_key = file("mykey.pub")
}

resource "aws_security_group" "my-sg" {
  name        = "my-sg"
  description = "Allow port 22 and 80"
  vpc_id      = "vpc-11f8e579"
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
   Name = "task2-sg"
  }
}

resource "aws_efs_file_system" "myefs" {
   creation_token = "myefs"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
 tags = {
     Name = "Task2-EFS-File-System"
   }
 }
resource "aws_efs_mount_target" "efs-mta" {
   file_system_id  = aws_efs_file_system.myefs.id
   subnet_id = "subnet-d3ead0bb"
   security_groups = [aws_security_group.my-sg.id]
}
resource "aws_efs_mount_target" "efs-mtb" {
   file_system_id  = aws_efs_file_system.myefs.id
   subnet_id = "subnet-133e555f"
   security_groups = [aws_security_group.my-sg.id]
}
resource "aws_efs_mount_target" "efs-mtc" {
   file_system_id  = aws_efs_file_system.myefs.id
   subnet_id = "subnet-941dafef"
   security_groups = [aws_security_group.my-sg.id]
}

resource "aws_instance" "mytask2instance" {
  ami             = "ami-052c08d70def0ac62"
  instance_type   = "t2.micro"
  key_name        = "mykey"
  security_groups = ["my-sg"]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("mykey")
    host        = aws_instance.mytask2instance.public_ip
  }
  provisioner "remote-exec" {
    inline = [
       "sudo yum install httpd git -y",
       "sudo systemctl restart httpd",
       "sudo systemctl enable httpd",
    ]
  }
  provisioner "remote-exec" {
    inline = [
       "sudo yum install httpd amazon-efs-utils -y",
       "sudo sleep 3m",
       "sudo mount -t efs '${aws_efs_file_system.myefs.id}':/ /var/www/html",
       "sudo su -c \"echo '${aws_efs_file_system.myefs.id}:/ /var/www/html nfs4 defaults,vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0' >> /etc/fstab\"",
    ]
  }
  tags = {
    Name = "BishalOS"
  }
}
output "InstancePIP" {  
  value = aws_instance.mytask2instance.public_ip
}


resource "aws_cloudfront_distribution" "my_cf_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "myweb"

    custom_origin_config {
      http_port              = 80
      https_port             = 80
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  enabled = true
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "myweb"

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

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = "bishal-task2-bucket"
  acl    = "public-read"
  tags = {
    Name        = "Code"
    Environment = "prod"
  }
}
resource "aws_s3_bucket_object" "files_upload" {
  depends_on = [
    aws_s3_bucket.bucket,
  ]
  bucket = "bishal-task2-bucket"
  key    = "image.jpg"
  source = "image.jpg"
}
resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
  {
         "Sid":"AllowPublicRead",
         "Effect":"Allow",
         "Principal": { 
             "AWS":"*"
         },
         "Action":"s3:GetObject",
         "Resource":"arn:aws:s3:::bishal-task2-bucket/*"
      }
    ]
}
POLICY
}












provider "aws" {
  region = "us-east-1"
}

# Security Group for Strapi and HTTP (80)
resource "aws_security_group" "strapi_sg" {
  name        = "strapi_sg"
  description = "Allow HTTP (80) and Strapi (1337)"

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

# EC2 Instance with automated Strapi install
resource "aws_instance" "strapi_ec2" {
  ami                    = "ami-053b0d53c279acc90" # Ubuntu 22.04 LTS in us-east-1
  instance_type          = "t2.micro"
  security_groups        = [aws_security_group.strapi_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y curl gnupg git build-essential nginx

              # Install Node.js 18
              curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
              apt install -y nodejs

              # Install Yarn and PM2
              npm install -g yarn pm2

              # Install Strapi CLI
              npm install -g create-strapi-app

              # Create and start Strapi app
              cd /home/ubuntu
              npx create-strapi-app my-project --quickstart --no-run

              cd my-project
              yarn build
              pm2 start yarn --name strapi -- start
              pm2 startup systemd
              pm2 save

              # Setup Nginx reverse proxy to Strapi on port 80
              cat > /etc/nginx/sites-available/strapi << EON
              server {
                  listen 80;
                  server_name _;

                  location / {
                      proxy_pass http://localhost:1337;
                      proxy_http_version 1.1;
                      proxy_set_header Upgrade \$http_upgrade;
                      proxy_set_header Connection 'upgrade';
                      proxy_set_header Host \$host;
                      proxy_cache_bypass \$http_upgrade;
                  }
              }
              EON

              ln -s /etc/nginx/sites-available/strapi /etc/nginx/sites-enabled/
              rm /etc/nginx/sites-enabled/default
              systemctl restart nginx
            EOF

  tags = {
    Name = "Strapi"
  }
}

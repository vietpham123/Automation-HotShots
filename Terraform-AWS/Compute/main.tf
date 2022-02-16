###########################################################
# This terraform manifest is used to create a compute     #
# instance that provides a basic reddit-like website      #
# that allows users to add links and upvote them          #
# using Ubuntu 16.04, ruby, mongodb                       #
###########################################################

###########################################################
# AWS provider configuration                              #
###########################################################

provider "aws" {
    region = var.region
    access_key = var.access_key
    secret_key = var.secret_key
}

#########################################################
# Enumerate all available AZ's in the VPC for a         #
# given region                                          #
#########################################################

data "aws_availability_zones" "AZs" {
  state = "available"
}

###########################################################
# AWS Instance t2.micro Ubuntu 16.04                      #
###########################################################

resource "aws_instance" "raddit" {
    ami = "ami-05803413c51f242b7"
    instance_type = "t2.micro"
    key_name = var.key_pair
    subnet_id = var.raddit_subnet
    associate_public_ip_address = "true"
    vpc_security_group_ids = [var.security_group]
    availability_zone = element(data.aws_availability_zones.AZs.names, 0)
    tags = {
        Name = var.compute_name
    }

    user_data = <<EOF
    #!/bin/bash
    echo "----- Cloning down gemfiles and raddit application -----"
    sudo git clone https://github.com/Artemmkin/raddit.git /var/lib/raddit

    echo "----- Installing Ruby -----"
    sudo apt-get update
    sudo apt-get install -y ruby-full build-essential

    echo "----- Installing Bundler -----"
    sudo gem install bundler -v "$(grep -A 1 "BUNDLED WITH" ~/var/lib/raddit/Gemfile.lock | tail -n 1)"

    echo "----- Building Gemfile -----"
    cd /var/lib/raddit
    sudo bundle install
    cd

    echo "----- Installing and configuring Mongodb -----"
    wget -qO - https://www.mongodb.org/static/pgp/server-3.2.asc | sudo apt-key add -
    echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org

    echo "----- Starting Mongodb -----"
    sudo systemctl start mongod
    sudo systemctl enable mongod

    echo "----- Downloading service file to system -----"
    sudo wget https://raw.githubusercontent.com/vietpham123/Automation-HotShots/main/raddit.service -P /etc/systemd/system/

    echo "----- Starting Raddit service -----"
    sudo systemctl start raddit
    sudo systemctl enable raddit
    EOF

    lifecycle {
        ignore_changes = [ami]
    }
}

###########################################################
# configuring system                                      #
###########################################################
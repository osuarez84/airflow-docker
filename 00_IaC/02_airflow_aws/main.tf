
provider "aws" {
    region = "eu-west-1"
    profile = "terraform"
}



# # TODO
# # Get the ami for a debian9 machine
# data "aws_ami" "ubuntu" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   owners = ["099720109477"] # Canonical
# }

resource "aws_key_pair" "ssh" {
    key_name = "ssh-key"
    public_key = file("/mnt/c/Users/veget/.ssh/id_rsa.pub")
}

resource "aws_security_group" "airflow-security" {
    name = "airflow-security"
    description = "Allo ssh inbound traffic"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }


    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_instance" "airflow-instance" {
    ami           = "ami-055958ae2f796344b"
    instance_type = "t2.large"


    root_block_device {
        volume_size = 100
    }

    key_name = aws_key_pair.ssh.key_name
    security_groups = [
        aws_security_group.airflow-security.name
    ]

    user_data = file("../../03_script_init_dependencies/dependencies.sh")
    tags = {
        Name = "Airflow"
    }

    lifecycle {
      prevent_destroy = true
    }
}

resource "random_id" "airflow-bucket" {
  byte_length = 8
}

resource "aws_s3_bucket" "airflow-bucket" {
    bucket = "airflow-logs-bucket-${random_id.airflow-bucket.hex}"
    acl = "private"

}


data "aws_secretsmanager_secret" "airflow-ddbb-secrets" {
  name = "airflow-postgres-secrets"
}

resource "aws_iam_role" "airflow-proxy-role" {
    name = "airflow_proxy_role"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

    tags = {
        tag-key = "tag-value"
    }
}


resource "aws_iam_policy" "policy" {
    name        = "test-policy"
    description = "A test policy"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GetSecretValue",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Effect": "Allow",
            "Resource": [
                "${data.aws_secretsmanager_secret.airflow-ddbb-secrets.arn}"
            ]
        },
        {
            "Sid": "DecryptSecretValue",
            "Action": [
                "kms:Decrypt"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:kms:eu-west-1:719633984135:key/ed5f7033-1313-4561-92c5-20097aaefcd1"
            ],
            "Condition": {
                "StringEquals": {
                    "kms:ViaService": "secretsmanager.eu-west-1.amazonaws.com"
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
    role       = aws_iam_role.airflow-proxy-role.name
    policy_arn = aws_iam_policy.policy.arn
}


resource "aws_db_instance" "airflow-ddbb" {
    allocated_storage = 20
    engine = "postgres"
    engine_version = "11.5"
    instance_class = "db.t2.micro"
    name = "airflow_ddbb"
    username = "airflow"
    password = "airflow-pass"
    port = 5432
    publicly_accessible = false
    vpc_security_group_ids = [
        aws_security_group.airflow-security.id
    ]
    skip_final_snapshot = true
}

# TODO
# resolver los ids de las subnets automaticamente
resource "aws_db_proxy" "airflow-proxy" {
    name = "airflow-proxy"
    engine_family = "POSTGRESQL"
    role_arn = aws_iam_role.airflow-proxy-role.arn
    vpc_security_group_ids = [ 
       aws_security_group.airflow-security.id 
    ]
    vpc_subnet_ids = [
        "subnet-8e3844d4",
        "subnet-e62b1880",
        "subnet-d84a4890"
    ]

    auth {
        auth_scheme = "SECRETS"
        iam_auth = "DISABLED"
        secret_arn = data.aws_secretsmanager_secret.airflow-ddbb-secrets.arn
    }
}


resource "aws_db_proxy_default_target_group" "airflow-proxy-target" {
    db_proxy_name = aws_db_proxy.airflow-proxy.name

    connection_pool_config {
        connection_borrow_timeout    = 120
        max_connections_percent      = 100
        max_idle_connections_percent = 50
    }
}

resource "aws_db_proxy_target" "example" {
    db_instance_identifier = aws_db_instance.airflow-ddbb.id
    db_proxy_name          = aws_db_proxy.airflow-proxy.name
    target_group_name      = aws_db_proxy_default_target_group.airflow-proxy-target.name
}
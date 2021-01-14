
# Deploying Airflow in GCP
TODO

# Deploying Airflow in AWS
A Terraform template with all the resources is prepared to make the deployment 
AWS services used:
- EC2 instance
- RDS instance (PostgreSQL)
- RDS proxy
- S3 bucket (Airflow logs)

## Using RDS and RDS Proxy
In the case of AWS the service to work with Postgres is RDS. 

We will use also a proxy to secure and scale the connections between the different Airflow services and the DDBB.

## Using S3 as a log storage
- Configure the `AIRFLOW__LOGGING__REMOTE_LOGGING`
- Configure the `AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER`
- Configure the `AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID`

## Using Traefik as a reverse proxy

These are the steps to configure Airflow to work with Traefik:
- Configure the file `acme.json` and created it before start
- Configure the domain name, for a free approach use `duckdns.org`


# Deploying Airflow in Azure
TODO

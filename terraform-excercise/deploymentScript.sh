#! /bin/sh

echo "Creating Infrastructure on AWS"

echo "Terraform Initialisation"

terraform init

echo "Terraform Apply"

terraform apply


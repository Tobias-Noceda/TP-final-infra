#!/bin/bash
# 1. Format the code
terraform fmt -recursive

# 2. Initialize
terraform init

# 3. Validate
terraform validate

# 4. Plan (Check if everything is green)
terraform plan

# 5. Apply
terraform apply -auto-approve

# 6. Get Credentials to talk to K8s
eval $(terraform output -raw get_credentials_command)

echo "Cluster is ready. Verify with: kubectl get nodes"

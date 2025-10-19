<i>P.S.:

- Make sure you already have the requirements mentioned in the root of this repository (create the key pair, etc).
- Make sure you choose the appropriate AMI image.</i>

## AWS Templates for Basic Infrastructure

<p align="center">
  <img src="../readme-img/logos.png" alt="logos" />
</p>

<hr>

### AWS Basic Infrastructure Diagram:

<p align="center">
  <img src="../readme-img/aws-basic-infra-diagram.png" alt="basic-infrastructure" />
</p>

## Using Terraform

Initialize Terraform<br>
```terraform init```
<img src="../readme-img/terraform-init.png" />

Generate execution plan<br>
```terraform plan```
<img src="../readme-img/terraform-plan.png" />

Creates or updates infrastructure<br>
```terraform apply```
<img src="../readme-img/terraform-apply.png" />

#### <i>Don't forget to destroy your infrastructure at the end to avoid unnecessary costs</i><br>```terraform destroy```
<img src="../readme-img/terraform-destroy.png" />

## Verify that your your instance has started and test your accesses (SSH and Nginx)
You can do this through EC2 Dashboard or running the following AWS cli command:<br>
```aws ec2 describe-instance-status```

Checking via AWS EC2 Dashboard:
<img src="../readme-img/ec2-instance-running.png" />

## SSH and Nginx validation
<i>Confirm your instance's public IP<br>You can validate via console or EC2 Dashboard</i>

```
# Get your public IP

aws ec2 describe-instances --query 'Reservations[].Instances[].PublicIpAddress' --output text
```

```
# If you need to get your private IP

aws ec2 describe-instances --query 'Reservations[].Instances[].PrivateIpAddress' --output text
```
<img src="../readme-img/ip-public-private.png" />

<br>

<i>Clicking on your instance ID</i>

<img src="../readme-img/ec2-instance-id.png" />
<br><br>
SSH and Nginx test
<img src="../readme-img/ssh-and-nginx-test.png" />
<br><br>

```
http://<your-instance-public-ip>
```
<img src="../readme-img/ec2-nginx-http-test.png">

## Using Ansible

<i>At this moment we are using only Ansible to update/upgrade whole system.<br>
We also will send a file to main hosts folder to make sure Ansible is working.</i>

### Easy way

- Get your public IP and change your inventory.ini file (ansible)
<br><br>
<img src="../readme-img/ansible-inventory-public-ip.png" /><br>

- Let's see if your host is visible

```
ansible all -m ping -i ansible/inventory.ini
```
<img src="../readme-img/ansible-host-visibility.png" /><br>

- Update / Upgrade your instance and push a text file to your host, using Ansible

```
ansible-playbook -i ansible/inventory.ini ansible/update-playbook.yml ansible/ansible-test-file.yml
```

<img src="../readme-img/ansible-update-upgrade-push-file.png" />

### "Hard" way
<i>Including the public IPs in the inventory.ini file is not necessary in this case.</i>

- Let's see if your host is visible

```
ansible all -m ping -i $(aws ec2 describe-instances --instance-ids $INSTANCE_IDS --query "Reservations[*].Instances[*].PublicIpAddress" --output text | tr '\n' ',') -e "ansible_ssh_private_key_file=~/.aws/my-ssh-key-votc.pem" -e "ansible_user=ubuntu" -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
```

<img src="../readme-img/pandora-get-public-ip.png" /><br>

- Update / Upgrade your instance and push a text file to your host, using Ansible

```
ansible-playbook ansible/update-playbook.yml ansible/ansible-test-file.yml -i $(aws ec2 describe-instances --instance-ids $INSTANCE_IDS --query "Reservations[*].Instances[*].PublicIpAddress" --output text | tr '\n' ',') -e "ansible_ssh_private_key_file=~/.aws/my-ssh-key-votc.pem" -e "ansible_user=ubuntu" -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
```

<img src="../readme-img/pandora-update-upgrade-push-file.png" />

### Dynamic way

```
None
```

That's it.
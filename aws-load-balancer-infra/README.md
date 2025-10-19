P.S.: Make sure you already have the requirements mentioned in the root of this repository (create the key pair, etc).

<p align="center">
  <img src="../readme-img/logos.png" alt="logos" />
</p>

<hr>

### AWS Load Balancer Infrastructure Diagram:

<p align="center">
  <img src="../readme-img/aws-load-balancer-infra-diagram.png" alt="load-balancer" />
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
<img src="../readme-img/terraform-apply-load-balancer.png" />

#### <i>Don't forget to destroy your infrastructure at the end to avoid unnecessary costs</i><br>```terraform destroy```
<img src="../readme-img/load-balancer-terraform-destroy.png" />

## Verifying Load Balancer Operation

<img src="../readme-img/load-balancer-working.png" />

## Verify that your your instances have started and test your accesses (SSH and Nginx)
You can do this through EC2 Dashboard or running the following AWS cli command:<br>
```aws ec2 describe-instance-status```

Checking via AWS EC2 Dashboard:
<img src="../readme-img/load-balancer-instances.png" />

## SSH and Nginx validation
<i>Confirm your instances public IPs<br>You can validate via console or EC2 Dashboard</i>

```
# Get your public IPs

aws ec2 describe-instances --query 'Reservations[].Instances[].PublicIpAddress' --output text
```

```
# If you need to get your private IPs

aws ec2 describe-instances --query 'Reservations[].Instances[].PrivateIpAddress' --output text
```
<img src="../readme-img/load-balancer-public-private-ip.png" />

<br>

<i>Clicking on your instances IDs</i>

<img src="../readme-img/ec2-instance-id.png" />
<br><br>
SSH and Nginx test
<img src="../readme-img/load-balancer-ssh.png">
<br><br>

```
http://<get-any-instance-public-ip>

# or

<your load balancer url>
e.g.: http://nginx-lb-588464347.us-east-1.elb.amazonaws.com
```
<img src="../readme-img/load-balancer-http-test.png">

## Using Ansible

<i>At this moment we are using only Ansible to update/upgrade whole system.<br>
We also will send a file to main hosts folder to make sure Ansible is working.</i>

### Easy way

- Get your public IPs and change your inventory.ini file (ansible)
<br><br>
<img src="../readme-img/load-balancer-ansible-public-ips.png" /><br>

- Let's see if your hosts are visible

```
ansible all -m ping -i ansible/inventory.ini
```
<img src="../readme-img/load-balancer-ips-visibility.png" /><br>

- Update / Upgrade your instances and push a text file to your hosts, using Ansible

```
ansible-playbook -i ansible/inventory.ini ansible/update-playbook.yml ansible/ansible-test-file.yml
```

<img src="../readme-img/load-balancer-ansible-update-1.png" /><br>

<img src="../readme-img/load-balancer-ansible-update-2.png" /><br>

<img src="../readme-img/load-balancer-ansible-update-3.png" /><br>



### "Hard" way
<i>Including the public IPs in the inventory.ini file is not necessary in this case.</i>

- Let's see if your hosts are visible

```
ansible all -m ping -i $(aws ec2 describe-instances --instance-ids $INSTANCE_IDS --query "Reservations[*].Instances[*].PublicIpAddress" --output text | tr '\n' ',') -e "ansible_ssh_private_key_file=~/.aws/my-ssh-key-votc.pem" -e "ansible_user=ubuntu" -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
```

<img src="../readme-img/load-balancer-pandora-get-public-ip.png" /><br>

- Update / Upgrade your instances and push a text file to your hosts, using Ansible

```
ansible-playbook ansible/update-playbook.yml ansible/ansible-test-file.yml -i $(aws ec2 describe-instances --instance-ids $INSTANCE_IDS --query "Reservations[*].Instances[*].PublicIpAddress" --output text | tr '\n' ',') -e "ansible_ssh_private_key_file=~/.aws/my-ssh-key-votc.pem" -e "ansible_user=ubuntu" -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
```

<img src="../readme-img/load-balancer-pandora-update-upgrade-1.png" /><br>

<img src="../readme-img/load-balancer-pandora-update-upgrade-2.png" />

That's it.
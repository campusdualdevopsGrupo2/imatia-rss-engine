#!/bin/bash

set -x
# Update the system and install necessary dependencies
apt-get update -y
apt-get install -y unzip curl nfs-common git sudo docker.io python3-pip

# Set hostname
hostnamectl set-hostname "i4-rss-engine-demo.campusdual.mkcampus.com"

# Set /etc/rss-engine and /etc/rss-engine-dns-suffix
echo -n "${inumber}" > /etc/rss-engine-name
echo -n "${suffix_name}.campusdual.mkcampus.com" > /etc/rss-engine-dns-suffix

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

# Instalar Docker
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Iniciar Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verificar Docker
sudo docker --version

# Install Docker Compose
sudo apt-get install -y docker-compose


# Ensure the playbook and docker-compose.yml file are available before running playbooks
mkdir -p /home/ubuntu/playbooks
curl -o /home/ubuntu/playbooks/install.yml https://raw.githubusercontent.com/campusdualdevopsGrupo2/imatia-rss-engine/refs/heads/main/ansible/install.yml
curl -o /home/ubuntu/playbooks/install2.yml https://raw.githubusercontent.com/campusdualdevopsGrupo2/imatia-rss-engine/refs/heads/main/ansible/grafana/install2.yml


#Añadir ubuntu a grupo docker y reiniciar servicio docker
sudo usermod -aG docker ubuntu
sudo systemctl restart docker


instance_id=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=I4_instance" --query "Reservations[0].Instances[0].InstanceId" --output text)
# Get IP addresses
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region eu-west-3)

record_name="$(cat /etc/rss-engine-name)$(cat /etc/rss-engine-dns-suffix)"
zone_id=${zone}

# Set Route 53 DNS records for the EC2 instance (Public and Private IPs)
aws route53 change-resource-record-sets --hosted-zone-id $zone_id --change-batch "{
    \"Changes\": [
        {
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"$record_name\",
                \"Type\": \"A\",
                \"TTL\": 60,
                \"ResourceRecords\": [{\"Value\": \"$PUBLIC_IP\"}]
            }
        }
    ]
}"



# Crear un servicio systemd para actualizar el DNS en cada reinicio
sudo tee /usr/local/bin/update-dns.sh > /dev/null <<'EOF'
#!/bin/bash
set -e

instance_id=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=I4_instance" --query "Reservations[0].Instances[0].InstanceId" --output text)

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region eu-west-3)



record_name="i4-rss-engine-demo.campusdual.mkcampus.com"
zone_id=${zone}

aws route53 change-resource-record-sets --hosted-zone-id $zone_id --change-batch "{
    \"Changes\": [
        {
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"$record_name\",
                \"Type\": \"A\",
                \"TTL\": 60,
                \"ResourceRecords\": [{\"Value\": \"$PUBLIC_IP\"}]
            }
        }
    ]
}"
EOF


#Dar permisos al script para ejecutarse
sudo chmod +x /usr/local/bin/update-dns.sh

#Condiguración del servicio de systemd llamando al script
sudo tee /etc/systemd/system/update-dns.service > /dev/null <<EOF
[Unit]
Description=Actualizar registro DNS en Route 53 con la IP privada
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-dns.sh

[Install]
WantedBy=multi-user.target
EOF



# Habilitar el servicio para que se ejecute al iniciar la instancia
sudo systemctl daemon-reload
sudo systemctl enable update-dns.service
sudo systemctl start update-dns.service

# Añadir ubuntu a grupo docker y reiniciar servicio docker
sudo usermod -aG docker ubuntu
sudo systemctl restart docker

# Run the Docker container with Ansible and execute the playbooks
sudo docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/ubuntu:/home/ubuntu \
  --network host \
  --ulimit nofile=65536:65536 \
  --ulimit nproc=65535 \
  --ulimit memlock=-1 \
  --privileged \
  -e ANSIBLE_HOST_KEY_CHECKING=False \
  -e ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no" \
  demisto/ansible-runner:1.0.0.110653 \
  sh -c "ansible-playbook -i 'localhost,' -c local /home/ubuntu/playbooks/install.yml && ansible-playbook -i 'localhost,' -c local /home/ubuntu/playbooks/install2.yml"
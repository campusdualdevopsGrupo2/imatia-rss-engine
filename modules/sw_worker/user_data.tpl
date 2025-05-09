#!/bin/bash

# Actualizar paquetes e instalar dependencias
LOG_FILE="/var/log/mi_script.log"

# Función para agregar logs al archivo
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}
# Actualizar paquetes e instalar dependencias

sudo apt-get update -y
sudo apt-get install -y nfs-common unzip dos2unix curl lsb-release python3-apt git

# Guardar el ID de la instancia y el DNS en archivos
echo "${instance_id}" > /etc/rss-engine-name
#echo "-rss-engine-demo.campusdual.mkcampus.com" > /etc/rss-engine-dns-suffix
echo "${record_name}" > /etc/record_name

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

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

log_message "Instalacion basica terminada"
              # Obtener la IP privada
private_ip=$(hostname -I | awk '{print $1}')
instance_id=$(aws ec2 describe-instances --filters  "Name=private-ip-address,Values=$private_ip" --query "Reservations[0].Instances[0].InstanceId" --output text)
# Get IP addresses
public_ip=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region eu-west-3)




# Leer los archivos para obtener los valores


              # Añadir la IP privada al registro de Route 53 (reemplazar los valores según sea necesario)
zone_id=${zone}  # ID de tu zona de Route 53
record_name=$(cat /etc/record_name)
aws route53 change-resource-record-sets \
                --hosted-zone-id $zone_id \
                --change-batch '{
                  "Changes": [
                    {
                      "Action": "UPSERT",
                      "ResourceRecordSet": {
                        "Name": "'$record_name'",
                        "Type": "A",
                        "TTL": 300,
                        "ResourceRecords": [{"Value": "'$private'"}]
                      }
                    }
                  ]
                }'
log_message "route53 command cli"
              # Crear un servicio systemd para actualizar el DNS en cada reinicio
# Crear un servicio systemd para actualizar el DNS en cada reinicio
# Crear un servicio systemd para actualizar el DNS en cada reinicio
sudo tee /usr/local/bin/update-dns.sh > /dev/null <<'EOF'
#!/bin/bash
set -e
zone_id=${zone}
private_ip=$(hostname -I | awk '{print $1}')
instance_id=$(aws ec2 describe-instances --filters  "Name=private-ip-address,Values=$private_ip" --query "Reservations[0].Instances[0].InstanceId" --output text)
# Get IP addresses
public_ip=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region eu-west-3)
record_name=$(cat /etc/record_name)
echo "IP y record_name: $public_ip $record_name"

json=$(cat <<EOT
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$record_name",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$private_ip"
          }
        ]
      }
    }
  ]
}
EOT
)

echo "JSON generado: $json"
aws route53 change-resource-record-sets --hosted-zone-id $zone_id --change-batch "$json"
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



# Crear un servicio systemd para el contenedor Docker (Para los contenedores)

sudo tee /etc/systemd/system/mydockerapp.service > /dev/null <<'EOF'
[Unit]
Description=Docker Container for my ECR app
After=network.target

[Service]
# Iniciar los contenedores en segundo plano
ExecStart=/usr/bin/docker compose -f /home/ubuntu/docker-compose.yml up -d 
# Detener los contenedores
ExecStop=/usr/bin/docker compose -f /home/ubuntu/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOF

              # Habilitar el servicio para que se ejecute al iniciar la instancia
sudo systemctl daemon-reload
sudo systemctl enable mydockerapp.service
sudo systemctl enable update-dns.service
sudo systemctl start update-dns.service

log_message "Servicio creado"

# Función para esperar la propagación de los cambios DNS

wait_for_dns_resolution() {
  local dns_name=$1
  local port=$2
  local timeout=60  # Tiempo máximo de espera en segundos
  local interval=5  # Intervalo entre verificaciones en segundos
  local elapsed=0

  log_message "Esperando a la resolución correcta de DNS para $dns_name en el puerto $port..."

  # Esperar a que el puerto esté accesible
# Esperar a que el puerto esté accesible
while true; do
    # Resolver el DNS para obtener la IP
    resolved_ip=$(dig +short "$dns_name")
    
    if [ -z "$resolved_ip" ]; then
        log_message "No se pudo resolver el nombre DNS: $dns_name"
        return 1
    fi

    log_message "La IP resuelta para $dns_name es: $resolved_ip"
    
    # Intentar la conexión al puerto con nc
    nc -z -w 3 "$resolved_ip" "$port"
    
    if [ $? -eq 0 ]; then
        log_message "Conexión exitosa al puerto $port en $resolved_ip."
        break  # Salir del bucle si nc es exitoso
    fi

    # Incrementar el tiempo de espera y comprobar si se alcanzó el timeout
    elapsed=$((elapsed + interval))
    if [ $elapsed -ge $timeout ]; then
        log_message "Timeout alcanzado después de $timeout segundos. No se pudo conectar al puerto $port en $resolved_ip."
        return 1
    fi

    log_message "Esperando la conexión al puerto $port en $resolved_ip... (Intento $((elapsed / interval)))"
    sleep $interval
done


  log_message "Conexión exitosa al puerto $port en $resolved_ip."
  return 0
}

# Uso de la función
dns_name="${record_name}"
port=22
wait_for_dns_resolution "$dns_name" "$port"


# Añadir ubuntu a grupo docker y reiniciar servicio docker

sudo usermod -aG docker ubuntu
sudo systemctl restart docker

# Esperar a que Docker esté completamente activo antes de continuar
while ! systemctl is-active --quiet docker; do
  echo "Esperando a que Docker esté activo..."
  sleep 2
done


echo "${sw_server_dns_name}" > /etc/dns_name

log_message "ssh keys"
ssh-keygen -t rsa -b 2048 -f /home/ubuntu/.ssh/id_rsa -N ""
cat /home/ubuntu/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys

curl -o /home/ubuntu/Dockerfile.ansible https://raw.githubusercontent.com/campusdualdevopsGrupo2/imatia-rss-engine/refs/heads/main/dockerfiles/Dockerfile.ansible
log_message "start build ansible"
sudo docker build -t ansible-local -f /home/ubuntu/Dockerfile.ansible  /home/ubuntu

mkdir /home/ubuntu/play
hosts_file="/home/ubuntu/play/hosts.ini"
# Generar el archivo hosts.ini
echo "[webserver]" > $hosts_file
echo "$private_ip ansible_user=ubuntu" >> $hosts_file

log_message "curl files from repo"

curl -o /home/ubuntu/Dockerfile https://raw.githubusercontent.com/campusdualdevopsGrupo2/imatia-rss-engine/refs/heads/main/dockerfiles/Dockerfile.worker.alpine
curl -o /home/ubuntu/play/docker-compose.yml.j2 https://raw.githubusercontent.com/campusdualdevopsGrupo2/imatia-rss-engine/refs/heads/main/ansible/SW_Worker/docker-compose-workers.yml.j2
curl -o /home/ubuntu/play/install2.yml  https://raw.githubusercontent.com/campusdualdevopsGrupo2/imatia-rss-engine/refs/heads/main/ansible/SW_Worker/set_workers.yml 

log_message "start playbooks"
echo ${secret_name} > /etc/secret_name

sudo docker run --rm -v /home/ubuntu/play:/ansible/playbooks -v /home/ubuntu/.ssh:/root/.ssh \
--network host -e ANSIBLE_HOST_KEY_CHECKING=False -e ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no" \
--privileged --name ansible-playbook-container \
--entrypoint "/bin/bash" ansible-local  -c "ansible-playbook -i /ansible/playbooks/hosts.ini /ansible/playbooks/install2.yml -e DNS_SERVER=$(cat /etc/dns_name) -e ENVIRON=${environment} -e SECRET_NAME=$(cat /etc/secret_name) "

sleep 150
log_message "end"


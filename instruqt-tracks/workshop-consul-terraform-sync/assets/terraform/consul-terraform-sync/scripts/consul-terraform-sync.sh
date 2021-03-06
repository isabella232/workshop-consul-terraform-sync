#!/bin/bash

#Utils
sudo apt-get install unzip

#Download Consul
curl --silent --remote-name https://releases.hashicorp.com/consul/1.8.0+ent/consul_1.8.0+ent_linux_amd64.zip
unzip consul_1.8.0+ent_linux_amd64.zip

#Download Consul Terraform Sync
curl --silent --remote-name https://releases.hashicorp.com/consul-terraform-sync/0.1.0-techpreview1/consul-terraform-sync_0.1.0-techpreview1_linux_amd64.zip
unzip consul-terraform-sync_0.1.0-techpreview1_linux_amd64.zip

#Install Consul
sudo chown root:root consul
sudo mv consul /usr/local/bin/
consul -autocomplete-install
complete -C /usr/local/bin/consul consul

#Install consul-terraform-sync
sudo chown root:root consul-terraform-sync
sudo mv consul-terraform-sync /usr/local/bin/

#Create Consul Terraorm Sync User
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo mkdir --parents /opt/consul-terraform-sync.d
sudo chown --recursive consul:consul /opt/consul 
sudo chown --recursive consul:consul /opt/consul-terraform-sync.d

#Create Systemd Config for Consul
sudo cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent  -bind '{{ GetInterfaceIP "eth0" }}' -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#Create Systemd Config for Consul Terraform Sync
sudo cat << EOF > /etc/systemd/system/consul-terraform-sync.service
[Unit]
Description="HashiCorp Consul Terraform Sync - A Network Infra Automation solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul-terraform-sync -config-file=/etc/consul-terraform-sync.d/consul-terraform-sync.hcl
KillMode=process
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#Create config dir
sudo mkdir --parents /etc/consul.d
sudo chown --recursive consul:consul /etc/consul.d

sudo mkdir --parents /etc/consul-terraform-sync.d
sudo chown --recursive consul:consul /etc/consul-terraform-sync.d

cat << EOF > /etc/consul.d/ca.pem
${ca_cert}
EOF

cat << EOF > /etc/consul.d/hcs.json
${consulconfig}
EOF

cat << EOF > /etc/consul.d/zz_override.hcl
data_dir = "/opt/consul"
ui = true
ca_file = "/etc/consul.d/ca.pem"
acl = {
  tokens = {
    default = "${consul_token}"
  }
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
}
EOF

cat << EOF > /etc/consul-terraform-sync.d/consul-terraform-sync.hcl
log_level = "info"
consul {
  address = "localhost:8500"
  token = "${consul_token}"
}
buffer_period {
  min = "5s"
  max = "20s"
}
task {
  name = "AS3-Fake-Service-Website"
  description = "automate F5 BIG-IP Pool Members Ops for Fake Service Website"
  source = "f5devcentral/app-consul-sync-nia/bigip"
  providers = ["bigip"]
  services = ["web", "app"]
}
driver "terraform" {
  log = true
  path = "/opt/consul-terraform-sync.d/"
  working_dir = "/opt/consul-terraform-sync.d/"
  required_providers {
    bigip = {
      source = "F5Networks/bigip"
    }
  }
}
provider "bigip" {
  address = "${bigip_mgmt_addr}:8443"
  username = "${bigip_admin_user}"
  password = "${bigip_admin_passwd}"
}
EOF

#Enable the service
sudo systemctl enable consul
sudo service consul start
sudo service consul status

#Enable the service
sudo systemctl enable consul-terraform-sync
sudo service consul-terraform-sync start
sudo service consul-terraform-sync status



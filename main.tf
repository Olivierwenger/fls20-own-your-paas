variable "hcloud_token" {}

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.25.2"
    }
  }
}

locals {
  vhost = "artdaimer.wngr.ch"
}

provider "hcloud" {
  token = var.hcloud_token
}

# # ssh key
resource "hcloud_ssh_key" "default" {
  name = "main ssh key"
  public_key = "${file("~/.ssh/id_ed25519.pub")}"
}

resource "hcloud_network" "network" {
  name     = "network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "network-subnet" {
  type         = "cloud"
  network_id   = hcloud_network.network.id
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_floating_ip_assignment" "main" {
  floating_ip_id = hcloud_floating_ip.floating_ip_1.id
  server_id = hcloud_server.dokku_server.id
}


resource "hcloud_floating_ip" "floating_ip_1" {
  type = "ipv4"
  home_location = "nbg1"
  name = "floating-ip-v2"
}


resource "hcloud_server" "dokku_server" {
  name = "dokku-server"
  server_type = "cx11"
  image = "ubuntu-20.04"
  location = "nbg1"
  ssh_keys = [hcloud_ssh_key.default.id]
  
  user_data    = <<EOF
#cloud-config
package_upgrade: true
runcmd:
  - wget -nv -O - https://github.com/olivierwenger.keys     | grep ed25519 | sed '1q;d' >> /home/ubuntu/.ssh/authorized_keys
  - echo "dokku dokku/web_config boolean false"              | debconf-set-selections
  - echo "dokku dokku/vhost_enable boolean true"             | debconf-set-selections
  - echo "dokku dokku/hostname string ${local.vhost}"        | debconf-set-selections
  - echo "dokku dokku/skip_key_file boolean true"            | debconf-set-selections
  - echo "dokku dokku/nginx_enable boolean true"             | debconf-set-selections
  - echo "dokku dokku/key_file string /root/.ssh/id_rsa.pub" | debconf-set-selections
  - [ apt-get, update, -qq ]
  - [ apt-get, -qq, -y, --no-install-recommends, install, apt-transport-https ]
  - wget -nv -O - https://get.docker.com/ | sh
  - [ gpasswd, -a, ubuntu, docker ]
  - wget -nv -O - https://packagecloud.io/dokku/dokku/gpgkey | apt-key add -
  - echo "deb https://packagecloud.io/dokku/dokku/ubuntu/ focal main" | sudo tee /etc/apt/sources.list.d/dokku.list
  - [ apt-get, update,-qq ]
  - [ apt-get, -qq, -y, install, dokku ]
  - [ dokku, plugin:install-dependencies, --core ]
  - [ dokku, "domains:set-global", ${local.vhost} ]
  - wget -nv -O - https://github.com/olivierwenger.keys     | grep ed25519 | sed '1q;d' | dokku ssh-keys:add olivier
  - [ dokku, plugin:install, https://github.com/dokku/dokku-letsencrypt.git ]
EOF

  network {
    network_id = hcloud_network.network.id
    ip         = "10.0.1.5"
    alias_ips  = [
      "10.0.1.6",
      "10.0.1.7"
    ]
  }

  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
}


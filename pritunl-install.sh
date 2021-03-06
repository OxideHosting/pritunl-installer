preflight(){
  if [ -r /etc/os-release ]; then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
    dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
    dist_version=$(cut -d "." -f1 <<< ${dist_version})
  else
    exit 1
  fi
  if [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ] || [ "$lsb_dist" = "fedora" ]; then
    if ! [ "$lsb_dist" = "fedora" ]; then
      lsb_dist="centos"
    fi
    dist_version="8"
  fi
}

install(){
  if [ "$lsb_dist" = "ubuntu" ] || [ "$lsb_dist" = "debian" ]; then
    apt-get update
    apt-get install -y sudo gnupg dnsutils
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    if [ "$lsb_dist" = "ubuntu" ]; then
      echo "deb http://repo.mongodb.org/apt/ubuntu $codename/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    else
      echo "deb http://repo.mongodb.org/apt/debian $codename/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    fi
    echo "deb https://repo.pritunl.com/stable/apt $codename main" | sudo -E tee /etc/apt/sources.list.d/pritunl.list >/dev/null 2>&1
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 7568D9BB55FF9E5287D586017AE645C0CF8E292A
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    sudo systemctl stop ufw.service nginx.service httpd.service apache.service
    sudo systemctl disable ufw.service nginx.service httpd.service apache.service
    sudo apt-get --assume-yes install apt-transport-https
sudo sh -c "echo 'deb http://deb.debian.org/debian buster-backports main contrib non-free' > /etc/apt/sources.list.d/buster-backports.list"
    sudo apt-get update -y
    sudo apt-get install -y mongodb-org pritunl wireguard
  elif [ "$lsb_dist" = "centos" ] || [ "$lsb_dist" = "fedora" ]; then
    yum update -y
    yum install -y sudo
echo "[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$dist_version/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc" | sudo -E tee /etc/yum.repos.d/mongodb-org-4.4.repo >/dev/null 2>&1
echo '[pritunl]
name=Pritunl Repository
baseurl=https://repo.pritunl.com/stable/yum/centos/'"$dist_version"'/
gpgcheck=1
enabled=1' | sudo -E tee /etc/yum.repos.d/pritunl.repo >/dev/null 2>&1
    if [ "$lsb_dist" = "centos" ]; then
      sudo rpm -Uvh "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$dist_version.noarch.rpm"
    fi
    gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 7568D9BB55FF9E5287D586017AE645C0CF8E292A
    gpg --armor --export 7568D9BB55FF9E5287D586017AE645C0CF8E292A > key.tmp; sudo rpm --import key.tmp; rm -f key.tmp
    sudo yum -y remove iptables-services
    sudo systemctl stop ufw.service nginx.service httpd.service apache.service
    sudo systemctl disable ufw.service nginx.service httpd.service apache.service
    if [ "$lsb_dist" = "centos" ]; then
      sudo yum install -y elrepo-release epel-release
      if [ "$dist_version" = "7" ]; then
          sudo yum install -y yum-plugin-elrepo
      fi
      sudo yum install -y mongodb-org pritunl kmod-wireguard wireguard-tools
    else
      sudo yum install -y mongodb-org pritunl wireguard-tools
    fi
  fi
  systemctl enable --now pritunl mongod
  server_ip=$(curl -s http://checkip.amazonaws.com)
  domain_record=$(dig +short "${HOSTNAME}")
  if [ "${server_ip}" = "${domain_record}" ]; then
    echo "You can access the Pritunl panel using the following link - https://$HOSTNAME"
  else
    echo "You can access the Pritunl panel using the following link - https://$server_ip"
  fi
}

preflight
install

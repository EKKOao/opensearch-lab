Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  (1..3).each do |i|
    config.vm.define "os#{i}" do |node|
      node.vm.hostname = "os#{i}"
      node.vm.network "private_network", ip: "192.168.56.#{10+i}"

      node.vm.disk :disk, size: "15GB", name: "extra_storage"

      node.vm.provider "virtualbox" do |vb|
        vb.memory = "4096"
        vb.cpus = 2
      end      

      node.vm.provision "packages", type: "shell", path: "01-packages.sh"
      node.vm.provision "user", type: "shell", path: "02-user.sh"
      node.vm.provision "memlock", type: "shell", path: "03-config.sh"
      node.vm.provision "file_structure", type: "shell", path: "04-storage.sh"
      node.vm.provision "swap", type: "shell", path: "05-swap.sh"
      node.vm.provision "nfs", type: "shell", path: "06-nfs.sh"
      node.vm.provision "network", type: "shell", path: "07-network.sh"
      node.vm.provision "install", type: "shell", path: "08-install.sh"
      node.vm.provision "certs", type: "shell", path: "09-certs.sh"
      node.vm.provision "service", type: "shell", path: "10-service.sh"
      node.vm.provision "es_config", type: "shell", path: "11-configure-cluster.sh"
      node.vm.provision "sudoers", type: "shell", path: "12-sudoers.sh"

    end
  end
end

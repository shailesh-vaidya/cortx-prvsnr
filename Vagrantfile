# vi: set ft=ruby :

# Vagrantfile configuration fefernece:
#   https://www.vagrantup.com/docs/hyperv/configuration.html

# read vm configuration(s) from JSON file
salt_nodes = [
  {
    "name" => "ees-node1",
    "cpus" => 2,
    "memory" => 4096,
    "mgmt0" => "172.16.10.101",
    "data0" => "172.19.10.101"
  },
  {
    "name"=> "ees-node2",
    "cpus"=> 2,
    "memory"=> 4096,
    "mgmt0" => "172.16.10.102",
    "data0" => "172.19.10.102"
  },
  {
    "name"=> "s3client",
    "cpus"=> 2,
    "memory"=> 2048,
    "mgmt0" => "172.16.10.103",
    "data0" => "172.19.10.103"
  }
]

# Disk configuration details
disks_dir = File.join(Dir.pwd, ".vdisks")
disk_count = 2
disk_size = 1024         # in MB

Vagrant.configure("2") do |config|

  salt_nodes.each do |node|
    config.vm.define node['name'] do |node_config|
      # Configure salt nodes
      node_config.vm.box_url = "http://ci-storage.mero.colo.seagate.com/prvsnr/vendor/centos/vagrant.boxes/centos_7.5.1804.box"
      node_config.vm.box_download_insecure = true
      node_config.vm.box = "centos_7.5.1804"
      node_config.vm.box_check_update = false
      node_config.vm.boot_timeout = 600
      node_config.vm.hostname = node['name']

      node_config.vm.provider :virtualbox do |vb, override|
        # Headless
        vb.gui = false

        # name
        vb.name = node['name']

        # Virtual h/w specs
        vb.memory = node['memory']
        vb.cpus = node['cpus']

        # Use differencing disk instead of cloning entire VDI
        vb.linked_clone = false

        ## Network configuration
        override.vm.network :private_network, ip: node['mgmt0'], virtualbox__intnet: "mgmt0"
        override.vm.network :private_network, ip: node['data0'], virtualbox__intnet: "data0"

        # Disable USB
        vb.customize ["modifyvm", :id, "--usb", "off"]
        vb.customize ["modifyvm", :id, "--usbehci", "off"]

        unless 's3client' == node['name']
          # Check if machine already provisioned
          if not File.exist?(File.join(Dir.pwd, "/.vagrant/machines/default/virtualbox/id"))
            # VDisk configuration start
            if not Dir.exist?(disks_dir)
              Dir.mkdir(disks_dir)
            end

            # SAS Controller - 1
            vb.customize [ 'storagectl',
              :id,
              '--name', "#{node['name']}_vdisk_vol_1",
              '--add', 'sas',
              '--controller', 'LSILogicSAS',
              '--portcount', 2,
              '--hostiocache', 'off',
              '--bootable', 'off'
            ]

            (1..disk_count).each do |disk_number|
              disk_file = File.expand_path(disks_dir).to_s + "/#{node['name']}_disk_#{disk_number}.vdi"

              # Note: Create a hard disk image: vboxmanage createmedium --filename $PWD/disk_<vm_name>_<disk_count>.vdi --size <disk_size> --format VDI
              if not File.exist?(disk_file)
                vb.customize ['createmedium',
                  'disk',
                  '--filename', disk_file,
                  '--size', disk_size,
                  '--format', 'VDI',
                  '--variant', 'Standard'
                ]
              end

              # Attach hard disk
              # see https://www.virtualbox.org/manual/ch08.html#vboxmanage-storageattach
              vb.customize [
                'storageattach',
                :id,
                '--storagectl', "#{node['name']}_vdisk_vol_1",
                '--port', disk_number - 1,
                '--device', 0,
                '--type', 'hdd',
                '--medium', disk_file,
                '--mtype', 'normal'
              ]
            end       # Disk creation loop
            # VDisk configuration end
          end         # Provisioned machine check
        end           # End of Unless
      end             # Virtualbox provisioner

      # Folder synchonization
      node_config.vm.synced_folder ".", "/opt/seagate/ees-prvsnr",
      type: "rsync",
      rsync__exclude: [".git", ".gitignore", ".vagrant", ".vdisks", "Vagrantfile"],
      rsync__args: ["--archive", "--delete", "-z", "--copy-links"],
      rsync__verbose: false

      node_config.vm.provision "shell", inline: <<-SHELL
        sudo yum remove epel-release -y

        [[ -f /etc/yum.repos.d/epel.repo.rpmsave ]] && sudo rm -rf /etc/yum.repos.d/epel.repo.*
        [[ -f /etc/yum.repos.d/CentOS-Base.repo ]] && sudo rm -rf /etc/yum.repos.d/*.repo
        sudo cp -R /opt/seagate/ees-prvsnr/files/etc/yum.repos.d /etc

        sudo ifdown enp0s8
        sudo ifdown enp0s9
        sudo ifdown data0
        sudo ifdown mgmt0

        # ToDo
        sudo cp -R /opt/seagate/ees-prvsnr/files/etc/modprobe.d/bonding.conf /etc/modprobe.d/bonding.conf
        echo IPADDR=#{node["mgmt0"]}
        echo IPADDR=#{node["data0"]}
        sudo cp /opt/seagate/ees-prvsnr/files/etc/sysconfig/network-scripts/ifcfg-* /etc/sysconfig/network-scripts/
        # sudo cp /opt/seagate/ees-prvsnr/files/etc/sysconfig/network-scripts/ifcfg-mgmt0 /etc/sysconfig/network-scripts/
        # sudo cp /opt/seagate/ees-prvsnr/files/etc/sysconfig/network-scripts/ifcfg-data0 /etc/sysconfig/network-scripts/
        sudo sed -i 's/IPADDR=/IPADDR=#{node["mgmt0"]}/g' /etc/sysconfig/network-scripts/ifcfg-mgmt0
        sudo sed -i 's/IPADDR=/IPADDR=#{node["data0"]}/g' /etc/sysconfig/network-scripts/ifcfg-data0

        sudo ifup data0
        sudo ifup mgmt0
        #sudo systemctl restart network.service

        sudo cp -R /opt/seagate/ees-prvsnr/files/etc/hosts /etc/hosts

        sudo mkdir -p /root/.ssh
        sudo chmod 755 /root/.ssh
        sudo cp -r /opt/seagate/ees-prvsnr/files/.ssh /root
        sudo cat /root/.ssh/id_rsa.pub>>/root/.ssh/authorized_keys
        sudo chmod 644 /root/.ssh/*
        sudo chmod 600 /root/.ssh/id_rsa

        sudo yum install -y salt-minion

        sudo systemctl stop salt-minion
        sudo systemctl disable salt-minion
        sudo cp /opt/seagate/ees-prvsnr/files/etc/salt/minion /etc/salt/minion
      SHELL

      unless 's3client' == node['name']
        node_config.vm.provision :salt do |salt|
          # Master/Minion specific configs.
          salt.masterless = true
          salt.minion_config = './files/etc/salt/minion'

          # Generic configs
          salt.install_type = 'stable'
          salt.run_highstate = true
          salt.colorize = true
          salt.log_level = 'warning'
        end     # End of Salt Provisioning
      end       # End of Unless
    end
  end
end

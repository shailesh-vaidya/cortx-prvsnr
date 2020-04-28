cluster:
  cluster_ip:                         # Cluster IP for HAProxy
  pvt_data_nw_addr: 192.168.0.0
  mgmt_vip:                           # Management VIP for CSM
  search_domains:                     # Do not update
  dns_servers:                        # Do not update
  type: single                           # single/ees/ecs
  node_list:
    - eosnode-1
  eosnode-1:
    hostname: eosnode-1
    is_primary: true
    bmc:
      ip: 
      user: ADMIN
      secret: 'adminBMC!'
    network:
      mgmt_nw:                        # Management network interfaces
        iface:
          - eth0
        ipaddr:                       # DHCP is assumed if left blank
        netmask: 255.255.0.0
        gateway:                   # Gateway IP of Management Network. Not requried for DHCP.
      data_nw:                        # Data network interfaces
        iface:
          - eth2                # Public Data
          - eth1                # Private Data (direct connect)
        ipaddr:                       # DHCP is assumed if left blank
        netmask: 255.255.0.0
        gateway:                   # Gateway IP of Public Data Network. Not requried for DHCP.
        pvt_ip_addr:               # Fixed IP of Private Data Network 
        roaming_ip:                # Applies to private data network                                      
    storage:
      metadata_device:                # Device for /var/mero and possibly SWAP
        - /dev/sdb                    # Auto-populated by components.system.storage.multipath
      data_devices:                   # Data device/LUN from storage enclosure
        - /dev/sdc

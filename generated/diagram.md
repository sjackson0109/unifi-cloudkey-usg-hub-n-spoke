```mermaid
graph LR
    hub -->|VPN| uk_lon_01
    uk_lon_02 -->|VPN| hub
    hub -->|VPN| fr_par_01
    de_ber_01 -->|VPN| hub
    hub -->|VPN| de_ber_02
    de_mun_01 -->|VPN| hub
    hub -->|VPN| ch_zur_01
```


:::mermaid
flowchart LR

    subgraph HUB["HUB"]
        hub_wan["wan1.hub.company.com"]
        subgraph A["FIREWALL"]
            remote_site["HUB-FW-01"]
        end
    end

    subgraph SPOKE["SPOKE"]
        subgraph B["FIREWALL"]
            local_site["local_site"]
        end
        remote_wan["DHCP"]
    end

    remote_site === hub_wan
    remote_wan === local_site

    hub_wan -.- vpn.tun0 -.- remote_wan
    hub_wan -.- vpn.tun1 -.- remote_wan
    
:::
# T-SHOOT

## Flow VPN Client to Firewall

```bash
VPN Client (192.168.5.xxx)                       # IP của VPN client khi kết nối thành công
        ↓
[Tunnel as0t2]                                   # ip route show sẽ thấy
        ↓
🔐 OpenVPN AS (decrypt)
        ↓
🧠 Access Control (OpenVPN policy engine)       # tìm trong Access Control
        ↓
📡 Linux Kernel Routing                         # sudo iptables -t nat -L -n -v
        ↓
🔥 iptables (NAT POSTROUTING nếu có)
        ↓
ens33 (192.168.131.xxx)                         # IP của máy ubuntu
        ↓
Firewall

```

## NAT
```bash
# show nat
sudo iptables -t nat -L -n -v

# backup
sudo iptables-save | sudo tee /root/iptables-backup-nat.txt > /dev/null

# hoặc
sudo sh -c "iptables-save > /root/iptables-backup-nat.txt"

# restore
sudo sh -c "iptables-restore < /root/iptables-backup-nat.txt"

# xóa 
sudo iptables -t nat -D POSTROUTING -s 192.168.0.0/16 -o ens33 -j MASQUERADE

# refine không NAT mà chuyển thẳng ra firewall
iptables -t nat -I POSTROUTING 1 -s 192.168.5.0/24 -o ens33 -j RETURN

# thêm
iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -o ens33 -j MASQUERADE

# Cài gói
sudo apt install iptables-persistent -y

# Lưu cấu hình vì xóa nó chỉ thực hiện trên RAM nên cần phải lưu (tương tự running config trong cisco)
sudo netfilter-persistent save

```


## DEBUG
```bash
sudo tcpdump -i any port 1194


sudo tcpdump -i any dst 192.168.99.11
sudo tcpdump -i any src 192.168.5.197 and dst 1.1.1.1
sudo tcpdump -i any host 192.168.5.131
sudo tcpdump -i ens33 port 443
sudo tcpdump -i ens33 src 192.168.5.146 -n
sudo tcpdump -i ens33 -n 'not port 22' -c 20

```

## FIREWALL

```bash
# Trạng thái firewall
sudo ufw status verbose

# Tắc firewall nếu active
sudo ufw disable
sudo ufw reload
sudo systemctl restart openvpnas

# List các port OpenVPN đang lắng nghe
sudo netstat -tulpn | grep openvpn

# Hoặc bổ sung thêm lệnh
sudo ufw allow 914:917/tcp

# Xem thông tin nat đã cấu hình
sudo nano /etc/ufw/before.rules
```

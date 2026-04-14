# 1. Chuẩn bị máy cấu hình như dưới và cài Ubuntu bao gồm SSH
- vCPU: 2
- vRam: 4 GB
- vHDD: 30 Gb
- Card mạng: Bridged
# 2. Cài OpenVPN-Server Sử dụng lệnh
```bash
curl -s https://raw.githubusercontent.com/khanhvc-doc/OpenVPN-Server/master/install.sh | sudo bash
```

# 3. Active/Patch để không giới hạng kết nối
```bash
curl -s https://raw.githubusercontent.com/khanhvc-doc/OpenVPN-Server/master/patch.sh | sudo bash
```
> Ps: Nhập mật khẩu vào để tiếp tục

# 4. Fix - Firewall (Một số trường hợp bị drop traffic thì dùng bước này)
```bash
curl -s https://raw.githubusercontent.com/khanhvc-doc/OpenVPN-Server/master/fix-firewall.sh | sudo bash
```

`Noted:` 
- 1. patch hoạt động với ubuntu 24.04.4 và py3.12.egg - python3.12

- 2. Khi thực hiện kết nối VPN về có khi bị lỗi hãy tắt firewall của ubuntu đi
```bash
sudo ufw disable
sudo ufw reload
sudo systemctl restart openvpnas
```

# Nếu không cài có thể import từ file OVA
https://drive.google.com/file/d/1SifrYMmefQm_ZmFzhYnuUHkbKujpCi5R/view?usp=sharing

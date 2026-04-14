
# Một số lệnh hay dùng:
## Đặt mật khẩu root: 
```bash
sudo passwd root
# Nhập mật khẩu mới 2 lần
```
## Gán quyền cho root login bằng SSH
```bash
# mở file config
sudo nano /etc/ssh/sshd_config
# tìm dòng "#PermitRootLogin prohibit-password" bỏ dấu # đầu tiên và sửa thành PermitRootLogin yes
# Lưu file: Nhấn Ctrl + O rồi Enter. -> Nhấn Ctrl + X để thoát

# khởi động lại dịch vụ
sudo systemctl restart ssh
```
## Switch đến user root
```bash
sudo -i
# nhập mật khẩu user hiện tại
```
## Switch từ user root sang user khác (sadmin)
```bash
sudo su sadmin
```

## Xem thông tin cấu hình IP address trong file YAML
```bash
ls /etc/netplan/
# sẽ thấy file .YAML, ví dụ: file có tên 50-cloud-init.yaml
```
    - Nếu muốn chỉnh nội dung ip cần đặt. ví dụ dưới
```bash
sudo nano /etc/netplan/50-cloud-init.yaml
```
    - Soạn nội dung file như dưới
```bash
# Nội dung file .yaml đặt ip tĩnh
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      dhcp4: false
      addresses:
        - 192.168.0.201/22
      routes:
        - to: default
          via: 192.168.0.7
      nameservers:
        addresses:
          - 192.168.99.11
          - 192.168.99.10

# Lưu file: Nhấn Ctrl + O rồi Enter. -> Nhấn Ctrl + X để thoát     
```
    - Test cấu hình (tác dụng 120 giây, nó sẽ tự động quay lại cấu hình cũ)

```bash
sudo netplan try
```

    - Áp dụng chính thức
```bash
sudo netplan apply
```

    - Kiểm tra ip

```bash
ip a
```
## Các lệnh dùng sau khi fix-firewall.sh

```bash
cat /etc/sysctl.d/99-openvpn.conf
```
```bash
grep FORWARD /etc/default/ufw
```
```bash
sudo head -20 /etc/ufw/before.rules
```
```bash
sudo ufw status verbose
```
```bash
sysctl net.ipv4.ip_forward
```
```bash
ip a
```


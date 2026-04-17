# TRIỂN KHAI VPN CLIENT-TO-SITE
**VPN Client-to-Site** là giải pháp cho phép người dùng từ xa kết nối an toàn vào mạng nội bộ công ty thông qua phần mềm VPN trên máy cá nhân và đường truyền Internet.

## 1. Khi nào dùng giải pháp này
Sử dụng khi nhân viên cần làm việc từ xa (Remote work), công tác hoặc truy cập tài nguyên nội bộ (File server, ERP) một cách bảo mật qua môi trường Internet công cộng.

## 2. Vị trí đặt VPN Server
- **Tại Firewall (DMZ Zone - `KHUYẾN NGHỊ`):** 
    - Tạo lớp bảo vệ trung gian giữa Internet và mạng nội bộ.

    - Firewall kiểm soát chặt chẽ luồng dữ liệu, giới hạn quyền truy cập vào các VLAN cần thiết.

    - Tách biệt lưu lượng người dùng bên ngoài và tài nguyên hệ thống, giảm thiểu rủi ro lan truyền mã độc

- **Tại Core Layer 3 Switch (Server Zone - `Không` khuyến nghị):**
    - Lưu lượng Internet đi trực tiếp vào "trái tim" của hệ thống mạng.

    - Thiếu các tính năng bảo mật chuyên sâu (DPI, IPS) của Firewall chuyên dụng.

    - Chiếm dụng tài nguyên xử lý của Core Switch, ảnh hưởng đến hiệu năng định tuyến nội bộ.

## 3. Sơ đồ tổng quan
![alt text](<VPN_Client-to-Site with Client-to-Site VPN Access.png>)

## 4. Lời khuyên thực thi
1. **Cấu hình NAT trên Firewall:**

    - `UDP 1194`: Port chính để truyền tải dữ liệu VPN (Data Channel), ưu tiên UDP để có tốc độ và độ trễ thấp nhất.

    - `TCP 943`: Port dành cho giao diện web quản trị (Admin UI) và Client Web Server của OpenVPN Access Server.

    - Thực hiện NAT các port này từ địa chỉ IP WAN vào đúng IP nội bộ của OpenVPN Server trong vùng DMZ.

2. **Thiết lập Chính sách Bảo mật (Firewall Policy):**

    - Tạo Rule kiểm soát luồng dữ liệu theo hướng: VPN_Zone ➔ Core_Layer_VLANs.

    - Nguyên tắc đặc quyền tối thiểu: Chỉ mở các dịch vụ cần thiết (ví dụ: RDP - 3389, HTTP/HTTPS, File Share - 445...) thay vì cho phép All Traffic để hạn chế rủi ro nếu một tài khoản VPN bị chiếm quyền.

3. **Cấu hình Định tuyến (Static Route):**

    - Trên Core Switch, phải thêm một bản ghi Static Route trỏ dải IP cấp cho VPN Clients (VPN Subnet) về phía IP của Firewall hoặc OpenVPN Server.

    - Điều này đảm bảo gói tin có thể đi ngược lại từ Server về phía người dùng từ xa (thông suốt hai chiều).

4. **Kiểm tra tính sẵn sàng:**

    - Đảm bảo các dịch vụ trong `Server Zone` đã chấp nhận kết nối từ dải IP của VPN.

    - Kiểm tra DNS để đảm bảo người dùng VPN có thể phân giải được tên miền nội bộ (Local Domain).


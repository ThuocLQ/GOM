# Delivery Copy (GOM)

Công cụ portable trên Windows để gom file bàn giao từ file/thư mục hoặc so sánh hai nhánh Git. Không cần cài đặt, EXE, .NET SDK hay build source.

## Có gì trong app?

- **Hỗ trợ chọn Profile bàn giao riêng biệt**:
  - **BVSC (Chứng khoán Bảo Việt)**: Tự động tổ chức cấu trúc thư mục chuẩn `2.HOST\upgrade\sql\2.HOST\...`, giữ nguyên `5.Reports` và `9.FileImport`, tự động sinh `2.HOST\upgrade\cmd\runUpdate.bat`, `setVariable.bat`, `2.HOST\upgrade\sql\install.sql`, thư mục `log`, `runscript.txt` với đường dẫn SQL tuyệt đối từ repo local, cùng `Huong_dan_cap_nhat.txt` và `Huong dan runall.sql` từ tài nguyên tích hợp trong app.
  - **Other**: Giữ nguyên cây thư mục repository (`1.BDSHOST`, `2.HOST`, `3.Service`...), tự động sinh `runscript.txt` tại thư mục bàn giao. Các lệnh script dùng đường dẫn tuyệt đối của file SQL trong repo local; không sinh `runscript.sql` hoặc `delivery_manifest`.
- **Tự động Checkout & Pull code mới nhất về local**:
  - Tự động checkout sang branch so sánh và pull commit mới nhất từ remote về local disk trước khi so sánh diff. Đảm bảo toàn bộ file được copy vào gói bàn giao đều là mã nguồn mới nhất trên máy.
- **Sắp xếp SQL thông minh (FlexDB Order)**:
  - Một chạm tự động sắp xếp toàn bộ script SQL theo thứ tự phụ thuộc chuẩn của FlexDB: `ChangeScripts` → `Views` → `Triggers` → `Procedures` → `Functions` → `Packages` → `Parameters` (ALLCODE, APPRVRQD, DEFERROR, SYSVAR, ...).
- **Rà soát danh sách trực quan**: include/exclude, tìm kiếm, lọc theo loại, tính tổng dung lượng và số lượng file SQL.
- **Chế độ sáng/tối**: đổi giao diện bằng nút **Dark mode** trên thanh đầu trang; lựa chọn được lưu tại `%LOCALAPPDATA%\GOM\theme.json` và tự áp dụng ở lần mở tiếp theo.
- **Đa ngôn ngữ**: giao diện mặc định bằng **English**, có thể chuyển sang **Arabic**; lựa chọn được lưu tại `%LOCALAPPDATA%\GOM\language.json`. Khi chọn tiếng Ả Rập, giao diện chuyển sang bố cục phải-sang-trái (RTL).
- **Copy an toàn**: Giữ nguyên cấu trúc thư mục, xử lý file trùng (Skip/Overwrite/Rename), đối soát SHA-256 sau khi copy.
- Không xuất file `delivery_manifest`.

## Cấu trúc gói bàn giao

### 1. Kiểu BVSC
```
<Thư_mục_đích>/
├── 2.HOST/
│   └── upgrade/
│       ├── cmd/
│       │   ├── runUpdate.bat       (Tập lệnh thực thi SQL*Plus tự động)
│       │   └── setVariable.bat     (Cấu hình HOST_USER, HOST_PASSW_USER, FLEX_TNSNAMES)
│       ├── log/                    (Thư mục chứa install.log)
│       ├── sql/
│       │   ├── install.sql         (Tập lệnh SQL tổng gọi @@2.HOST/...)
│       │   └── 2.HOST/
│       │       ├── 0.ChangeScripts/
│       │       ├── 1.View/
│       │       ├── 2.Trigger/
│       │       ├── 3.Procedure/
│       │       ├── 4.Function/
│       │       ├── 5.Package/
│       │       └── 7.Parameters/
│       └── runscript.txt
├── 5.Reports/                      (File báo cáo .rpt nếu có)
└── 9.FileImport/                   (File template excel nếu có)
```

### 2. Kiểu Other
```
<Thư_mục_đích>/
├── 1.BDSHOST/
│   └── Parameters/...
├── 2.HOST/
│   ├── 0.ChangeScripts/...
│   ├── 1.VIEW/...
│   ├── 2.TRIGGER/...
│   ├── 3.PROCEDURE/...
│   ├── 5.PACKAGE/...
│   └── 7.Parameters/...
├── 3.Service/...
└── runscript.txt                   (Script SQL*Plus với đường dẫn SQL tuyệt đối từ repo local)
```

## Chạy app

1. Giải nén ZIP hoặc mở thư mục app.
2. Double-click `DeliveryCopy.cmd` (hoặc chạy `powershell -File App.ps1`).
3. Khi app mở, chọn kiểu gom dự án (**BVSC** hoặc **Other**). Bạn cũng có thể đổi Profile bất kỳ lúc nào ở thanh menu trên cùng.
4. Chọn nguồn:
   - **File và thư mục**: Bấm `Select files` hoặc `Select folder`.
   - **Git comparison**: Chọn thư mục repo, bấm `Load branches`, chọn Base và Compare branch. App sẽ tự động checkout và pull code mới nhất về local khi bấm `Add Git changes`.
5. Khi có Compare branch, app tạo gói bàn giao trong thư mục con mang tên branch đó. Các ký tự không dùng được trong tên thư mục Windows, như `/`, được thay bằng `-`.
5. Kiểm tra danh sách ở bước **2 Review**:
   - Bấm `Sort SQL (FlexDB Order)` để sắp xếp thứ tự thực thi SQL chuẩn.
6. Chọn thư mục đích và bấm **Start delivery** ở bước **3 Deliver**.

## Open source

| File | Vai trò |
| --- | --- |
| `App.ps1` | Logic giao diện, chuyển đổi Profile/ngôn ngữ, lưu tùy chọn giao diện và xử lý luồng sự kiện |
| `UI.xaml` | Layout giao diện, bộ chọn Profile, điều khiển Git và Review |
| `Localization.json` | Bản dịch giao diện tiếng Ả Rập, với tiếng Anh làm ngôn ngữ mặc định |
| `Localization.ps1` | Nạp bản dịch và áp dụng hướng RTL/LTR theo ngôn ngữ |
| `Core.Git.ps1` | Git fetch, auto checkout & pull branch, diff và trích xuất file |
| `Core.FileOps.ps1` | Ánh xạ đường dẫn theo Profile (BVSC / Other), scan file, copy và hash |
| `Core.SqlPlus.ps1` | Sinh bộ script thực thi cho BVSC (runUpdate.bat, setVariable.bat, install.sql) và Other (runscript.txt với đường dẫn repo local tuyệt đối) |

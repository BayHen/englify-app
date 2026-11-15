# Chuyển quyền quản lý schema sang Supabase

Schema `public` hiện có baseline tại `supabase/migrations/20261110072647_baseline_englify_schema.sql`, tạo từ **Supabase local** đã áp Alembic revision `20261109_13`. Hai migration sau khóa bảng Alembic metadata, thêm constraint avatar và RPC onboarding. Ba seed nằm trong `supabase/seeds/`; bucket avatar và deep link local cấu hình trong `config.toml`. `npx.cmd supabase db reset --network-id <NETWORK_CỦA_BẠN>` đã tái tạo được local schema, seed và bucket. **Không chạy baseline này trên project Supabase đã có bảng hoặc dữ liệu**: nó chứa CREATE TABLE và chưa được ghi nhận trong migration history của project remote.

Trước khi tạo `supabase/migrations/*.sql`:

1. Tạo backup có thể restore và môi trường thử nghiệm tách biệt.
2. Chạy `\.venv\Scripts\python.exe scripts\supabase_preflight.py` từ root để ghi revision, row count, RLS và constraint. Lệnh chỉ đọc; đầu ra chứa số lượng bản ghi, không chứa nội dung hoặc kết nối.
3. Trên bản sao thử nghiệm, xác nhận revision hiện tại `20261110_15`, bảng và số dòng. Baseline local phải được đối chiếu với schema remote bằng `db diff`/schema dump trước khi đánh dấu version trong migration history remote. Không áp baseline này lên DB đang hoạt động.
4. Chỉ thêm SQL migration tăng dần cho các RPC/view/policy còn thiếu. Kiểm tra bằng hai tài khoản thật, anon, và dữ liệu thử; so sánh số bản ghi trước/sau. Mỗi SQL function có `SET search_path` an toàn và chỉ cấp `EXECUTE` cho role cần thiết.
5. Khi mobile/admin đã chuyển hết endpoint và bộ regression đạt, mới ngừng Alembic/FastAPI. Xem `docs/SUPABASE_MIGRATION_AUDIT.md`.

## Kiểm tra local đã thực hiện

`supabase db reset --network-id englify-local-test-20261110` và `python scripts/supabase_local_integration.py` đã đạt trên máy phát triển ngày 10/11/2026. Script integration chỉ chấp nhận API local `127.0.0.1:54321`, tự tạo/xóa hai tài khoản thử và không in token. `--network-id` phải thống nhất giữa `supabase start` và `db reset`; nếu đổi network, Auth/Storage có thể không phân giải được hostname DB. Không dùng `--remote` cho các lệnh này.

Không đưa URL database, password, service-role key hoặc file backup vào Git.

Migration `20261110100000_real_english_rpc.sql` bổ sung lưu biểu thức theo RLS và RPC quiz Real English. Database hiện có revision Alembic 16; baseline SQL chỉ dùng cho dự án Supabase mới, không áp lại vào database đang có dữ liệu.

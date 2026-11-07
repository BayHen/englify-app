# Englify Quest Admin

Trang Next.js quản lý nội dung học tập bằng Supabase Auth và API FastAPI. Xem [hướng dẫn tiếng Việt](../../docs/ADMIN_DASHBOARD.md) để cấu hình, cấp quyền admin, chạy migration và kiểm thử.

```powershell
Copy-Item apps/admin/.env.example apps/admin/.env.local
npm.cmd run admin
```

Không đặt service role key trong ứng dụng này. Một tài khoản chỉ có quyền admin sau khi được thêm vào `public.admin_members` bằng thao tác database có kiểm soát.

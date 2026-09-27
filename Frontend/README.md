# College Management System - Clean Frontend

This is the cleaned Flutter frontend. The old prototype `lib/features` tree was removed because it depended on packages that were not present in `pubspec.yaml` and caused the large cascading analyzer error list.

## Replace

Replace your current Flutter project files with this project. If you have custom native Android/iOS changes, keep those platform-specific changes.

## Run

```powershell
flutter clean
flutter pub get
flutter run
```

## API

The frontend points to:
https://student-details-worker.student-project-2026.workers.dev

Login validates the bearer token with `GET /rbac/role-list`.

Main application endpoints:
- `/student/all`
- `/student/create`
- `/academic/overview`
- `/academic/branches`
- `/academic/departments`
- `/academic/courses`
- `/academic/subjects`
- `/academic/faculty`
- `/attendance/all`
- `/users`
- `/rbac/roles`
- `/rbac/role-list`
- `/rbac/doctypes`
- `/rbac/permissions`

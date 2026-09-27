🎓 College Management System
> A modern full-stack College Management System built with **Flutter**, **Cloudflare Workers**, **Hono**, and **Cloudflare D1** — designed to manage students, faculty, academics, attendance, reports, and role-based access from a unified platform.
<p align="center">
<img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Cloudflare%20Workers-F38020?style=for-the-badge&logo=cloudflare&logoColor=white" />
  <img src="https://img.shields.io/badge/Hono-E36002?style=for-the-badge&logo=hono&logoColor=white" />
  <img src="https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white" />
  <img src="https://img.shields.io/badge/Cloudflare%20D1-F38020?style=for-the-badge&logo=cloudflare&logoColor=white" />
  <img src="https://img.shields.io/badge/Drizzle%20ORM-C5F74F?style=for-the-badge&logo=drizzle&logoColor=black" />
</p>
<p align="center">
  <strong>Students • Faculty • HOD • Administration • Attendance • Academics • Reports • Security</strong>
</p>
---
✨ Overview
The College Management System is a full-stack application created to provide a centralized platform for managing day-to-day academic and administrative operations.
The system provides dedicated experiences for different institutional roles while keeping authentication, authorization, academic data, attendance, and reporting within one connected platform.
Instead of building isolated modules, this project brings the major college workflows together through a Flutter frontend and a lightweight, scalable Cloudflare-based backend.
🎯 Designed For
🎓 Students
👨‍🏫 Faculty
🏛️ Heads of Department (HOD)
🛠️ Administrators
👑 Super Administrators
---
🚀 Key Features
👨‍🎓 Student Management
Student profiles
Student academic information
Department and course information
Enrollment information
Student-specific dashboard
Student attendance
Student reports
Role-aware access to personal information
👨‍🏫 Faculty Management
Faculty profiles
Faculty department association
Faculty academic responsibilities
Student access based on assigned scope
Attendance management
Academic information access
🏛️ Department & Academic Management
Branch management
Department management
Course management
Subject management
Faculty management
Student enrollment management
Academic relationships between departments, courses, faculty, subjects, and students
📅 Attendance Management
Attendance records
Attendance viewing
Attendance marking
Attendance approval workflows
Role-based attendance access
Student-specific attendance views
📊 Reports
The application provides role-aware reporting capabilities across areas such as:
Student information
Attendance
Departments
Faculty
Academic data
🔐 Security & Access Control
The backend implements role-based access control with dedicated permissions and scope handling.
Supported roles:
Role	Access
👨‍🎓 STUDENT	Personal academic information, attendance and reports
👨‍🏫 FACULTY	Academic, student and attendance operations within assigned scope
🏛️ HOD	Department-level academic and administrative operations
🛠️ ADMIN	System-wide administrative operations
👑 SUPER_ADMIN	Highest level system administration
Access is enforced at the backend level rather than relying only on frontend navigation.
---
🏗️ Architecture
```text
┌───────────────────────────────────────────────┐
│                  Flutter App                  │
│                                               │
│  Dashboard • Students • Faculty • Attendance │
│  Academics • Reports • Administration         │
└───────────────────────┬───────────────────────┘
                        │
                        │ HTTPS / REST API
                        ▼
┌───────────────────────────────────────────────┐
│             Cloudflare Worker                 │
│                                               │
│                    Hono                       │
│                                               │
│  Authentication                               │
│  Authorization                                │
│  Role & Scope Validation                      │
│  Academic APIs                                │
│  Attendance APIs                              │
│  Reporting APIs                               │
└───────────────┬───────────────────┬───────────┘
                │                   │
                ▼                   ▼
      ┌─────────────────┐   ┌──────────────────┐
      │ Cloudflare D1   │   │ Durable Objects  │
      │                 │   │                  │
      │ Application DB  │   │ Stateful Logic   │
      └─────────────────┘   └──────────────────┘
                │
                ▼
        ┌─────────────────┐
        │   Drizzle ORM  │
        └─────────────────┘
```
---
🛠️ Technology Stack
Frontend
Flutter
Dart
Material UI
Responsive application architecture
REST API integration
Role-aware navigation
Backend
TypeScript
Cloudflare Workers
Hono
Zod
`@hono/zod-validator`
REST APIs
CORS
Bearer/API-token authentication
OpenAPI / Swagger
Database
Cloudflare D1
SQLite
Drizzle ORM
Database migrations
Cloud Infrastructure
Cloudflare Workers
Cloudflare D1
Cloudflare Durable Objects
Wrangler CLI
---
🔐 Authentication Model
The application uses a role-based shared token model.
The username identifies the account, while the API token identifies the user's role.
Role	Example Username	Role Token
Student	`student2026`	`student_2026`
Faculty	`faculty2026`	`faculty_2026`
HOD	`hod2026`	`hod_2026`
Admin	`admin2026`	`admin_2026`
Super Admin	`superadmin2026`	`superadmin_2026`
Individual accounts belonging to the same role can use that role's token.
For example:
```text
Username: rahul
Token:    student_2026
```
or:
```text
Username: ramesh
Token:    student_2026
```
The backend validates that the supplied username belongs to the role represented by the token.
> **Note:** The credentials above are demo/project credentials. Production deployments should use securely managed authentication credentials and secrets.
---
👥 Role-Based Application Experience
The interface adapts according to the authenticated user's role.
🎓 Student
Student navigation focuses on:
```text
Dashboard
My Profile
My Attendance
My Reports
```
👨‍🏫 Faculty
Faculty navigation includes:
```text
Dashboard
Students
Subjects
Attendance
Reports
```
🏛️ HOD
HOD navigation includes:
```text
Dashboard
Department
Students
Faculty
Attendance
Approvals
Reports
```
🛠️ Administration
Administrative roles provide access to broader institutional management functionality.
---
📁 Project Structure
```text
college-management-system/
│
├── Backend/
│   │
│   ├── index.ts
│   ├── package.json
│   ├── tsconfig.json
│   ├── wrangler.jsonc
│   ├── worker-configuration.d.ts
│   │
│   ├── drizzle/
│   │   └── *.sql
│   │
│   └── ...
│
├── Frontend/
│   │
│   ├── lib/
│   │   ├── main.dart
│   │   ├── api.dart
│   │   └── ...
│   │
│   ├── pubspec.yaml
│   └── ...
│
├── Student_Management_RBAC_SRS.docx
│
├── .gitignore
│
└── README.md
```
---
🌐 Backend API
The backend is deployed using Cloudflare Workers.
Production API
```text
https://student-details-worker.student-project-2026.workers.dev
```
API Documentation
The backend includes OpenAPI / Swagger support for exploring available endpoints.
Common API areas include:
```text
Authentication
Users
Students
Attendance
Branches
Departments
Courses
Faculty
Subjects
Enrollments
Reports
```
---
🔑 Example API Request
Example authenticated request:
```http
GET /me
Authorization: Bearer student_2026
X-College-Username: student2026
```
Example response:
```json
{
  "success": true,
  "user": {
    "id": 2,
    "username": "student2026",
    "roleId": 5,
    "studentId": null
  },
  "role": "STUDENT"
}
```
---
⚙️ Getting Started
Prerequisites
Make sure you have the following installed:
Flutter SDK
Dart SDK
Node.js
npm
Wrangler CLI
Cloudflare account
---
1. Clone the Repository
```bash
git clone https://github.com/udaykiran0729/college-management-system.git
```
```bash
cd college-management-system
```
---
📱 Frontend Setup
Navigate to the Flutter application:
```bash
cd Frontend
```
Install dependencies:
```bash
flutter pub get
```
Run the application:
```bash
flutter run
```
For a web build:
```bash
flutter run -d chrome
```
---
☁️ Backend Setup
Navigate to the backend:
```bash
cd Backend
```
Install dependencies:
```bash
npm install
```
Login to Cloudflare:
```bash
npx wrangler login
```
Generate Worker types:
```bash
npx wrangler types
```
Run the backend locally:
```bash
npx wrangler dev
```
The local API will be available at:
```text
http://127.0.0.1:8787
```
---
🗄️ Database
The project uses Cloudflare D1 for persistent application data.
Database migrations are maintained inside:
```text
Backend/drizzle/
```
Apply migrations locally:
```bash
npx wrangler d1 migrations apply student-db --local
```
Apply migrations to the deployed database:
```bash
npx wrangler d1 migrations apply student-db --remote
```
> Make sure your Cloudflare configuration and database bindings are correctly configured before running remote migrations.
---
🚀 Deployment
Deploy Backend
From the `Backend` directory:
```bash
npx wrangler deploy
```
Cloudflare Workers will deploy the API to your configured Workers environment.
---
🔒 Environment & Secrets
Sensitive configuration should never be committed to GitHub.
The repository intentionally ignores files such as:
```text
.dev.vars
.env
.env.*
.wrangler/
```
For local development, configure secrets and environment variables using your local development configuration.
For production, use Cloudflare's secret management facilities.
---
🧩 Backend Highlights
The backend was designed around a modular access-control approach.
Authentication
Requests are authenticated before protected resources are accessed.
Role Authorization
Each role has its own permitted operations.
Scope Enforcement
Different roles can operate within different data scopes.
For example:
```text
SUPER_ADMIN
     │
     └── System-wide access

ADMIN
     │
     └── System-wide administration

HOD
     │
     └── Department-level access

FACULTY
     │
     └── Assigned academic scope

STUDENT
     │
     └── Own student information
```
This approach helps keep authorization decisions on the server rather than relying exclusively on the frontend.
---
📚 Academic Modules
The system connects multiple academic entities:
```text
Branch
   │
   ▼
Department
   │
   ├──────────────► Faculty
   │
   ├──────────────► Course
   │                  │
   │                  ▼
   │               Subjects
   │
   └──────────────► Students
                      │
                      ▼
                  Enrollments
                      │
                      ▼
                  Attendance
```
This provides a foundation for extending the platform with additional academic workflows.
---
📊 Example Use Cases
Student
```text
Login
  ↓
View Dashboard
  ↓
View Profile
  ↓
View Attendance
  ↓
View Reports
```
Faculty
```text
Login
  ↓
View Assigned Academic Data
  ↓
View Students
  ↓
Manage Attendance
  ↓
View Reports
```
HOD
```text
Login
  ↓
View Department
  ↓
Manage Department-Level Academic Data
  ↓
Review Attendance
  ↓
Handle Approvals
  ↓
View Reports
```
Administrator
```text
Login
  ↓
Manage Institutional Data
  ↓
Manage Academic Structure
  ↓
Manage Users
  ↓
Review Reports
```
---
🧪 Development & Testing
The project was developed with separate frontend and backend layers so each part can be tested independently.
Backend
```bash
npm install
npx wrangler dev
```
Frontend
```bash
flutter pub get
flutter run
```
API Verification
Protected API endpoints can be tested using:
Swagger / OpenAPI
Postman
cURL
Flutter application
---
🛡️ Security Considerations
The application includes multiple layers of backend protection:
Authentication middleware
Role-based authorization
Scope-based access enforcement
Request validation
CORS configuration
Protected administrative endpoints
Database-level filtering based on access scope
Environment-based secret handling
The frontend should be treated as a client and not as the final authority for access decisions.
---
🔮 Future Improvements
The architecture provides room for future expansion, including:
🔔 Notifications
📧 Email integration
📱 Push notifications
📈 Advanced analytics dashboards
📝 Examination management
💰 Fee management
📚 Library management
🗓️ Timetable management
🧾 Certificate management
📄 Document management
🧑‍💼 Staff administration
📊 More advanced reporting
🔐 Production-grade identity management
🧪 Automated integration testing
🚀 CI/CD pipelines
---
🤝 Contributing
Contributions are welcome.
If you would like to improve the project:
Fork the repository
Create a feature branch
```bash
git checkout -b feature/your-feature
```
Make your changes
Test the application
Commit your changes
```bash
git commit -m "Add your feature"
```
Push the branch
```bash
git push origin feature/your-feature
```
Open a Pull Request
Please keep contributions focused, documented, and tested.
---
🐛 Reporting Issues
Found a bug or have an improvement?
Open an issue with:
Clear title
Steps to reproduce
Expected behavior
Actual behavior
Relevant screenshots or logs
Environment information
---
📌 Project Status
🟢 Active Development
The current version provides a functional full-stack foundation covering:
Student management
Faculty management
Academic management
Attendance
Reports
Authentication
Role-based access
Scope-based authorization
Cloud deployment
The architecture is designed to support additional college-management modules over time.
---
📄 Documentation
The project includes a Software Requirements Specification document:
```text
Student_Management_RBAC_SRS.docx
```
This document describes the system requirements, roles, permissions, and functional scope of the application.
---
🌍 Deployment
Frontend
Flutter can be deployed to:
Web
Android
iOS
Windows
Linux
macOS
Backend
The API is designed for deployment on:
Cloudflare Workers
Cloudflare D1
Cloudflare Durable Objects
This allows the backend to run on Cloudflare's global edge infrastructure.
---
⭐ Why This Project?
The project demonstrates how a modern full-stack application can combine:
```text
Flutter
   +
TypeScript
   +
Hono
   +
Cloudflare Workers
   +
Cloudflare D1
   +
Drizzle ORM
   +
Role-Based Security
```
into a single college-management platform.
It is also structured so that developers can extend the existing foundation with additional institutional workflows without replacing the core architecture.
---
👨‍💻 Author
Uday Kiran
GitHub:
https://github.com/udaykiran0729
---
⭐ Support the Project
If you find this project useful or interesting:
⭐ Star the repository
🍴 Fork the project
🐛 Report issues
💡 Suggest improvements
🤝 Contribute
Every contribution helps the project grow.
---
📜 License
This project is currently provided for educational, demonstration, and development purposes.
If you plan to use the project commercially or redistribute it, please contact the repository owner regarding licensing.
---
<p align="center">
🎓 College Management System
Built with Flutter + Cloudflare Workers + Hono + D1
<br/>
⭐ Star the repository if you find it useful.
</p>

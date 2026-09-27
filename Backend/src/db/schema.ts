import {
  sqliteTable,
  integer,
  text,
  unique,
} from "drizzle-orm/sqlite-core";

export const students = sqliteTable("students", {
  id: integer("id")
    .primaryKey({ autoIncrement: true }),

  name: text("name")
    .notNull(),

  age: integer("age")
    .notNull(),

  course: text("course")
    .notNull(),

  marks: integer("marks")
    .notNull(),
});

export const rolePermissions = sqliteTable(
  "role_permissions",
  {
    id: integer("id")
      .primaryKey({ autoIncrement: true }),

    role: text("role")
      .notNull(),

    permission: text("permission")
      .notNull(),
  },
  (table) => ({
    rolePermissionUnique: unique(
      "role_permission_unique",
    ).on(
      table.role,
      table.permission,
    ),
  }),
);
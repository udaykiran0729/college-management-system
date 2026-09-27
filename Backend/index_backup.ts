import { Hono } from "hono";
import { cors } from "hono/cors";
import * as z from "zod";
import { zValidator } from "@hono/zod-validator";
import { swaggerUI } from "@hono/swagger-ui";
import { drizzle } from "drizzle-orm/d1";
import { eq } from "drizzle-orm";

import { StudentDO } from "./src/do/StudentDO";
import { students } from "./src/db/schema";

/* =========================================================
   CLOUDFLARE BINDINGS
========================================================= */

type Bindings = {
  MY_APP_NAME: string;
  API_TOKEN: string;
  DB: D1Database;

  // IMPORTANT:
  // This tells TypeScript that the namespace contains StudentDO.
  STUDENT_DO: DurableObjectNamespace<StudentDO>;
};

/* =========================================================
   HONO APPLICATION
========================================================= */

const app = new Hono<{
  Bindings: Bindings;
}>();

/* =========================================================
   CORS
   IMPORTANT:
   CORS must run before authentication so the browser's
   OPTIONS preflight request is not rejected by auth.
========================================================= */

app.use(
  "*",
  cors({
    origin: "*",
    allowHeaders: ["Content-Type", "Authorization"],
    allowMethods: [
      "GET",
      "POST",
      "PUT",
      "DELETE",
      "OPTIONS",
    ],
  }),
);

/* =========================================================
   ZOD SCHEMAS
========================================================= */

const StudentCreateSchema = z.object({
  name: z
    .string()
    .min(2, "Name must contain at least 2 characters"),

  age: z
    .number()
    .int("Age must be an integer")
    .min(1, "Age must be at least 1")
    .max(100, "Age must not exceed 100"),

  course: z
    .string()
    .min(2, "Course must contain at least 2 characters"),

  marks: z
    .number()
    .min(0, "Marks cannot be negative")
    .max(100, "Marks cannot exceed 100")
});

const StudentUpdateSchema =
  StudentCreateSchema.partial();

/* =========================================================
   AUTHENTICATION
========================================================= */

async function authenticate(
  c: any,
  next: any
) {
  const authorization =
    c.req.header("Authorization");

  if (!authorization) {
    return c.json(
      {
        error:
          "Authorization header is required"
      },
      401
    );
  }

  const parts =
    authorization.split(" ");

  const scheme =
    parts[0];

  const token =
    parts[1];

  if (
    scheme !== "Bearer" ||
    !token ||
    token !== c.env.API_TOKEN
  ) {
    return c.json(
      {
        error:
          "Invalid or missing API token"
      },
      401
    );
  }

  await next();
}

/* =========================================================
   PROTECT D1 ROUTES
========================================================= */

app.use(
  "/student/*",
  authenticate
);

/* =========================================================
   PROTECT DURABLE OBJECT ROUTES
========================================================= */

app.use(
  "/do/student/*",
  authenticate
);

/* =========================================================
   DURABLE OBJECT HELPER
========================================================= */

function getStudentDO(
  c: {
    env: Bindings;
  }
): DurableObjectStub<StudentDO> {

  const id =
    c.env.STUDENT_DO.idFromName(
      "student-demo"
    );

  return c.env.STUDENT_DO.get(id);
}

/* =========================================================
   OPENAPI DOCUMENT
========================================================= */

const openApiDoc = {
  openapi: "3.0.0",

  info: {
    title:
      "Student Management API",

    version:
      "3.0.0",

    description:
      "Student Management API using Hono, Zod, Bearer Authentication, Drizzle ORM, Cloudflare D1 and SQLite Durable Objects"
  },

  servers: [
    {
      url:
        "http://127.0.0.1:8787",

      description:
        "Local development server"
    }
  ],

  components: {

    securitySchemes: {

      bearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "API Token"
      }

    },

    schemas: {

      Student: {

        type: "object",

        properties: {

          id: {
            type: "integer",
            example: 1
          },

          name: {
            type: "string",
            example: "Rahul"
          },

          age: {
            type: "integer",
            example: 20
          },

          course: {
            type: "string",
            example: "Computer Science"
          },

          marks: {
            type: "integer",
            example: 85
          }

        }

      },

      StudentCreate: {

        type: "object",

        required: [
          "name",
          "age",
          "course",
          "marks"
        ],

        properties: {

          name: {
            type: "string",
            example: "Arjun"
          },

          age: {
            type: "integer",
            example: 22
          },

          course: {
            type: "string",
            example:
              "Software Engineering"
          },

          marks: {
            type: "integer",
            example: 88
          }

        }

      },

      StudentUpdate: {

        type: "object",

        properties: {

          name: {
            type: "string",
            example: "Arjun Kumar"
          },

          age: {
            type: "integer",
            example: 23
          },

          course: {
            type: "string",
            example:
              "Computer Science"
          },

          marks: {
            type: "integer",
            example: 95
          }

        }

      }

    }

  },

  paths: {

    /* =====================================================
       HOME
    ===================================================== */

    "/": {

      get: {

        summary:
          "Get API information",

        responses: {

          "200": {
            description:
              "API information"
          }

        }

      }

    },

    /* =====================================================
       D1 CREATE
    ===================================================== */

    "/student/create": {

      post: {

        summary:
          "Create student in D1",

        security: [
          {
            bearerAuth: []
          }
        ],

        requestBody: {

          required: true,

          content: {

            "application/json": {

              schema: {
                $ref:
                  "#/components/schemas/StudentCreate"
              }

            }

          }

        },

        responses: {

          "201": {
            description:
              "Student created"
          },

          "400": {
            description:
              "Validation error"
          },

          "401": {
            description:
              "Unauthorized"
          }

        }

      }

    },

    /* =====================================================
       D1 READ ALL
    ===================================================== */

    "/student/all": {

      get: {

        summary:
          "Get all D1 students",

        security: [
          {
            bearerAuth: []
          }
        ],

        responses: {

          "200": {
            description:
              "Students returned"
          },

          "401": {
            description:
              "Unauthorized"
          }

        }

      }

    },

    /* =====================================================
       D1 READ ONE
    ===================================================== */

    "/student/{id}": {

      get: {

        summary:
          "Get D1 student by ID",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        responses: {

          "200": {
            description:
              "Student found"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       D1 UPDATE
    ===================================================== */

    "/student/update/{id}": {

      put: {

        summary:
          "Update D1 student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        requestBody: {

          required: true,

          content: {

            "application/json": {

              schema: {
                $ref:
                  "#/components/schemas/StudentUpdate"
              }

            }

          }

        },

        responses: {

          "200": {
            description:
              "Student updated"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       D1 DELETE
    ===================================================== */

    "/student/delete/{id}": {

      delete: {

        summary:
          "Delete D1 student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        responses: {

          "200": {
            description:
              "Student deleted"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       DURABLE OBJECT TEST
    ===================================================== */

    "/do/test": {

      get: {

        summary:
          "Test Durable Object SQLite",

        responses: {

          "200": {
            description:
              "Durable Object SQLite status"
          }

        }

      }

    },

    /* =====================================================
       DO CREATE
    ===================================================== */

    "/do/student/create": {

      post: {

        summary:
          "Create student in Durable Object SQLite",

        security: [
          {
            bearerAuth: []
          }
        ],

        requestBody: {

          required: true,

          content: {

            "application/json": {

              schema: {
                $ref:
                  "#/components/schemas/StudentCreate"
              }

            }

          }

        },

        responses: {

          "201": {
            description:
              "Student created in Durable Object"
          },

          "400": {
            description:
              "Validation error"
          },

          "401": {
            description:
              "Unauthorized"
          }

        }

      }

    },

    /* =====================================================
       DO READ ALL
    ===================================================== */

    "/do/student/all": {

      get: {

        summary:
          "Get all Durable Object students",

        security: [
          {
            bearerAuth: []
          }
        ],

        responses: {

          "200": {
            description:
              "Students returned"
          },

          "401": {
            description:
              "Unauthorized"
          }

        }

      }

    },

    /* =====================================================
       DO READ ONE
    ===================================================== */

    "/do/student/{id}": {

      get: {

        summary:
          "Get Durable Object student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        responses: {

          "200": {
            description:
              "Student found"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       DO UPDATE
    ===================================================== */

    "/do/student/update/{id}": {

      put: {

        summary:
          "Update Durable Object student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        requestBody: {

          required: true,

          content: {

            "application/json": {

              schema: {
                $ref:
                  "#/components/schemas/StudentUpdate"
              }

            }

          }

        },

        responses: {

          "200": {
            description:
              "Student updated"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    },

    /* =====================================================
       DO DELETE
    ===================================================== */

    "/do/student/delete/{id}": {

      delete: {

        summary:
          "Delete Durable Object student",

        security: [
          {
            bearerAuth: []
          }
        ],

        parameters: [

          {

            name: "id",

            in: "path",

            required: true,

            schema: {
              type: "integer"
            },

            example: 1

          }

        ],

        responses: {

          "200": {
            description:
              "Student deleted"
          },

          "404": {
            description:
              "Student not found"
          }

        }

      }

    }

  }
};

/* =========================================================
   SWAGGER JSON
========================================================= */

app.get(
  "/swagger.json",
  (c) => {
    return c.json(openApiDoc);
  }
);

/* =========================================================
   SWAGGER UI
========================================================= */

app.get(
  "/swagger",
  swaggerUI({
    url: "/swagger.json"
  })
);

/* =========================================================
   HOME
========================================================= */

app.get(
  "/",
  (c) => {

    return c.json({

      message:
        "Student Management API",

      application:
        c.env.MY_APP_NAME,

      databases: {

        d1:
          "Cloudflare D1 + SQLite",

        durableObject:
          "SQLite-backed Durable Object"

      },

      orm:
        "Drizzle ORM",

      authentication:
        "Bearer Token",

      validation:
        "Zod",

      documentation:
        "/swagger"

    });

  }
);

/* =========================================================
   D1 + DRIZZLE
   CREATE
========================================================= */

app.post(
  "/student/create",

  zValidator(
    "json",
    StudentCreateSchema
  ),

  async (c) => {

    const db =
      drizzle(c.env.DB);

    const body =
      c.req.valid("json");

    const result =
      await db
        .insert(students)
        .values({

          name:
            body.name,

          age:
            body.age,

          course:
            body.course,

          marks:
            body.marks

        })
        .returning();

    return c.json({

      message:
        "Student created successfully in D1",

      student:
        result[0]

    }, 201);

  }
);

/* =========================================================
   D1 + DRIZZLE
   READ ALL
========================================================= */

app.get(
  "/student/all",

  async (c) => {

    const db =
      drizzle(c.env.DB);

    const result =
      await db
        .select()
        .from(students);

    return c.json({

      count:
        result.length,

      students:
        result

    });

  }
);

/* =========================================================
   D1 + DRIZZLE
   READ ONE
========================================================= */

app.get(
  "/student/:id",

  async (c) => {

    const db =
      drizzle(c.env.DB);

    const id =
      Number(
        c.req.param("id")
      );

    if (!Number.isInteger(id)) {

      return c.json(
        {
          error:
            "Invalid student ID"
        },
        400
      );

    }

    const result =
      await db
        .select()
        .from(students)
        .where(
          eq(
            students.id,
            id
          )
        );

    if (
      result.length === 0
    ) {

      return c.json(
        {
          error:
            "Student not found"
        },
        404
      );

    }

    return c.json(
      result[0]
    );

  }
);

/* =========================================================
   D1 + DRIZZLE
   UPDATE
========================================================= */

app.put(
  "/student/update/:id",

  zValidator(
    "json",
    StudentUpdateSchema
  ),

  async (c) => {

    const db =
      drizzle(c.env.DB);

    const id =
      Number(
        c.req.param("id")
      );

    if (!Number.isInteger(id)) {

      return c.json(
        {
          error:
            "Invalid student ID"
        },
        400
      );

    }

    const body =
      c.req.valid("json");

    const result =
      await db
        .update(students)
        .set(body)
        .where(
          eq(
            students.id,
            id
          )
        )
        .returning();

    if (
      result.length === 0
    ) {

      return c.json(
        {
          error:
            "Student not found"
        },
        404
      );

    }

    return c.json({

      message:
        "Student updated successfully in D1",

      student:
        result[0]

    });

  }
);

/* =========================================================
   D1 + DRIZZLE
   DELETE
========================================================= */

app.delete(
  "/student/delete/:id",

  async (c) => {

    const db =
      drizzle(c.env.DB);

    const id =
      Number(
        c.req.param("id")
      );

    if (!Number.isInteger(id)) {

      return c.json(
        {
          error:
            "Invalid student ID"
        },
        400
      );

    }

    const result =
      await db
        .delete(students)
        .where(
          eq(
            students.id,
            id
          )
        )
        .returning();

    if (
      result.length === 0
    ) {

      return c.json(
        {
          error:
            "Student not found"
        },
        404
      );

    }

    return c.json({

      message:
        "Student deleted successfully from D1",

      student:
        result[0]

    });

  }
);

/* =========================================================
   DURABLE OBJECT
   TEST SQLITE
========================================================= */

app.get(
  "/do/test",

  async (c) => {

    const studentDO =
      getStudentDO(c);

    const tables =
      await studentDO.testDatabase();

    const count =
      await studentDO.countStudents();

    return c.json({

      message:
        "Durable Object SQLite is working",

      tables,

      studentCount:
        count

    });

  }
);

/* =========================================================
   DURABLE OBJECT
   CREATE
========================================================= */

app.post(
  "/do/student/create",

  zValidator(
    "json",
    StudentCreateSchema
  ),

  async (c) => {

    const body =
      c.req.valid("json");

    const studentDO =
      getStudentDO(c);

    const student =
      await studentDO.createStudent(

        body.name,

        body.age,

        body.course,

        body.marks

      );

    return c.json({

      message:
        "Student created in Durable Object SQLite",

      student

    }, 201);

  }
);

/* =========================================================
   DURABLE OBJECT
   READ ALL
========================================================= */

app.get(
  "/do/student/all",

  async (c) => {

    const studentDO =
      getStudentDO(c);

    const result =
      await studentDO.getAllStudents();

    return c.json({

      count:
        result.length,

      students:
        result

    });

  }
);

/* =========================================================
   DURABLE OBJECT
   READ ONE
========================================================= */

app.get(
  "/do/student/:id",

  async (c) => {

    const id =
      Number(
        c.req.param("id")
      );

    if (!Number.isInteger(id)) {

      return c.json(
        {
          error:
            "Invalid student ID"
        },
        400
      );

    }

    const studentDO =
      getStudentDO(c);

    const student =
      await studentDO.getStudent(id);

    if (!student) {

      return c.json(
        {
          error:
            "Student not found"
        },
        404
      );

    }

    return c.json(
      student
    );

  }
);

/* =========================================================
   DURABLE OBJECT
   UPDATE
========================================================= */

app.put(
  "/do/student/update/:id",

  zValidator(
    "json",
    StudentUpdateSchema
  ),

  async (c) => {

    const id =
      Number(
        c.req.param("id")
      );

    if (!Number.isInteger(id)) {

      return c.json(
        {
          error:
            "Invalid student ID"
        },
        400
      );

    }

    const body =
      c.req.valid("json");

    const studentDO =
      getStudentDO(c);

    const student =
      await studentDO.updateStudent(
        id,
        body
      );

    if (!student) {

      return c.json(
        {
          error:
            "Student not found"
        },
        404
      );

    }

    return c.json({

      message:
        "Student updated in Durable Object SQLite",

      student

    });

  }
);

/* =========================================================
   DURABLE OBJECT
   DELETE
========================================================= */

app.delete(
  "/do/student/delete/:id",

  async (c) => {

    const id =
      Number(
        c.req.param("id")
      );

    if (!Number.isInteger(id)) {

      return c.json(
        {
          error:
            "Invalid student ID"
        },
        400
      );

    }

    const studentDO =
      getStudentDO(c);

    const student =
      await studentDO.deleteStudent(
        id
      );

    if (!student) {

      return c.json(
        {
          error:
            "Student not found"
        },
        404
      );

    }

    return c.json({

      message:
        "Student deleted from Durable Object SQLite",

      student

    });

  }
);

/* =========================================================
   EXPORT WORKER + DURABLE OBJECT
========================================================= */

export default app;

export {
  StudentDO
};
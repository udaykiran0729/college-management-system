import { DurableObject } from "cloudflare:workers";

export class StudentDO extends DurableObject<Env> {

  constructor(
    ctx: DurableObjectState,
    env: Env
  ) {
    super(ctx, env);

    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        course TEXT NOT NULL,
        marks INTEGER NOT NULL
      )
    `);
  }

  async createStudent(
    name: string,
    age: number,
    course: string,
    marks: number
  ) {
    const result = this.ctx.storage.sql.exec(
      `
      INSERT INTO students
        (name, age, course, marks)
      VALUES (?, ?, ?, ?)
      RETURNING *
      `,
      name,
      age,
      course,
      marks
    );

    return result.one();
  }

  async getAllStudents() {
    const result = this.ctx.storage.sql.exec(`
      SELECT *
      FROM students
      ORDER BY id
    `);

    return result.toArray();
  }

  async getStudent(id: number) {
    const result = this.ctx.storage.sql.exec(
      `
      SELECT *
      FROM students
      WHERE id = ?
      `,
      id
    );

    return result.one();
  }

  async updateStudent(
    id: number,
    data: {
      name?: string;
      age?: number;
      course?: string;
      marks?: number;
    }
  ) {
    const existing =
      this.ctx.storage.sql
        .exec(
          `
          SELECT *
          FROM students
          WHERE id = ?
          `,
          id
        )
        .one();

    if (!existing) {
      return null;
    }

    const name =
      data.name ?? existing.name;

    const age =
      data.age ?? existing.age;

    const course =
      data.course ?? existing.course;

    const marks =
      data.marks ?? existing.marks;

    const result =
      this.ctx.storage.sql.exec(
        `
        UPDATE students
        SET
          name = ?,
          age = ?,
          course = ?,
          marks = ?
        WHERE id = ?
        RETURNING *
        `,
        name,
        age,
        course,
        marks,
        id
      );

    return result.one();
  }

  async deleteStudent(id: number) {
    const result =
      this.ctx.storage.sql.exec(
        `
        DELETE FROM students
        WHERE id = ?
        RETURNING *
        `,
        id
      );

    return result.one();
  }

  async testDatabase() {
    const result =
      this.ctx.storage.sql.exec(`
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
        ORDER BY name
      `);

    return result.toArray();
  }

  async countStudents() {
    const result =
      this.ctx.storage.sql.exec(`
        SELECT COUNT(*) AS count
        FROM students
      `);

    return result.one();
  }
}
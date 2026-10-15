import mysql from "mysql2/promise";
import { config } from "./config.js";

export const pool = mysql.createPool({
  host: config.db.socketPath ? undefined : config.db.host,
  port: config.db.socketPath ? undefined : config.db.port,
  socketPath: config.db.socketPath,
  user: config.db.user,
  password: config.db.password,
  database: config.db.database,
  ssl: config.db.ssl ? { minVersion: "TLSv1.2", rejectUnauthorized: true } : undefined,
  connectionLimit: config.db.connectionLimit,
  waitForConnections: true,
  charset: "utf8mb4",
  timezone: "Z",
  dateStrings: false,
  namedPlaceholders: false,
  multipleStatements: false,
});

export type Row = Record<string, any>;

export async function query<T = Row>(sql: string, params: unknown[] = []): Promise<T[]> {
  const [rows] = await pool.query(sql, params);
  return rows as T[];
}

export async function exec(sql: string, params: unknown[] = []) {
  const [res] = await pool.execute(sql, params as any[]);
  return res as mysql.ResultSetHeader;
}

/** Run fn inside a transaction on one connection. */
export async function tx<T>(fn: (c: mysql.PoolConnection) => Promise<T>): Promise<T> {
  const c = await pool.getConnection();
  try {
    await c.beginTransaction();
    const out = await fn(c);
    await c.commit();
    return out;
  } catch (e) {
    await c.rollback().catch(() => {});
    throw e;
  } finally {
    c.release();
  }
}

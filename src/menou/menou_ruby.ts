import { Menou } from "./menou";
import { observableSpawn, spawn } from "../tools";
import { SpawnOptionsWithoutStdio } from "child_process";
import { Client } from 'pg';
import format from 'pg-format';
import { Result, Test, Schema } from "../types/menou";
import axios from "axios";
import { Subscription } from "rxjs";
import fs from "fs";
import { URLSearchParams } from "url";
import { wrapper } from 'axios-cookiejar-support';
import { CookieJar } from 'tough-cookie';

export class MenouRuby extends Menou {
  opts: SpawnOptionsWithoutStdio = {};
  DATABASE_URL = `${process.env.DATABASE_URL?.replace(/menou-next/g, `menou-${this.id}`)}`;
  client = wrapper(axios.create({
    baseURL: `http://localhost/`,
    timeout: 5000,
    validateStatus: s => true,
    maxRedirects: 0,
    jar: new CookieJar(),
    withCredentials: true
  }));
  pid = 0;

  constructor() {
    super();
    this.opts = {
      cwd: this.repoDir,
      env: { ...process.env, DATABASE_URL: this.DATABASE_URL }
    };
  }

  async run_tests(tests: Test[]) {
    for (const test of tests) {
      console.log(`[TEST]: ${test.name}`)
      for (const task of test.tasks) {
        console.log(`[TASK]: ${task.type}`)
        try {
          let res = null
          switch (task.type) {
            case 'db_schema': {
              if (!task.expect || !task.expect?.schema) break
              res = await this.checkSchema(`${task.table}`, task.expect.schema || [])
              break
            }
            case 'file_exists': {
              if (!task.expect || !task.expect?.files) break
              res = await this.checkFileExists(task.expect.files)
              break
            }
            case 'http_get_status': {
              if (!task.expect || !task.path) break
              const value = parseInt(`${task.expect.value}`)
              if (isNaN(value)) break
              res = await this.checkHttpGetStatus(`${task.path}`, value)
              break
            }
            case 'http_post_status': {
              if (!task.expect || !task.path) break
              const value = parseInt(`${task.expect.value}`)
              if (isNaN(value)) break
              res = await this.checkHttpPostStatus(`${task.path}`, task.body, value)
              break
            }
            case 'db_where': {
              if (!task.expect || !task.table || !task.where) break
              res = await this.dbSelect(`${task.table}`, task.where, task.expect.result)
              break
            }
          }
          if(Array.isArray(res)) {
            for (const r of res) {
              if (!r.ok) {
                console.log(`[ERROR]: ${r.error}`)
                return
              }
            }
          } else {
            if(res && !res.ok) 
              console.log(`[ERROR]: ${res.error}`)
          }
        } catch (e: any) {
          console.error({ ok: false, error: e.message })
        }
      }
    }
  }

  async migrate() {
    await spawn('bundle', [], this.opts, console.log, console.error)
    await spawn('bundle', ['exec', 'rake', 'db:create'], this.opts, console.log, console.error)
    await spawn('bundle', ['exec', 'rake', 'db:migrate'], this.opts, console.log, console.error)
    await spawn('bundle', ['exec', 'rake', 'db:seed'], this.opts, console.log, console.error)
  }

  async start(tests: Test[]) {
    try {
      const port = await this.getPort()
      this.client.defaults.baseURL = `http://localhost:${port}/`
      const { observable, pid } = observableSpawn('ruby', ["app.rb", '-o', '0.0.0.0', '-p', `${port}`], this.opts)
      if(pid) this.pid = pid

      await Promise.race([
        new Promise(res => {
          const sub: Subscription = observable.subscribe({
            next: data => {
              if(`${data}`.match(/HTTPServer#start/)){
                res(null);
              }
            },
            complete: () => sub.unsubscribe()
          })
        }),
        new Promise((_, rej) => setTimeout(() => rej(null), 5000))
      ])

      await this.run_tests(tests)
    } catch (e) {
      console.log("Failed to start process")
    }
  }

  async checkSchema(table_name: string, schemas: Schema[]): Promise<Result[]> {
    const client = new Client({ connectionString: this.DATABASE_URL })
    await client.connect()
    const res = await client.query(format("SELECT * FROM information_schema.columns WHERE table_name = %L;", table_name))

    const result = schemas.map(schema => {
      const column = res.rows.find(row => row.column_name === schema?.name)
      if(!column) return { ok:false, error: `not found: ${schema?.name}` }
      if(schema.options?.null !== undefined) {
        if(schema.options.null) {
          if (column.is_nullable != 'YES') return { ok: false, error: `nullable: ${schema?.name}` }
        } else {
          if (column.is_nullable != 'NO') return { ok: false, error: `nullable: ${schema?.name}` }
        }
      }
      return { ok: true }
    })

    await client.end()
    return result
  }

  async dbSelect(table_name: string, where: any, expect: any): Promise<Result> {
    const client = new Client({ connectionString: this.DATABASE_URL })
    await client.connect()

    const res = await client.query(`SELECT * FROM ${table_name} WHERE ${Object.keys(where).map(key => `${key} = '${where[key]}'`).join(' AND ')};`)

    if(res.rows.length === 0 && expect === null) return { ok: true }
    if(res.rows.length === 0) return { ok: false, error: `not found: ${JSON.stringify(where)}` }
    if(res.rows.length > 1) return { ok: false, error: 'multiple rows' }

    Object.keys(expect).forEach(key => {
      if(res.rows[0][key] !== expect[key]) return { ok: false, error: 'invalid value', value: res.rows[0][key], expected: expect[key], sql: `SELECT * FROM ${table_name} WHERE ${Object.keys(where).map(key => `${key} = '${where[key]}'`).join(' AND ')};` }
    })

    await client.end()
    return { ok: true }
  }

  async checkHttpGetStatus(path: string, value: number): Promise<Result> {
    const res = await this.client.get(path)
    if (res.status !== value) return { ok: false, error: `expected: ${value}, result: ${res.status}` }
    return { ok: true, expect: `${value}` }
  }

  async checkHttpPostStatus(path: string, body: any, value: number): Promise<Result> {
    const params = new URLSearchParams();
    for (const key in body) {
      params.append(key, body[key]);
    }
    const res = await this.client.post(path, params)
    if (res.status !== value) return { ok: false, error: `expected: ${value}, result: ${res.status}` }
    return { ok: true, expect: `${value}` }
  }

  async clean() {
    process.kill(this.pid)
    fs.rmSync(this.repoDir, { recursive: true })
    await spawn('bundle', ['exec', 'rake', 'db:drop'], this.opts)
  }
}
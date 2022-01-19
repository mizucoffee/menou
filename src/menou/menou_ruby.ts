import path from "path";
import { Menou } from "./menou";
import { observableSpawn, spawn } from "../tools";
import { SpawnOptionsWithoutStdio } from "child_process";
import { Client } from 'pg';
import format from 'pg-format';
import { Expect, Test } from "../types/menou";
import axios from "axios";
import { Observable, Subscription } from "rxjs";
import fs from "fs";

export class MenouRuby extends Menou {
  opts: SpawnOptionsWithoutStdio = {};
  DATABASE_URL = `${process.env.DATABASE_URL?.replace(/menou-next/g, `menou-${this.id}`)}`;
  client = axios.create({
    baseURL: `http://localhost/`,
    timeout: 5000,
    validateStatus(status) {
      return true
    },
    maxRedirects: 0
  });
  pid = 0;
  // observable?: Observable<any>;

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
          switch (task.type) {
            case 'db_schema': {
              const res = await this.checkSchema(`${task.table}`, task.expects || [])
              console.log(res)
              break
            }
            case 'file_exists': {
              if (!task.expects) break
              const res = await Promise.all(task.expects.map(expect => this.checkFileExists(`${expect.name}`)))
              console.log(res)
              break
            }
            case 'http_get_status': {
              if (!task.expect || !task.path) break
              const value = parseInt(`${task.expect.value}`)
              if (isNaN(value)) break
              const res = await this.checkHttpStatus(`${task.path}`, value)
              console.log(res)
              break
            }
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
  }

  async start(tests: Test[]) {
    try {
      const port = await this.getPort()
      this.client.defaults.baseURL = `http://localhost:${port}/`
      const { observable, pid } = observableSpawn('ruby', ["app.rb", '-o', '0.0.0.0', '-p', `${port}`], this.opts)
      if(pid) this.pid = pid
      // this.observable = observable
  
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

  async checkSchema(table_name: string, expected_schema: Expect[]) {
    const client = new Client({ connectionString: this.DATABASE_URL })
    await client.connect()
    const res = await client.query(format("SELECT * FROM information_schema.columns WHERE table_name = %L;", table_name))

    const result = expected_schema.map(expect => {
      const column = res.rows.find(row => row.column_name === expect?.name)
      if(!column) return { ok:false, error: 'not found' }
      if(expect.options?.null !== undefined) {
        if(expect.options.null) {
          if (column.is_nullable != 'YES') return { ok: false, error: 'nullable' }
        } else {
          if (column.is_nullable != 'NO') return { ok: false, error: 'nullable' }
        }
      }
      return { ok: true }
    })

    await client.end()
    return result
  }

  async checkHttpStatus(path: string, value: number) {
    const res = await this.client.get(path)
    if (res.status !== value) return { ok: false, error: `expected: ${value}, result: ${res.status}` }
    return { ok: true, expect: value }
  }

  async clean() {
    process.kill(this.pid)
    fs.rmSync(this.repoDir, { recursive: true })
    await spawn('bundle', ['exec', 'rake', 'db:drop'], this.opts)
  }
}
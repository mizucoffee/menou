import path from "path";
import { Menou } from "./menou";
import { observableSpawn, spawn } from "../tools";
import { SpawnOptionsWithoutStdio } from "child_process";

import { Client } from 'pg';
import format from 'pg-format';
import { Expect, Test } from "../types/menou";
import { isCleanOptionsArray } from "simple-git/src/lib/tasks/clean";

export class MenouRuby extends Menou {
  opts: SpawnOptionsWithoutStdio = {};
  DATABASE_URL = `${process.env.DATABASE_URL?.replace(/menou-next/g, `menou-${this.id}`)}`;

  constructor() {
    super();
    this.opts = {
      cwd: this.repoDir,
      env: {
        ...process.env,
        DATABASE_URL: this.DATABASE_URL,
      }
    };
  }

  async run_tests(tests: Test[]) {
    for (const test of tests) {
      console.log(`[TEST]: ${test.name}`)
      for (const task of test.tasks) {
        console.log(`[TASK]: ${task.type}`)
        switch (task.type) {
          case 'db_schema': {
            const res = await this.checkSchema(`${task.table}`, task.expects || [])
            console.log(res)
            break
          }
        }
      }
    }
  }

  async migrate() {
    console.log(this.id)
    await spawn('bundle', [], this.opts, console.log, console.error)
    await spawn('bundle', ['exec', 'rake', 'db:create'], this.opts, console.log, console.error)
    await spawn('bundle', ['exec', 'rake', 'db:migrate'], this.opts, console.log, console.error)
  }

  start() {
    observableSpawn('ruby', [path.join(this.repoDir, "app.rb"), '-o', '0.0.0.0'], this.opts)
  }

  async checkSchema(table_name: string, expected_schema: Expect[]) {
    console.log(this.DATABASE_URL)
    const client = new Client({ connectionString: this.DATABASE_URL })
    await client.connect()
    const res = await client.query(format("SELECT * FROM information_schema.columns WHERE table_name = %L;", table_name))

    const result = expected_schema.map(expect => {
      const column = res.rows.find(row => row.column_name === expect?.name)
      if(!column) return { ok:false, error: 'not found' }
      if(expect.options?.null !== undefined) {
        if(expect.options.null) {
          if (column.is_nullable != 'YES') return { ok:false, error: 'nullable' }
        } else {
          if (column.is_nullable != 'NO') return { ok:false, error: 'nullable' }
        }
      } 
        
      return { ok :true }
    })

    await client.end()
    return result
  }
}
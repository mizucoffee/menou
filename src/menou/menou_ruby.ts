import { Menou } from "./menou";
import { spawn } from "../tools";
import { spawnSync, SpawnOptionsWithoutStdio } from "child_process";

export class MenouRuby extends Menou {
  opts: SpawnOptionsWithoutStdio = {};

  constructor() {
    super();
    this.opts = {
      cwd: this.repoDir,
      env: {
        ...process.env,
        DATABASE_URL: `${process.env.DATABASE_URL?.replace(/menou-next/g, `menou-${this.id}`)}`
      }
    };
  }

  async migrate() {
    await spawn('bundle', [], this.opts, console.log, console.error)
    await spawn('bundle', ['exec', 'rake', 'db:create'], this.opts, console.log, console.error)
    await spawn('bundle', ['exec', 'rake', 'db:migrate'], this.opts, console.log, console.error)
  }
  check_schema() {

  }
}
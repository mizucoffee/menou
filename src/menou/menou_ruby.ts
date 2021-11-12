import { Menou } from "./menou";
import { spawn } from "../tools";

export class MenouRuby extends Menou {
  async migrate() {
    const DATABASE_URL = process.env.DATABASE_URL?.replace(/menou-next/g, `menou-${this.id}`)
    const opt = { cwd: this.repoDir, env: {DATABASE_URL} };
    await spawn('bundle', [], opt, console.log, console.error)
    await spawn('bundle', ['exec', 'rake', 'db:migrate'], opt, console.log, console.error)
  }
  check_schema() {

  }
}
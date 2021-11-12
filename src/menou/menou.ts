import simpleGit from "simple-git";
import fs from "fs";
import path from "path";
import os from "os";
import { Client as PgClient } from "pg";

const client = new PgClient({connectionString: process.env.DATABASE_URL})
client.connect()

export abstract class Menou {
  protected repoDir = "";
  protected id = "";

  constructor() {
    this.repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "menou-"));
    this.id = this.repoDir.split("menou-")[1]
  }

  async git_clone(repoUrl: string, options?: { branch?: string; path?: string }) {
    await simpleGit().clone(repoUrl, this.repoDir);
    if (options?.branch != null) {
      await simpleGit(this.repoDir).checkout(options.branch);
    }
    if (options?.path != null) {
      this.repoDir = path.join(this.repoDir, options.path)
    }
    return this.repoDir;
  }

  abstract migrate(): void;
  abstract check_schema(): void;
}

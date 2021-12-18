import simpleGit from "simple-git";
import fs from "fs";
import path from "path";
import os from "os";
import { Client as PgClient } from "pg";
import { Test } from "../types/menou";
import glob from "glob-promise";

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

  abstract run_tests(tests: Test[]): Promise<any>;
  abstract start(): void;
  abstract migrate(): void;
  // abstract checkSchema(): void;

  async checkFileExists(file_name: string) {
    const files = await glob(path.join(this.repoDir, file_name))
    if (files.length == 0)
      return { ok: false, error: `${file_name} not found`, expect: file_name }
    return { ok: true, expect: file_name }
  }
}

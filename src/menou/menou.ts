import simpleGit from "simple-git";
import fs from "fs";
import path from "path";
import os from "os";
import { Client as PgClient } from "pg";
import { TaskError, TaskResult, Test } from "../types/menou";
import glob from "glob-promise";
import { getPortPromise as getPort } from "portfinder";

const client = new PgClient({connectionString: process.env.DATABASE_URL})
client.connect()

export abstract class Menou {
  protected repoDir = "";
  protected id = "";
  private port = 0;

  constructor() {
    this.repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "menou-"));
    this.id = this.repoDir.split("menou-")[1]
  }

  protected async getPort() {
    if (this.port == 0) {
      this.port = await getPort();
    }
    return this.port;
  }

  async git_clone(repoUrl: string, options?: { branch?: string; path?: string }) {
    await simpleGit().clone(repoUrl, this.repoDir);
    if (options?.branch != null && options.branch != "") {
      await simpleGit(this.repoDir).checkout(options.branch);
    }
    if (options?.path != null && options.path != "") {
      this.repoDir = path.join(this.repoDir, options.path)
    }
    return this.repoDir;
  }

  abstract runTests(tests: Test[]): Promise<any>;
  abstract start(tests: Test[]): Promise<any>;
  abstract migrate(): void;
  // abstract checkSchema(): void;
  abstract clean(): Promise<any>;

  checkFileExists(files: string[]): Promise<TaskResult[]> {
    return Promise.all(files.map(async (file) => {
      const errors: TaskError[] = [];
      const files = await glob(path.join(this.repoDir, file))
      if (files.length == 0) errors.push({ message: `${file}が見つかりません` })
      return { ok: true, title: file, target: 'file_exists', errors} as TaskResult
    }))
  }
}

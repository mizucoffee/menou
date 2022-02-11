import { Menou } from "./menou";
import { observableSpawn, spawn } from "../tools";
import { Client } from 'pg';
import format from 'pg-format';
import { Test, Schema, DomExpect, TestResult, TaskResult, TaskError, ScreenShot } from "../types/menou";
import axios from "axios";
import fs from "fs";
import { URLSearchParams } from "url";
import { wrapper } from 'axios-cookiejar-support';
import { CookieJar } from 'tough-cookie';
import puppeteer, { Browser } from "puppeteer";
import urlJoin from "url-join";
import uniqid from "uniqid";
import { Subscription } from "rxjs";
import NodePath from "path";
import glob from "glob-promise";
import path from "path";

const sleep = (ms: number) => new Promise(res => setTimeout(() => res(true), ms));

interface Result {
  testResults: TestResult[];
  screenShots: ScreenShot[];
}

export class MenouRuby extends Menou {
  DATABASE_URL = `${process.env.DATABASE_URL?.replace(/menou-next/g, `menou-${this.id}`)}`;
  client = wrapper(axios.create({
    baseURL: `http://localhost/`,
    timeout: 5000,
    validateStatus: () => true,
    maxRedirects: 0,
    jar: new CookieJar(),
    withCredentials: true
  }));
  pid = 0;
  browser?: Browser;
  listener?: (result: any) => void;

  constructor() {
    super();
  }

  getOpts() {
    return {
      cwd: this.repoDir,
      env: { ...process.env, DATABASE_URL: this.DATABASE_URL }
    }
  }

  setListener(listener: (result: any) => void) {
    this.listener = listener
  }

  async runTests(tests: Test[]): Promise<Result> {
    const testResults: TestResult[] = [];
    const screenShots: ScreenShot[] = [];
    for (const test of tests) {
      const result: TaskResult[] = [];
      if(this.listener) this.listener({name: test.name})
      for (const task of test.tasks) {
        try {
          switch (task.type) {
            case 'db_schema': {
              if (!task.expect || !task.expect?.schema) break
              result.push(...await this.checkSchema(`${task.table}`, task.expect.schema))
              break
            }
            case 'file_exists': {
              if (!task.expect || !task.expect?.files) break
              result.push(...await this.checkFileExists(task.expect.files))
              break
            }
            case 'http_get_status': {
              if (!task.expect || !task.path) break
              const value = parseInt(`${task.expect.value}`)
              if (isNaN(value)) break
              result.push(await this.checkHttpGetStatus(`${task.path}`, value))
              break
            }
            case 'http_post_status': {
              if (!task.expect || !task.path) break
              const value = parseInt(`${task.expect.value}`)
              if (isNaN(value)) break
              result.push(await this.checkHttpPostStatus(`${task.path}`, task.body, value))
              break
            }
            case 'db_where': {
              if (!task.expect || !task.table || !task.where) break
              result.push(await this.dbWhere(`${task.table}`, task.where, task.expect.result))
              break
            }
            case 'dom': {
              if (!task.expect || !task.expect.dom || !task.path) break
              const dom = await this.checkDom(task.path, task.expect.dom)
              result.push(...dom.tr)
              screenShots.push(...dom.ss)
              break
            }
          }
        } catch (e: any) {
          result.push({
            ok: false,
            title: task.type,
            target: task.type,
            errors: [{ message: e.stack }]
          })
        }
      }
      testResults.push({ ok: result.every(r => r.ok), title: test.name, items: result })
    }
    return { testResults, screenShots }
  }

  async migrate() {
    try {
      await spawn('bundle', ['--without', 'development'], this.getOpts())
      await spawn('bundle', ['exec', 'rake', 'db:create'], this.getOpts())
      await spawn('bundle', ['exec', 'rake', 'db:migrate'], this.getOpts())
      await spawn('bundle', ['exec', 'rake', 'db:seed'], this.getOpts())
    } catch (e) {
      console.error(e)
    }
  }

  async start(tests: Test[]): Promise<Result> {
    let result: Result = {
      testResults: [],
      screenShots: []
    };
    try {
      this.browser = await puppeteer.launch({ args: ['--no-sandbox'] });

      const port = await this.getPort()
      this.client.defaults.baseURL = `http://localhost:${port}/`
      const { observable, pid } = observableSpawn('ruby', ["app.rb", '-o', '0.0.0.0', '-p', `${port}`], this.getOpts())
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

      result = await this.runTests(tests)
    } catch (e) {
      console.log("Failed to start process")
    }
    return result
  }

  async checkSchema(table_name: string, schemas: Schema[]): Promise<TaskResult[]> {
    const client = new Client({ connectionString: this.DATABASE_URL })
    await client.connect()
    const res = await client.query(format("SELECT * FROM information_schema.columns WHERE table_name = %L;", table_name))

    const results = schemas.map(schema => {
      const errors: TaskError[] = [];

      const column = res.rows.find(row => row.column_name === schema.name)
      if(!column) {
        errors.push({message: 'カラムが存在しません'})
      } else {
        if(schema.options?.null && schema.options.null !== (column.is_nullable == 'YES')) {
          errors.push({message: "オプション'null'の値が正しくありません", expect: schema.options.null, result: `${column.is_nullable == 'YES'}`})
        }
        if (schema.options?.default && schema.options.default !== column.column_default) {
          errors.push({message: "オプション'default'の値が正しくありません", expect: schema.options.default, result: column.column_default})
        }
      }
      return { ok: errors.length == 0 , target: 'db_schema', title: `${table_name}#${schema?.name}の型チェック`, errors }
    })

    await client.end()
    return results
  }

  async dbWhere(table_name: string, where: any, expect: any): Promise<TaskResult> {
    const errors: TaskError[] = [];

    const client = new Client({ connectionString: this.DATABASE_URL })
    await client.connect()

    const res = await client.query(`SELECT * FROM ${table_name} WHERE ${Object.keys(where).map(key => `${key} = '${where[key]}'`).join(' AND ')};`)

    if (res.rows.length === 0 && expect != null) {
      errors.push({message: 'レコードが存在しません'})
    }
    if (res.rows.length === 1 && expect === null) {
      errors.push({message: 'レコードが存在します'})
    }
    if (res.rows.length === 1 && expect != null) {
      Object.keys(expect).forEach(key => {
        if (expect[key] != res.rows[0][key] && !(!Number.isNaN(new Date(res.rows[0][key]).getDate()) && new Date(res.rows[0][key]).getDate() == new Date(expect[key]).getDate())) {
          if(!Number.isNaN(new Date(res.rows[0][key]).getDate())) {
            errors.push({message: `${key}の値が正しくありません`, expect: `${new Date(res.rows[0][key])}`, result: `${new Date(res.rows[0][key])}`})
          } else {
            errors.push({message: `${key}の値が正しくありません`, expect: expect[key], result: res.rows[0][key]})
          }  
        }
      })
    }

    await client.end()
    return {
      ok: errors.length == 0,
      target: `db_where`,
      title: `SELECT * FROM ${table_name} WHERE ${Object.keys(where).map(key => `${key} = '${where[key]}'`).join(' AND ')};`,
      errors
    }
  }

  async checkHttpGetStatus(path: string, value: number): Promise<TaskResult> {
    const errors: TaskError[] = [];

    const res = await this.client.get(path)
    if (res.status !== value)
      errors.push({message: 'ステータスが正しくありません', expect: `${value}`, result: `${res.status}`})
    return { ok: errors.length == 0, target: `http_get_status`, title: `GET ${path}`, errors }
  }

  async checkHttpPostStatus(path: string, body: any, value: number): Promise<TaskResult> {
    const errors: TaskError[] = [];
    
    const params = new URLSearchParams();
    for (const key in body) params.append(key, body[key]);

    const res = await this.client.post(path, params)
    if (res.status !== value)
      errors.push({message: 'ステータスが正しくありません', expect: `${value}`, result: `${res.status}`})
    return { ok: errors.length == 0, target: `http_post_status`, title: `POST ${path}`, errors }
  }

  async checkDom(path: string, expects: DomExpect[]): Promise<{tr: TaskResult[], ss: ScreenShot[]}> {
    const results: TaskResult[] = []
    const screenshots: ScreenShot[] = []
    const target = 'dom'

    if(!this.browser) return {tr: [{ ok: false, target: 'dom', title: 'DOM解析システムの準備', errors: [{message: 'Menou DOM解析システムを起動出来ませんでした'}] }], ss: screenshots}

    const page = await this.browser?.newPage()
    await page.goto(urlJoin(`${this.client.defaults.baseURL}`, path));
    await page.setViewport({ width: 1920, height: 1080 })

    for(const expect of expects) {
      const errors: TaskError[] = [];
      let title = 'DOM検証'
      try {
        switch(expect.target) {
          case 'page_title': {
            title = 'ページ名の検証'
            const pageTitle = await page.title()
            if(Array.isArray(expect.expect)) {
              if(!expect.expect.includes(pageTitle)) {
                errors.push({message: 'ページ名が正しくありません', expect: expect.expect.join(", "), result: pageTitle})
              }
            } else {
              if(pageTitle !== expect.expect)
                errors.push({message: 'ページ名が正しくありません', expect: expect.expect, result: pageTitle})
            }
            break
          }
          case 'content': {
            if(!expect.selector || !Array.isArray(expect.expect)) continue
            title = `要素'${expect.selector}'の値`

            const texts = await page.evaluate((selector: string) => Array.from(document.querySelectorAll(selector)).map(e => e.textContent?.trim()), expect.selector)

            if(texts.length == 0) {
              errors.push({message: `要素'${expect.selector}'が存在しません`, expect: expect.expect.join(", ")})
              break
            }

            texts.forEach(text => {
              if(!expect.expect.includes(text)) {
                errors.push({message: `要素'${expect.selector}'の値が正しくありません`, expect: expect.expect.join(", "), result: text})
              }
            })
            break
          }
          case 'contents': {
            if(!expect.selector || !Array.isArray(expect.expect)) continue
            title = `要素'${expect.selector}'の値`

            const texts = await page.evaluate((selector: string) => Array.from(document.querySelectorAll(selector)).map(e => e.textContent?.trim()), expect.selector)

            if(texts.length == 0) {
              errors.push({message: `要素'${expect.selector}'が存在しません`, expect: expect.expect.join(", ")})
              break
            }

            expect.expect.forEach((e, i) => {
              if(e == null) e = '';
              if(texts[i] != e) errors.push({ message: `要素'${expect.selector}'の値が正しくありません`, expect: e, result: texts[i] })
            })
            break
          }
          case 'css': {
            if(!expect.selector || !Array.isArray(expect.expect)) continue
            title = `要素'${expect.selector}'の値`

            const styles = await page.evaluate((selector: string, expects: {property: string, value: string}[]) => {
              return Array.from(document.querySelectorAll(selector))
                .map(e => expects.reduce((data, expect) => {
                  data[expect.property] = getComputedStyle(e).getPropertyValue(expect.property)
                  return data
                }, {} as any))
            }, expect.selector, expect.expect)

            if(styles.length == 0) {
              errors.push({message: `要素'${expect.selector}'が存在しません`})
              break
            }

            styles.forEach((e: any, i) => {
              expect.expect.forEach((ex: {property: string, value: string}) => {
                if(e[ex.property] != ex.value) errors.push({ message: `要素'${expect.selector}[${i}]'の値が正しくありません`, expect: `${ex.property}: ${ex.value}`, result: `${ex.property}: ${e[ex.property]}` })
              })
            })
            break
          }
          case 'exists': {
            if(!expect.selector) continue
            title = `要素'${expect.selector}'の存在状態`

            const res = await page.evaluate((selector: string) => document.querySelectorAll(selector).length > 0, expect.selector)
            if(expect.expect != res) {
              errors.push({message: `要素'${expect.selector}'の存在状態が正しくありません`, expect: expect.expect, result: `${res}`})
              break
            }
            break
          }
          case 'displayed': {
            if(!expect.selector) continue
            title = `要素'${expect.selector}'の存在状態`

            const res = await page.evaluate((selector: string) => {
              const element = document.querySelector(selector) as HTMLElement
              if(!element) return false
              if(getComputedStyle(element)['display'] == 'none') return false
              if(getComputedStyle(element)['visibility'] == 'hidden') return false
              if(getComputedStyle(element)['opacity'] == '0') return false
              return true
            }, expect.selector)
            if(expect.expect != res) {
              errors.push({message: `要素'${expect.selector}'の表示状態が正しくありません`, expect: `${expect.expect}`, result: `${res}`})
              break
            }

            break
          }
          case 'screenshot': {
            if(!expect.name) continue
            const id = `${this.id}-${uniqid()}`
            const ssPath = NodePath.join(process.env.SCREENSHOTS_DIR || `${NodePath.dirname(`${require?.main?.filename}`)}/../public/screenshots/` , `/${id}.png`)
            await page.screenshot({ path: ssPath });
            screenshots.push({ name: expect.name, path: `/screenshots/${id}.png` })
            continue
          }
          case 'click': {
            if(!expect.selector) continue
            title = `要素'${expect.selector}'をクリック`

            try {
              if(expect.type == 'navigation') {
                await Promise.all([
                  page.waitForNavigation({waitUntil: ['load', 'networkidle2'], timeout: 5000}),
                  page.click(expect.selector)
                ]);
              } else {
                await page.click(expect.selector);
              }
            } catch(e: any) {
              errors.push({ message: e.message })
            }
            break
          }
          case 'wait': {
            if(!expect.timeout) continue

            if(!expect.selector) {
              await sleep(expect.timeout * 1000)
            } else {
              try {
                await Promise.race([
                  page.waitForSelector(expect.selector, { timeout: expect.timeout * 1000 }),
                  new Promise(async res => {
                    if(await page.evaluate((selector: string) => document.querySelector(selector), `${expect.selector}`) != null) res(null)
                  })
                ])
              } catch(e: any) {
                errors.push({ message: e.message })
              }
            }
            break
          }
          case 'input': {
            if(!expect.selector || !expect.value) continue
            try {
              await page.$eval(expect.selector, element => (element as HTMLInputElement).value = '');
              await page.type(expect.selector, `${expect.value}`)
            } catch(e: any) {
              errors.push({ message: e.message })
            }
            break
          }
        }
      } catch(e: any) {
        errors.push({ message: e.message })
      }
      results.push({ ok: errors.length == 0, title, target, errors })
    }
      

    await page.close();
    return { tr: results, ss: screenshots }
  }

  async clean() {
    await this.browser?.close()
    process.kill(this.pid);
    // await spawn('bundle', ['exec', 'rake', 'db:drop'], this.opts, console.log, console.error)
    fs.rmSync(this.repoDir, { recursive: true })
  }
}

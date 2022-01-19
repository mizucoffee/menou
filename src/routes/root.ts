import { Router } from "express";
import YAML from "js-yaml";
import { MenouRuby } from "../menou/menou_ruby";
import fs from 'fs'
import path from 'path'

const appDir = path.dirname(`${require?.main?.filename}`);

const router = Router();

router.get("/", (req, res) => {
  res.render('index');
});

router.post("/analyze", async (req, res) => {
  const menou = new MenouRuby()
  const repo = await menou.git_clone('https://github.com/mizucoffee/todo_app')

  const config = YAML.load(fs.readFileSync(path.join(appDir, '../tests/todo.yml'), 'utf8')) as any;
  
  await menou.migrate()
  const results = await menou.start(config.tests)

  // await menou.clean()

  res.render('index');
});

export default router;

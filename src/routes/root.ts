import { Router } from "express";
import { MenouRuby } from "../menou/menou_ruby";

const router = Router();

router.get("/", (req, res) => {
  res.render('index');
});

router.post("/analyze", async (req, res) => {
  const menou = new MenouRuby()
  const repo = await menou.git_clone('https://github.com/mizucoffee/todo_app')
  console.log(repo)
  await menou.migrate()
  res.render('index');
});

export default router;

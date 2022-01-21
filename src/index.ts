import { urlencoded, json } from 'body-parser'
import express from 'express'
import { Server } from 'http'
import { connectLogger, getLogger } from 'log4js'
import { PrismaClient } from '@prisma/client'
import * as sourceMap from 'source-map-support'
import dotenv from "dotenv";
import socketio from "socket.io";
import YAML from "js-yaml";
import { MenouRuby } from "./menou/menou_ruby";
import fs from 'fs'
import path from 'path'

// Database
const prisma = new PrismaClient()

const appDir = path.dirname(`${require?.main?.filename}`);
const configList = fs.readdirSync(path.join(appDir, '../tests')).map(file => YAML.load(fs.readFileSync(path.join(appDir, '../tests', file), 'utf8')) as any);

// Logger
const logger = getLogger()
logger.level = 'debug'

// Source Map
sourceMap.install()

// Initialise
const app = express()
const server = new Server(app)
const io = new socketio.Server(server)
dotenv.config()

// Configuration
app.disable('x-powered-by')
app.use(urlencoded({ limit: '100mb', extended: true }))
app.use(json({ limit: '100mb' }))
app.use(express.static('./public'))
app.use(connectLogger(logger, { level: 'info' }))
app.set('view engine', 'pug')

// Router
app.get("/", (req, res) => {
  res.render('index', { configList: configList.map(config => ({ id: config.id, name: config.name}) )});
});

app.get("/result/:id", async (req, res) => {
  const result = await prisma.result.findUnique({ where: { id: Number(req.params.id) }, include: { testResults: { include: { taskResults: { include: { errors: true } } } }, screenShots: true } })
  if (result == null) return res.status(404).send('Not found')
  res.render('result', result);
})

io.on('connection', socket => {
  socket.on('start', async message => {
    const config = configList.find(config => config.id === message.type);
    if(message.repo == null || config == null) {
      console.log("[ERROR] Config not found")
      io.to(socket.id).emit('error', "Config not found")
      return;
    }
    const menou = new MenouRuby()
    menou.setListener(result => {
      socket.emit('result', result)
    })
    socket.emit('result', {ok: true, name: "[PREPARE] Git clone"})
    await menou.git_clone(message.repo, { branch: message.branch, path: message.path })
    socket.emit('result', {ok: true, name: "[PREPARE] DB migration"})
    await menou.migrate()
    const menouResult = await menou.start(config.tests)
    await menou.clean()

    const result = await prisma.result.create({data: {
      screenShots: {
        createMany: {
          data: menouResult.screenShots
        }
      },
      target: config.name,
      repository: message.repo
    }})
    
    for( const tr1 of menouResult.testResults) {
      const testResult = await prisma.testResult.create({
        data: {
          result: {
            connect: {
              id: result.id
            }
          },
          title: tr1.title,
          ok: tr1.ok,
        }
      })

      for( const tr2 of tr1.items) {
        const taskResult = await prisma.taskResult.create({
          data: {
            testResult: {
              connect: {
                id: testResult.id
              }
            },
            title: tr2.title,
            ok: tr2.ok,
            target: tr2.target,
          }
        })

        for( const tr3 of tr2.errors) {
          await prisma.error.create({
            data: {
              taskResult: {
                connect: {
                  id: taskResult.id
                }
              },
              message: tr3.message,
              expect: tr3.expect,
              result: tr3.result,
            }
          })
        }
      }
    }
  
    socket.emit('done', result.id)
  })
})

server.listen(process.env.PORT || 3000)

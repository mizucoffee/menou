import { urlencoded, json } from 'body-parser'
import express from 'express'
import { Server } from 'http'
import { connectLogger, getLogger } from 'log4js'
import { PrismaClient } from '@prisma/client'
import * as sourceMap from 'source-map-support'
import dotenv from "dotenv";

// Database
const prisma = new PrismaClient()

// Logger
const logger = getLogger()
logger.level = 'debug'

// Source Map
sourceMap.install()

// Initialise
const app = express()
const server = new Server(app)
dotenv.config()

// Configuration
app.disable('x-powered-by')
app.use(urlencoded({ limit: '100mb', extended: true }))
app.use(json({ limit: '100mb' }))
app.use(express.static('./public'))
app.use(connectLogger(logger, { level: 'info' }))
app.set('view engine', 'pug')

// Router
import root from './routes/root'

app.use('/', root)

server.listen(process.env.PORT || 3000)

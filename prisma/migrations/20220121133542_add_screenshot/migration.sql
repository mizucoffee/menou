/*
  Warnings:

  - You are about to drop the column `json` on the `Result` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "Result" DROP COLUMN "json";

-- CreateTable
CREATE TABLE "TestResult" (
    "id" SERIAL NOT NULL,
    "ok" BOOLEAN NOT NULL DEFAULT false,
    "title" TEXT NOT NULL,
    "resultId" INTEGER NOT NULL,

    CONSTRAINT "TestResult_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TaskResult" (
    "id" SERIAL NOT NULL,
    "ok" BOOLEAN NOT NULL DEFAULT false,
    "title" TEXT NOT NULL,
    "target" TEXT NOT NULL,
    "testResultId" INTEGER NOT NULL,

    CONSTRAINT "TaskResult_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Error" (
    "id" SERIAL NOT NULL,
    "message" TEXT NOT NULL,
    "expect" TEXT,
    "result" TEXT,
    "taskResultId" INTEGER,

    CONSTRAINT "Error_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ScreenShot" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "resultId" INTEGER,

    CONSTRAINT "ScreenShot_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "TestResult" ADD CONSTRAINT "TestResult_resultId_fkey" FOREIGN KEY ("resultId") REFERENCES "Result"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TaskResult" ADD CONSTRAINT "TaskResult_testResultId_fkey" FOREIGN KEY ("testResultId") REFERENCES "TestResult"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Error" ADD CONSTRAINT "Error_taskResultId_fkey" FOREIGN KEY ("taskResultId") REFERENCES "TaskResult"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ScreenShot" ADD CONSTRAINT "ScreenShot_resultId_fkey" FOREIGN KEY ("resultId") REFERENCES "Result"("id") ON DELETE SET NULL ON UPDATE CASCADE;

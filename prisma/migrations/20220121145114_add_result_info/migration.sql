/*
  Warnings:

  - Added the required column `repository` to the `Result` table without a default value. This is not possible if the table is not empty.
  - Added the required column `target` to the `Result` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "Result" ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "repository" TEXT NOT NULL,
ADD COLUMN     "target" TEXT NOT NULL;

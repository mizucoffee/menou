import child_process from "child_process";
import { Observable } from "rxjs";

export function checkProperty(target: { [key: string]: string; }, properties: string[]) {
  return properties.every(property => {
    if (!target.hasOwnProperty(property)) return false
    if (target[property] == null) return false
    if (target[property] == "") return false
    return true
  })
}

export function spawn (cmd: string, args: string[], options: child_process.SpawnOptionsWithoutStdio, stdout?: (data: string) => void, stderr?: (data: string) => void, close?: (code: number) => void):Promise<string> {
  return new Promise((res, rej)=>{
    const process = child_process.spawn(cmd, args, options);
    process.stdout.setEncoding('utf-8');
    process.stderr.setEncoding('utf-8');
    let result = "";
    process.stdout.on('data', (data) => {
      result += data;
      if(stdout) stdout(data.trim())
    });
    if(stderr) process.stderr.on('data', stderr);
    process.on('exit', code => {
      if (close) close(code || 0);
      if (code == 0) res(result)
      else rej(code)
    });
  })
}

export function observableSpawn(cmd: string, args: string[], options: child_process.SpawnOptionsWithoutStdio){
  return new Observable((subscriber) => {
    const process = child_process.spawn(cmd, args, options);
    process.stdout.setEncoding('utf-8');
    process.stderr.setEncoding('utf-8');
    process.stdout.on('data', data => subscriber.next(data));
    process.stderr.on('data', data => subscriber.error(data));
    process.on('exit', code => {
      if (code == 0) subscriber.complete();
      else subscriber.error(code);
    })
  });
}

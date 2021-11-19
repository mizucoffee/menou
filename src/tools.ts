import child_process from "child_process";

export function checkProperty(target: { [key: string]: string; }, properties: string[]) {
  return properties.every(property => {
    if (!target.hasOwnProperty(property)) return false
    if (target[property] == null) return false
    if (target[property] == "") return false
    return true
  })
}

export function spawn (cmd: string, args: string[], options: child_process.SpawnOptionsWithoutStdio, stdout?: (data: string) => void, stderr?: (data: string) => void):Promise<string> {
  return new Promise((res, rej)=>{
    const process = child_process.spawn(cmd, args, options);
    process.stdout.setEncoding('utf-8');
    process.stderr.setEncoding('utf-8');
    let result = "";
    process.stdout.on('data', (data) => {
      result += data;
      if(stdout) stdout(data)
    });
    if(stderr) process.stderr.on('data', stderr);
    process.on('exit', code => {
      if (code == 0) res(result)
      else rej(code)
    });
  })
}
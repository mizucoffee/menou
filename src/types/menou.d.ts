export class Test {
  name: string;
  tasks: Task[];
}

export class Task {
  type: string;
  path?: string;
  files?: string[];
  table?: string;
  where?: any;
  expect?: Expect;
  body?: any;
}

export class Expect {
  name?: string;
  value?: string;
  result?: any;
  schema?: Schema[];
  files?: string[];
  dom?: DomExpect[];
}

export class Schema {
  name: string;
  type: string;
  options?: any;
}

export class DomExpect {
  target: string;
  expect: any;
  selector?: string;
  second?: number;
  name?: string;
  timeout?: number;
  text?: string;
}

export class Result {
  ok: boolean;
  error?: string;
  expect?: string;
  value?: string;
  sql?: string;
}

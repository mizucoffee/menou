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
  name?: string;
  timeout?: number;
  value?: string;
  type?: string;
}

export class TestResult {
  ok: boolean;
  title: string;
  items: TaskResult[];
}

export class TaskResult {
  ok: boolean;
  title: string;
  target: string;
  errors: TaskError[]
}

export class TaskError {
  message: string;
  expect?: string;
  result?: string;
}

export class ScreenShot {
  name: string;
  path: string;
}
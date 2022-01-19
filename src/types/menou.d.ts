export class Test {
  name: string;
  tasks: Task[];
}

export class Task {
  type: string;
  path?: string;
  files?: string[];
  table?: string;
  expect?: Expect;
  expects?: Expect[];
}

export class Expect {
  name?: string;
  type?: string;
  options?: any;
  value?: string;
}
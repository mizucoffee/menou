export class Test {
  name: string;
  tasks: Task[];
}

export class Task {
  type: string;
  files?: string[];
  table?: string;
  expects?: Expect[];
}

export class Expect {
  name: string;
  type: string;
  options: any;
}
import { Queue, Worker, Job } from 'bullmq';
import IORedis from 'ioredis';

type ImportJobData = {
  userId: string;
  fileBufferBase64: string; // to avoid binary in Redis
  mapping: any;
  kind: 'csv'|'xlsx'|'xls';
  options: { skipDuplicates: boolean; overwriteDuplicates: boolean; useAI: boolean; applyAICategory: boolean };
};

let connection: IORedis | undefined;
let importQueue: Queue<ImportJobData> | undefined;
let startedWorker = false;

function getConnection(): IORedis | undefined {
  const url = process.env.REDIS_URL;
  if (!url) return undefined;
  if (!connection) {
    connection = new IORedis(url, { maxRetriesPerRequest: null });
  }
  return connection;
}

export function getImportQueue(): Queue<ImportJobData> | undefined {
  const conn = getConnection();
  if (!conn) return undefined;
  if (!importQueue) {
    importQueue = new Queue<ImportJobData>('import-jobs', { connection: conn });
  }
  return importQueue;
}

export async function addImportJob(data: ImportJobData) {
  const q = getImportQueue();
  if (!q) throw new Error('queue_unavailable');
  const job = await q.add('import', data, { attempts: 1, removeOnComplete: true, removeOnFail: true });
  return job.id as string;
}

export async function getJobStatus(id: string) {
  const q = getImportQueue();
  if (!q) throw new Error('queue_unavailable');
  const job = await q.getJob(id);
  if (!job) return { state: 'not_found' } as const;
  const state = await job.getState();
  return { state, progress: job.progress, returnvalue: job.returnvalue } as const;
}

// Optional in-process worker (enable with RUN_QUEUE_WORKER=true)
export function maybeStartWorker(processor: (job: Job<ImportJobData>) => Promise<any>) {
  if (startedWorker) return;
  if (process.env.RUN_QUEUE_WORKER !== 'true') return;
  const conn = getConnection();
  if (!conn) return;
  startedWorker = true;
  // eslint-disable-next-line no-new
  new Worker<ImportJobData>('import-jobs', processor, { connection: conn });
}


// The caller owns `seen`, so a retry can ack without doing the work twice.
export function consume(job, sink) {
  if (job.seen.has(job.id)) {
    return { acked: true, duplicate: true };
  }
  job.seen.add(job.id);
  sink(job.body);
  return { acked: true, duplicate: false };
}

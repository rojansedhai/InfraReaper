export function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function getConfig() {
  const maxTtlHours = Number(process.env.MAX_TTL_HOURS ?? "24");

  return {
    awsRegion: process.env.AWS_REGION ?? process.env.AWS_DEFAULT_REGION ?? "us-east-1",
    destroyLambdaArn: process.env.DESTROY_LAMBDA_ARN,
    dlqArn: process.env.DLQ_ARN,
    lockTable: requireEnv("LOCK_TABLE"),
    metricsTable: requireEnv("METRICS_TABLE"),
    maxTtlHours: Number.isFinite(maxTtlHours) ? maxTtlHours : 24,
    resourceDir: process.env.RESOURCE_DIR ?? `${process.cwd()}/resource`,
    scheduleGroup: process.env.SCHEDULE_GROUP ?? "infrareaper",
    schedulerRoleArn: process.env.SCHEDULER_ROLE_ARN,
    stateBucket: requireEnv("STATE_BUCKET"),
    terraformBin: process.env.TERRAFORM_BIN ?? "/opt/bin/terraform"
  };
}


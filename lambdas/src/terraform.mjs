import { spawn } from "node:child_process";
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";

const COMMAND_TIMEOUT_MS = Number(process.env.TERRAFORM_TIMEOUT_MS ?? 12 * 60 * 1000);

function run(command, args, options) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: {
        ...process.env,
        TF_IN_AUTOMATION: "true",
        TF_INPUT: "0"
      },
      stdio: ["ignore", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";
    const timeout = setTimeout(() => {
      child.kill("SIGTERM");
      reject(new Error(`${command} ${args.join(" ")} timed out`));
    }, COMMAND_TIMEOUT_MS);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => {
      clearTimeout(timeout);
      reject(error);
    });

    child.on("close", (code) => {
      clearTimeout(timeout);
      if (code === 0) {
        resolve({ stdout, stderr });
        return;
      }

      const error = new Error(`${command} ${args.join(" ")} exited with code ${code}: ${stderr || stdout}`);
      error.stdout = stdout;
      error.stderr = stderr;
      reject(error);
    });
  });
}

function backendArgs(config, environmentId) {
  return [
    `bucket=${config.stateBucket}`,
    `key=envs/${environmentId}/terraform.tfstate`,
    `region=${config.awsRegion}`,
    `dynamodb_table=${config.lockTable}`,
    "encrypt=true"
  ].flatMap((item) => ["-backend-config", item]);
}

function toTerraformVars(request, config) {
  return {
    aws_region: config.awsRegion,
    env_id: request.environmentId,
    expires_at: request.expiresAt,
    extra_tags: request.extraTags ?? {},
    name_suffix: request.nameSuffix,
    purpose: request.purpose,
    requested_by: request.requestedBy,
    resource_type: request.resourceType
  };
}

function filterOutputs(outputs) {
  return Object.fromEntries(
    Object.entries(outputs).map(([key, output]) => [
      key,
      output.sensitive ? { sensitive: true, value: null } : output
    ])
  );
}

export async function runTerraformApply(config, request) {
  const workDir = await prepareWorkDir(config, request.environmentId);
  const varFile = await writeVariables(workDir, config, request);

  await run(config.terraformBin, ["init", "-input=false", ...backendArgs(config, request.environmentId)], {
    cwd: workDir
  });
  await run(config.terraformBin, ["apply", "-auto-approve", "-input=false", `-var-file=${varFile}`], {
    cwd: workDir
  });

  const output = await run(config.terraformBin, ["output", "-json"], { cwd: workDir });
  return filterOutputs(JSON.parse(output.stdout || "{}"));
}

export async function runTerraformDestroy(config, request) {
  const workDir = await prepareWorkDir(config, request.environmentId);
  const varFile = await writeVariables(workDir, config, request);

  await run(config.terraformBin, ["init", "-input=false", ...backendArgs(config, request.environmentId)], {
    cwd: workDir
  });
  await run(config.terraformBin, ["destroy", "-auto-approve", "-input=false", `-var-file=${varFile}`], {
    cwd: workDir
  });
}

async function prepareWorkDir(config, environmentId) {
  const workDir = join(tmpdir(), `infrareaper-${environmentId}`);
  await rm(workDir, { recursive: true, force: true });
  await mkdir(workDir, { recursive: true });
  await cp(config.resourceDir, workDir, { recursive: true });
  return workDir;
}

async function writeVariables(workDir, config, request) {
  const varFile = join(workDir, "terraform.tfvars.json");
  await writeFile(varFile, JSON.stringify(toTerraformVars(request, config), null, 2));

  const written = await readFile(varFile, "utf8");
  if (!written.includes(request.environmentId)) {
    throw new Error("Terraform variable file failed integrity check");
  }

  return varFile;
}


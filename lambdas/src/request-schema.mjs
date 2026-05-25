import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const RESOURCE_TYPES = new Set(["s3_bucket", "iam_role", "sqs_queue", "dynamodb_table"]);
const EMAILISH = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export function slugify(value, fallback = "temp") {
  const slug = String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-{2,}/g, "-")
    .slice(0, 48);

  return slug || fallback;
}

export function normalizeTags(tags) {
  if (!tags || typeof tags !== "object" || Array.isArray(tags)) {
    return {};
  }

  return Object.fromEntries(
    Object.entries(tags)
      .slice(0, 10)
      .map(([key, value]) => [slugify(key).slice(0, 32), String(value).slice(0, 80)])
      .filter(([key]) => key.length > 0)
  );
}

export function validateProvisionRequest(input, options = {}) {
  const errors = [];
  const maxTtlHours = Number(options.maxTtlHours ?? 24);
  const principalEmail = options.principalEmail;

  const resourceType = input.resourceType;
  if (!RESOURCE_TYPES.has(resourceType)) {
    errors.push("resourceType must be one of: s3_bucket, iam_role");
  }

  const ttlHours = Number(input.ttlHours);
  if (!Number.isInteger(ttlHours) || ttlHours < 1 || ttlHours > maxTtlHours) {
    errors.push(`ttlHours must be an integer from 1 to ${maxTtlHours}`);
  }

  const requestedBy = String(principalEmail || input.requestedBy || "").trim().slice(0, 120);
  if (!EMAILISH.test(requestedBy) && !requestedBy.startsWith("arn:aws:")) {
    errors.push("requestedBy must be a valid email address or authenticated AWS principal");
  }

  const purpose = String(input.purpose || "").trim().slice(0, 160);
  if (purpose.length < 6) {
    errors.push("purpose must be at least 6 characters");
  }

  const nameSuffix = slugify(input.name ?? purpose);
  const extraTags = normalizeTags(input.tags);

  if (errors.length > 0) {
    const error = new Error(errors.join("; "));
    error.statusCode = 400;
    throw error;
  }

  return {
    extraTags,
    nameSuffix,
    purpose,
    requestedBy,
    resourceType,
    ttlHours
  };
}

export function validateDestroyEvent(input) {
  const environmentId = String(input.environmentId || "").trim();
  if (!/^env-[a-f0-9]{12}$/.test(environmentId)) {
    throw new Error("Destroy event is missing a valid environmentId");
  }

  if (!RESOURCE_TYPES.has(input.resourceType)) {
    throw new Error("Destroy event is missing a valid resourceType");
  }

  return {
    environmentId,
    expiresAt: String(input.expiresAt || ""),
    nameSuffix: slugify(input.nameSuffix ?? environmentId),
    purpose: String(input.purpose || "scheduled-destroy").slice(0, 160),
    requestedBy: String(input.requestedBy || "scheduler").slice(0, 120),
    resourceType: input.resourceType
  };
}

if (process.argv[1] && resolve(fileURLToPath(import.meta.url)) === resolve(process.argv[1])) {
  const sample = validateProvisionRequest(
    {
      resourceType: "s3_bucket",
      ttlHours: 2,
      requestedBy: "dev@example.com",
      purpose: "schema self test",
      name: "Branch 42"
    },
    { maxTtlHours: 24 }
  );

  console.log(JSON.stringify(sample, null, 2));
}

import crypto from "node:crypto";
import { SchedulerClient, CreateScheduleCommand } from "@aws-sdk/client-scheduler";
import { DynamoDBClient, GetItemCommand, UpdateItemCommand } from "@aws-sdk/client-dynamodb";
import { getConfig } from "./config.mjs";
import { getPrincipalEmail, handleOptions, jsonResponse, parseBody } from "./http.mjs";
import { validateProvisionRequest } from "./request-schema.mjs";
import { runTerraformApply } from "./terraform.mjs";

const scheduler = new SchedulerClient({});
const dynamodb = new DynamoDBClient({});

function scheduleExpressionFromDate(date) {
  return `at(${date.toISOString().replace(/\.\d{3}Z$/, "")})`;
}

function createEnvironmentId() {
  return `env-${crypto.randomBytes(6).toString("hex")}`;
}

export async function handler(event) {
  const optionsResponse = handleOptions(event);
  if (optionsResponse) {
    return optionsResponse;
  }

  try {
    const config = getConfig();
    const method = event.requestContext?.http?.method || event.httpMethod;

    if (method === "GET") {
      const { Item } = await dynamodb.send(
        new GetItemCommand({
          TableName: config.metricsTable,
          Key: { PK: { S: "GLOBAL" } }
        })
      );
      return jsonResponse(200, {
        environmentsCreated: Item?.EnvironmentsCreated?.N ? parseInt(Item.EnvironmentsCreated.N, 10) : 0,
        hoursSaved: Item?.HoursSaved?.N ? parseInt(Item.HoursSaved.N, 10) : 0
      });
    }

    if (!config.destroyLambdaArn || !config.schedulerRoleArn) {
      throw new Error("Provisioner is missing destroy Lambda or scheduler role configuration");
    }

    const input = parseBody(event);
    const validated = validateProvisionRequest(input, {
      maxTtlHours: config.maxTtlHours,
      principalEmail: getPrincipalEmail(event)
    });

    const environmentId = createEnvironmentId();
    const expiresAt = new Date(Date.now() + validated.ttlHours * 60 * 60 * 1000).toISOString();
    const request = {
      ...validated,
      environmentId,
      expiresAt
    };

    const scheduleName = `destroy-${environmentId}`;

    await scheduler.send(
      new CreateScheduleCommand({
        ActionAfterCompletion: "DELETE",
        ClientToken: environmentId,
        Description: `Destroy InfraReaper environment ${environmentId}`,
        FlexibleTimeWindow: { Mode: "OFF" },
        GroupName: config.scheduleGroup,
        Name: scheduleName,
        ScheduleExpression: scheduleExpressionFromDate(new Date(expiresAt)),
        ScheduleExpressionTimezone: "UTC",
        Target: {
          Arn: config.destroyLambdaArn,
          DeadLetterConfig: config.dlqArn ? { Arn: config.dlqArn } : undefined,
          Input: JSON.stringify(request),
          RoleArn: config.schedulerRoleArn
        }
      })
    );

    const outputs = await runTerraformApply(config, request);

    try {
      await dynamodb.send(
        new UpdateItemCommand({
          TableName: config.metricsTable,
          Key: { PK: { S: "GLOBAL" } },
          UpdateExpression: "ADD EnvironmentsCreated :inc, HoursSaved :hours",
          ExpressionAttributeValues: {
            ":inc": { N: "1" },
            ":hours": { N: String(Math.max(0, 730 - validated.ttlHours)) }
          }
        })
      );
    } catch (err) {
      console.error("Failed to update metrics", err);
    }

    return jsonResponse(201, {
      environmentId,
      expiresAt,
      outputs,
      scheduleName
    });
  } catch (error) {
    console.error("Provisioning failed", {
      message: error.message,
      statusCode: error.statusCode
    });

    return jsonResponse(error.statusCode ?? 500, {
      message: error.statusCode ? error.message : "Provisioning failed"
    });
  }
}


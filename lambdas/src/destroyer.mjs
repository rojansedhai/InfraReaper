import { getConfig } from "./config.mjs";
import { validateDestroyEvent } from "./request-schema.mjs";
import { runTerraformDestroy } from "./terraform.mjs";

export async function handler(event) {
  const config = getConfig();
  const request = validateDestroyEvent(event);
  try {
    await runTerraformDestroy(config, request);

    return {
      ok: true,
      environmentId: request.environmentId,
      destroyedAt: new Date().toISOString()
    };
  } catch (error) {
    console.error("Destroy failed", {
      environmentId: request.environmentId,
      message: error.message
    });
    throw error;
  }
}


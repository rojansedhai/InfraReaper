const corsHeaders = {
  "Access-Control-Allow-Headers": "authorization,content-type",
  "Access-Control-Allow-Methods": "OPTIONS,POST",
  "Access-Control-Allow-Origin": process.env.CORS_ALLOW_ORIGIN ?? "*"
};

export function jsonResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  };
}

export function parseBody(event) {
  if (!event?.body) {
    return {};
  }

  const raw = event.isBase64Encoded
    ? Buffer.from(event.body, "base64").toString("utf8")
    : event.body;

  return JSON.parse(raw);
}

export function getPrincipalEmail(event) {
  return (
    event?.requestContext?.authorizer?.jwt?.claims?.email ??
    event?.requestContext?.authorizer?.jwt?.claims?.["cognito:username"] ??
    event?.requestContext?.identity?.userArn ??
    null
  );
}

export function handleOptions(event) {
  if (event?.requestContext?.http?.method === "OPTIONS" || event?.httpMethod === "OPTIONS") {
    return jsonResponse(204, {});
  }

  return null;
}


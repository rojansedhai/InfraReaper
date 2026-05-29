import { CloudWatchLogsClient, FilterLogEventsCommand } from "@aws-sdk/client-cloudwatch-logs";
const client = new CloudWatchLogsClient({});
client.send(new FilterLogEventsCommand({
    logGroupName: "/aws/lambda/infrareaper-provisioner",
    limit: 50,
    startTime: Date.now() - 15 * 60 * 1000 // Last 15 minutes
})).then(r => {
    for (const e of r.events) {
        if (e.message.includes("ERROR") || e.message.includes("error") || e.message.includes("Error") || e.message.includes("Error:") || e.message.includes("failed")) {
            console.log(new Date(e.timestamp).toISOString(), e.message);
        }
    }
}).catch(console.error);

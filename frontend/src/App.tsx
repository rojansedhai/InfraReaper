import { Clock, Hammer, Info, Loader2, ShieldCheck, Trash2, Leaf, AlertTriangle, Zap } from "lucide-react";
import { FormEvent, useMemo, useState, useEffect } from "react";

type ResourceType = "s3_bucket" | "iam_role" | "sqs_queue" | "dynamodb_table";

type ProvisionResponse = {
  environmentId: string;
  expiresAt: string;
  scheduleName: string;
  outputs: Record<string, { value: unknown; sensitive?: boolean }>;
};

type RequestState = {
  resourceType: ResourceType;
  ttlHours: number;
  requestedBy: string;
  purpose: string;
  name: string;
};

const initialState: RequestState = {
  resourceType: "s3_bucket",
  ttlHours: 4,
  requestedBy: "",
  purpose: "",
  name: ""
};

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL?.replace(/\/$/, "");
const AUTH_TOKEN = import.meta.env.VITE_AUTH_TOKEN;

export function App() {
  const [form, setForm] = useState<RequestState>(initialState);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [result, setResult] = useState<ProvisionResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [metrics, setMetrics] = useState<{environmentsCreated: number, hoursSaved: number} | null>(null);

  useEffect(() => {
    fetch(`${import.meta.env.VITE_API_BASE_URL}/metrics`)
      .then(res => res.json())
      .then(data => {
        if (data && typeof data.environmentsCreated === 'number') {
          setMetrics(data);
        }
      })
      .catch(err => console.error("Failed to load metrics", err));
  }, []);

  const ttlLabel = useMemo(() => {
    const expires = new Date(Date.now() + form.ttlHours * 60 * 60 * 1000);
    return expires.toLocaleString([], {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit"
    });
  }, [form.ttlHours]);

  async function submitRequest(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSubmitting(true);
    setError(null);
    setResult(null);

    try {
      if (!API_BASE_URL) {
        throw new Error("Set VITE_API_BASE_URL before submitting requests.");
      }

      const response = await fetch(`${API_BASE_URL}/environments`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(AUTH_TOKEN ? { Authorization: `Bearer ${AUTH_TOKEN}` } : {})
        },
        body: JSON.stringify(form)
      });

      const payload = await response.json().catch(() => null);
      if (!response.ok) {
        throw new Error(payload?.message ?? "Provisioning request failed.");
      }

      setResult(payload as ProvisionResponse);
      setForm((current) => ({ ...initialState, requestedBy: current.requestedBy }));
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Something went wrong.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Ephemeral Environments</p>
          <h1>InfraReaper</h1>
        </div>
        {metrics && (
          <div className="finopsWidget">
            <Leaf size={18} />
            <div>
              <strong>{metrics.environmentsCreated}</strong> Destroyed
            </div>
            <div className="divider" />
            <div>
              <strong>{metrics.hoursSaved.toLocaleString()}</strong> Hours Saved
            </div>
          </div>
        )}
      </header>

      <section className="workspace">
        <form className="requestPanel" onSubmit={submitRequest}>
          <div className="panelHeader">
            <Hammer size={22} aria-hidden="true" />
            <div>
              <h2>Request Resource</h2>
              <p>Provision a tagged AWS test resource with automatic teardown.</p>
            </div>
          </div>

          <label>
            Resource type
            <select
              value={form.resourceType}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  resourceType: event.target.value as ResourceType
                }))
              }
            >
              <option value="s3_bucket">Private S3 bucket</option>
              <option value="iam_role">Scoped IAM role</option>
              <option value="sqs_queue">SQS Queue</option>
              <option value="dynamodb_table">DynamoDB Table</option>
            </select>
          </label>

          <label>
            <div className="labelRow">
              <span>Name</span>
              <span className="helperText">Appended to Env ID for global uniqueness.</span>
            </div>
            <input
              value={form.name}
              maxLength={48}
              placeholder="branch-142"
              onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
              required
            />
          </label>

          <label>
            Requested by
            <input
              value={form.requestedBy}
              type="email"
              placeholder="dev@example.com"
              onChange={(event) =>
                setForm((current) => ({ ...current, requestedBy: event.target.value }))
              }
              required
            />
          </label>

          <label>
            Purpose
            <textarea
              value={form.purpose}
              maxLength={160}
              placeholder="Integration test for checkout refactor"
              onChange={(event) =>
                setForm((current) => ({ ...current, purpose: event.target.value }))
              }
              required
            />
          </label>

          <label>
            <span className="rangeLabel">
              TTL hours
              <strong>{form.ttlHours}h</strong>
            </span>
            <input
              type="range"
              min="1"
              max="24"
              value={form.ttlHours}
              onChange={(event) =>
                setForm((current) => ({ ...current, ttlHours: Number(event.target.value) }))
              }
            />
          </label>

          <div className="expiryPreview">
            <Clock size={18} aria-hidden="true" />
            Scheduled teardown around {ttlLabel}
          </div>

          <button type="submit" disabled={isSubmitting}>
            {isSubmitting ? <Loader2 className="spin" size={18} aria-hidden="true" /> : <Trash2 size={18} aria-hidden="true" />}
            {isSubmitting ? "Provisioning" : "Provision with auto-destroy"}
          </button>
        </form>

        <aside className="resultPanel">
          <div className="infoCard">
            <h2><Info size={18} className="icon-align" /> Architecture Lifecycle</h2>
            <p>
              When provisioned, an EventBridge schedule is queued for your chosen TTL.
            </p>
            <p>
              <strong>What gets destroyed?</strong> When the TTL expires, ONLY your temporary resources (S3, DynamoDB, etc.) are destroyed. The InfraReaper control plane remains intact and ready.
            </p>
          </div>

          <div className="infoCard">
            <h2><Zap size={18} className="icon-align" /> Enterprise Features</h2>
            <p>
              <strong>FinOps Tracker:</strong> Automatically calculates hours of cloud waste prevented via a zero-cost DynamoDB counter.
            </p>
            <p>
              <strong>Dead Letter Queues (DLQ):</strong> Failed automated destroys are securely caught by an SQS DLQ to prevent silent resource orphaning.
            </p>
          </div>

          <div className="infoCard" style={{ borderColor: 'rgba(248, 81, 73, 0.3)', background: 'rgba(248, 81, 73, 0.05)' }}>
            <h2 style={{ color: '#f85149' }}><AlertTriangle size={18} className="icon-align" /> Warnings & Limitations</h2>
            <p>
              <strong>State File Locks:</strong> Manual modifications to temporary resources may cause the automated destroy to fail.
            </p>
            <p>
              <strong>Lambda Timeouts:</strong> Do not provision long-running resources (e.g., RDS, EKS) as they will exceed the 15-minute Lambda limit.
            </p>
            <p>
              <strong>Cold Starts:</strong> The first request after a period of inactivity may return a "Service Unavailable" or "Gateway Timeout" error due to API Gateway's 29-second limit. The Lambda will still successfully provision your resource in the background.
            </p>
            <p>
              <strong>Security:</strong> Do not deploy this control plane to a production AWS account without enabling the JWT Authorizer.
            </p>
          </div>

          {error ? <div className="notice error">{error}</div> : null}

          {result ? (
            <div className="notice success">
              <span>Environment ready</span>
              <dl>
                <div>
                  <dt>ID</dt>
                  <dd>{result.environmentId}</dd>
                </div>
                <div>
                  <dt>Destroy schedule</dt>
                  <dd>{result.scheduleName}</dd>
                </div>
                <div>
                  <dt>Expires</dt>
                  <dd>{new Date(result.expiresAt).toLocaleString()}</dd>
                </div>
              </dl>
            </div>
          ) : (
            <div className="emptyState">
              <Clock size={30} aria-hidden="true" />
              <span>No active request in this browser session.</span>
            </div>
          )}
        </aside>
      </section>
    </main>
  );
}


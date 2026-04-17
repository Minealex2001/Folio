import { HttpsError } from "firebase-functions/v2/https";

const COLLECTIONS_QUERY_URL =
  "https://collections.mp.microsoft.com/v6.0/collections/query";

export function msStoreProductFolioMonthly(): string {
  return process.env.MS_STORE_PRODUCT_FOLIO_CLOUD_MONTHLY?.trim() ?? "";
}

export function msStoreInkSmall(): string {
  return process.env.MS_STORE_INK_SMALL?.trim() ?? "";
}

export function msStoreInkMedium(): string {
  return process.env.MS_STORE_INK_MEDIUM?.trim() ?? "";
}

export function msStoreInkLarge(): string {
  return process.env.MS_STORE_INK_LARGE?.trim() ?? "";
}

/** Producto Store: librería pequeña (+20 GB). Hereda MS_STORE_BACKUP_STORAGE_PACK si no hay _SMALL. */
export function msStoreBackupStoragePackSmall(): string {
  return (
    process.env.MS_STORE_BACKUP_STORAGE_PACK_SMALL?.trim() ||
    process.env.MS_STORE_BACKUP_STORAGE_PACK?.trim() ||
    ""
  );
}

export function msStoreBackupStoragePackMedium(): string {
  return process.env.MS_STORE_BACKUP_STORAGE_PACK_MEDIUM?.trim() ?? "";
}

export function msStoreBackupStoragePackLarge(): string {
  return process.env.MS_STORE_BACKUP_STORAGE_PACK_LARGE?.trim() ?? "";
}

const MS_BACKUP_GRANT_SMALL = 20 * 1024 * 1024 * 1024;
const MS_BACKUP_GRANT_MEDIUM = 75 * 1024 * 1024 * 1024;
const MS_BACKUP_GRANT_LARGE = 250 * 1024 * 1024 * 1024;

function azureTenantId(): string {
  return process.env.AZURE_AD_TENANT_ID?.trim() ?? "";
}

function azureClientId(): string {
  return process.env.AZURE_AD_CLIENT_ID?.trim() ?? "";
}

function azureClientSecret(): string {
  return process.env.AZURE_AD_CLIENT_SECRET?.trim() ?? "";
}

export function microsoftStoreValidationConfigured(): boolean {
  return (
    azureTenantId().length > 0 &&
    azureClientId().length > 0 &&
    azureClientSecret().length > 0 &&
    msStoreProductFolioMonthly().length > 0
  );
}

async function fetchAzureAdToken(scope: string): Promise<string | null> {
  const tenant = azureTenantId();
  const clientId = azureClientId();
  const secret = azureClientSecret();
  const tokenUrl = `https://login.microsoftonline.com/${encodeURIComponent(
    tenant
  )}/oauth2/v2.0/token`;
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: secret,
    scope,
    grant_type: "client_credentials",
  });
  const res = await fetch(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const json = (await res.json()) as { access_token?: string; error?: string };
  if (res.ok && typeof json.access_token === "string") {
    return json.access_token;
  }
  console.warn("Azure AD token failed", scope, json.error, res.status);
  return null;
}

export async function acquireMicrosoftStoreAccessToken(): Promise<string> {
  if (!microsoftStoreValidationConfigured()) {
    throw new HttpsError(
      "failed-precondition",
      "Microsoft Store validation is not configured (Azure AD + MS_STORE_PRODUCT_FOLIO_CLOUD_MONTHLY)."
    );
  }
  const scopes = [
    "https://onestore.microsoft.com/.default",
    "https://purchase.mp.microsoft.com/.default",
  ];
  for (const scope of scopes) {
    const tok = await fetchAzureAdToken(scope);
    if (tok) return tok;
  }
  throw new HttpsError(
    "internal",
    "Could not acquire Azure AD token for Microsoft Store (check tenant, client id/secret, and API permissions)."
  );
}

function normalizeItems(payload: unknown): Record<string, unknown>[] {
  if (payload === null || typeof payload !== "object") return [];
  const root = payload as Record<string, unknown>;
  const raw =
    root.Items ??
    root.items ??
    root.DataItems ??
    root.dataItems ??
    root.CollectionItems ??
    root.collectionItems;
  if (!Array.isArray(raw)) return [];
  return raw.filter(
    (x): x is Record<string, unknown> =>
      x !== null && typeof x === "object" && !Array.isArray(x)
  ) as Record<string, unknown>[];
}

export async function queryMicrosoftStoreUserCollection(
  collectionsId: string
): Promise<Record<string, unknown>[]> {
  const token = await acquireMicrosoftStoreAccessToken();
  const res = await fetch(COLLECTIONS_QUERY_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      beneficiaries: [collectionsId],
      modifiedAfter: "1970-01-01T00:00:00.000Z",
      maxPageSize: 100,
    }),
  });
  const text = await res.text();
  let parsed: unknown;
  try {
    parsed = JSON.parse(text) as unknown;
  } catch {
    console.error("Microsoft Store collections: non-JSON", text.slice(0, 500));
    throw new HttpsError(
      "internal",
      "Microsoft Store collections API returned invalid JSON."
    );
  }
  if (!res.ok) {
    console.error("Microsoft Store collections HTTP", res.status, text.slice(0, 800));
    throw new HttpsError(
      "failed-precondition",
      `Microsoft Store collections query failed (HTTP ${res.status}).`
    );
  }
  return normalizeItems(parsed);
}

function normId(s: string | undefined): string {
  return (s ?? "").trim().toLowerCase();
}

function itemProductId(item: Record<string, unknown>): string {
  const v = item.productId ?? item.ProductId;
  return typeof v === "string" ? v.trim() : "";
}

function itemSkuId(item: Record<string, unknown>): string {
  const v = item.skuId ?? item.SkuId;
  return typeof v === "string" ? v.trim() : "";
}

function itemState(item: Record<string, unknown>): string {
  const v = item.state ?? item.State ?? item.status ?? item.Status;
  return typeof v === "string" ? v.trim() : "";
}

function itemQuantity(item: Record<string, unknown>): number {
  const v = item.quantity ?? item.Quantity;
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isFinite(n) || n < 1) return 1;
  return Math.min(1000, Math.trunc(n));
}

function itemLooksActive(item: Record<string, unknown>): boolean {
  const st = itemState(item).toLowerCase();
  if (!st) return true;
  if (st.includes("revoke")) return false;
  if (st.includes("cancel")) return false;
  if (st === "inactive") return false;
  return true;
}

export function inkDropsForMicrosoftStoreProductId(
  productId: string
): number {
  const p = normId(productId);
  if (!p) return 0;
  if (p === normId(msStoreInkSmall())) return 300;
  if (p === normId(msStoreInkMedium())) return 1000;
  if (p === normId(msStoreInkLarge())) return 2500;
  return 0;
}

export function backupBytesForMicrosoftStoreProductId(
  productId: string
): number {
  const p = normId(productId);
  if (!p) return 0;
  const large = normId(msStoreBackupStoragePackLarge());
  const medium = normId(msStoreBackupStoragePackMedium());
  const small = normId(msStoreBackupStoragePackSmall());
  if (large && p === large) return MS_BACKUP_GRANT_LARGE;
  if (medium && p === medium) return MS_BACKUP_GRANT_MEDIUM;
  if (small && p === small) return MS_BACKUP_GRANT_SMALL;
  return 0;
}

export function itemMatchesMonthlySubscription(
  item: Record<string, unknown>
): boolean {
  const pid = itemProductId(item);
  if (!pid) return false;
  if (normId(pid) !== normId(msStoreProductFolioMonthly())) return false;
  return itemLooksActive(item);
}

export function microsoftPurchaseDedupKey(
  item: Record<string, unknown>
): string | null {
  const pid = itemProductId(item);
  const sku = itemSkuId(item);
  const omRaw = item.orderManagementData ?? item.OrderManagementData;
  if (omRaw && typeof omRaw === "object" && !Array.isArray(omRaw)) {
    const om = omRaw as Record<string, unknown>;
    const orderId = om.orderId ?? om.OrderId;
    if (typeof orderId === "string" && orderId.trim()) {
      return `msstore:order:${orderId.trim()}`;
    }
  }
  const lm = item.lastModified ?? item.LastModified;
  const lmStr = typeof lm === "string" ? lm.trim() : "";
  if (pid && sku && lmStr) {
    return `msstore:${normId(pid)}:${normId(sku)}:${lmStr}`;
  }
  return null;
}

export type MicrosoftStoreCollectionScan = {
  subscriptionActive: boolean;
  subscriptionStoreProductId: string | null;
  consumableGrants: { dedupKey: string; drops: number }[];
  backupStorageGrants: { dedupKey: string; bytes: number }[];
};

export function scanMicrosoftStoreCollectionItems(
  items: Record<string, unknown>[]
): MicrosoftStoreCollectionScan {
  const monthlyId = msStoreProductFolioMonthly();
  let subscriptionActive = false;
  let subscriptionStoreProductId: string | null = null;

  for (const item of items) {
    if (itemMatchesMonthlySubscription(item)) {
      subscriptionActive = true;
      subscriptionStoreProductId = monthlyId || itemProductId(item) || null;
      break;
    }
  }

  const consumableGrants: { dedupKey: string; drops: number }[] = [];
  const backupStorageGrants: { dedupKey: string; bytes: number }[] = [];
  for (const item of items) {
    const pid = itemProductId(item);
    if (!pid) continue;
    if (normId(pid) === normId(monthlyId)) continue;
    if (!itemLooksActive(item)) continue;
    const key = microsoftPurchaseDedupKey(item);
    if (!key) continue;
    const qty = itemQuantity(item);
    const dropsEach = inkDropsForMicrosoftStoreProductId(pid);
    if (dropsEach > 0) {
      consumableGrants.push({ dedupKey: key, drops: dropsEach * qty });
      continue;
    }
    const backupEach = backupBytesForMicrosoftStoreProductId(pid);
    if (backupEach > 0) {
      backupStorageGrants.push({
        dedupKey: `${key}:backup`,
        bytes: backupEach * qty,
      });
    }
  }

  return {
    subscriptionActive,
    subscriptionStoreProductId,
    consumableGrants,
    backupStorageGrants,
  };
}

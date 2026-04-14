"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.msStoreProductFolioMonthly = msStoreProductFolioMonthly;
exports.msStoreInkSmall = msStoreInkSmall;
exports.msStoreInkMedium = msStoreInkMedium;
exports.msStoreInkLarge = msStoreInkLarge;
exports.microsoftStoreValidationConfigured = microsoftStoreValidationConfigured;
exports.acquireMicrosoftStoreAccessToken = acquireMicrosoftStoreAccessToken;
exports.queryMicrosoftStoreUserCollection = queryMicrosoftStoreUserCollection;
exports.inkDropsForMicrosoftStoreProductId = inkDropsForMicrosoftStoreProductId;
exports.itemMatchesMonthlySubscription = itemMatchesMonthlySubscription;
exports.microsoftPurchaseDedupKey = microsoftPurchaseDedupKey;
exports.scanMicrosoftStoreCollectionItems = scanMicrosoftStoreCollectionItems;
const https_1 = require("firebase-functions/v2/https");
const COLLECTIONS_QUERY_URL = "https://collections.mp.microsoft.com/v6.0/collections/query";
function msStoreProductFolioMonthly() {
    var _a, _b;
    return (_b = (_a = process.env.MS_STORE_PRODUCT_FOLIO_CLOUD_MONTHLY) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function msStoreInkSmall() {
    var _a, _b;
    return (_b = (_a = process.env.MS_STORE_INK_SMALL) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function msStoreInkMedium() {
    var _a, _b;
    return (_b = (_a = process.env.MS_STORE_INK_MEDIUM) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function msStoreInkLarge() {
    var _a, _b;
    return (_b = (_a = process.env.MS_STORE_INK_LARGE) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function azureTenantId() {
    var _a, _b;
    return (_b = (_a = process.env.AZURE_AD_TENANT_ID) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function azureClientId() {
    var _a, _b;
    return (_b = (_a = process.env.AZURE_AD_CLIENT_ID) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function azureClientSecret() {
    var _a, _b;
    return (_b = (_a = process.env.AZURE_AD_CLIENT_SECRET) === null || _a === void 0 ? void 0 : _a.trim()) !== null && _b !== void 0 ? _b : "";
}
function microsoftStoreValidationConfigured() {
    return (azureTenantId().length > 0 &&
        azureClientId().length > 0 &&
        azureClientSecret().length > 0 &&
        msStoreProductFolioMonthly().length > 0);
}
async function fetchAzureAdToken(scope) {
    const tenant = azureTenantId();
    const clientId = azureClientId();
    const secret = azureClientSecret();
    const tokenUrl = `https://login.microsoftonline.com/${encodeURIComponent(tenant)}/oauth2/v2.0/token`;
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
    const json = (await res.json());
    if (res.ok && typeof json.access_token === "string") {
        return json.access_token;
    }
    console.warn("Azure AD token failed", scope, json.error, res.status);
    return null;
}
async function acquireMicrosoftStoreAccessToken() {
    if (!microsoftStoreValidationConfigured()) {
        throw new https_1.HttpsError("failed-precondition", "Microsoft Store validation is not configured (Azure AD + MS_STORE_PRODUCT_FOLIO_CLOUD_MONTHLY).");
    }
    const scopes = [
        "https://onestore.microsoft.com/.default",
        "https://purchase.mp.microsoft.com/.default",
    ];
    for (const scope of scopes) {
        const tok = await fetchAzureAdToken(scope);
        if (tok)
            return tok;
    }
    throw new https_1.HttpsError("internal", "Could not acquire Azure AD token for Microsoft Store (check tenant, client id/secret, and API permissions).");
}
function normalizeItems(payload) {
    var _a, _b, _c, _d, _e;
    if (payload === null || typeof payload !== "object")
        return [];
    const root = payload;
    const raw = (_e = (_d = (_c = (_b = (_a = root.Items) !== null && _a !== void 0 ? _a : root.items) !== null && _b !== void 0 ? _b : root.DataItems) !== null && _c !== void 0 ? _c : root.dataItems) !== null && _d !== void 0 ? _d : root.CollectionItems) !== null && _e !== void 0 ? _e : root.collectionItems;
    if (!Array.isArray(raw))
        return [];
    return raw.filter((x) => x !== null && typeof x === "object" && !Array.isArray(x));
}
async function queryMicrosoftStoreUserCollection(collectionsId) {
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
    let parsed;
    try {
        parsed = JSON.parse(text);
    }
    catch {
        console.error("Microsoft Store collections: non-JSON", text.slice(0, 500));
        throw new https_1.HttpsError("internal", "Microsoft Store collections API returned invalid JSON.");
    }
    if (!res.ok) {
        console.error("Microsoft Store collections HTTP", res.status, text.slice(0, 800));
        throw new https_1.HttpsError("failed-precondition", `Microsoft Store collections query failed (HTTP ${res.status}).`);
    }
    return normalizeItems(parsed);
}
function normId(s) {
    return (s !== null && s !== void 0 ? s : "").trim().toLowerCase();
}
function itemProductId(item) {
    var _a;
    const v = (_a = item.productId) !== null && _a !== void 0 ? _a : item.ProductId;
    return typeof v === "string" ? v.trim() : "";
}
function itemSkuId(item) {
    var _a;
    const v = (_a = item.skuId) !== null && _a !== void 0 ? _a : item.SkuId;
    return typeof v === "string" ? v.trim() : "";
}
function itemState(item) {
    var _a, _b, _c;
    const v = (_c = (_b = (_a = item.state) !== null && _a !== void 0 ? _a : item.State) !== null && _b !== void 0 ? _b : item.status) !== null && _c !== void 0 ? _c : item.Status;
    return typeof v === "string" ? v.trim() : "";
}
function itemQuantity(item) {
    var _a;
    const v = (_a = item.quantity) !== null && _a !== void 0 ? _a : item.Quantity;
    const n = typeof v === "number" ? v : Number(v);
    if (!Number.isFinite(n) || n < 1)
        return 1;
    return Math.min(1000, Math.trunc(n));
}
function itemLooksActive(item) {
    const st = itemState(item).toLowerCase();
    if (!st)
        return true;
    if (st.includes("revoke"))
        return false;
    if (st.includes("cancel"))
        return false;
    if (st === "inactive")
        return false;
    return true;
}
function inkDropsForMicrosoftStoreProductId(productId) {
    const p = normId(productId);
    if (!p)
        return 0;
    if (p === normId(msStoreInkSmall()))
        return 300;
    if (p === normId(msStoreInkMedium()))
        return 1000;
    if (p === normId(msStoreInkLarge()))
        return 2500;
    return 0;
}
function itemMatchesMonthlySubscription(item) {
    const pid = itemProductId(item);
    if (!pid)
        return false;
    if (normId(pid) !== normId(msStoreProductFolioMonthly()))
        return false;
    return itemLooksActive(item);
}
function microsoftPurchaseDedupKey(item) {
    var _a, _b, _c;
    const pid = itemProductId(item);
    const sku = itemSkuId(item);
    const omRaw = (_a = item.orderManagementData) !== null && _a !== void 0 ? _a : item.OrderManagementData;
    if (omRaw && typeof omRaw === "object" && !Array.isArray(omRaw)) {
        const om = omRaw;
        const orderId = (_b = om.orderId) !== null && _b !== void 0 ? _b : om.OrderId;
        if (typeof orderId === "string" && orderId.trim()) {
            return `msstore:order:${orderId.trim()}`;
        }
    }
    const lm = (_c = item.lastModified) !== null && _c !== void 0 ? _c : item.LastModified;
    const lmStr = typeof lm === "string" ? lm.trim() : "";
    if (pid && sku && lmStr) {
        return `msstore:${normId(pid)}:${normId(sku)}:${lmStr}`;
    }
    return null;
}
function scanMicrosoftStoreCollectionItems(items) {
    const monthlyId = msStoreProductFolioMonthly();
    let subscriptionActive = false;
    let subscriptionStoreProductId = null;
    for (const item of items) {
        if (itemMatchesMonthlySubscription(item)) {
            subscriptionActive = true;
            subscriptionStoreProductId = monthlyId || itemProductId(item) || null;
            break;
        }
    }
    const consumableGrants = [];
    for (const item of items) {
        const pid = itemProductId(item);
        if (!pid)
            continue;
        if (normId(pid) === normId(monthlyId))
            continue;
        const dropsEach = inkDropsForMicrosoftStoreProductId(pid);
        if (dropsEach <= 0)
            continue;
        if (!itemLooksActive(item))
            continue;
        const key = microsoftPurchaseDedupKey(item);
        if (!key)
            continue;
        const qty = itemQuantity(item);
        consumableGrants.push({ dedupKey: key, drops: dropsEach * qty });
    }
    return {
        subscriptionActive,
        subscriptionStoreProductId,
        consumableGrants,
    };
}
//# sourceMappingURL=microsoft_store.js.map
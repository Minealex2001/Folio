"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.aggregateGlobalTelemetryStats = exports.aggregateDailyTelemetryStats = exports.onTelemetryEventCreated = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const FieldValue = admin.firestore.FieldValue;
function firestore() {
    return admin.firestore();
}
/**
 * Mantiene un índice de UIDs con actividad por día UTC (arrayUnion).
 * Evita collectionGroup('events') completo en el job de agregación diaria.
 */
exports.onTelemetryEventCreated = (0, firestore_2.onDocumentCreated)({
    region: 'us-east1',
    document: 'analytics_events/{userId}/events/{eventId}',
    memory: '256MiB',
}, async (event) => {
    const userId = event.params.userId;
    if (!userId)
        return;
    const dateStr = new Date().toISOString().split('T')[0];
    await firestore()
        .collection('telemetryDailyUserIndex')
        .doc(dateStr)
        .set({
        userIds: FieldValue.arrayUnion(userId),
        updatedAt: firestore_1.Timestamp.now(),
    }, { merge: true });
});
async function userIdsForAggregation(dateStr) {
    var _a;
    const indexSnap = await firestore()
        .collection('telemetryDailyUserIndex')
        .doc(dateStr)
        .get();
    const fromIndex = new Set();
    if (indexSnap.exists) {
        const raw = (_a = indexSnap.data()) === null || _a === void 0 ? void 0 : _a.userIds;
        if (Array.isArray(raw)) {
            for (const id of raw) {
                if (typeof id === 'string' && id.length > 0)
                    fromIndex.add(id);
            }
        }
    }
    if (fromIndex.size > 0) {
        return fromIndex;
    }
    console.warn(`telemetryDailyUserIndex/${dateStr} empty; falling back to collectionGroup(events)`);
    const usersSnapshot = await firestore()
        .collectionGroup('events')
        .select()
        .get();
    const userIds = new Set();
    usersSnapshot.forEach((doc) => {
        const path = doc.ref.path;
        const match = path.match(/analytics_events\/([^/]+)\//);
        if (match) {
            userIds.add(match[1]);
        }
    });
    return userIds;
}
/**
 * Función programada que se ejecuta cada hora para agregar eventos diarios
 * Suma eventos por tipo, cuenta errores, duración total de sync/performance
 */
exports.aggregateDailyTelemetryStats = (0, scheduler_1.onSchedule)({
    region: 'us-east1',
    schedule: '0 * * * *',
    timeZone: 'UTC',
    memory: '256MiB',
}, async () => {
    try {
        const now = new Date();
        const dateStr = now.toISOString().split('T')[0];
        const userIds = await userIdsForAggregation(dateStr);
        for (const userId of userIds) {
            await aggregateUserDailyStats(userId, dateStr);
        }
        console.log(`Aggregated telemetry stats for ${userIds.size} users on ${dateStr}`);
    }
    catch (error) {
        console.error('Failed to aggregate telemetry stats:', error);
        throw error;
    }
});
/**
 * Agrega las estadísticas diarias para un usuario específico
 */
async function aggregateUserDailyStats(userId, dateStr) {
    try {
        const dayStart = new Date(`${dateStr}T00:00:00.000Z`);
        const dayEnd = new Date(`${dateStr}T00:00:00.000Z`);
        dayEnd.setUTCDate(dayEnd.getUTCDate() + 1);
        const eventsSnapshot = await firestore()
            .collection('analytics_events')
            .doc(userId)
            .collection('events')
            .where('timestamp', '>=', firestore_1.Timestamp.fromDate(dayStart))
            .where('timestamp', '<', firestore_1.Timestamp.fromDate(dayEnd))
            .get();
        const stats = {
            date: dateStr,
            totalEvents: eventsSnapshot.size,
            eventsByType: {},
            errorCount: 0,
            totalSyncTimeMs: 0,
            totalPerformanceTimeMs: 0,
            lastUpdate: firestore_1.Timestamp.now(),
        };
        eventsSnapshot.forEach((doc) => {
            const data = doc.data();
            const type = data.type || 'unknown';
            stats.eventsByType[type] = (stats.eventsByType[type] || 0) + 1;
            if (type === 'error') {
                stats.errorCount++;
            }
            const durationMs = typeof data.durationMs === 'number' && !Number.isNaN(data.durationMs)
                ? data.durationMs
                : 0;
            if (type === 'sync' && durationMs > 0) {
                stats.totalSyncTimeMs += durationMs;
            }
            if (type === 'performance') {
                stats.totalPerformanceTimeMs += durationMs;
            }
        });
        const statsRef = firestore()
            .collection('analytics_events')
            .doc(userId)
            .collection('stats')
            .doc(dateStr);
        await statsRef.set(stats, { merge: true });
    }
    catch (error) {
        console.error(`Failed to aggregate stats for user ${userId}:`, error);
        throw error;
    }
}
async function aggregateGlobalStatsForDate(dateStr) {
    const statsSnapshot = await firestore()
        .collectionGroup('stats')
        .where('date', '==', dateStr)
        .get();
    const globalStats = {
        date: dateStr,
        totalUsersWithEvents: 0,
        totalEvents: 0,
        globalEventsByType: {},
        totalErrors: 0,
        totalSyncTimeMs: 0,
        totalPerformanceTimeMs: 0,
        activeUsers: new Set(),
        lastUpdate: firestore_1.Timestamp.now(),
    };
    statsSnapshot.forEach((doc) => {
        const data = doc.data();
        const uid = doc.ref.path.split('/')[1];
        globalStats.activeUsers.add(uid);
        globalStats.totalEvents += data.totalEvents || 0;
        globalStats.totalErrors += data.errorCount || 0;
        globalStats.totalSyncTimeMs += data.totalSyncTimeMs || 0;
        globalStats.totalPerformanceTimeMs += data.totalPerformanceTimeMs || 0;
        const eventsByType = data.eventsByType || {};
        for (const [type, count] of Object.entries(eventsByType)) {
            globalStats.globalEventsByType[type] =
                (globalStats.globalEventsByType[type] || 0) + count;
        }
    });
    globalStats.totalUsersWithEvents = globalStats.activeUsers.size;
    await firestore()
        .collection('telemetryGlobalStats')
        .doc(dateStr)
        .set({
        ...globalStats,
        activeUsers: Array.from(globalStats.activeUsers),
        eventsByType: globalStats.globalEventsByType,
    });
    console.log(`Aggregated global telemetry stats for ${globalStats.totalUsersWithEvents} users on ${dateStr}. ` +
        `Total events: ${globalStats.totalEvents}`);
}
/**
 * Agregados globales para el panel staff: día UTC actual y anterior (cada hora).
 */
exports.aggregateGlobalTelemetryStats = (0, scheduler_1.onSchedule)({
    region: 'us-east1',
    schedule: '15 * * * *',
    timeZone: 'UTC',
    memory: '256MiB',
}, async () => {
    try {
        const now = new Date();
        const todayStr = now.toISOString().split('T')[0];
        const yesterday = new Date(now);
        yesterday.setUTCDate(yesterday.getUTCDate() - 1);
        const yesterdayStr = yesterday.toISOString().split('T')[0];
        await aggregateGlobalStatsForDate(todayStr);
        await aggregateGlobalStatsForDate(yesterdayStr);
    }
    catch (error) {
        console.error('Failed to aggregate global telemetry stats:', error);
        throw error;
    }
});
//# sourceMappingURL=telemetry.js.map
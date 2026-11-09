/**
 * RideSync Cloud Functions.
 *
 * V1 has exactly one function, `getRoute`, so the Routes API key stays on the
 * server and never ships inside the app.
 */
import { initializeApp } from "firebase-admin/app";
import { getDatabase, ServerValue } from "firebase-admin/database";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/** Same region as the Realtime Database, to keep the write fast. */
const REGION = "asia-southeast1";
const DATABASE_URL =
  "https://ridesync-dff42-default-rtdb.asia-southeast1.firebasedatabase.app";

initializeApp({ databaseURL: DATABASE_URL });

/** Routes API key, stored in Secret Manager (never in source or the app). */
const routesApiKey = defineSecret("ROUTES_API_KEY");

const ROUTES_ENDPOINT =
  "https://routes.googleapis.com/directions/v2:computeRoutes";
/** Only the fields the app stores, which also keeps billing at the base SKU. */
const ROUTES_FIELD_MASK =
  "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline";
const ROUTES_TIMEOUT_MS = 10_000;

const ROOM_CODE_PATTERN = /^[A-Z0-9]{6}$/;
const MAX_NAME_LENGTH = 200;
const MAX_ADDRESS_LENGTH = 300;

interface LatLng {
  latitude: number;
  longitude: number;
}

interface RouteRequest {
  roomCode: string;
  origin: LatLng;
  destination: LatLng & { name: string; address: string };
}

interface ComputedRoute {
  distanceMeters: number;
  durationSeconds: number;
  polyline: string;
}

/**
 * Computes the group's planned route with the Routes API and writes it to
 * `rooms/{roomCode}/route`, where every rider's app picks it up.
 *
 * Only the room's host may call it, and only while a guided ride is being
 * planned. Calling it again replaces the previous route.
 */
export const getRoute = onCall(
  { region: REGION, secrets: [routesApiKey], maxInstances: 10 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to plan a ride.");
    }
    const input = parseRequest(request.data);

    const db = getDatabase();
    const room = db.ref(`rooms/${input.roomCode}`);
    const meta = (await room.child("meta").get()).val() as
      | { hostUid?: string; status?: string; mode?: string }
      | null;
    if (!meta) {
      throw new HttpsError("not-found", "No ride found for that code.");
    }
    if (meta.hostUid !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Only the host can choose the destination.",
      );
    }
    if (meta.mode !== "guided" || meta.status !== "planning") {
      throw new HttpsError(
        "failed-precondition",
        "This ride is not being planned.",
      );
    }

    const computed = await computeRoute(input, routesApiKey.value());
    const route = {
      destinationName: input.destination.name,
      destinationAddress: input.destination.address,
      latitude: input.destination.latitude,
      longitude: input.destination.longitude,
      distanceMeters: computed.distanceMeters,
      durationSeconds: computed.durationSeconds,
      polyline: computed.polyline,
      createdBy: uid,
    };
    await room.child("route").set({
      ...route,
      createdAt: ServerValue.TIMESTAMP,
    });
    return route;
  },
);

/** Validates the client payload; never trusts its shape. */
function parseRequest(data: unknown): RouteRequest {
  if (typeof data !== "object" || data === null) {
    throw invalid("Missing request data.");
  }
  const body = data as Record<string, unknown>;
  const roomCode = body.roomCode;
  if (typeof roomCode !== "string" || !ROOM_CODE_PATTERN.test(roomCode)) {
    throw invalid("Invalid room code.");
  }
  const origin = parseLatLng(body.origin, "origin");
  const destination = body.destination as Record<string, unknown> | undefined;
  const name = destination?.name;
  const address = destination?.address;
  if (
    typeof name !== "string" ||
    name.trim().length === 0 ||
    name.length > MAX_NAME_LENGTH
  ) {
    throw invalid("Invalid destination name.");
  }
  if (typeof address !== "string" || address.length > MAX_ADDRESS_LENGTH) {
    throw invalid("Invalid destination address.");
  }
  return {
    roomCode,
    origin,
    destination: {
      ...parseLatLng(destination, "destination"),
      name: name.trim(),
      address: address.trim(),
    },
  };
}

function parseLatLng(value: unknown, label: string): LatLng {
  const point = value as Record<string, unknown> | undefined;
  const latitude = point?.latitude;
  const longitude = point?.longitude;
  if (
    typeof latitude !== "number" ||
    typeof longitude !== "number" ||
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    Math.abs(latitude) > 90 ||
    Math.abs(longitude) > 180
  ) {
    throw invalid(`Invalid ${label} coordinates.`);
  }
  return { latitude, longitude };
}

function invalid(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

/**
 * Asks the Routes API for a two-wheeler route, falling back to driving where
 * two-wheeler routing is not available.
 */
async function computeRoute(
  input: RouteRequest,
  apiKey: string,
): Promise<ComputedRoute> {
  const route =
    (await requestRoute(input, apiKey, "TWO_WHEELER")) ??
    (await requestRoute(input, apiKey, "DRIVE"));
  if (!route) {
    throw new HttpsError(
      "not-found",
      "No route found to that destination. Try another place.",
    );
  }
  return route;
}

async function requestRoute(
  input: RouteRequest,
  apiKey: string,
  travelMode: "TWO_WHEELER" | "DRIVE",
): Promise<ComputedRoute | null> {
  const toWaypoint = (point: LatLng) => ({
    location: {
      latLng: { latitude: point.latitude, longitude: point.longitude },
    },
  });

  let response: Response;
  try {
    response = await fetch(ROUTES_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": ROUTES_FIELD_MASK,
      },
      body: JSON.stringify({
        origin: toWaypoint(input.origin),
        destination: toWaypoint(input.destination),
        travelMode,
        routingPreference: "TRAFFIC_AWARE",
        units: "METRIC",
      }),
      signal: AbortSignal.timeout(ROUTES_TIMEOUT_MS),
    });
  } catch (error) {
    logger.error("Routes API request failed", { travelMode, error });
    throw new HttpsError(
      "unavailable",
      "Could not reach the routing service. Try again.",
    );
  }

  if (!response.ok) {
    const detail = await response.text();
    // Some regions do not support two-wheeler routing; let the caller fall
    // back to driving.
    if (travelMode === "TWO_WHEELER" && response.status === 400) {
      logger.warn("Two-wheeler routing unavailable; using driving", { detail });
      return null;
    }
    logger.error("Routes API returned an error", {
      status: response.status,
      detail,
    });
    throw new HttpsError("internal", "Could not generate the route.");
  }

  const body = (await response.json()) as {
    routes?: Array<{
      distanceMeters?: number;
      duration?: string;
      polyline?: { encodedPolyline?: string };
    }>;
  };
  const first = body.routes?.[0];
  const polyline = first?.polyline?.encodedPolyline;
  if (!first || !polyline) return null;

  return {
    distanceMeters: first.distanceMeters ?? 0,
    // The API reports durations as e.g. "1834s".
    durationSeconds: Number.parseInt(first.duration ?? "0", 10) || 0,
    polyline,
  };
}

/**
 * Tests for the userSearch Firestore triggers.
 *
 * The v2 trigger's `.run` is the bare user handler (see firebase-functions
 * `firestore.js`: `func.run = handler`), so we invoke it with a minimal event
 * shaped to what the handler reads — `event.params.userId` and
 * `event.data.data()` (onCreate) / `event.data.before|after.data()` (onUpdate).
 */

import { clearDb, db } from "./setup";
import {
  syncUserSearchOnCreate,
  syncUserSearchOnUpdate,
} from "../src/users/syncUserSearch";

type Trigger = { run: (event: unknown) => unknown | Promise<unknown> };

const onCreate = syncUserSearchOnCreate as unknown as Trigger;
const onUpdate = syncUserSearchOnUpdate as unknown as Trigger;

function createEvent(userId: string, data: Record<string, unknown>) {
  return { params: { userId }, data: { data: () => data } };
}

function updateEvent(
  userId: string,
  before: Record<string, unknown>,
  after: Record<string, unknown>,
) {
  return {
    params: { userId },
    data: { before: { data: () => before }, after: { data: () => after } },
  };
}

async function getUserSearch(uid: string) {
  const snap = await db.collection("userSearch").doc(uid).get();
  return snap.exists ? (snap.data() as Record<string, unknown>) : null;
}

describe("syncUserSearchOnCreate", () => {
  afterEach(clearDb);

  it("writes name, name_lower, and photoUrl", async () => {
    await onCreate.run(
      createEvent("u1", { name: "Alice Smith", photoUrl: "http://x/a.png" }),
    );

    expect(await getUserSearch("u1")).toEqual({
      name: "Alice Smith",
      name_lower: "alice smith",
      photoUrl: "http://x/a.png",
    });
  });

  it("defaults photoUrl to null when absent", async () => {
    await onCreate.run(createEvent("u2", { name: "Bob" }));

    expect(await getUserSearch("u2")).toEqual({
      name: "Bob",
      name_lower: "bob",
      photoUrl: null,
    });
  });

  it("treats a missing name as an empty string", async () => {
    await onCreate.run(createEvent("u3", {}));

    expect(await getUserSearch("u3")).toEqual({
      name: "",
      name_lower: "",
      photoUrl: null,
    });
  });
});

describe("syncUserSearchOnUpdate", () => {
  afterEach(clearDb);

  it("updates the search doc when the name changes", async () => {
    await db
      .collection("userSearch")
      .doc("u1")
      .set({ name: "Old", name_lower: "old", photoUrl: null });

    await onUpdate.run(
      updateEvent("u1", { name: "Old" }, { name: "New Name" }),
    );

    expect(await getUserSearch("u1")).toEqual({
      name: "New Name",
      name_lower: "new name",
      photoUrl: null,
    });
  });

  it("updates when only the photoUrl changes", async () => {
    await onUpdate.run(
      updateEvent(
        "u1",
        { name: "Alice", photoUrl: null },
        { name: "Alice", photoUrl: "http://x/new.png" },
      ),
    );

    expect(await getUserSearch("u1")).toEqual({
      name: "Alice",
      name_lower: "alice",
      photoUrl: "http://x/new.png",
    });
  });

  it("skips the write when name and photoUrl are unchanged", async () => {
    // A marker field survives only if the handler returns without writing.
    await db.collection("userSearch").doc("u1").set({
      name: "Alice",
      name_lower: "alice",
      photoUrl: null,
      marker: "keep",
    });

    await onUpdate.run(
      updateEvent(
        "u1",
        { name: "Alice", photoUrl: null, bio: "before" },
        { name: "Alice", photoUrl: null, bio: "after" },
      ),
    );

    expect((await getUserSearch("u1"))?.marker).toBe("keep");
  });
});

/**
 * Tests for the listBoardGames callable: ordering, limit, prefix search, and
 * input validation. Catalog docs are seeded directly via the admin SDK.
 */

import { clearDb } from "./setup";
import {
  callListBoardGames,
  callListBoardGamesNoAuth,
} from "./helpers/callables";
import { seedBoardGame } from "./helpers/seed";

describe("listBoardGames", () => {
  afterEach(clearDb);

  it("returns games ordered by name ascending", async () => {
    await seedBoardGame("catan", "Catan");
    await seedBoardGame("azul", "Azul");
    await seedBoardGame("wingspan", "Wingspan");

    const result = await callListBoardGames({}, "u1");

    expect(result.games.map((g) => g.name)).toEqual([
      "Azul",
      "Catan",
      "Wingspan",
    ]);
  });

  it("maps gameId and name", async () => {
    await seedBoardGame("azul", "Azul");

    const result = await callListBoardGames({}, "u1");

    expect(result.games[0]).toEqual({ gameId: "azul", name: "Azul" });
  });

  it("respects the limit parameter", async () => {
    for (let i = 0; i < 5; i++) {
      await seedBoardGame(`g${i}`, `Game ${i}`);
    }

    const result = await callListBoardGames({ limit: 2 }, "u1");

    expect(result.games).toHaveLength(2);
  });

  it("prefix search returns only names starting with the query", async () => {
    await seedBoardGame("azul", "Azul");
    await seedBoardGame("azul-summer", "Azul Summer Pavilion");
    await seedBoardGame("catan", "Catan");

    const result = await callListBoardGames({ search: "Azul" }, "u1");

    expect(result.games.map((g) => g.name)).toEqual([
      "Azul",
      "Azul Summer Pavilion",
    ]);
  });

  it("prefix search is case-sensitive on the name field", async () => {
    await seedBoardGame("azul", "Azul");

    // Lowercase query does not match the capitalized `name` field.
    const result = await callListBoardGames({ search: "azul" }, "u1");

    expect(result.games).toHaveLength(0);
  });

  it("treats a blank search as no filter", async () => {
    await seedBoardGame("azul", "Azul");
    await seedBoardGame("catan", "Catan");

    const result = await callListBoardGames({ search: "   " }, "u1");

    expect(result.games).toHaveLength(2);
  });

  it("returns an empty list when the catalog is empty", async () => {
    const result = await callListBoardGames({}, "u1");
    expect(result.games).toEqual([]);
  });

  it("throws unauthenticated without auth", async () => {
    await expect(callListBoardGamesNoAuth({})).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  it("rejects a limit below 1", async () => {
    await expect(callListBoardGames({ limit: 0 }, "u1")).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  it("rejects a limit above 100", async () => {
    await expect(
      callListBoardGames({ limit: 101 }, "u1"),
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a non-integer limit", async () => {
    await expect(
      callListBoardGames({ limit: 2.5 }, "u1"),
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("rejects a search string longer than 100 characters", async () => {
    await expect(
      callListBoardGames({ search: "x".repeat(101) }, "u1"),
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});

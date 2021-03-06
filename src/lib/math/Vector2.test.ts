import { Vector2 } from "./Vector2";

describe("Vector2", () => {
  test("constructor defaults", () => {
    const a = new Vector2();
    expect(a.x).toBe(0);
    expect(a.y).toBe(0);
  });

  test("constructor values", () => {
    const b = new Vector2(1, 2);
    expect(b.x).toBe(1);
    expect(b.y).toBe(2);
  });

  test("clone", () => {
    const b = new Vector2(1, 2);
    const c = b.clone();
    expect(c.x).toBe(1);
    expect(c.y).toBe(2);
  });

  test("copy", () => {
    const b = new Vector2(1, 2);
    const d = new Vector2().copy(b);
    expect(d.x).toBe(1);
    expect(d.y).toBe(2);
  });
});

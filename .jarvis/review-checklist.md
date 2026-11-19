# Roblox code review checklist

You are reviewing ONE Luau file from a Roblox game. Claude wrote this code.
Your job is to find REAL problems a player would notice or could abuse.

## Facts about this codebase (do not report these as problems)

- Roblox runs server scripts one at a time. There are NO race conditions between
  two players touching the same thing in the same frame. Never report a "race condition".
- `src/server/Systems/Actions.luau` already rate-limits every client request and
  checks that the action name is a string. Do not report "no rate limiting".
- Values in `Config` and `Formulas` are written by the developer, not by players.
  Do not report "Config could be wrong" or "weights could be wrong".
- DataStore saving has retries, a session lock, autosave, and BindToClose.
  Do not report "autosave could lose a few minutes of data" unless you see a real bug.

## Check these, in this order

1. **Distance checks.** Exploiters can teleport their character anywhere and can
   fire `Touched` on any part from anywhere. They can also call any remote
   (`Actions.register(...)` handlers) directly, skipping ProximityPrompts. A
   ProximityPrompt's `MaxActivationDistance` does NOT protect a remote handler
   that calls the same function. So for every `.Touched` handler and every
   `Actions.register` handler that gives coins, items or pets, look for a line
   that compares the player's `HumanoidRootPart.Position` with the object's
   position (`.Magnitude`). If there is no such line, FAIL.
2. **Trusting the client.** Does the server use any number, price, amount, item
   or position that came from the client? It should only accept a NAME or ID and
   look up the real value itself.
3. **Argument checks.** Does every remote handler check `typeof(arg)` before using it?
4. **Spending.** Before taking coins or items, does it check that the player has
   enough? Can the amount ever go negative?
5. **Purchases (Robux).** Does ProcessReceipt save the data BEFORE returning
   `PurchaseGranted`? Does it ignore duplicate purchase ids?
6. **Leaks.** Are connections and per-player tables cleaned up when a player leaves?
7. **Plain bugs.** Wrong variable, off-by-one, a nil that is not handled, an
   infinite loop with no `task.wait`.

## How to answer

Go through checks 1 to 7 IN ORDER and answer every one, using exactly this format:

```
1. Distance checks: PASS / FAIL / N/A
   Evidence: <quote the line(s) you looked at, or "no such code in this file">
   (If FAIL) How a player abuses it: <one sentence>
   (If FAIL) Fix: <one or two sentences>
```

Rules:
- N/A means the file has no code of that kind at all. PASS needs a quoted line
  that proves it. If you can't quote proof, it is not a PASS.
- Then finish with one line: `Summary: <number> FAIL(s)` and the most serious one.
- No intro paragraph and no general advice.

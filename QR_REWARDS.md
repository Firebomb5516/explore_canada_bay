# Passport QR Rewards

Passport signs store their reward directly inside the QR code as a compact JSON
object. The app validates the object, rejects rewards from other apps, limits XP
and progress values, and remembers each `rewardId` so it cannot be claimed
twice on the same device.

## XP-only reward

```json
{
  "namespace": "explore_canada_bay.passport",
  "version": 1,
  "rewardId": "bay-run-finish-01",
  "place": "Bay Run Finish",
  "xp": 75
}
```

## XP and badge-progress reward

```json
{
  "namespace": "explore_canada_bay.passport",
  "version": 1,
  "rewardId": "cabarita-park-01",
  "place": "Cabarita Park",
  "xp": 40,
  "badge": {
    "id": "nature_trail",
    "name": "Nature Trail",
    "description": "Discover parks, wildlife and native habitats.",
    "category": "Nature",
    "icon": "eco",
    "color": "#00B87A",
    "target": 5,
    "progress": 1
  }
}
```

## Instant badge reward

Set `unlock` to `true` for a rare code that completes its badge immediately.

```json
{
  "namespace": "explore_canada_bay.passport",
  "version": 1,
  "rewardId": "yaralla-heritage-special-01",
  "place": "Yaralla Estate",
  "xp": 100,
  "badge": {
    "id": "heritage_hunter",
    "name": "Heritage Hunter",
    "description": "Uncover the stories behind local landmarks.",
    "category": "Heritage",
    "icon": "museum",
    "color": "#5FA8FF",
    "target": 4,
    "progress": 1,
    "unlock": true
  }
}
```

## Validation rules

- `namespace` must be `explore_canada_bay.passport`.
- `version` must currently be `1`.
- Every physical reward needs a unique `rewardId` of at most 80 characters.
- `place` is required and limited to 100 characters.
- `xp` must be an integer from 0 to 500.
- Badge targets are limited to 1–50 and progress cannot exceed the target.
- Known badge IDs are `nature_trail`, `food_finder`, `heritage_hunter`, and
  `foreshore_walker`. New IDs also work and appear as new passport badges.

The scanner screen includes an **Enter code** option and a demo payload for
testing without a physical QR code.

## Production security

Plain QR JSON is suitable for this school-project prototype, but it can be
copied or recreated. A public production rewards program should replace it with
a server-redeemed one-time token or a digitally signed payload. Never store a
private signing key in the app.

# Blockora remote levels

Firebase Remote Config parameter name: `blockora_levels_json` (String).

Paste this JSON in the Firebase Console and publish Remote Config.
The app uses the bundled default levels if Firebase is unavailable or the JSON is invalid.
Level numbers must be sequential starting at 1, targets must be strictly increasing positive integers.

```json
${JSON.stringify({levels:[500,1000,1800,2800,4000,5500,7500,10000,13000,17000].map((target,i)=>({level:i+1,target}))},null,2)}
```

Note: Publishing this parameter in Firebase Console is a separate owner action.

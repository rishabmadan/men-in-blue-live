# Men in Blue Live 🏏🇮🇳

Production-ready, ad-free iOS Live Activity cricket score tracking system designed to bypass native Apple background execution limits by matching a Python serverless backend with an ActivityKit client via secure APNs push channels.

## Key Features

- **Dynamic Island & Lock Screen**: Styled in true dark mode (Color.black) with expanded, compact, and minimal presentation states.
- **Strict Country Filter**: Dual-layer refusal logic. The system refuses to track, save, push, or initialize any Live Activity if neither participant matches `India` or `IND`.
- **Serverless Ingestion**: Python (Vercel/Supabase compatible) cron worker running on `* * * * *` to fetch live cricket status, sign ES256 JWTs using Apple `.p8` keys, and transmit push payloads over HTTP/2.
- **Zero Ads**: 100% free of third-party ad networks, tracking SDKs, and telemetry.

## Directory Structure

```text
├── iOS/
│   ├── MenInBlueLive/
│   │   ├── LiveScoreManager.swift   # ActivityKit lifecycle & token uploader
│   │   └── Info.plist               # NSSupportsLiveActivities configuration
│   └── MenInBlueLiveWidget/
│       └── CricketWidget.swift      # Lock Screen banner & Dynamic Island views
├── backend/
│   ├── api/
│   │   └── index.py                 # Vercel serverless token store & cron engine
│   ├── vercel.json                  # Cron scheduler (* * * * *) & routes
│   ├── requirements.txt             # PyJWT, cryptography, httpx[http2]
│   └── .env.example                 # Environment variables template
└── .github/
    └── workflows/
        └── build.yml                # Automated macOS TestFlight CI/CD pipeline
```

## Quick Start

### 1. Deploy Backend to Vercel
1. Create a new repository on GitHub: `https://github.com/rishabmadan/men-in-blue-live`
2. Push this codebase to GitHub.
3. Import the repository in [Vercel](https://vercel.com) and set the Root Directory to `backend`.
4. Configure environment variables in Vercel (`APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_P8_KEY`, `IOS_BUNDLE_ID`, `APNS_ENVIRONMENT`, `CRICKET_API_KEY`).

### 2. Configure iOS App
1. Set `backendBaseURL` in `LiveScoreManager.swift` to your Vercel deployment URL.
2. In your Xcode Project / GitHub Actions workflow, ensure `NSSupportsLiveActivities` is enabled.
3. Deploy to TestFlight and install on iPhone.

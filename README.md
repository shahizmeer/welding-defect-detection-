# welding-defect-detection-

Flutter app (`firstly/`) + Python Flask API (`backend/`) for weld detection and score prediction.

## Backend

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Copy `backend/.env.example` to `backend/.env` and fill in your Cloudinary credentials.

Place these files in `backend/` (not in Git — too large):

- `best.pt`
- `final_score_model_xgboost.pkl`

```powershell
python app.py
```

Server runs at `http://0.0.0.0:5000`.

## Flutter app

```powershell
cd firstly
flutter pub get
flutter run --dart-define=API_HOST=YOUR_PC_IP
```

- Android emulator: `--dart-define=API_HOST=10.0.2.2`
- Physical phone (same Wi‑Fi): your PC IP from `ipconfig` (e.g. `192.168.x.x`)
- Windows desktop: omit `API_HOST` (uses `127.0.0.1`)

## Push to GitHub

1. Create a new empty repo on [github.com](https://github.com/new) (e.g. `WeldAI`).
2. In PowerShell, from this folder (`weldai`):

```powershell
git config --global --add safe.directory D:/flutterapps/weldai
cd D:\flutterapps\weldai
git add .
git status
git commit -m "Initial commit: WeldAI Flutter app and Flask backend"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/WeldAI.git
git push -u origin main
```

Replace `YOUR_USERNAME` and repo name with yours.

**Do not commit:** `backend/.env`, model files (`.pt`, `.pkl`), `backend/uploads/`, `firstly/build/`.

If Git says "dubious ownership", run the `safe.directory` line above once.

# SpendSense

## Run the receipt prediction API

Receipt item classification requires the FastAPI service to be running on the
same computer as the ML model. From the project root:

```powershell
python -m uvicorn backend.app:app --host 0.0.0.0 --port 8000
```

The phone and computer must be on the same network. The app's default API URL is
`http://192.168.1.9:8000`; if the computer's LAN address changes, launch Flutter
with the current address:

```powershell
flutter run --dart-define=ML_API_BASE_URL=http://<computer-lan-ip>:8000
```

For an Android emulator, use `http://10.0.2.2:8000` as the base URL. Prediction
failures preserve an item’s existing OCR category; items without one remain
editable in the receipt review screen.

# SustAIn

A mobile-first Flutter app that helps households cut food waste. Scan a grocery receipt, a handwritten shopping list, or a barcode, and SustAIn builds your kitchen inventory, estimates when each item will spoil, nudges you to cook it before it does, and shows you what you saved in CO2, water, energy, and money.

Built with Flutter, Firebase, and the OpenAI API. Runs on Android and iOS from one codebase.

---

## What it does

### Capture your groceries three ways

**Receipt scanning.** Photograph a printed receipt and SustAIn extracts the line items. The parser is store-agnostic: instead of hardcoding rules per retailer, it locates the item block by scoring lines on price and quantity density, collapses continuation fragments like `@ $2.99/kg` or a bare `0.165 kg` onto the item above them, strips noise (loyalty lines, payment methods, phone numbers, postal codes, dates), and stops at the totals boundary. Output is a clean list of `{name, qty, unit}` with duplicates merged.

**Handwritten lists.** Point the camera at a handwritten grocery list. Images run through a preprocessing step (crop, enhance) before OCR, then a cleanup pass strips bullets and leading numbers and splits comma-joined entries so "milk, eggs" becomes two items.

**Barcodes.** Scan a product barcode and SustAIn looks it up against Open Food Facts, falling back from the v3 to the v2 endpoint when a product only has legacy data.

### Know when things expire

Items are enriched with metadata from Spoonacular and shelf-life estimates derived from the USDA FoodKeeper dataset, so each item in your inventory carries a realistic expiry date rather than one you have to enter yourself.

### Get nudged before food goes bad

Local notifications fire for items approaching expiry, with randomized, deliberately light-hearted copy: *"Your spinach is sitting in the fridge like a forgotten roommate, want to cook with it?"* The goal is a reminder you'll act on rather than one you'll mute.

### Cook what you already have

Browse recipes by category, save and favourite them, and generate a grocery list from a recipe. Ingredients you buy are fuzzy-matched against your grocery list so "potatoes," "potato," and "peeled potato" resolve to the same entry.

### Ask FoodBot

An in-app chatbot backed by OpenAI `gpt-4o-mini`, scoped by system prompt to food storage, shelf life, expiry, preservation methods, and freshness. Ask it whether you can freeze cooked rice or how long opened yogurt lasts. It politely declines anything off-topic.

### See your impact

The waste dashboard aggregates what you consumed versus what expired and reports:

- **CO2, water, energy, and money saved**, computed per-kilogram from an impact factor table loaded from CSV, with exact-key lookup (`veg.tomato`) falling back to a leaf match (`tomato`)
- **Missed savings** from items that expired, framed positively rather than as a scolding
- **Waste diverted %**, consumed mass over total mass

Raw numbers get translated into things people can picture: kilometres of driving avoided, showers' worth of water, days of household electricity. Constants are centralized and documented with their sources, so they can be retuned per region.

---

## Tech stack

| Layer | What's used |
|---|---|
| Framework | Flutter (Dart SDK ^3.9.2) |
| State | Provider, Riverpod |
| Auth & data | Firebase Auth, Google Sign-In, Cloud Firestore |
| Local storage | sqflite, shared_preferences |
| OCR | Google ML Kit Text Recognition, Google ML Kit Document Scanner, Google Cloud Vision (`DOCUMENT_TEXT_DETECTION`) |
| Barcode | Google ML Kit Barcode Scanning, Open Food Facts |
| AI | OpenAI Chat Completions (`gpt-4o-mini`) |
| External data | Spoonacular, USDA FoodKeeper |
| UI | Material 3, google_fonts, fl_chart, flutter_chat_ui |
| Notifications | flutter_local_notifications, permission_handler |

---

## Project structure

```
lib/
├── main.dart                  App entry, Firebase init, auth gate
├── firebase_options.dart
├── app/                       Theme
├── features/
│   ├── Login/                 Sign in, account creation, household survey
│   ├── home/
│   │   ├── inventory/         Inventory tab
│   │   ├── User_inventory/    Inventory detail
│   │   └── receipe/           Recipes, categories, favourites, grocery list
│   ├── ocr_scan/
│   │   ├── domain/            Receipt parser, handwriting pipeline, image
│   │   │                      preprocessing, Cloud Vision, product lookup
│   │   └── presentation/      Scan page, finder overlay, edit sheet
│   ├── chatbot/               FoodBot chat page and OpenAI service
│   └── account/               Profile, password, help, about
├── waste_dashboard/
│   ├── domain/services/       Impact calculator, equivalency mapper
│   ├── data/impact_factors/   Per-kg factor table (CSV)
│   └── presentation/          Dashboard and summary cards
├── services/                  Inventory, grocery, notification services
├── utils/                     Ingredient normalization
└── widgets/                   Shared widgets
```

The OCR and waste dashboard features follow a domain/presentation split, keeping parsing and calculation logic testable and free of Flutter imports.

---

## Running it locally

**Prerequisites:** Flutter SDK (Dart ^3.9.2), a Firebase project, and API keys for the services below.

```bash
git clone https://github.com/Krupalmewada/sust_ai_n.git
cd sust_ai_n
flutter pub get
```

**1. Firebase.** Run `flutterfire configure` against your own Firebase project to regenerate `lib/firebase_options.dart`, and enable Email/Password and Google sign-in methods in the Firebase console.

**2. API keys.** Create `assets/keys.env` (gitignored, never commit it):

```
SpoonacularapiKey=your_spoonacular_key
chatBotApiKey=your_openai_key
cloudVisionApiKey=your_google_cloud_vision_key
```

**3. Run.**

```bash
flutter run
```

The app needs camera and notification permissions on first launch.

---

## Known limitations

- **API keys ship in the client.** Keys are loaded from a bundled `.env` asset, which means they are extractable from a built APK. A production version would proxy these calls through a backend so no key reaches the device.
- **Receipt parsing is heuristic.** It generalizes across stores by design, but unusual receipt layouts will produce misreads. The edit sheet exists so users can correct items before they hit inventory.
- **Impact factors are approximations.** Values are per-kilogram averages with Canadian grid intensity assumed at 0.12 kg CO2e/kWh. Useful for relative comparison, not for precise carbon accounting.
- **Shelf-life estimates are dataset-driven,** not measured. Treat them as guidance, not a guarantee of food safety.
- **Test coverage is minimal.**

---

## Roadmap

- Move third-party API calls behind a backend so keys leave the client
- Broaden the impact factor table and make grid intensity province-aware
- Unit tests for the receipt parser and impact calculator, the two most logic-heavy modules
- Offline-first inventory sync

---

## Author

**Krupal Mewada** · [GitHub](https://github.com/Krupalmewada) · [LinkedIn](https://www.linkedin.com/in/krupal-mewada/) · [Portfolio](https://krupalmewada.github.io/portfolio/v2/)

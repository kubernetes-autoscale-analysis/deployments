# Kontekst projektu – środowisko testowe do pracy magisterskiej

## 🎯 Cel projektu
Celem jest przeprowadzenie testów obciążeniowych oraz analizy porównawczej wydajności trzech implementacji aplikacji REST API realizujących operację mnożenia macierzy o złożoności O(n³), działających w różnych środowiskach wykonawczych oraz modelach skalowania.

---

## 🧪 Testowane aplikacje

Każda aplikacja udostępnia endpoint REST API przyjmujący parametr `matrixSize` i wykonujący operację mnożenia macierzy:

- **WASM Kotlin (WASI)**
- **WASM C++ (WASI)**
- **Kotlin Spring Boot (JVM)**

Algorytm bazowy:

- generuje dwie macierze `n x n` wypełnione wartościami `1.0`
- wykonuje klasyczne mnożenie macierzy (trzy zagnieżdżone pętle)
- oblicza checksum wynikowej macierzy

Złożoność obliczeniowa: **O(n³)**

---

## ☸️ Środowiska uruchomieniowe

### 🔹 Lokalny Kubernetes (główne środowisko badawcze)

Uruchomiony lokalnie przy użyciu:
- Kind (Kubernetes in Docker)

Testowane strategie autoskalowania:

1. **HPA (Horizontal Pod Autoscaler)**
    - skalowanie na podstawie CPU

2. **VPA (Vertical Pod Autoscaler)**
    - dynamiczna zmiana zasobów kontenera

3. **KEDA (Kubernetes Event-Driven Autoscaling)**
    - skalowanie na podstawie zdarzeń (event-driven)

---

### ⚡ Serverless (środowisko walidacyjne)

- Google Cloud Run

Cechy:
- automatyczne skalowanie
- skalowanie do zera
- model pay-per-use

---

## 🧰 Narzędzia testowe i monitoring

### 🔹 Generowanie ruchu
- k6

Zastosowanie:
- symulacja użytkowników (VU – virtual users)
- testy obciążeniowe i wydajnościowe

---

### 🔹 Zbieranie i analiza danych

#### Metryki:
- latency (avg, p95, p99)
- throughput (requests per second)
- error rate
- zużycie CPU i pamięci
- liczba instancji (autoscaling behavior)

#### Stack monitoringowy:
- Prometheus – zbieranie metryk
- Grafana – wizualizacja
- InfluxDB – baza danych time-series (dla k6)

---

## 📊 Scenariusze testowe

### Parametry:
- `matrixSize`: np. 100, 200, 500
- liczba użytkowników (VU): np. 10, 50, 100

### Scenariusze:
- brak autoskalowania (baseline)
- HPA
- VPA
- KEDA
- serverless (Cloud Run)

Każdy scenariusz wykonywany dla wszystkich trzech aplikacji.

---

## 🔍 Cele analizy

Porównanie:

1. **Wydajność**
    - czas odpowiedzi
    - przepustowość

2. **Efektywność skalowania**
    - czas reakcji autoscalera
    - stabilność systemu

3. **Zużycie zasobów**
    - CPU / RAM

4. **Model uruchomieniowy**
    - Kubernetes vs Serverless

5. **Technologia wykonawcza**
    - WebAssembly vs JVM

---

## 🧠 Hipotezy badawcze (przykładowe)

- WASM może oferować niższe zużycie zasobów niż JVM
- Serverless lepiej radzi sobie z burst traffic
- HPA zapewnia lepszą responsywność niż VPA przy workloadach CPU-bound
- KEDA jest bardziej efektywna przy event-driven scenariuszach

---

## 🧩 Architektura eksperymentu

### Lokalnie:
- Kubernetes (Kind)
- aplikacje jako Deployment + Service
- autoscaling (HPA/VPA/KEDA)
- monitoring (Prometheus + Grafana)
- testy (k6)

### Chmura:
- Cloud Run (deployment aplikacji)
- k6 jako generator ruchu
- porównanie wyników z lokalnym środowiskiem

---

## 💡 Uzasadnienie podejścia

- Lokalny Kubernetes umożliwia:
    - pełną kontrolę środowiska
    - brak kosztów
    - powtarzalność eksperymentów

- Cloud Run:
    - reprezentuje realne środowisko serverless
    - pozwala na walidację wyników

---

## 🚀 Rezultat końcowy

Kompleksowa analiza porównawcza:
- różnych technologii (WASM vs JVM)
- różnych strategii autoskalowania
- różnych modeli infrastruktury (Kubernetes vs Serverless)

z uwzględnieniem:
- wydajności
- skalowalności
- efektywności kosztowej
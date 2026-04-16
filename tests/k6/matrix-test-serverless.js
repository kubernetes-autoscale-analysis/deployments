import http from 'k6/http';
import { check, sleep } from 'k6';

// --- KONFIGURACJA SUPABASE ---
const SUPABASE_URL = __ENV.SUPABASE_URL || 'https://bluttrfvtwqwbcoguykq.supabase.co';
const SUPABASE_KEY = __ENV.SUPABASE_KEY || 'sb_secret_Arc46qK_KVhNe_vPRdQmqA_FAJGjYeA';

export const options = {
    vus: __ENV.VUS || 1,
    duration: __ENV.DURATION || '30s',
    setupTimeout: '300s', // Dłuższy timeout na wybudzenie instancji (Cold Start)
};

// --- PARAMETRY ŚRODOWISKA ---
const MATRIX_SIZE = __ENV.MATRIX_SIZE || 100;
const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const APP_TYPE = __ENV.APP_TYPE || 'Unknown';

// Funkcja setup wykonuje się RAZ przed właściwym testem
// Idealne miejsce na zmierzenie Cold Startu
export function setup() {
    console.log(`⏳ Budzenie instancji (Cold Start) dla: ${APP_TYPE}...`);
    const url = `${BASE_URL}/api/stress-test?matrixSize=${MATRIX_SIZE}`;
    
    const start = Date.now();
    const res = http.get(url, { timeout: '240s' }); // Długi timeout na pierwsze zapytanie
    const end = Date.now();

    const isOk = check(res, {
        'cold start status 200': (r) => r.status === 200,
        'cold start has result': (r) => r.body && r.body.includes('checksum'),
    });

    const coldStartTime = isOk ? (end - start) : 0;
    console.log(`⏱️ Cold Start zakończony: ${coldStartTime}ms (Status: ${res.status})`);

    return { coldStartTime: coldStartTime };
}

export default function (data) {
    const url = `${BASE_URL}/api/stress-test?matrixSize=${MATRIX_SIZE}`;
    const res = http.get(url);

    check(res, {
        'is status 200': (r) => r.status === 200,
        'has result': (r) => r.body && r.body.includes('checksum'),
    });

    sleep(1);
}

export function handleSummary(data) {
    // Pobieramy dane z funkcji setup
    const coldStartTime = data.setup_data ? data.setup_data.coldStartTime : 0;
    
    console.log(`📊 Przygotowywanie raportu serverless dla: ${APP_TYPE}`);

    const durationSeconds = Math.round(data.state.testRunDurationMs / 1000);
    const endTime = Date.now();
    const startTimeIso = new Date(endTime - data.state.testRunDurationMs).toISOString();

    const appTypeIds = {
        'C++': 1,
        'Kotlin Spring Boot': 2,
        'Kotlin WASM WASI': 3
    };

    const payload = {
        rodzaj_aplikacji_id: appTypeIds[APP_TYPE] || null,
        zimne_uruchomienie: parseFloat(coldStartTime.toFixed(2)),
        czas_odpowiedzi: parseFloat(data.metrics.http_req_duration.values['p(95)'].toFixed(2)),
        przepustowosc: Math.round(data.metrics.http_reqs.values.rate),
        max_zuzycie_cpu: null,
        max_zuzycie_ram: null,
        liczba_instancji_podow: null,
        rozmiar_macierzy: parseInt(MATRIX_SIZE),
        wirtualni_uzytkownicy: parseInt(__ENV.VUS || options.vus),
        czas_trwania_testu: durationSeconds,
        data_realizacji_testu: startTimeIso
    };

    console.log(`📤 Wysyłanie do Supabase (Tabela: pomiary_serverless):`, JSON.stringify(payload));

    const supabaseResponse = http.post(
        `${SUPABASE_URL}/rest/v1/pomiary_serverless`,
        JSON.stringify(payload),
        {
            headers: {
                'apikey': SUPABASE_KEY,
                'Authorization': `Bearer ${SUPABASE_KEY}`,
                'Content-Type': 'application/json',
                'Prefer': 'return=representation'
            }
        }
    );

    if (supabaseResponse.status >= 200 && supabaseResponse.status < 300) {
        console.log('✅ Wyniki zapisane pomyślnie!');
    } else {
        console.error(`❌ Błąd zapisu w Supabase (${supabaseResponse.status}):`, supabaseResponse.body);
    }

    return { 'stdout': JSON.stringify(data) };
}

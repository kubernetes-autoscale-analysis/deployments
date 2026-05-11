import http from 'k6/http';
import { check, sleep } from 'k6';

// --- KONFIGURACJA SUPABASE ---
const SUPABASE_URL = __ENV.SUPABASE_URL || 'https://bluttrfvtwqwbcoguykq.supabase.co';
const SUPABASE_KEY = __ENV.SUPABASE_KEY || 'sb_secret_Arc46qK_KVhNe_vPRdQmqA_FAJGjYeA';

export const options = {
    vus: __ENV.VUS || 1,
    duration: __ENV.DURATION || '30s',
    setupTimeout: '120s',
};

// --- PARAMETRY ŚRODOWISKA ---
const MATRIX_SIZE = __ENV.MATRIX_SIZE || 100;
const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const APP_TYPE = __ENV.APP_TYPE || 'Unknown';
const SCALING_TYPE = __ENV.SCALING_TYPE || 'hpa';

// Pomiar zimnego startu (pierwsze zapytanie)
export function setup() {
    console.log(`⏳ Pierwsze zapytanie (Cold Start check) dla: ${APP_TYPE}...`);
    const url = `${BASE_URL}/api/stress-test?matrixSize=${MATRIX_SIZE}`;
    
    const start = Date.now();
    const res = http.get(url, { timeout: '60s' });
    const end = Date.now();

    const isOk = check(res, {
        'setup status 200': (r) => r.status === 200,
        'setup has result': (r) => r.body && r.body.includes('checksum'),
    });

    const coldStartTime = isOk ? (end - start) : 0;
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
    const coldStartTime = data.setup_data ? data.setup_data.coldStartTime : 0;
    
    console.log(`📊 Przygotowywanie raportu dla: ${APP_TYPE} (${SCALING_TYPE})`);

    const durationSeconds = Math.round(data.state.testRunDurationMs / 1000);
    const endTime = Date.now();
    const startTimeIso = new Date(endTime - data.state.testRunDurationMs).toISOString();
    const startTimeSeconds = Math.floor((endTime - data.state.testRunDurationMs) / 1000);

    // 1. Pobieranie metryk z Prometheusa
    const promUrl = 'http://localhost:9090/api/v1/query';
    const queries = {
        cpu_usage: `max_over_time(sum(irate(container_cpu_usage_seconds_total{pod=~"wasm-app-.*", container="wasm-app"}[30s]))[${durationSeconds}s:1s])`,
        cpu_limit: `max(kube_pod_container_resource_limits{resource="cpu", pod=~"wasm-app-.*", container="wasm-app"})`,
        ram_usage: `max_over_time(sum(container_memory_working_set_bytes{pod=~"wasm-app-.*", container="wasm-app"})[${durationSeconds}s:1s])`,
        ram_limit: `max(kube_pod_container_resource_limits{resource="memory", pod=~"wasm-app-.*", container="wasm-app"})`,
        pods: `max_over_time(count(kube_pod_status_phase{phase="Running", pod=~"wasm-app-.*"})[${durationSeconds}s:1s])`,
        restarts: `count(kube_pod_created{pod=~"wasm-app-.*"} > ${startTimeSeconds})`
    };

    let rawMetrics = { cpu_usage: 0, cpu_limit: 0, ram_usage: 0, ram_limit: 0, pods: 0, restarts: 0 };

    try {
        for (let key in queries) {
            let res = http.get(`${promUrl}?query=${encodeURIComponent(queries[key])}`);
            if (res.status === 200) {
                let json = JSON.parse(res.body);
                if (json.data.result.length > 0) {
                    rawMetrics[key] = parseFloat(json.data.result[0].value[1]);
                }
            }
        }
    } catch (e) {
        console.error('❌ Błąd podczas odczytu z Prometheusa:', e);
    }

    const cpu_percent = rawMetrics.cpu_limit > 0 ? (rawMetrics.cpu_usage / rawMetrics.cpu_limit) * 100 : 0;
    const ram_percent = rawMetrics.ram_limit > 0 ? (rawMetrics.ram_usage / rawMetrics.ram_limit) * 100 : 0;

    const appTypeIds = {
        'C++': 1,
        'Kotlin Spring Boot': 2,
        'Kotlin WASM WASI': 3
    };

    // Konwersja zimnego startu na sekundy (dla lepszej czytelności przy dużych wartościach)
    const coldStartSeconds = parseFloat((coldStartTime / 1000).toFixed(3));

    const payload = {
        rodzaj_aplikacji_id: appTypeIds[APP_TYPE] || null,
        scenariusz_id: parseInt(__ENV.SCENARIO_ID) || null,
        zimne_uruchomienie: coldStartSeconds,
        czas_odpowiedzi: parseFloat(data.metrics.http_req_duration.values['p(95)'].toFixed(2)),
        przepustowosc: Math.round(data.metrics.http_reqs.values.rate),
        max_zuzycie_cpu: parseFloat(cpu_percent.toFixed(2)),
        max_zuzycie_ram: parseFloat(ram_percent.toFixed(2)),
        liczba_instancji_podow: Math.round(rawMetrics.pods),
        liczba_restartow: Math.round(rawMetrics.restarts),
        rozmiar_macierzy: parseInt(MATRIX_SIZE),
        wirtualni_uzytkownicy: parseInt(__ENV.VUS || options.vus),
        czas_trwania_testu: durationSeconds,
        data_realizacji_testu: startTimeIso
    };

    console.log(`📤 Wysyłanie do Supabase (Tabela: pomiary_${SCALING_TYPE}):`, JSON.stringify(payload));

    const supabaseResponse = http.post(
        `${SUPABASE_URL}/rest/v1/pomiary_${SCALING_TYPE}`,
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

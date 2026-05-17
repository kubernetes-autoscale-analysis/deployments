import http from 'k6/http';
import { check, sleep } from 'k6';

// --- KONFIGURACJA SUPABASE ---
const SUPABASE_URL = __ENV.SUPABASE_URL || 'https://bluttrfvtwqwbcoguykq.supabase.co';
const SUPABASE_KEY = __ENV.SUPABASE_KEY || 'sb_secret_Arc46qK_KVhNe_vPRdQmqA_FAJGjYeA';

export const options = {
    vus: __ENV.VUS || 1,
    duration: __ENV.DURATION || '30s',
    setupTimeout: '300s',
};

// --- PARAMETRY ŚRODOWISKA ---
const MATRIX_SIZE = __ENV.MATRIX_SIZE || 100;
const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const APP_TYPE = __ENV.APP_TYPE || 'Unknown';
const SCALING_TYPE = __ENV.SCALING_TYPE || 'hpa';
const HTTP_HOST = __ENV.HTTP_HOST || '';

// Pomiar zimnego startu (pętla do skutku)
export function setup() {
    console.log(`⏳ Oczekiwanie na dostępność aplikacji (${APP_TYPE})...`);
    const url = `${BASE_URL}/api/stress-test?matrixSize=${MATRIX_SIZE}`;
    const params = HTTP_HOST ? { headers: { 'Host': HTTP_HOST }, timeout: '15s' } : { timeout: '15s' };
    
    const startTime = Date.now();
    let isOk = false;
    let attempts = 0;
    let lastRes = null;

    // Próbujemy przez max 5 minut (zgodnie z setupTimeout: '300s')
    while (Date.now() - startTime < 290000) {
        attempts++;
        try {
            lastRes = http.get(url, params);
            
            if (lastRes.status === 200 && lastRes.body && lastRes.body.includes('checksum')) {
                isOk = true;
                break;
            }
            
            if (attempts % 5 === 0) {
                console.log(`... próba ${attempts}, status: ${lastRes.status}, czas: ${Math.round((Date.now() - startTime)/1000)}s`);
            }
        } catch (e) {
            if (attempts % 5 === 0) console.log(`... próba ${attempts}, błąd połączenia, czas: ${Math.round((Date.now() - startTime)/1000)}s`);
        }
        
        sleep(0.5); // 500ms przerwy między strzałami
    }

    const endTime = Date.now();
    const coldStartTime = isOk ? (endTime - startTime) : 0;

    if (isOk) {
        console.log(`✅ Aplikacja gotowa po ${coldStartTime}ms (${attempts} prób)`);
    } else {
        console.error(`❌ Aplikacja nie wstała! Ostatni status: ${lastRes ? lastRes.status : 'brak'}`);
    }

    return { coldStartTime: coldStartTime };
}

export default function (data) {
    const url = `${BASE_URL}/api/stress-test?matrixSize=${MATRIX_SIZE}`;
    const params = { timeout: '180s' };
    if (HTTP_HOST) {
        params.headers = { 'Host': HTTP_HOST };
    }
    const res = http.get(url, params);

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
    
    // Zwiększamy zakres czasu dla limitów, aby złapać je nawet jeśli pody już zniknęły
    const queries = {
        cpu_usage: `sum(max_over_time(irate(container_cpu_usage_seconds_total{pod=~"wasm-app-.*", container="wasm-app"}[1m])[${durationSeconds}s:1s]))`,
        cpu_limit: `max_over_time(max(kube_pod_container_resource_limits{resource="cpu", pod=~"wasm-app-.*", container="wasm-app"})[${durationSeconds}s:1s])`,
        ram_usage: `sum(max_over_time(container_memory_working_set_bytes{pod=~"wasm-app-.*", container="wasm-app"}[${durationSeconds}s:1s]))`,
        ram_limit: `max_over_time(max(kube_pod_container_resource_limits{resource="memory", pod=~"wasm-app-.*", container="wasm-app"})[${durationSeconds}s:1s])`,
        pods: `max(kube_deployment_status_replicas_available{deployment="wasm-app"})`,
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

    // Liczba instancji to zamierzona liczba replik (dla VPA zwykle 2)
    const intendedReplicas = Math.round(rawMetrics.pods) || 2;
    // Restart to liczba nowych podów stworzonych W TRAKCIE testu
    const detectedRestarts = Math.max(0, Math.round(rawMetrics.restarts));

    // Jeśli chcemy procent, to musimy uważać na sumowanie usage vs max limit
    // Dla 2 replik, cpu_usage to suma szczytów obu podów. cpu_limit to max limit jednego poda.
    // Poprawny procent obciążenia względem sumarycznego limitu:
    const total_cpu_limit = rawMetrics.cpu_limit * intendedReplicas;
    const total_ram_limit = rawMetrics.ram_limit * intendedReplicas;

    const cpu_percent = total_cpu_limit > 0 ? (rawMetrics.cpu_usage / total_cpu_limit) * 100 : 0;
    const ram_percent = total_ram_limit > 0 ? (rawMetrics.ram_usage / total_ram_limit) * 100 : 0;

    const appTypeIds = {
        'C++': 1,
        'Kotlin Spring Boot': 2,
        'Kotlin WASM WASI': 3
    };

    // Konwersja zimnego startu na sekundy (dla lepszej czytelności przy dużych wartościach)
    const coldStartSeconds = parseFloat((coldStartTime / 1000).toFixed(3));

    // Bezpieczne pobieranie metryk k6 (na wypadek gdyby żaden test nie przeszedł)
    const p95_duration = (data.metrics.http_req_duration && data.metrics.http_req_duration.values) 
        ? parseFloat(data.metrics.http_req_duration.values['p(95)'].toFixed(2)) 
        : 0;
    
    const req_rate = (data.metrics.http_reqs && data.metrics.http_reqs.values)
        ? Math.round(data.metrics.http_reqs.values.rate)
        : 0;

    const payload = {
        rodzaj_aplikacji_id: appTypeIds[APP_TYPE] || null,
        scenariusz_id: parseInt(__ENV.SCENARIO_ID) || null,
        zimne_uruchomienie: coldStartSeconds,
        czas_odpowiedzi: p95_duration,
        przepustowosc: req_rate,
        max_zuzycie_cpu: parseFloat(cpu_percent.toFixed(2)),
        max_zuzycie_ram: parseFloat(ram_percent.toFixed(2)),
        liczba_instancji_podow: intendedReplicas,
        liczba_restartow: detectedRestarts,
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

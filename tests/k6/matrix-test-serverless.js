import http from 'k6/http';
import { check, sleep } from 'k6';

const SUPABASE_URL = __ENV.SUPABASE_URL || 'https://bluttrfvtwqwbcoguykq.supabase.co';
const SUPABASE_KEY = __ENV.SUPABASE_KEY || 'sb_secret_Arc46qK_KVhNe_vPRdQmqA_FAJGjYeA';

export const options = {
    vus: __ENV.VUS || 1,
    duration: __ENV.DURATION || '30s',
};

const MATRIX_SIZE = __ENV.MATRIX_SIZE || 100;
const BASE_URL = __ENV.BASE_URL || 'http://localhost';
const APP_TYPE = __ENV.APP_TYPE || 'Unknown';
const SCALING_TYPE = 'serverless';

let firstSuccessTime = 0;
const startTime = Date.now();

export default function () {
    const url = `${BASE_URL}/api/stress-test?matrixSize=${MATRIX_SIZE}`;
    const res = http.get(url);

    const isOk = check(res, {
        'is status 200': (r) => r.status === 200,
        'has result': (r) => r.body.includes('checksum'),
    });

    if (isOk && firstSuccessTime === 0) {
        firstSuccessTime = Date.now() - startTime;
    }

    sleep(1);
}

export function handleSummary(data) {
    console.log(`📊 Przygotowywanie raportu serverless dla: ${APP_TYPE}`);

    const durationSeconds = Math.round(data.state.testRunDurationMs / 1000);
    const endTime = Date.now();
    const startTimeIso = new Date(endTime - data.state.testRunDurationMs).toISOString();

    const cpu_usage = null;
    const ram_usage = null;
    const pods = null;

    const appTypeIds = {
        'C++': 1,
        'Kotlin Spring Boot': 2,
        'Kotlin WASM WASI': 3
    };

    const payload = {
        rodzaj_aplikacji_id: appTypeIds[APP_TYPE] || null,
        zimne_uruchomienie: parseFloat(firstSuccessTime.toFixed(2)),
        czas_odpowiedzi: parseFloat(data.metrics.http_req_duration.values.avg.toFixed(2)),
        przepustowosc: Math.round(data.metrics.http_reqs.values.rate),
        max_zuzycie_cpu: cpu_usage,
        max_zuzycie_ram: ram_usage,
        liczba_instancji_podow: pods,
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

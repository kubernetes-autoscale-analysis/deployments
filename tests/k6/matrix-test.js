import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    vus: __ENV.VUS || 1,
    duration: __ENV.DURATION || '30s',
};

const MATRIX_SIZE = __ENV.MATRIX_SIZE || 100;
const BASE_URL = __ENV.BASE_URL || 'http://localhost';

export default function () {
    const url = `${BASE_URL}/api/stress-test?matrixSize=${MATRIX_SIZE}`;
    const res = http.get(url);

    check(res, {
        'is status 200': (r) => r.status === 200,
        'has result': (r) => r.body.includes('checksum'),
    });

    sleep(1);
}

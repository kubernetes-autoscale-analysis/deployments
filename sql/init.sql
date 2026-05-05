-- Słownik rodzajów aplikacji
CREATE TABLE rodzaje_aplikacji (
    id SERIAL PRIMARY KEY,
    nazwa TEXT NOT NULL UNIQUE
);

-- Inicjalizacja słownika aplikacji
INSERT INTO rodzaje_aplikacji (nazwa) VALUES
    ('C++'),
    ('Kotlin Spring Boot'),
    ('Kotlin WASM WASI');

-- NOWA TABELA: Słownik scenariuszy testowych
CREATE TABLE scenariusze_testowe (
    id SERIAL PRIMARY KEY,
    kod CHAR(1) NOT NULL UNIQUE, -- 'A', 'B', 'C', 'D'
    nazwa TEXT NOT NULL,
    opis TEXT
);

-- Inicjalizacja słownika scenariuszy
INSERT INTO scenariusze_testowe (kod, nazwa, opis) VALUES
    ('A', 'Baseline Performance', 'Punkt odniesienia, niskie stałe obciążenie'),
    ('B', 'Ramp-up & Scalability', 'Badanie płynności skalowania pod narastającym ruchem'),
    ('C', 'Spike Test', 'Odporność na gwałtowne skoki obciążenia'),
    ('D', 'Soak & Adaptation', 'Stabilność długoterminowa i adaptacja zasobów (VPA)');

-- Tabele pomiarowe z powiązaniem do scenariusza
CREATE TABLE pomiary_hpa (
    id SERIAL PRIMARY KEY,
    rodzaj_aplikacji_id INTEGER REFERENCES rodzaje_aplikacji(id),
    scenariusz_id INTEGER REFERENCES scenariusze_testowe(id),
    zimne_uruchomienie DOUBLE PRECISION,
    czas_odpowiedzi DOUBLE PRECISION,
    przepustowosc INTEGER,
    max_zuzycie_cpu DOUBLE PRECISION,
    max_zuzycie_ram DOUBLE PRECISION,
    cpu_request DOUBLE PRECISION,
    ram_request INTEGER,
    liczba_instancji_podow INTEGER,
    rozmiar_macierzy INTEGER,
    wirtualni_uzytkownicy INTEGER,
    czas_trwania_testu INTEGER,
    data_realizacji_testu TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- (Powtórzenie analogicznej struktury dla pozostałych tabel)
CREATE TABLE pomiary_vpa (LIKE pomiary_hpa INCLUDING ALL);
CREATE TABLE pomiary_keda (LIKE pomiary_hpa INCLUDING ALL);
CREATE TABLE pomiary_serverless (LIKE pomiary_hpa INCLUDING ALL);

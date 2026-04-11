-- Słownik rodzajów aplikacji
CREATE TABLE rodzaje_aplikacji (
    id SERIAL PRIMARY KEY,
    nazwa TEXT NOT NULL UNIQUE
);

-- Inicjalizacja słownika
INSERT INTO rodzaje_aplikacji (nazwa) VALUES
    ('C++'),
    ('Kotlin Spring Boot'),
    ('Kotlin WASM WASI');

-- Tabele pomiarowe
CREATE TABLE pomiary_hpa (
    id SERIAL PRIMARY KEY,
    rodzaj_aplikacji_id INTEGER REFERENCES rodzaje_aplikacji(id),
    zimne_uruchomienie DOUBLE PRECISION,
    czas_odpowiedzi DOUBLE PRECISION,
    przepustowosc INTEGER,
    max_zuzycie_cpu DOUBLE PRECISION,
    max_zuzycie_ram DOUBLE PRECISION,
    liczba_instancji_podow INTEGER,
    rozmiar_macierzy INTEGER,
    wirtualni_uzytkownicy INTEGER,
    czas_trwania_testu INTEGER,
    data_realizacji_testu TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pomiary_vpa (
    id SERIAL PRIMARY KEY,
    rodzaj_aplikacji_id INTEGER REFERENCES rodzaje_aplikacji(id),
    zimne_uruchomienie DOUBLE PRECISION,
    czas_odpowiedzi DOUBLE PRECISION,
    przepustowosc INTEGER,
    max_zuzycie_cpu DOUBLE PRECISION,
    max_zuzycie_ram DOUBLE PRECISION,
    liczba_instancji_podow INTEGER,
    rozmiar_macierzy INTEGER,
    wirtualni_uzytkownicy INTEGER,
    czas_trwania_testu INTEGER,
    data_realizacji_testu TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pomiary_keda (
    id SERIAL PRIMARY KEY,
    rodzaj_aplikacji_id INTEGER REFERENCES rodzaje_aplikacji(id),
    zimne_uruchomienie DOUBLE PRECISION,
    czas_odpowiedzi DOUBLE PRECISION,
    przepustowosc INTEGER,
    max_zuzycie_cpu DOUBLE PRECISION,
    max_zuzycie_ram DOUBLE PRECISION,
    liczba_instancji_podow INTEGER,
    rozmiar_macierzy INTEGER,
    wirtualni_uzytkownicy INTEGER,
    czas_trwania_testu INTEGER,
    data_realizacji_testu TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pomiary_serverless (
    id SERIAL PRIMARY KEY,
    rodzaj_aplikacji_id INTEGER REFERENCES rodzaje_aplikacji(id),
    zimne_uruchomienie DOUBLE PRECISION,
    czas_odpowiedzi DOUBLE PRECISION,
    przepustowosc INTEGER,
    max_zuzycie_cpu DOUBLE PRECISION,
    max_zuzycie_ram DOUBLE PRECISION,
    liczba_instancji_podow INTEGER,
    rozmiar_macierzy INTEGER,
    wirtualni_uzytkownicy INTEGER,
    czas_trwania_testu INTEGER,
    data_realizacji_testu TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

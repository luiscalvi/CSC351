CREATE DATABASE IF NOT EXISTS global_power_generation;
USE global_power_generation;

CREATE TABLE IF NOT EXISTS countries (
    countrycode CHAR(3) PRIMARY KEY,
    countryname VARCHAR(100) NOT NULL,
    continent VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS operators (
    operatorid INT PRIMARY KEY,
    operatorname VARCHAR(150) NOT NULL,
    headquarterscountry CHAR(3) NOT NULL,
    CONSTRAINT fk_operators_country FOREIGN KEY (headquarterscountry)
        REFERENCES countries(countrycode)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fuel_types (
    fuelid INT PRIMARY KEY,
    fuelcategory VARCHAR(50) NOT NULL,
    fuelname VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS power_plants (
    plantid INT PRIMARY KEY,
    plantname VARCHAR(150) NOT NULL,
    countrycode CHAR(3) NOT NULL,
    operatorid INT NOT NULL,
    fuelid INT NOT NULL,
    capacitymw DECIMAL(12,2) NOT NULL,
    commissionyear INT NOT NULL,
    CONSTRAINT fk_plants_country FOREIGN KEY (countrycode)
        REFERENCES countries(countrycode) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_plants_operator FOREIGN KEY (operatorid)
        REFERENCES operators(operatorid) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_plants_fuel FOREIGN KEY (fuelid)
        REFERENCES fuel_types(fuelid) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS generation_records (
    plantid INT NOT NULL,
    year INT NOT NULL,
    generationgwh DECIMAL(15,2) NOT NULL,
    PRIMARY KEY (plantid, year),
    CONSTRAINT fk_generation_plant FOREIGN KEY (plantid)
        REFERENCES power_plants(plantid) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS emission_metrics (
    plantid INT NOT NULL,
    year INT NOT NULL,
    co2emissionstonnes DECIMAL(18,2) NOT NULL,
    PRIMARY KEY (plantid, year),
    CONSTRAINT fk_emissions_plant FOREIGN KEY (plantid)
        REFERENCES power_plants(plantid) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;


-- Problem 1: plant, country, operator, fuel, capacity, commission year.
SELECT power_plants.plantname, countries.countryname,
       operators.operatorname, fuel_types.fuelcategory,
       fuel_types.fuelname, power_plants.capacitymw,
       power_plants.commissionyear
FROM power_plants
JOIN countries ON power_plants.countrycode = countries.countrycode
JOIN operators ON power_plants.operatorid = operators.operatorid
JOIN fuel_types ON power_plants.fuelid = fuel_types.fuelid
ORDER BY power_plants.capacitymw DESC;

-- Problem 2: annual generation in 2024.
SELECT power_plants.plantname, power_plants.countrycode,
       generation_records.year, generation_records.generationgwh
FROM power_plants
JOIN generation_records ON power_plants.plantid = generation_records.plantid
WHERE generation_records.year = 2024
ORDER BY generation_records.generationgwh DESC;

-- Problem 3: generation and emissions for 2024.
SELECT power_plants.plantname, power_plants.countrycode,
       generation_records.year, generation_records.generationgwh,
       emission_metrics.co2emissionstonnes
FROM power_plants
JOIN generation_records ON power_plants.plantid = generation_records.plantid
JOIN emission_metrics ON power_plants.plantid = emission_metrics.plantid
    AND generation_records.year = emission_metrics.year
WHERE generation_records.year = 2024
ORDER BY emission_metrics.co2emissionstonnes ASC;

-- Problem 4: operator totals across all years (CTE, no table aliases).
WITH operator_generation AS (
    SELECT power_plants.operatorid,
           SUM(generation_records.generationgwh) AS totalgenerationgwh
    FROM power_plants
    JOIN generation_records ON power_plants.plantid = generation_records.plantid
    GROUP BY power_plants.operatorid
)
SELECT operators.operatorname, operators.headquarterscountry,
       operator_generation.totalgenerationgwh
FROM operators
JOIN operator_generation ON operators.operatorid = operator_generation.operatorid
ORDER BY operator_generation.totalgenerationgwh DESC;

-- Problem 5: separate country generation and emissions CTEs (no table aliases).
WITH country_generation AS (
    SELECT power_plants.countrycode,
           SUM(generation_records.generationgwh) AS totalgenerationgwh
    FROM power_plants
    JOIN generation_records ON power_plants.plantid = generation_records.plantid
    GROUP BY power_plants.countrycode
),
country_emissions AS (
    SELECT power_plants.countrycode,
           SUM(emission_metrics.co2emissionstonnes) AS totalco2emissionstonnes
    FROM power_plants
    JOIN emission_metrics ON power_plants.plantid = emission_metrics.plantid
    GROUP BY power_plants.countrycode
)
SELECT countries.countryname, country_generation.totalgenerationgwh,
       country_emissions.totalco2emissionstonnes
FROM countries
JOIN country_generation ON countries.countrycode = country_generation.countrycode
JOIN country_emissions ON countries.countrycode = country_emissions.countrycode
ORDER BY country_generation.totalgenerationgwh DESC;

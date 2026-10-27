CREATE DATABASE IF NOT EXISTS global_space_missions
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE global_space_missions;

CREATE TABLE IF NOT EXISTS countries (
    CountryCode CHAR(3) PRIMARY KEY,
    CountryName VARCHAR(100) NOT NULL,
    Continent VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS organizations (
    OrgID INT PRIMARY KEY,
    OrgName VARCHAR(150) NOT NULL,
    HeadquartersCountry CHAR(3) NOT NULL,
    OrgType VARCHAR(30) NOT NULL,
    CONSTRAINT uq_org_name_country UNIQUE (OrgName, HeadquartersCountry),
    CONSTRAINT fk_organizations_countries
        FOREIGN KEY (HeadquartersCountry) REFERENCES countries (CountryCode)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS launch_sites (
    SiteID INT PRIMARY KEY,
    SiteName VARCHAR(150) NOT NULL,
    CountryCode CHAR(3) NOT NULL,
    Status VARCHAR(30) NOT NULL,
    CONSTRAINT uq_launch_sites_country_name UNIQUE (CountryCode, SiteName),
    CONSTRAINT fk_launch_sites_countries
        FOREIGN KEY (CountryCode) REFERENCES countries (CountryCode)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rockets (
    RocketID INT PRIMARY KEY,
    RocketName VARCHAR(100) NOT NULL,
    OrgID INT NOT NULL,
    PayloadCapacityKg DECIMAL(12,2) NOT NULL,
    OperationalStatus VARCHAR(30) NOT NULL,
    CONSTRAINT uq_rockets_org_name UNIQUE (OrgID, RocketName),
    CONSTRAINT chk_rockets_capacity CHECK (PayloadCapacityKg >= 0),
    CONSTRAINT fk_rockets_organizations
        FOREIGN KEY (OrgID) REFERENCES organizations (OrgID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS missions (
    MissionID INT PRIMARY KEY,
    MissionName VARCHAR(150) NOT NULL,
    RocketID INT NOT NULL,
    SiteID INT NOT NULL,
    Destination VARCHAR(50) NOT NULL,
    LaunchYear SMALLINT NOT NULL,
    Outcome VARCHAR(30) NOT NULL,
    CONSTRAINT chk_missions_launchyear CHECK (LaunchYear BETWEEN 1950 AND 2200),
    CONSTRAINT fk_missions_rockets
        FOREIGN KEY (RocketID) REFERENCES rockets (RocketID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_missions_launch_sites
        FOREIGN KEY (SiteID) REFERENCES launch_sites (SiteID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payloads (
    PayloadID INT PRIMARY KEY,
    MissionID INT NOT NULL,
    PayloadName VARCHAR(150) NOT NULL,
    PayloadType VARCHAR(50) NOT NULL,
    MassKg DECIMAL(12,2) NOT NULL,
    CONSTRAINT uq_payloads_mission_name UNIQUE (MissionID, PayloadName),
    CONSTRAINT chk_payloads_mass CHECK (MassKg >= 0),
    CONSTRAINT fk_payloads_missions
        FOREIGN KEY (MissionID) REFERENCES missions (MissionID)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

/* 
Query 1:
Retrieve the mission name, rocket name, organization name, 
launch site name, destination, launch year, and outcome for 
all space missions without using table aliases. 
Sort the results in descending order by launch year and ascending order by mission name.
*/
SELECT
    missions.MissionName,
    rockets.RocketName,
    organizations.OrgName,
    launch_sites.SiteName,
    missions.Destination,
    missions.LaunchYear,
    missions.Outcome
FROM missions
INNER JOIN rockets
    ON missions.RocketID = rockets.RocketID
INNER JOIN organizations
    ON rockets.OrgID = organizations.OrgID
INNER JOIN launch_sites
    ON missions.SiteID = launch_sites.SiteID
ORDER BY missions.LaunchYear DESC, missions.MissionName ASC;

/* 
Query 2:
Retrieve the mission name, rocket name, payload name, payload type, 
and payload mass (in kg) for all payloads launched in 2024 without using table aliases. 
Sort the results in descending order by payload mass.
*/
SELECT
    missions.MissionName,
    rockets.RocketName,
    payloads.PayloadName,
    payloads.PayloadType,
    payloads.MassKg
FROM payloads
INNER JOIN missions
    ON payloads.MissionID = missions.MissionID
INNER JOIN rockets
    ON missions.RocketID = rockets.RocketID
WHERE missions.LaunchYear = 2024
ORDER BY payloads.MassKg DESC;

/* 
Query 3:
Retrieve all launch sites along with their matching mission names, rockets, 
and launch years for missions that took place in 2024 without using table aliases, 
ensuring that launch sites with no recorded 2024 missions still 
appear in the results with null values for the mission fields. 
Sort the results in alphabetical order by launch site name.
*/
SELECT
    launch_sites.SiteName,
    missions.MissionName,
    rockets.RocketName,
    missions.LaunchYear
FROM launch_sites
LEFT JOIN missions
    ON launch_sites.SiteID = missions.SiteID
    AND missions.LaunchYear = 2024
LEFT JOIN rockets
    ON missions.RocketID = rockets.RocketID
ORDER BY launch_sites.SiteName ASC;

/* 
Query 4:
Write a SQL query using a Common Table Expression (CTE) to calculate the total payload mass (in kg) 
deployed by each organization across all missions without using table aliases. 
Retrieve the organization name, headquarters country, organization type, 
and total payload mass, and sort the results in descending order by total payload mass.
*/
WITH organization_payload_totals AS (
    SELECT
        organizations.OrgID,
        COALESCE(SUM(payloads.MassKg), 0.00) AS TotalPayloadMassKg
    FROM organizations
    LEFT JOIN rockets
        ON organizations.OrgID = rockets.OrgID
    LEFT JOIN missions
        ON rockets.RocketID = missions.RocketID
    LEFT JOIN payloads
        ON missions.MissionID = payloads.MissionID
    GROUP BY organizations.OrgID
)
SELECT
    organizations.OrgName,
    organizations.HeadquartersCountry,
    organizations.OrgType,
    organization_payload_totals.TotalPayloadMassKg
FROM organizations
INNER JOIN organization_payload_totals
    ON organizations.OrgID = organization_payload_totals.OrgID
ORDER BY organization_payload_totals.TotalPayloadMassKg DESC;

/* 
Query 5:
Write a SQL query using two separate Common Table Expressions (CTEs)—one to calculate 
total missions by country code and another to calculate total 
payload mass by country code without using table aliases. 
Then, combine these CTEs with the countries table to display the country name, 
total number of missions, and total payload mass (in kg). 
Sort the results in descending order by total payload mass.
*/
WITH country_mission_totals AS (
    SELECT
        launch_sites.CountryCode,
        COUNT(missions.MissionID) AS TotalMissions
    FROM launch_sites
    LEFT JOIN missions
        ON launch_sites.SiteID = missions.SiteID
    GROUP BY launch_sites.CountryCode
),
country_payload_totals AS (
    SELECT
        launch_sites.CountryCode,
        COALESCE(SUM(payloads.MassKg), 0.00) AS TotalPayloadMassKg
    FROM launch_sites
    LEFT JOIN missions
        ON launch_sites.SiteID = missions.SiteID
    LEFT JOIN payloads
        ON missions.MissionID = payloads.MissionID
    GROUP BY launch_sites.CountryCode
)
SELECT
    countries.CountryName,
    COALESCE(country_mission_totals.TotalMissions, 0) AS TotalMissions,
    COALESCE(country_payload_totals.TotalPayloadMassKg, 0.00) AS TotalPayloadMassKg
FROM countries
LEFT JOIN country_mission_totals
    ON countries.CountryCode = country_mission_totals.CountryCode
LEFT JOIN country_payload_totals
    ON countries.CountryCode = country_payload_totals.CountryCode
ORDER BY TotalPayloadMassKg DESC;

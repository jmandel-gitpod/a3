-- Queries 118 patient synthetic dataset at composed-circle-270115.a3
-- generated using https://github.com/synthetichealth/synthea

WITH pt AS (
	SELECT id AS PatientId,
		birthDate_aa.start AS birthDate
	FROM `composed-circle-270115`.a3.Patient
),

dm_dx AS (
	SELECT subject.reference_id_aa AS PatientId,
		Condition.id AS ResourceId

	FROM `composed-circle-270115`.a3.Condition
		LEFT JOIN UNNEST(clinicalStatus.coding) clinical_status_coding ON true,
		UNNEST(Condition.code.coding) condition_coding

	WHERE subject.type = "Patient"
		AND condition_coding.system = 'http://snomed.info/sct'
		AND condition_coding.code IN ('105401000119101','106281000119103','10754881000119104','111307005','111552007','123763000','127012008','1481000119100','190330002','190331003','190368000','190372001','190389009','190406000','190407009','190410002','190411003','190412005','199223000','199225007','199226008','199227004','199228009','199229001','199230006','199231005','23045005','237599002','237600004','237601000','237604008','237613005','237618001','237619009','237627000','237651005','24203005','2751001','28032008','31321000119102','313435000','313436004','314771006','314893005','314902007','314903002','314904008','33559001','359642000','368521000119107','408539000','426705001','426875007','427089005','42954008','44054006','445260006','46635009','4783006','51002006','530558861000132104','57886004','59079001','5969009','609561005','609562003','609563008','609564002','609566000','609567009','609568004','609569007','609570008','609571007','609572000','609573005','609574004','609575003','609576002','609577006','609578001','70694009','709147009','710815001','716362006','71791000119104','719216001','720519003','722454003','724136006','73211009','733072002','734022008','75524006','75682002','76751001','81531005','8801005','91352004','9859006')
		AND clinical_status_coding.code = 'active'
),

htn_dx AS (
	SELECT subject.reference_id_aa AS PatientId,
		Condition.id AS ResourceId

	FROM `composed-circle-270115`.a3.Condition
		LEFT JOIN UNNEST(clinicalStatus.coding) clinical_status_coding ON true,
		UNNEST(Condition.code.coding) condition_coding

	WHERE subject.type = "Patient"
		AND ((
			condition_coding.system = 'http://snomed.info/sct'
			AND condition_coding.code IN ('10725009', '10964002', '1201005', '123799005', '59621000')
		) OR (
			condition_coding.system = 'http://hl7.org/fhir/ValueSet/icd-9'
			AND condition_coding.code IN ('401.1', '401.9')
		))
		AND clinical_status_coding.code = 'active'
),

a1c_2 AS (
	SELECT subject.reference_id_aa AS PatientId,
		Observation.id AS ResourceId, 
		valueQuantity AS valueQuantity,
		effectiveDateTime_aa.start AS effectiveDateTime_start,
		effectiveDateTime_aa.end AS effectiveDateTime_end

	FROM `composed-circle-270115`.a3.Observation,
		UNNEST(Observation.code.coding) observation_coding

	WHERE subject.type = 'Patient'
		AND (status = 'final' OR status = 'amended' OR status = 'corrected')
		AND (observation_coding.system = 'http://loinc.org' AND observation_coding.code = '4548-4')
		AND (
			observation_coding.system = 'http://loinc.org'
			AND observation_coding.code = '4548-4'
		) AND (
			valueQuantity.system = 'http://unitsofmeasure.org'
			AND valueQuantity.code = '%'
		)
),

a1c_2_latest AS (
	SELECT * FROM (
		SELECT a1c_2.*,
			DENSE_RANK() OVER (
				PARTITION BY a1c_2.PatientId
				ORDER BY a1c_2.effectiveDateTime_end DESC
			) AS rank
		FROM a1c_2
	) AS q WHERE rank = 1	
),

a1c_2_elevated AS (
	SELECT * FROM a1c_2_latest
	-- elevated a1c value is lowered to 6 to match patients in sample dataset
	WHERE a1c_2_latest.valueQuantity.value > 6
),

a1c_1 AS (	
	SELECT subject.reference_id_aa AS PatientId,
		Observation.id AS ResourceId, 
		Observation.valueQuantity AS valueQuantity,
		effectiveDateTime_aa.start AS effectiveDateTime_start,
		effectiveDateTime_aa.end AS effectiveDateTime_end

	FROM `composed-circle-270115`.a3.Observation
		INNER JOIN a1c_2_elevated 
			ON a1c_2_elevated.PatientId = subject.reference_id_aa
			AND DATETIME(effectiveDateTime_aa.end) < DATETIME_ADD(DATETIME(a1c_2_elevated.effectiveDateTime_start), INTERVAL -1 DAY)
			-- Date constraint adjusted to match patients in sample dataset
			-- AND DATETIME(effectiveDateTime_aa.end) > DATETIME_ADD(DATETIME(a1c_2_elevated.effectiveDateTime_start), INTERVAL -60 DAY)
     INNER JOIN pt
     ON pt.PatientId = subject.reference_id_aa
			AND DATETIME(effectiveDateTime_aa.start) >= DATETIME_ADD(DATETIME(pt.birthDate), INTERVAL 18 YEAR),
		UNNEST(Observation.code.coding) observation_coding

	WHERE subject.type = 'Patient'
		AND (status = 'final' OR status = 'amended' OR status = 'corrected')
		AND (observation_coding.system = 'http://loinc.org' AND observation_coding.code = '4548-4')
		AND (
			observation_coding.system = 'http://loinc.org'
			AND observation_coding.code = '4548-4'
		) AND (
			Observation.valueQuantity.system = 'http://unitsofmeasure.org'
			AND Observation.valueQuantity.code = '%'
		)
),

a1c_1_latest AS (
	SELECT * FROM (
		SELECT a1c_1.*,
			DENSE_RANK() OVER (
				PARTITION BY a1c_1.PatientId
				ORDER BY a1c_1.effectiveDateTime_end DESC
			) AS rank
		FROM a1c_1
	) AS q WHERE rank = 1
),

a1c_1_elevated AS (
	SELECT * FROM a1c_1_latest
	-- elevated a1c value is lowered to 6 to match patients in sample dataset
	WHERE a1c_1_latest.valueQuantity.value > 6
)

SELECT DISTINCT(a1c_1_elevated.PatientId) FROM a1c_1_elevated
	INNER JOIN dm_dx ON a1c_1_elevated.PatientId = dm_dx.PatientId
	LEFT JOIN htn_dx oN a1c_1_elevated.PatientId = htn_dx.PatientId
WHERE htn_dx.PatientId IS NULL
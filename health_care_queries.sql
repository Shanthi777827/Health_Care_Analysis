
Select * from health_care.appointments;
Select * from health_care.billing;
Select * from health_care.doctors;
Select * from health_care.patients;
Select * from health_care.treatments;

-- 1.Total number of unique patients in the system

SELECT 
    COUNT(DISTINCT patient_id) AS total_patients
FROM
    health_care.patients;


-- 2.Total appointments scheduled vs completed vs cancelled vs no-show

SELECT 
    status, COUNT(*) AS status_count
FROM
    health_care.appointments
GROUP BY status;


-- 3. Appointment no-show rate (KPI)
-- No-show Rate (%) = (No-shows ÷ Total Appointments) × 100

select 
(select count(*) from health_care.appointments where status ="No-show")/
(select count(*) from health_care.appointments ) * 100 as no_show_rate_percentage;


-- 4. patient age (calculated from date_of_birth)

SELECT 
    first_name,
    last_name,
    gender,
    TIMESTAMPDIFF(YEAR,
        date_of_birth,
        CURDATE()) AS Patient_age
FROM
    health_care.patients;



-- 5. Average patient age

SELECT 
    AVG(TIMESTAMPDIFF(YEAR,
        date_of_birth,
        CURDATE())) AS Patient_age
FROM
    health_care.patients;
    
    
    
-- 6. Most common reason for visit

SELECT 
    reason_for_visit, COUNT(*)
FROM
    health_care.appointments
GROUP BY reason_for_visit
ORDER BY COUNT(*) DESC;

-- 7. Which treatment type is most common across all patients?

SELECT 
    treatment_type AS common_treatment,
    COUNT(*) AS common_treatment_count
FROM
    health_care.treatments
GROUP BY common_treatment;


-- 8. What is the average treatment cost?

SELECT 
    AVG(cost)
FROM
    health_care.treatments;

-- 9.How many patients have insurance coverage?

SELECT 
    COUNT(payment_method) AS Total_insurance
FROM
    health_care.billing
WHERE
    payment_method = 'Insurance'


-- 10.What is the total revenue generated per payment method (cash card insurance)?

SELECT 
    payment_method, SUM(amount) AS total_revenue
FROM
    health_care.billing
WHERE
    payment_status = 'Paid'
GROUP BY payment_method;





-- 11.Top 5 doctors by number of completed appointments
SELECT 
    d.first_name,
    d.last_name,
    COUNT(*) AS completed_appointments
FROM
    health_care.doctors AS d
        LEFT JOIN
    health_care.appointments AS a ON d.doctor_id = a.doctor_id
WHERE
    a.status = 'completed'
GROUP BY d.first_name , d.last_name
ORDER BY completed_appointments DESC
LIMIT 5;


-- 12. Highest earning insurance providers (payer analysis)
 
SELECT 
    p.insurance_provider,
    COUNT(p.patient_id) AS patient_count,
    SUM(t.cost) AS total_cost,
    ROUND(AVG(t.cost), 2) AS avg_cost_per_patient
FROM
    health_care.patients AS p
    left join health_care.appointments AS a
    on p.patient_id = a.patient_id
    left join health_care.treatments as t
    on a.appointment_id=t.appointment_id
    GROUP BY p.insurance_provider,a.reason_for_visit
     order  BY total_cost DESC;



-- 13. Rank doctors based on the number of appointments they have handled. Display only the top 5 doctors along with their specialization.	

select d.first_name,d.last_name,d.specialization,count(*) as appointment_count,
row_number() OVER(order by count(*) desc) as top_doctors
from health_care.doctors as d		
Left Join health_care.appointments as a	
On d.doctor_id=a.doctor_id
where a.status = "completed" 
group by d.doctor_id,d.first_name,d.last_name,d.specialization
order by appointment_count desc;
																								

-- 14. List all patients who have had more than one appointment.

SELECT 
    p.first_name,
    p.last_name,
    COUNT(appointment_id) AS appointment_count
FROM
    health_care.patients AS p
        LEFT JOIN
    health_care.appointments AS a ON p.patient_id = a.patient_id
GROUP BY p.first_name , p.last_name , a.reason_for_visit
HAVING COUNT(*) > 1
ORDER BY appointment_count;


-- 15. Uses multiple table joins, subqueries, grouping with conditions, time functions.
-- Which patients have had treatments but no bills generated yet? 

SELECT 
    p.first_name,
    p.last_name,
    a.status AS treatment_completed,
    b.payment_status,
    COUNT(*) AS count
FROM
    health_care.patients AS p
        LEFT JOIN
    health_care.billing AS b ON p.patient_id = b.patient_id
        LEFT JOIN
    health_care.appointments AS a ON p.patient_id = a.patient_id
WHERE
    b.payment_status IN ('Pending' , 'Failed')
        AND a.status = 'completed'
GROUP BY p.first_name , p.last_name , b.payment_status , a.status
ORDER BY count DESC;


-- 16.Using a CTE, find patients who have had more than 3 appointments.

WITH appointments_counts as (
			select 
            p.patient_id,
            p.first_name,
            p.last_name,
            count(a.appointment_id) as total_appointments
			from health_care.patients as p
			left join health_care.appointments as a
			on p.patient_id = a.patient_id
			group by p.patient_id,p.first_name,p.last_name
)
                            
select *
from appointments_counts
where total_appointments>3;


-- 17. Rank treatments by cost for each patient using Row_number. (Window function)

select p.patient_id,p.first_name,p.last_name,a.reason_for_visit,t.treatment_type,t.cost,
Row_number() over(partition by  patient_id Order by cast(t.cost as decimal(10,2)) desc) as rank_cost
FROM health_care.patients as p
Left Join health_care.appointments as a
On p.patient_id = a.patient_id
right join clean_treatments as t
on a.appointment_id = t.appointment_id;





-- 18. What is the time gap in days between each patient’s consecutive appointments? (Window function + LAG)
-- LAG(a.appointment_date) → gives you the previous appointment date for that same patient.

-- PARTITION BY p.patient_id → ensures the comparison happens per patient, not across all patients.

-- ORDER BY a.appointment_date → ensures the appointments are in chronological order.

-- DATEDIFF(a.appointment_date, previous_date) → finds the gap in days.

WITH appointment_gap as (
select p.first_name,
p.last_name,
a.appointment_date,
a.appointment_time,
lag(a.appointment_date) OVER(Partition By p.patient_id order by a.appointment_date) as previous_date
from health_care.patients as p
Left Join health_care.appointments as a
on p.patient_id = a.patient_id) 
select first_name,
last_name,
appointment_date,
appointment_time,
coalesce(DATE_FORMAT(previous_date, '%Y-%m-%d'), 'First Visit') AS previous_date,
coalesce(DATEDIFF(appointment_date,previous_date),0) as days_gap
from appointment_gap;




-- or


select p.first_name,
p.last_name,
a.appointment_date,
a.appointment_time,
lag(a.appointment_date) OVER(Partition By p.patient_id order by a.appointment_date) as previous_date
,Datediff(appointment_date,lag(a.appointment_date) OVER(Partition By p.patient_id order by a.appointment_date)) as days_gap
from health_care.patients as p
Left Join health_care.appointments as a
on p.patient_id = a.patient_id


-- 19.Using CTE, list top 5 doctors by total billed revenue. (CTE + Join + Order By)

with cte As(
select d.first_name,d.last_name,sum(b.amount) as total_Amount
from health_care.doctors as d
Left join health_care.appointments as a
on d.doctor_id = a.doctor_id
left join health_care.billing as b
on a.patient_id = b.patient_id
where  payment_status ="paid"
group by d.first_name,d.last_name
)
select *from cte
order by total_Amount desc
limit 5;






















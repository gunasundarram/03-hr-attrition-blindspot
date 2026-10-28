SELECT COUNT(*) FROM hr.employees_raw;          -- expect 1470

SELECT * FROM hr.employees_raw LIMIT 5;         -- eyeball the rows

SELECT attrition, COUNT(*) FROM hr.employees_raw GROUP BY 1;   -- expect No 1233, Yes 237

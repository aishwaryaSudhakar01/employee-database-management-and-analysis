USE employees;

-- Total number of employees
SELECT COUNT(DISTINCT emp_no) AS total_employees
FROM employees;

-- Getting the number of male and female employees
SELECT 
  SUM(CASE WHEN gender = 'M' THEN 1 ELSE 0 END) AS male_num,
  SUM(CASE WHEN gender = 'F' THEN 1 ELSE 0 END) AS female_num
FROM employees;

-- Most common department for female employees
WITH CTE AS (
  SELECT
    e.emp_no,
    de.dept_no,
    d.dept_name
  FROM employees e 
    JOIN dept_emp de ON de.emp_no = e.emp_no
    JOIN departments d ON d.dept_no = de.dept_no
  WHERE e.gender = 'F' )

SELECT 
  dept_name,
  COUNT(dept_no) AS num_of_females
FROM CTE
GROUP BY dept_name
ORDER BY num_of_females
LIMIT 1;

-- Distribution of current job titles among employees
SELECT
  SUM(CASE WHEN title = 'Staff' THEN 1 ELSE 0 END) AS staff_num,
  SUM(CASE WHEN title = 'Senior Staff' THEN 1 ELSE 0 END) AS sen_staff_num,
  SUM(CASE WHEN title = 'Engineer' THEN 1 ELSE 0 END) AS engg_num,
  SUM(CASE WHEN title = 'Assistant Engineer' THEN 1 ELSE 0 END) AS ast_engg_num,
  SUM(CASE WHEN title = 'Senior Engineer' THEN 1 ELSE 0 END) AS ast_engg_num,
  SUM(CASE WHEN title = 'Technique Leader' THEN 1 ELSE 0 END) AS techq_num,
  SUM(CASE WHEN title = 'Manager' THEN 1 ELSE 0 END) AS manager_num
FROM titles
HAVING MAX(to_date);

-- Minimum and Maximum salary for each job title
SELECT
  t.title,
  MAX(s.salary) AS max_salary,
  MIN(s.salary) AS min_salary
FROM salaries s 
  JOIN titles t ON s.emp_no = t.emp_no
GROUP BY t.title
ORDER BY max_salary DESC, min_salary ASC;

-- Average salary for each job title compared to the overall average salary
 SELECT 
    t.title, 
    AVG(s.salary) AS avg_salary, 
    AVG(s.salary) / (SELECT AVG(salary) FROM salaries) AS avg_salary_ratio
FROM titles t
  JOIN employees e ON t.emp_no = e.emp_no
  JOIN salaries s ON e.emp_no = s.emp_no
GROUP BY t.title;

-- Salary range of employees by department
SELECT 
  de.dept_no,
  d.dept_name,
  CONCAT('$', MIN(s.salary), '-', '$', MAX(s.salary)) AS salary_range
FROM dept_emp de
  JOIN salaries s ON de.emp_no = s.emp_no
  JOIN departments d ON de.dept_no = d.dept_no
GROUP BY de.dept_no, d.dept_name
ORDER BY de.dept_no;

-- Finding the number of salary hikes for each employee
SELECT
  e.emp_no,
  t.title,
  COUNT(s.salary) AS salary_hikes
FROM employees e
  JOIN titles t ON e.emp_no = t.emp_no
  JOIN salaries s ON t.emp_no = s.emp_no
GROUP BY e.emp_no, t.title
HAVING MAX(t.to_date);

-- Observing which job titles get the highest salary hikes
WITH CTE AS (
SELECT 
  s.emp_no, 
  t.title, 
  COUNT(s.salary) AS salary_hikes,
  RANK() OVER (PARTITION BY s.emp_no ORDER BY COUNT(s.salary) DESC) AS row_num
FROM salaries s
  JOIN titles t ON s.emp_no = t.emp_no 
    AND s.from_date BETWEEN t.from_date AND t.to_date
    AND s.to_date BETWEEN t.from_date AND t.to_date
GROUP BY s.emp_no, t.title)

SELECT
  title,
  ROUND((AVG(salary_hikes)/MAX(salary_hikes))*100.0,2) AS hikes_perc
FROM CTE
WHERE row_num = 1
GROUP BY title
ORDER BY hikes_perc DESC
LIMIT 3;

-- Average salary increase when an employee gets promoted
WITH CTE AS (
  SELECT s.emp_no, s.salary AS old_salary, 
  LEAD(s.salary) OVER (PARTITION BY s.emp_no ORDER BY t.from_date) AS new_salary
  FROM salaries s
  JOIN titles t ON s.emp_no = t.emp_no AND s.from_date < t.to_date
  WHERE t.to_date IS NOT NULL )

SELECT AVG(new_salary - old_salary) AS avg_salary_increase
FROM CTE;

-- Number of employees who have reached their highest department
WITH CTE AS (
  SELECT emp_no, dept_no, MAX(to_date) AS max_date
  FROM dept_emp
  GROUP BY emp_no, dept_no ), 

CTE1 AS (
  SELECT 
    e.emp_no, 
    d.dept_name, 
    t.title, 
    t.to_date
  FROM employees e
  JOIN CTE c ON e.emp_no = c.emp_no
  JOIN dept_emp de ON e.emp_no = de.emp_no AND c.dept_no = de.dept_no AND c.max_date = de.to_date
  JOIN departments d ON de.dept_no = d.dept_no
  JOIN titles t ON e.emp_no = t.emp_no AND c.max_date = t.to_date )

SELECT 
  dept_name,
  COUNT(*) AS num_of_employees
FROM CTE1
WHERE title = 'Manager'
GROUP BY dept_name;

-- Top 10 salaries of managers offered by the company and their department
SELECT 
  s.emp_no,
  dm.dept_no,
  s.salary
FROM salaries s
  JOIN dept_manager dm ON dm.emp_no = s.emp_no
ORDER BY s.salary DESC
LIMIT 10;

-- Employee turnover rate by department
WITH CTE AS (
  SELECT 
    d.dept_name,
    COUNT(DISTINCT e.emp_no) AS department_size,
	  (SELECT COUNT(DISTINCT e.emp_no)
       FROM employees e
	     JOIN dept_emp de ON e.emp_no = de.emp_no
		 JOIN titles t ON e.emp_no = t.emp_no
	   WHERE t.to_date != '9999-01-01'
		 AND de.to_date = '9999-01-01'
		 AND de.dept_no = d.dept_no
	   HAVING MAX(t.to_date)) AS resigned_employees
  FROM departments d
  JOIN dept_emp de ON d.dept_no = de.dept_no
  JOIN employees e ON de.emp_no = e.emp_no
  GROUP BY d.dept_name)
  
SELECT
  CTE.dept_name,
  ROUND((resigned_employees/department_size)*100.0,2) AS turnover_rate
FROM CTE
ORDER BY turnover_rate DESC; 

-- Historical performance of bad managers
SELECT 
   d.dept_no AS dept_num,
   d.dept_name AS dept_name,
   dm.emp_no AS employee_ID,
   RANK() OVER (PARTITION BY dm.dept_no ORDER BY s.salary DESC) AS department_salary_ranking,
   s.salary,
   s.from_date AS salary_from_date,
   s.to_date AS salary_to_date,
   dm.from_date AS dept_manager_from_date,
   dm.to_date AS dept_manager_to_date
FROM dept_manager dm
JOIN salaries s ON dm.emp_no = s.emp_no
   AND s.from_date BETWEEN dm.from_date AND dm.to_date
   AND s.to_date BETWEEN dm.from_date AND dm.to_date
JOIN departments d ON dm.dept_no = d.dept_no;


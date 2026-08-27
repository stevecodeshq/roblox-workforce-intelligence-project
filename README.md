# Workforce Intelligence and Organizational Performance Analysis

**Generation TIFC Data Analyst Capstone** · Roblox Africa Operations (Ghana Hub)

A ten-stage analytics project that took seven fragmented HR datasets, cleaned and integrated them into a single SQL database, and delivered an executive Power BI dashboard, a full analysis report, and ranked recommendations for leadership.

---

## The problem

Roblox Africa's workforce data was split across seven separate systems — employee records, education, finance, health, and two years of performance history — with no single place to ask a question across all of them. Leadership couldn't answer basic questions about workforce cost, risk, or efficiency without manually cross-referencing files by hand.

## What this project delivers

- **Cleaned and integrated dataset** — 270,000+ raw records reduced to 30,000 verified employee records across 8 departments and 5 years (2021–2025)
- **SQL database** with documented schema, foreign keys, and data-quality constraints (`roblox_workforce.sql` / `.db`)
- **Data dictionary and ERD** — every column, every relationship, tested against the live data
- **21 logged data-quality issues**, each traced to a specific record and resolved through a documented client correspondence
- **Executive Power BI dashboard** — 4 pages: Executive Summary, Workforce & Education, Compensation & Cost, Wellbeing & Department Performance
- **Analysis report** with 16 findings, each independently verified against the database
- **5 ranked, deadline-specific recommendations** for leadership
- **Maintenance plan** covering refresh cadence, data ownership, and error-prevention rules going forward

## Key findings

| Finding | Number |
|---|---|
| Employees currently marked Active | 33.6% |
| Employees without active health insurance cover | 66.7% |
| Employees with 5 or fewer medical leave days remaining | 5,740 (19.1%) |
| Largest gap between headcount share and pay share, any department | 0.1 points |
| Finance vs. Data & Analytics revenue per employee | 3.6× |

## Tools used

`SQL` (SQLite) · `Python` (pandas, Jupyter) · `Power BI Desktop` (DAX, Power Query) · `Excel` · `Word`

## Repository structure

```
01_Planning_and_Requirements_Gathering/   Project outline, client note-taking template
02_Data_Exploration_and_Documentation/    Data dictionary, ERD
03_Error_Detection/                       Mistakes handout — 21 logged issues
04_Client_Communication/                  Error report email, client decisions log
05_Data_Cleaning/                         Cleaned dataset, cleaning script (.ipynb)
06_Data_Integration_and_Database_Build/   SQL build script, master_employee dataset
07_Exploratory_Analysis_and_Insight_Generation/  analysis.ipynb — 16 verified findings
08_Visualisation_and_Dashboard_Build/     dashboard.pbix, exported PDF
09_Validation_Report_and_Presentation/    Validation checklist, analysis report
10_Maintenance_and_Handover/              Maintenance plan
```

## Honest limitations

This project is transparent about what the data can and can't support:

- The pay period (monthly vs. annual) for salary figures was never confirmed — every compensation figure is reported exactly as supplied, never annualised.
- The education-to-department "mismatch" figure (73%) depends on a mapping assumption, not a client-confirmed rule, and is flagged as such everywhere it appears.
- Department cost and individual salary totals sit on different scales (~21× apart) for reasons not yet resolved — the two are never divided against each other.

Full detail on every open question is in the Maintenance & Follow-Up Plan.

---

*Capstone project for the Generation TIFC Data Analyst Upskill programme.*

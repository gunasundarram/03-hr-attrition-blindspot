# Data Dictionary — HR Attrition Blindspot

Source: IBM HR Analytics Employee Attrition dataset (Kaggle). Synthetic data
created by IBM data scientists; findings are illustrative, not real-company evidence.
Rows: 1,470 employees. Overall attrition: 16.1% (237 leavers).

## 

## Source columns kept

|Column|Meaning|Scale / values|
|-|-|-|
|employee\_number|Unique employee ID|Integer|
|performance\_rating|Latest performance rating|3 = Excellent, 4 = Outstanding (no 1s or 2s exist)|
|overtime|Works overtime|Yes / No|
|years\_since\_last\_promotion|Years since last promotion|0-15|
|years\_with\_curr\_manager|Years with current manager|0-17|
|monthly\_income|Monthly pay|Integer|
|job\_level|Seniority|1-5|
|job\_satisfaction|Survey score|1 = Low ... 4 = Very High|
|work\_life\_balance|Survey score|1 = Bad ... 4 = Best|
|attrition|Left the company|Yes / No|

## 

## Engineered columns

|Column|Definition|Justification|
|-|-|-|
|attrition\_flag|1 if attrition = 'Yes' else 0|Numeric outcome for DAX/averages|
|high\_performer\_flag|1 if performance\_rating = 4|Only 3 and 4 exist; 4 = top \~15%|
|overtime\_flag|1 if overtime = 'Yes'|Binary driver|
|promo\_stagnation\_flag|1 if years\_since\_last\_promotion >= 3|Threshold chosen from Part A (update if you changed it)|
|new\_manager\_flag|1 if years\_with\_curr\_manager <= 1|Threshold chosen from Part A (update if you changed it)|
|below\_level\_median\_pay\_flag|1 if income < median income for the same job\_level|Fair-pay comparison within level|
|tenure\_band / promo\_gap\_band / manager\_tenure\_band|Readable groupings|For slicers and chart axes|
|performance\_label|'High (4)' or 'Solid (3)'|Readable label|

## 

## Dropped columns

|Column|Reason|
|-|-|
|employee\_count|Constant (always 1), no information|
|standard\_hours|Constant (always 80), no information|
|over18|Constant (always 'Y'), no information|
|daily\_rate, hourly\_rate, monthly\_rate|Not meaningful pay measures in this dataset; monthly\_income is used instead|




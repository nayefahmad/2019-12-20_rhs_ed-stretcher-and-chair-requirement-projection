

select distinct [EmergencyAreaDescription]
from EDMart.dbo.vwEDVisitAreaRegional
where FacilityShortName='RHS';

select L.*, R.DispositionDate, R.DispositionTime, R.AdmittedFlag, R.Age
, DispositionDate+DispositionTime as DischargeDateTime
, R.StartDate, R.StartTime
, StartDate+StartTime as StartDateTime
from EDMart.dbo.vwEDVisitAreaRegional L
	left join EDMart.dbo.vwEDVisitIdentifiedRegional R
	on L.VisitID=R.visitID
where L.FacilityShortName='RHS' and EmergencyAreaDescription='Shortstay Peds - ED'
	and EmergencyAreaDate>='2016/4/1'
order by EmergencyAreaDate+EmergencyAreaTime;



-- create a list of unique VisitIDs from vwEDVisitAreaRegional 
-- purpose: this splits the filtering criteria and the final query into two steps 
--		The next query gets the patient list after applying search criteria
--		After that, we do a join and filter for this patient list 


drop table if exists #t1_pt_list; 
select distinct visitID
into #t1_pt_list
from EDMart.dbo.vwEDVisitAreaRegional
where FacilityShortName='RHS' 
	and EmergencyAreaDescription='Shortstay Peds - ED' -- If we're not focussing on a particular ED area, we can drop this filter 
	and EmergencyAreaDate between '2016/4/1' and '2019/3/31';
--11110 rows



-- Create a "long-format" table with 1 row for each ED area that each 
-- patient goes to, including a row for Discharge 
drop table if exists #t2_ED_path; 
select PatientID, Age, VisitID, EmergencyAreaDescription, AreaDate, AreaDateTime
	, ROW_NUMBER() over (Partition by VisitID Order by AreaDateTime) as RowID
into #t2_ED_path
from (select L.VisitID
			, R.PatientID
			, R.Age
			, EmergencyAreaDescription
			, EmergencyAreaDate as AreaDate
			, EmergencyAreaDate+EmergencyAreaTime as AreaDateTime 
		from EDMart.dbo.vwEDVisitAreaRegional L
			left join EDMart.dbo.vwEDVisitIdentifiedRegional R
			on L.VisitID=R.VisitID
		where L.FacilityShortName='RHS'  
			and L.VisitID in (select VisitID from #t1_pt_list)
		
		union 

		-- for each VisitID, add a row to show when they left ED 
		select VisitID
			, PatientID
			, Age
			, 'Discharge' as EmergencyAreaDescription
			, AreaDate = case when AdmittedFlag=1 then BedRequestDate
					else DispositionDate end
			, AreaDateTime = case when AdmittedFlag=1 then BedRequestDate+BedRequestTime 
					else DispositionDate+DispositionTime end
		from EDMart.dbo.vwEDVisitIdentifiedRegional
		where FacilityShortName='RHS' 
			and VisitID in (select VisitID from #t1_pt_list)
) a; -- ends subquery 
--47027 rows 
--select * from #t2_ED_path order by VisitID, RowID, PatientID; 




select Fiscalyear
	, count(*) as ArrivalToSSU
	, avg(datediff(mi, InDateTime, OutDateTime)*1.0) as SSULOSperArrival
	, count(distinct VisitID) as EDVisitCount
from(
	select d.FiscalYear, L.PatientID, L.VisitID, L.EmergencyAreaDescription, L.AreaDate
		, L.AreaDateTime as InDateTime
		, R.AreaDateTime as OutDateTime
	from (select * from #t2_ED_path where EmergencyAreaDescription = 'Shortstay Peds - ED') L
		
		-- bring the next row into the same row, as a new column: 
		left join #t2_ED_path R
			on L.VisitID = R.visitID 
				and L.RowID = R.RowID-1  
		left join ADTCMart.dim.date d
			on L.AreaDate = ShortDate
	where R.AreaDateTime is not null
)a
group by FiscalYear
order by FiscalYear

--Results
--16/17	3124		126.164532
--17/18	3958		122.452248
--18/19	4411		129.706415





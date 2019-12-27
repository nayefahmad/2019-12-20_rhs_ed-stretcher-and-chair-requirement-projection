
select distinct [EmergencyAreaDescription]
from EDMart.dbo.vwEDVisitAreaRegional
where FacilityShortName='RHS'

select L.*, R.DispositionDate, R.DispositionTime, R.AdmittedFlag, R.Age, DispositionDate+DispositionTime as DischargeDateTime
, R.StartDate, R.StartTime, StartDate+StartTime as StartDateTime
from EDMart.dbo.vwEDVisitAreaRegional L
left outer join EDMart.dbo.vwEDVisitIdentifiedRegional R
on L.VisitID=R.visitID
where L.FacilityShortName='RHS' and EmergencyAreaDescription='Shortstay Peds - ED'
and EmergencyAreaDate>='2016/4/1'
order by EmergencyAreaDate+EmergencyAreaTime

select distinct visitID
into #TempPatList
from EDMart.dbo.vwEDVisitAreaRegional
where FacilityShortName='RHS' and EmergencyAreaDescription='Shortstay Peds - ED'
and EmergencyAreaDate between '2016/4/1' and '2019/3/31'
--11110 rows

If Object_ID ('tempdb.dbo.#TempPath') is not NULL  drop table #TempPath
select PatientID, Age, VisitID, EmergencyAreaDescription, AreaDate, AreaDateTime
, ROW_NUMBER() over (Partition by VisitID Order by AreaDateTime) as RowID
into #tempPath
from (select L.VisitID, R.PatientID, R.Age, EmergencyAreaDescription, EmergencyAreaDate as AreaDate, EmergencyAreaDate+EmergencyAreaTime as AreaDateTime 
	from EDMart.dbo.vwEDVisitAreaRegional L
	left outer join EDMart.dbo.vwEDVisitIdentifiedRegional R
	on L.VisitID=R.VisitID
	where L.FacilityShortName='RHS'  and L.VisitID in (select VisitID from #TempPatList)
	union 
	select VisitID, PatientID, Age, 'Discharge' as EmergencyAreaDescription
	, AreaDate = case when AdmittedFlag=1 then BedRequestDate
					else DispositionDate end
	, AreaDateTime = case when AdmittedFlag=1 then BedRequestDate+BedRequestTime 
					else DispositionDate+DispositionTime end
	from EDMart.dbo.vwEDVisitIdentifiedRegional
	where FacilityShortName='RHS' and VisitID in (select VisitID from #TempPatList)
	)a
	--47027

select Fiscalyear, count(*) as ArrivalToSSU, avg(datediff(mi, InDateTime, OutDateTime)*1.0) as SSULOSperArrival, count(distinct VisitID) as EDVisitCount
from
(
select d.FiscalYear, L.PatientID, L.VisitID, L.AreaDate, L.AreaDateTime as InDateTime, R.AreaDateTime as OutDateTime
from (select * from #TempPath where EmergencyAreaDescription = 'Shortstay Peds - ED') L
left outer join #TempPath R
on L.VisitID=R.visitID and L.RowID=R.RowID-1
left outer join EDMart.dim.date d
on L.AreaDate=ShortDate
where R.AreaDateTime is not null
)a
group by FiscalYear
order by FiscalYear

--Results
--16/17	3124		126.164532
--17/18	3958		122.452248
--18/19	4411		129.706415






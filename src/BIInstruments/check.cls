Class BIInstruments.check
{

/// do ##class(dev.bi).checkAllPivots()
ClassMethod checkPivots(stopOnError As %Boolean = 0) As %Status
{
	set countOfPivots = 0
	set countOfErrors = 0
	
	set sc = ##class(%DeepSee.Utils).%GetPivotList(.listOfPivots)

	set key = $order(listOfPivots(""))
	set errorList = ""
	
	while (key'="")
	{
		set sc = ..checkPivot(key,,.errors)

		set countOfPivots = countOfPivots + 1
		set:$$$ISERR(sc) countOfErrors = countOfErrors + 1
		quit:$$$ISERR(sc)&&stopOnError
		set key = $order(listOfPivots(key))
		// sometimes errors is empty 
		if errors '= ""
		{
			set errorList = errorList _ $lb(errors, key)
		}	
	}
	// going through list with pivots and errors
	w !, "Pivot errors and pivots summary"
	set ptr=0
	while $listnext(errorList,ptr,error) {
          w !,error	  
    }
	
	w !,"Pivots tested: "_countOfPivots,!
	w !,"Errors: "_countOfErrors, !
	

	if countOfErrors {
		set sc=$$$ERROR($$$GeneralError, "Found "_countOfErrors_" errors in pivots in "_$namespace_" namespace")
	}
	return sc
}

/// do ##class(dev.bi).exportCubes()
ClassMethod exportCubes() As %Status
{

	set sc = ##class(%DeepSee.Utils).%GetCubeList(.listOfCubes,"cubes")

	set key = $order(listOfCubes(""))

	while (key'="")
	{
		set cubeClassName = ##class(%DeepSee.Utils).%GetCubeClass(key)
		set cubeSourceClassName = ##class(BIInstruments.utils).getSourceClass(key)

		do ##class(BIInstruments.utils).exportUDL(cubeClassName_".cls")
		do ##class(BIInstruments.utils).exportUDL(cubeSourceClassName_".cls")

		set key = $order(listOfCubes(key))
	}

	return $$$OK
}

/// do ##class(dev.bi).checkPivot()
ClassMethod checkPivot(pivotFullName, debug = 1, ByRef errors) As %Status
{
	do ##class(%DeepSee.Utils).%GetResultSetFromPivot(pivotFullName, .sc,1, .pParms)
	w:debug "Pivot: "_pivotFullName,!
	w:debug "Status: "_$system.Status.DisplayError(sc),!
	set errors = $system.Status.GetErrorText(sc)
	return sc
}

/// do ##class(dev.bi).checkDashboards()
ClassMethod checkDashboards(stopOnError As %Boolean = 0) As %Status
{
	set countOfDashboards = 0
	set countOfPivots = 0
	set countOfPitotErrors = 0
	set countOfControlErrors = 0
	set scStop = 0
	
	set sc = ##class(%DeepSee.Utils).%GetDashboardList(.listOfDashboards)

	set key = $order(listOfDashboards(""))
	set dashErrors = ""
	set controlErrors = ""
	while (key'="")
	{
		set st = ..checkDashboard(key, .countOfPivots, .countOfPitotErrors, .countOfControlErrors, .scStop, .pivotsError, .controlError)
		set countOfDashboards = countOfDashboards + 1
		quit:scStop&&stopOnError
		set key = $order(listOfDashboards(key))
		if pivotsError '= ""
		{
			set dashErrors = dashErrors _ $lb(pivotsError, key)
		}
		if controlError '= ""
		{
			set controlErrors = controlErrors _ $lb(controlError, key)
		}
		
		
	}
	w !, "Pivot errors and dashboard summary"
	set ptr=0
	while $listnext(dashErrors,ptr,error) {
          w !,error	  
    }
	w !
	w !, "Control errors and dashboard summary"
	while $listnext(controlErrors,ptr,Controlerror) {
          w !,Controlerror	  
    }

	w !
	w !,"Dashboards tested: "_countOfDashboards,!
	w "Pivots tested: "_countOfPivots,!
	w "Pivots errors: "_countOfPitotErrors,!
	w "Filters errors: "_countOfControlErrors,!

	if countOfPitotErrors {
		set sc=$$$ERROR($$$GeneralError, "Found "_countOfPitotErrors_" errors in pivots in "_$namespace_" namespace")
	}
	if countOfControlErrors {
		set sc=$SYSTEM.Status.AppendStatus(sc,$$$ERROR($$$GeneralError, "Found "_countOfControlErrors_" errors in filters in "_$namespace_" namespace"))
	}
	return sc
}

/// do ##class(dev.bi).checkDashboard("Basic Dashboard Demo.dashboard")
ClassMethod checkDashboard(dashboardName, ByRef countOfPivots = 0, ByRef countOfPitotErrors = 0, ByRef countOfControlErrors = 0, ByRef scStop = 0, ByRef pivotsError, ByRef controlError) As %Status
{
	set dashboard = ##class(%DeepSee.Dashboard.Utils).%OpenDashboard(dashboardName,.tSC)
	
	if '$isObject(dashboard)
	{
		w !,"Dashboard "_dashboardName_" does not exist.",!
		return $$$OK
	}

	w !,"Dashboard name: "_dashboardName,!
	;set wDashName = 1
	set pivotsError = ""
	set controlError = ""
	for i=1:1:dashboard.widgets.Count()
	{
		set widget = dashboard.widgets.GetAt(i)
		set pivotFullName= widget.dataSource
		w "Widget name: "_widget.name,!

		if $$$LOWER($E(pivotFullName,*-3,*))=".kpi" {
			w "The datasource is KPI, tests are not supported for now skip",!
			continue
		}

		if pivotFullName="" {
			w "The datasource is empty, skip",!
			continue
		}

		set countOfPivots = countOfPivots + 1

		set cubeName = ##class(BIInstruments.utils).getCubeNameByPivot(pivotFullName)

		#; w:wDashName !,"Dashboard name: "_dashboardName,!
		#; set wDashName = 0

		w "Cube name: "_cubeName,!
		w "Pivot name: "_ pivotFullName,!
		set pivotSC = ..checkPivot(pivotFullName,0)

		
		if $$$ISERR(pivotSC)
		{	
			set pivotsError = $system.Status.GetErrorText(pivotSC)
			w "Pivot status: ",$system.Status.GetErrorText(pivotSC),!!	
			set countOfPitotErrors = countOfPitotErrors + 1
			set scStop = 1
		}
		else
		{
			w "Pivot status: OK!",!!
		}

		for j=1:1:widget.controls.Count()
		{
			set control = widget.controls.GetAt(j)
			set action = control.action
			set targetProperty = control.targetProperty
			set label = control.label

			if (action = "setFilter") || (action = "applyFilter")
			{
				set controlSc = ##class(%DeepSee.Utils).%GetDimensionInfo(cubeName, targetProperty)
				w "Filter name: "_label,!

				if $$$ISERR(controlSc)
				{
					set controlError = $system.Status.GetErrorText(controlSc)
					w "Status: "_controlError,!
					set countOfControlErrors = countOfControlErrors + 1
					set scStop = 1
				}
				else
				{
					w "Status: OK!",!
				}
			}
			
		}

	}
 	return $$$OK
}

// method check SQL component and XML structure of the KPI

ClassMethod checkKPI() As %Status
{
	set sc = $$$OK

	Set sc = ##class(%DeepSee.Utils).%GetKPIList(.tKPIList)

	set key = $order(tKPIList(""))
   	while (key'="") {
		set kpiName = $list(tKPIList(key), 1)
		Set tKpiClassName = ##class(%DeepSee.Utils).%GetKPIClass(kpiName_".kpi",.tSC)
		set kpitype = $classmethod(tKpiClassName, "%GetSourceType")
		if kpitype = "sql"
		{
			set pSQL = $classmethod(tKpiClassName,"%GetSQLText")
			set xmlGeneration = $classmethod(tKpiClassName, "%Generate")

            set tStatement = ##class(%SQL.Statement).%New(2,"Sample")
	        set sc = tStatement.%Prepare(.pSQL)

		}
		elseif kpitype = "mdx"
		{
			set pMDX = $classmethod(tKpiClassName,"%GetMDXText")
			set sc = ##class(BIInstruments.utils).getMDX(pMDX)
		}
		
		w "KPI: ",kpiName,!
		w "query: "_$select(sc'=1:$System.Status.GetErrorText(sc),1:"OK"),!
		w "xml definition:" _$select(sc'=1:$System.Status.GetErrorText(xmlGeneration),1:"OK"),!,!
	
			
    	set key = $ORDER(tKPIList(key))
   }
	
	 
	quit sc
}

// method rebuild cubes to check for missing data or wrong syntax

ClassMethod UpdateCubes(verbose = 0, NumberOfFacts = 0) As %Status
{
	Set st = ##class(%DeepSee.Utils).%GetCubeList(.list, "cubes")
	Return:$$$ISERR(st) st

	Set cube=""
	For {
		 Set cube=$Order(list(cube))

		 Quit:cube=""
		 Set st1 = ##class(%DeepSee.Utils).%BuildCube(cube, $$$YES, verbose, 0, NumberOfFacts)

		 Set st = $$$ADDSC(st, st1)
	}
	Return st
}

ClassMethod Check(pivotCheck As %Boolean = 0, dashboardCheck As %Boolean = 0, cubesCheck As %Boolean = 0, KPICheck As %Boolean = 0) As %Status
{
	set st = $$$OK
	if cubesCheck
	{	
		w !, "Test sequence for cubes has started", !
		set st = ..UpdateCubes(1)
	}
	if pivotCheck
	{	w !, "Test sequence for pivots has started", !
		set st = ..checkPivots()
	}
	if dashboardCheck
	{
		w !, "Test sequence for dashboards has started", !
		set st = ..checkDashboards()
	}
	if KPICheck
	{
		w !, "Test sequence for KPI has started", !
		set st = ..checkKPI()
	}

	quit st
}

}

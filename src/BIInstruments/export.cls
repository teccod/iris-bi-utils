Class BIInstruments.export
{

/// export all available code
ClassMethod export(mask = "", generated = 0, system = 0, percent = 0, mapped = 0, dfi = 0)
{
	#define export(%code, %file) set sc = $system.OBJ.ExportUDL(%code, %file,"/diffexport") ##continue
								 write:sc "Ok" do:'sc $system.OBJ.DisplayError(sc)

	#define isGenerated(%code) ##class(%RoutineMgr).IsGenerated( %code )
	#define isPercented(%code) ("%" = $e(%code))
	#define isMapped(%code) ##class(%RoutineMgr).IsMapped( %code )
	#define log write !, code, " -> ", $piece(filename,##class(BIInstruments.utils).workdir(),2), " "
						
	write "#; Exporting to ", ##class(BIInstruments.utils).workdir(),!
	#; classes
	set rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:Summary")
	if rs.Execute() 
	{
		while rs.%Next()
		{
			set code = rs.Name _ ".cls", isSystem = rs.System
			if ( 'system && isSystem ) continue
			if ( 'generated && $$$isGenerated( code ) ) continue
			if ( 'percent && $$$isPercented( code ) ) continue
			if ( 'mapped && $$$isMapped( code ) ) continue
			if ( '##class(BIInstruments.utils).checkMasks( code, mask ) ) continue
			
			set filename = ##class(BIInstruments.utils).filename( code )
			do ##class(BIInstruments.utils).mkdir( filename )
			$$$log
			$$$export( code, filename )
		} 
		set rs=""
	}

	#; routines
	set rs = ##class(%ResultSet).%New("%Routine:RoutineList")
	if rs.Execute() 
	{
		while rs.%Next() 
		{
	 		set code = rs.Name
	 		write code,!
	 		if ( 'generated && $$$isGenerated( code ) ) continue
	 		if ( 'percent && $$$isPercented( code ) ) continue
			if ( 'mapped && $$$isMapped( code ) ) continue
			if ( '##class(BIInstruments.utils).checkMasks( code, mask ) ) continue
			
			set filename = ##class(BIInstruments.utils).filename( code )
			do ##class(BIInstruments.utils).mkdir( filename )
			$$$log
			$$$export( code, filename )

		} 
		set rs=""
	}

	#; dfi
	do ##class(BIInstruments.utils).fixDashIntoName()
	#define export(%code,%file) set sc = ##class(%DeepSee.UserLibrary.Utils).%Export( %code, %file, 0 ) 
	
	set sql = "Select id, fullName as Name, documentName From %DeepSee_UserLibrary.FolderItem"
    set rs = ##class(%SQL.Statement).%ExecDirect( .stm, sql )
	while rs.%Next() 
	{
		set code = rs.Name
		set filename = ##class(BIInstruments.utils).filename( code_".dfi" )
		set documentName = rs.documentName
		
		if ($L(code,"$TRASH")>1) continue
		
		if ( 'generated && $$$isGenerated( code ) ) continue
	 	if ( 'percent && $$$isPercented( code ) ) continue
		if ( 'mapped && $$$isMapped( code ) ) continue
		if ( '##class(BIInstruments.utils).checkMasks(documentName, mask) ) continue
		
		do ##class(BIInstruments.utils).mkdir( filename )
		
		if dfi
		{
			$$$log
			$$$export( code, filename)
		}
		elseif ('dfi)
		{
			set documentName = $replace(documentName,"/","-")
			set filename = $extract(filename,1,*-4)
			do ##class(BIInstruments.utils).fixXMLLine(documentName,filename_".xml")
		}

	} 
	set rs=""
	
	#;DeepSee artefacts
	do ..exportCubes()
	do ..exportDeepSeeArtefacts()
	write !,!, "#; Exported to ", ##class(BIInstruments.utils).workdir()
	
    return $$$OK
}

ClassMethod exportDeepSeeArtefacts() As %Status
{
	set sc = $$$OK
	set artefacts = $listbuild("DeepSee.Variables","DeepSee.TermList","DeepSee.CalcMbrs")

	for i=1:1:$listlength(artefacts)
	{
		set artefact = $list(artefacts,i)
		continue:$data(@("^"_artefact))=0

		set artefact = artefact_".GBL"
		set filename = ##class(BIInstruments.utils).filename(artefact)
		do ##class(BIInstruments.utils).mkdir(filename)

		//without .gbl in the file name
		set filename = $e(filename,1, *-4)

		set sc = ..exportXML(artefact, filename_".xml")
	}

	return sc
}


ClassMethod exportXML(documentName, filename) As %Status
{
	set stream = ##class(%Stream.FileBinary).%New()
	do stream.LinkToFile(filename)
	do $system.OBJ.ExportToStream(documentName, .stream)

	set matcher=##class(%Regex.Matcher).%New("<Export generator=.+>")
	set matcher.Text = stream.Read(stream.Size)
	set data = matcher.ReplaceFirst("<Export generator=""Cache"">")

	do stream.Clear()
	do stream.Write(data)
	return stream.%Save()
}

ClassMethod exportUDL(itemName As %String) As %Status
{
	set filename = ##class(BIInstruments.utils).filename(itemName)
	do ##class(BIInstruments.utils).mkdir( filename )

	write !, itemName, " -> ", $piece(filename,##class(BIInstruments.utils).workdir(),2), " "

	set sc = $system.OBJ.ExportUDL(itemName, filename,"/diffexport")
	write:sc "Ok" do:'sc $system.OBJ.DisplayError(sc)

	return sc
}

ClassMethod exportDashboards() As %Status
{
	do ##class(BIInstruments.utils).fixDashIntoName()

	set sc = ##class(%DeepSee.Utils).%GetDashboardList(.listOfDashboards)

	set key = $order(listOfDashboards(""))

	while (key'="")
	{
		do ..exportDFIinXML(key_".DFI")
		set key = $order(listOfDashboards(key))
	}

	return $$$OK
}

ClassMethod exportPivots() As %Status
{
	do ##class(BIInstruments.utils).fixDashIntoName()

	set sc = ##class(%DeepSee.Utils).%GetPivotList(.listOfPivots)

	set key = $order(listOfPivots(""))

	while (key'="")
	{
		do ..exportDFIinXML(key_".DFI")
		set key = $order(listOfPivots(key))
	}

	return $$$OK
}

ClassMethod exportDFIinXML(itemName As %String) As %Status
{
	set filename = ##class(BIInstruments.utils).filename(itemName)
	do ##class(BIInstruments.utils).mkdir( filename )

	write !, itemName, " -> ", $piece(filename,##class(BIInstruments.utils).workdir(),2), " "

	set documentName = $replace(itemName,"/","-")
	set filename = $extract(filename,1,*-4)
	do ..exportXML(documentName,filename_".xml")

	return $$$OK
}

/// Export Cube Classes
ClassMethod exportCubes() As %Status
{
	#define export(%code, %file) set sc = $system.OBJ.ExportUDL(%code, %file,"/diffexport") ##continue
								 write:sc "Ok" do:'sc $system.OBJ.DisplayError(sc)
	#define isMapped(%code) ##class(%RoutineMgr).IsMapped( %code )
	#define isPercented(%code) ("%" = $e(%code))
	#define isCube(%code) $classmethod(%code,"%Extends","%DeepSee.CubeDefinition")
	
	#define log write !, code, " -> ", $piece(filename,##class(BIInstruments.utils).workdir(),2), " "
	
	Set sc = $$$OK
	#; classes
	set rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:Summary")
	if rs.Execute() 
	{
		while rs.%Next()
		{
			set code = rs.Name _ ".cls", isSystem = rs.System
			if isSystem continue
			if $$$isPercented( code ) continue
			if $$$isMapped( code )  continue
			
			if '($classmethod(rs.Name,"%Extends","%DeepSee.CubeDefinition")) continue
			set filename = ##class(BIInstruments.utils).filename( code )
			do ##class(BIInstruments.utils).mkdir( filename )
			$$$log
			$$$export( code, filename )
		} 
		set rs=""
	}


	Return sc
}


ClassMethod exportKPIs() As %Status
{

	set sc = ##class(%DeepSee.Utils).%GetKPIList(.listOfKPIs)

	set key = $order(listOfKPIs(""))

	while (key'="")
	{
		set kpiClassName = ##class(%DeepSee.Utils).%GetKPIClass(key)

		do ..exportUDL(kpiClassName_".cls")
		set key = $order(listOfKPIs(key))
	}

	return $$$OK
}
/// Method to export all cubes, source cube classes, dashboards, 
/// pivots and globals from the namespace available to the current user
ClassMethod exportBI() As %Status
{
	do ..exportCubes()
	do ..exportKPIs()
	do ..exportDashboards()
	do ..exportPivots()
	do ..exportDeepSeeArtefacts()
	
	return $$$OK
}

}

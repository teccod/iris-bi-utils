Class utils.export
{
/// export all available code
ClassMethod export(mask = "", generated = 0, system = 0, percent = 0, mapped = 0, dfi = 0)
{
	#define export(%code, %file) set sc = $system.OBJ.ExportUDL(%code, %file,"/diffexport") ##continue
								 write:sc "Ok" do:'sc $system.OBJ.DisplayError(sc)

	#define isGenerated(%code) ##class(%RoutineMgr).IsGenerated( %code )
	#define isPercented(%code) ("%" = $e(%code))
	#define isMapped(%code) ##class(%RoutineMgr).IsMapped( %code )
	#define log write !, code, " -> ", $piece(filename,..workdir(),2), " "
						
	write "#; Exporting to ", ..workdir(),!
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
			if ( '..checkMasks( code, mask ) ) continue
			
			set filename = ..filename( code )
			do ..mkdir( filename )
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
			if ( '..checkMasks( code, mask ) ) continue
			
			set filename = ..filename( code )
			do ..mkdir( filename )
			$$$log
			$$$export( code, filename )

		} 
		set rs=""
	}

	#; dfi
	do ..fixDashIntoName()
	#define export(%code,%file) set sc = ##class(%DeepSee.UserLibrary.Utils).%Export( %code, %file, 0 ) 
	
	set sql = "Select id, fullName as Name, documentName From %DeepSee_UserLibrary.FolderItem"
    set rs = ##class(%SQL.Statement).%ExecDirect( .stm, sql )
	while rs.%Next() 
	{
		set code = rs.Name
		set filename = ..filename( code_".dfi" )
		set documentName = rs.documentName
		
		if ($L(code,"$TRASH")>1) continue
		
		if ( 'generated && $$$isGenerated( code ) ) continue
	 	if ( 'percent && $$$isPercented( code ) ) continue
		if ( 'mapped && $$$isMapped( code ) ) continue
		if ( '..checkMasks(documentName, mask) ) continue
		
		do ..mkdir( filename )
		
		if dfi
		{
			$$$log
			$$$export( code, filename)
		}
		elseif ('dfi)
		{
			set documentName = $replace(documentName,"/","-")
			set filename = $extract(filename,1,*-4)
			do ..fixXMLLine(documentName,filename_".xml")
		}

	} 
	set rs=""
	
	#;DeepSee artefacts
	do ..exportCubes()
	do ##class(dev.bi).exportDeepSeeArtefacts()
	write !,!, "#; Exported to ", ..workdir()
	
    return $$$OK
}

ClassMethod filename(code)
{
	#define log(%dir,%sc) w !, "mkdir ", %dir, " ", sc

	set wd = ..workdir()

	if '##class(%File).DirectoryExists( wd ) {
		set sc = ##class(%File).CreateDirectoryChain( wd )
		$$$log(wd,sc)
	}

	set ext = $p( code, ".", * ), ext = $zcvt( ext, "l" )

	// for each type - different directory
	set extensions = $lb("int","inc","mac","dfi","gbl")
	if ($lf(extensions, ext)>0)
	{
		set wd = ##class(%File).NormalizeDirectory( ext, wd )
	}

	// directory must exist before any call (%File).NormalizeFilename( , wd)
	if '##class(%File).DirectoryExists( wd ) 
	{
		set sc = ##class(%File).CreateDirectoryChain( wd )
		$$$log(wd,sc)
	}

	set filename = ##class(%File).NormalizeFilename( code, wd )
	
	// lowercase file extension
	set $p(filename,".",*)=ext
	
	#; for *.cls Package.Subpackage.ClassName.cls -> Folder/Subfolder/ClassName.cls
	if (ext="cls")
	{
		set dirs = $piece( code, ".",1, *-2 ), dirs = $translate( dirs, ".", "/" )
		set relpath = dirs _ "/" _ $piece( code, ".", *-1, * ) ;
		set filename = ##class(%File).NormalizeFilename( relpath, wd )
	}

	return filename
}

/// get or set working directory for export/import source
ClassMethod workdir(workdir)
{
	set:$d(workdir) workdir = ##class(%File).NormalizeDirectory(workdir)
	set gln = ..gln() 
	set:$d(workdir) @gln = workdir
	
	///zu(12) namespace directory by default
	#define nsdir $zu(12,"")
	return $g(@gln, $$$nsdir)
}

ClassMethod checkMasks(name As %String, masks As %String) As %Boolean
{
	return:masks="" 1
	return:name="" 0
	
	set name = $zcvt(name,"l")
	set masks =  $zcvt(masks,"l")
	
	for i=1:1:$l(masks,",")
	{
		set pattern = "^"
		set mask = $p(masks, ",", i)
		
		for index=1:1:$l(mask)
		{
			set char = $e(mask, index)
    		set pattern = pattern _ $case(char,
    									  ".":"\.",
    									  "?":".",
    									  "*":".*",
    									     :char
    									  )	
		}
		set pattern = pattern _ "$|"
	}
	set pattern = $e(pattern,1,*-1)
	set matcher=##class(%Regex.Matcher).%New(pattern, name)
	do matcher.Locate() 
	return $select(matcher.Group="":0, 1:1)
}

ClassMethod mkdir(filename As %String) As %Status
{
	set sc = $$$OK
	set path = ##class(%File).GetDirectory(filename) 
	if '##class(%File).DirectoryExists(path) 
	{
		set sc = ##class(%File).CreateDirectoryChain(path) 
		write !, "mkdir ", path, " ", sc 
	}
	return sc
}

ClassMethod fixDashIntoName()
{
	set sql = "Select id, fullName as Name, documentName From %DeepSee_UserLibrary.FolderItem"
    set rs = ##class(%SQL.Statement).%ExecDirect( .stm, sql )
    while rs.%Next() {
		if $find(rs.Name, "-"){
			write rs.Name," -> "
			set item = ##class(%DeepSee.UserLibrary.FolderItem).%OpenId(rs.id)
			set item.name = $replace(item.name,"-"," ")
			write item.name,!
			do item.%Save()
		}
    }
    kill rs
}

ClassMethod fixXMLLine(documentName, filename) As %Status
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

/// Export Cube Classes
ClassMethod exportCubes() As %Status
{
	#define export(%code, %file) set sc = $system.OBJ.ExportUDL(%code, %file,"/diffexport") ##continue
								 write:sc "Ok" do:'sc $system.OBJ.DisplayError(sc)
	#define isMapped(%code) ##class(%RoutineMgr).IsMapped( %code )
	#define isPercented(%code) ("%" = $e(%code))
	#define isCube(%code) $classmethod(%code,"%Extends","%DeepSee.CubeDefinition")
	
	#define log write !, code, " -> ", $piece(filename,..workdir(),2), " "
	
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
			set filename = ..filename( code )
			do ..mkdir( filename )
			$$$log
			$$$export( code, filename )
		} 
		set rs=""
	}


	Return sc
}
}
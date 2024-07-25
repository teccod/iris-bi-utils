Class BIInstruments.utils
{

Parameter TRACKEDEXT As List = {$lb("xml", "cls", "csp", "csr", "mac", "int", "bas", "inc", "gbl", "prj", "obj", "pkg", "gof", "dfi", "pivot", "dashboard")};

ClassMethod ToCacheName(ByRef filename)
{
	if $get(filename)="" break
	do:$L($zcvt(filename,"L"),".xml")>1 ..getExtension(.filename)
	set str = $Select(
		$L(filename,"cls/")>1:$Replace($P(filename,"cls/",2),"/","."),
	    $L(filename,"csp/")>1:$Replace($P(filename,"csp/",2),"/","."),
	    $L(filename,"dfi/")>1:$Replace($P(filename,"dfi/",2),"/","-"),
	    $L(filename,"inc/")>1:$Replace($P(filename,"inc/",2),"/","."),
	    $L(filename,"web/")>1:$Replace($P(filename,"web/",2),"/","."),
	    1:$Replace(filename,"/",".")
	   )
	set filename = $P(str,".",1,*-1)_"."_ $ZCVT($P(str,".",*),"U")
}

ClassMethod isRelevantFile(file As %String) As %Boolean
{
	set ext = $select($length(file, ".")=1:"", 1:$piece(file, ".", *))
	quit $lf(..#TRACKEDEXT, ext)>0
}

ClassMethod getExtension(ByRef filename)
{
	if ($L(filename,"dfi/") > 1) {
		set filename = $extract(filename,1,*-4)_".DFI"
	}elseif ($L(filename,"cls/") > 1) {
		set filename = $extract(filename,1,*-4)_".CLS"
	}elseif ($L(filename,"gbl/") > 1) {
		set filename = $p($extract(filename,1,*-4),"gbl/",2)
	}
}

ClassMethod getLocalGitPathByWorkdir(workdir As %String) As %String
{
	set path = ""
	if ($L(workdir,"/") > 1) {
		if ($P(workdir,"/",*) = "") {
			set path = $P(workdir,"/",*-1)
		}else {
			set path = $P(workdir,"/",*)
		}

	}else {
		if ($P(workdir,"\",*) = "") {
			set path = $P(workdir,"\",*-1)
		}else {
			set path = $P(workdir,"\",*)
		}
	}
	
	return path_"/"
}

ClassMethod getSourceClass(pCubeName As %String) As %String
{
  Quit $G(^DeepSee.Cubes("cubes",$$$UPPER(pCubeName),"sourceClass"))
}

ClassMethod getCubeNameByPivot(pivotFullName) As %String
{
	set mdx = ##class(%DeepSee.Utils).%GetMDXFromPivot(pivotFullName,,0)

	set cubeName = $p(mdx," FROM [", 2)
	set cubeName = $p(cubeName,"]", 1)

	return cubeName
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

/// gl[obal] n[ame] - storage for settings
ClassMethod gln() [ CodeMode = expression, Private ]
{
"^"_$classname()
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

ClassMethod getMDX(pPivotName As %String, Output MDX) As %Status
{
	#dim tPivot As %DeepSee.Dashboard.Pivot
	#dim tPivotTable As %DeepSee.Component.pivotTable
	set MDX = ""

	set tPivot = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(pPivotName,.sc)
	return:'$IsObject(tPivot) $$$OK
	return:$$$ISERR(sc) sc

	set tPivotTable = ##class(%DeepSee.Component.pivotTable).%New()
	set sc = tPivot.%CopyToComponent(tPivotTable)
	return:$$$ISERR(sc) sc

	set rs = tPivotTable.%CreateResultSet(.sc,,,,.MDX) // returns tQueryText - mdx without filters
	return:$$$ISERR(sc) sc
	
	set MDX = $TR(MDX,$C(10),"")
	
	return sc
}

/// get the filtermask for the repository.
/// looks for .gitignore file and applies all the lines to filters
ClassMethod setIgnore(ByRef filtermask, verbose)
{
	// working with .gitignore file
	// gitignore consists of masks of filtering files
	set filename=..workdir()_"/.gitignore"
	if '##class(%File).Exists(filename) quit
	set file=##class(%File).%New(filename)
	set sc=file.Open("R")
	if 'sc 
	{
		if verbose do $System.OBJ.DisplayError(sc) return
	}

	While 'file.AtEnd
	{
		set filtermask($I(filtermask))=file.ReadLine()
	}
	quit
}

ClassMethod inFilter(ByRef filtermask, filename) As %Boolean
{
	set result=0
	for 
	{
		if '$d(filtermask($I(i))) quit
		set filter=$piece(filtermask(i),"*")
		if $length(filename,filter)>1 set result=1
	}

	return result
}

ClassMethod patch(filename = "", commitFrom = "", commitTo = "") As %Status
{
	set gln = ..gln()
	set git = @gln@("git")

	set:commitTo="" commitTo=1
	if (git = 0) 
	{
		set:(commitFrom="")||(commitFrom=1) commitFrom=0
		set sc = ##class(BIInstruments.diff.gitLocal).buildDiff(##class(BIInstruments.utils).workdir(), "HEAD~"_commitTo, "HEAD~"_commitFrom, .items)
		return:$$$ISERR(sc) sc
	}
	elseif(git = 1) 
	{
		set owner = @gln@("owner")
		set repository = @gln@("repository")
		set user = @gln@("user")
		set password = @gln@("password")
		set:commitFrom="" commitFrom=1
		
		set sc = ##class(BIInstruments.diff.gitHub).Get(.items, owner, repository, user, password, commitFrom, commitTo)
		return:$$$ISERR(sc) sc	
	}
	
	if (filename="") 
	{
		set filename=$G(@gln@("projectName"),"patch")
		set filename=filename_$p($zdt($h,8)," ")_$tr($p($p($zdt($h)," ",2),":",1,2),":")_".xml"	
	}
	zw filename
	set sc = $system.OBJ.Export(.items,filename)
	
	return sc
}

ClassMethod init(confile = "isc.json")
{
	quit:..workdir()="" "workdir is empty"
	quit:'##class(%File).Exists(..workdir()_confile) "configuration file: "_confile_" not found in "_..workdir()
	
	set stream=##class(%Stream.FileCharacter).%New()
	set sc=stream.LinkToFile(..workdir()_confile)
	set conf={}.%FromJSON(stream.Read($$$MaxCacheInt))
	
	set gln = "^dev.code"
	
	set @gln@("compileList")=conf.compileList
	set @gln@("projectName")=conf.projectName
	set @gln@("owner")=conf.owner
	set @gln@("repository")=conf.repository
	set @gln@("user")=conf.user
	set @gln@("password")=conf.password
	set @gln@("git")=conf.git
	set:@gln@("git")="" @gln@("git")=0
	
	write "compileList="_conf.compileList,!
	write "projectName="_conf.projectName,!
	write "owner="_conf.owner,!
	write "repository="_conf.repository,!
	write "user="_conf.user,!
	write "password="_conf.password,!
	write "git="_conf.git,!
	
	quit $$$OK
}

/// export release file for list and project settings
ClassMethod release()
{
	set gln=..gln()
	set list=$G(@gln@("compileList"))
	if list="" write "Nothing to release. Run init method first" quit

	set release=$G(@gln@("projectName"),"release")
	set release=release_$p($zdt($h,8)," ")_$tr($p($p($zdt($h)," ",2),":",1,2),":")_".xml"
	do $System.OBJ.Export(list,release)
	write "All objects with mask "_list_" has been exported to "_release
}

ClassMethod compile()
{
	set gln=..gln()
	set list=$G(@gln@("compileList"))
	if list="" write "Nothing to compile. Run init method first" quit
	do $System.OBJ.compile(list)
}
}


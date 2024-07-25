Class BIInstruments.FileManExtension Extends %Studio.Extension.Base
{

/// Called before the item is saved to the database it is passed
/// a reference to the current temporary storage of this item so that it
/// can be modified before the save completes. If you quit with an error
/// value then it will abort the save.
Method OnBeforeSave(InternalName As %String, Location As %String = "", Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
	Quit $$$OK
}

/// This is called after the item has been saved to the database.
/// It may be passed a reference to the object representing the item
/// just saved. It can be use to export this documement to an external form for example.
Method OnAfterSave(InternalName As %String, Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
	set ignorList = $lb("BIInstruments.export.CLS",
						"BIInstruments.FileManExtension.CLS",
						"BIInstruments.diff.gitHub.CLS",
						"BIInstruments.diff.gitLocal.CLS",
						"BIInstruments.utils.CLS")
	quit:$lf(ignorList, InternalName)=1 $$$OK
						
	set classAndRoutinesExts = $lb("cls","mac","int","inc")
	
	set ext = $zcvt($p(InternalName,".",*), "l")
	
	if $lf(classAndRoutinesExts, ext)
	{
		do ..exportClassAndRoutine($p(InternalName, ".", 1, *-1)_"."_ext)
	}
	elseif ext = "dfi"
	{
		set fileName = ##class(BIInstruments.utils).filename($replace(InternalName,"-","/"))
		set fileName = $extract(fileName,1,*-4)_".xml"
		
		do ##class(BIInstruments.utils).mkdir(fileName)
		do ##class(BIInstruments.utils).fixXMLLine(InternalName, fileName)
	}
	
	Quit $$$OK
}

ClassMethod exportClassAndRoutine(className) As %Status
{
	#define isGenerated(%code) ##class(%RoutineMgr).IsGenerated( %code )
	#define isPercented(%code) ("%" = $e(%code))
	#define isMapped(%code) ##class(%RoutineMgr).IsMapped( %code )
	
	if ($$$isGenerated(className)) quit $$$OK
	if ($$$isPercented(className)) quit $$$OK
	if ($$$isMapped(className)) quit $$$OK
	
	set fileName = ##class(BIInstruments.utils).filename(className)
	do ##class(BIInstruments.utils).mkdir(fileName)
	set sc = $system.OBJ.ExportUDL(className, fileName,"/diffexport")
	
	return $$$OK
}

/// This is called if you compile a class and the compilation updates the class storage.
/// It is called after the storage has been updated so you can determine how to deal with this
/// change in the class. The <var>Location</var> is the global reference to the class definition that was changed.
Method OnAfterStorage(InternalName As %String, Location As %String = "") As %Status
{
	Quit $$$OK
}

/// Called before the compile of the item is done.
/// It is passed a qstruct which can be inspected and modified.
Method OnBeforeCompile(InternalName As %String, ByRef qstruct As %String) As %Status
{
	Quit $$$OK
}

/// Called after the compile of the item is done.
Method OnAfterCompile(InternalName As %String) As %Status
{
	Quit $$$OK
}

/// Called in the class compiler after we have resolved the list of classes to be compiled but
/// before we have started the compile itself.
/// <var>List</var> is a subscripted array of items that will be compiled.
Method OnBeforeClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String) As %Status
{
	Quit $$$OK
}

/// Called in the class compiler after we have compiled all the classes before we exit.
/// <var>List</var> is a subscripted array of items that were compiled. <var>Status</var> is the current compile return
/// error %Status, so the callback can check if there was any error in compiling the list of classes.
Method OnAfterClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String, Status As %Status) As %Status
{
	Quit $$$OK
}

/// Called in the activated source control class before starting a compile after we have resolved the list of classes
/// but before we have started the compile itself. Note that this is a class method and it does not require the source
/// control class to be instantiated in order for it to be called. By default it will call the <method>OnBeforeClassCompile</method>
/// if there is a source control class instantiated, but you can override this to do whatever you require.
/// Returning an error here will abort the compile.
/// <var>List</var> is a subscripted array of items that will be compiled.
ClassMethod OnBeforeAllClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String) As %Status
{
	Set sc=$$$OK
	If $isobject($get(%SourceControl)) {
		Set tmp=%SourceControl New %SourceControl
		Set sc=tmp.OnBeforeClassCompile(.List,Level,.qstruct)
	}
	Quit sc
}

/// Called in the activated source control class after we have compiled all the classes but before we exit.
/// Note that this is a class method and it does not require the source
/// control class to be instantiated in order for it to be called. By default it will call the <method>OnAfterClassCompile</method>
/// if there is a source control class instantiated, but you can override this to do whatever you require.
/// <var>List</var> is a subscripted array of items that were compiled. <var>Status</var> is the current compile return
/// error %Status, so the callback can check if there was any error in compiling the list of classes.
ClassMethod OnAfterAllClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String, Status As %Status) As %Status
{
	Set sc=$$$OK
	If $isobject($get(%SourceControl)) {
		Set tmp=%SourceControl New %SourceControl
		Set sc=tmp.OnAfterClassCompile(.List,Level,.qstruct,.Status)
	}
	Quit sc
}

/// Called before an item is deleted. Returning an error code prevents the delete from occurring.
Method OnBeforeDelete(InternalName As %String) As %Status
{
	Quit $$$OK
}

/// Called after an item is deleted.
Method OnAfterDelete(InternalName As %String) As %Status
{
	set ext = $zcvt($p(InternalName,".",*), "l")
	
	if ext = "dfi"
	{
		set fileName = ##class(BIInstruments.utils).filename($replace(InternalName,"-","/"))
		set fileName = $extract(fileName,1,*-4)_".xml"
	}
	else
	{
		set fileName = ##class(BIInstruments.utils).filename(InternalName)
	}
	
	do ##class(%File).Delete(fileName)
	
	set dir = ##class(%File).ParentDirectoryName(fileName)
	
	while dir '= ##class(BIInstruments.utils).workdir()
	{
		set rs = ##class(%File).FileSetFunc(dir, , , 1)
		quit:rs.%Next()=1
		
		do ##class(%File).RemoveDirectory(dir)
		set dir = ##class(%File).ParentDirectoryName(dir)
	}
	
	Quit $$$OK
}

}


Class BIInstruments.diff.gitLocal
{

/// Get diff between two points in repository
/// repo - repository root directory
/// sha1, sha2 - poins of history in repository
/// 
/// Internal diff statuses:
/// M modified - File has been modified
/// C copy-edit - File has been copied and modified //3
/// R rename-edit - File has been renamed and modified //3
/// A added - File has been added
/// D deleted - File has been deleted
/// U unmerged - File has conflicts after a merge 
/// 
/// do ##class(isc.diff.gitLocal).buildDiff("C:\\temp\cache-udl\", "HEAD~10", "HEAD", release)
ClassMethod buildDiff(repo As %String, sha1 As %String, sha2 As %String, Output items) As %Status
{
	$$$TOE(sc, ..createFile(.tempFile))
	set oldDirectory = $system.Process.CurrentDirectory()
	do $system.Process.CurrentDirectory(repo)
	$$$TOE(sc, ..execute($$$FormatText("git diff --name-status %1 %2 > %3 2>&1", sha1, sha2, tempFile)))
	$$$TOE(sc, ..fileToString(tempFile, .diffRaw))
	
	set workdir = ##class(dev.code).workdir()
	set path = ##class(dev.diff.utils).getLocalGitPathByWorkdir(workdir)
	
	for i=1:1:$length(diffRaw, $c(10)) 
	{
		set element = $piece(diffRaw, $c(10), i)
		set status = $e($piece(element, $c(9)))
		set file = $piece(element, $c(9), 2)
		
		if ($l(file, path) < 2) continue
		
		set isRelevantFile = ##class(dev.diff.utils).isRelevantFile(file)
		if ((element="") || ('isRelevantFile))	continue
		
		if $length(element, $c(9))=2 
		{
			if ((status="M") || (status="U")) || (status="A") 
			{
				do ##class(dev.diff.utils).ToCacheName(.file)
				set items(file) = ""
			}
		}elseif $length(element, $c(9))=3 
		{
			set file = $piece(element, $c(9), 3)
			if ($l(file, path) < 2) continue
			if ((status="C") || (status="R")) 
			{
				do ##class(dev.diff.utils).ToCacheName(.file)
				set items(file) = ""
			}
		}
	}
	do $system.Process.CurrentDirectory(oldDirectory)
	return sc
}

/// Create file name. 
/// Если name не задан, то возвращается имя созданного файла (в папке Temp). 
/// Если name - расширение, то возвращается имя созданного файла (в папке Temp) с заданным расширением.
/// stream - стрим файла
/// content - строка или stream который записывается в файл
ClassMethod createFile(ByRef name As %String = "", Output stream As %Stream.FileBinary, content As %String) As %Status
{
	#dim sc As %Status = $$$OK
	
	if name="" {
		set name = ##class(%File).TempFilename()
	} elseif $length(name, ".")=1 {
		set name = ##class(%File).TempFilename(name)
	}
	
	set stream = ##class(%Stream.FileBinary).%New()
	set sc = stream.LinkToFile(name)
	
	if $data(content) {
		if $isObject(content) {
			set sc = stream.CopyFrom(content)
		} else {
			set sc = stream.Write(content)
		}
		quit:$$$ISERR(sc) sc
		set sc = stream.%Save()
		do stream.Rewind()
	}
	
	quit sc
}

/// Прочитать файл в строку
ClassMethod fileToString(name As %String, Output content As %String, delete As %Boolean = {$$$YES}) As %Status
{
	#dim sc As %Status = $$$OK
	set stream = ##class(%Stream.FileBinary).%New()
	set sc = stream.LinkToFile(name)
	
	set content = stream.Read($$$MaxStringLength)
	
	if delete {
		kill stream
		set sc = ..deleteFile(name)
	}
	
	quit sc
}

/// Удалить файл
ClassMethod deleteFile(name As %String) As %Status
{
	#dim sc As %Status = $$$OK
	set success = ##class(%File).Delete(name, .code)
	set:success'=$$$YES sc = $$$ERROR($$$GeneralError, $$$FormatText("Error deleting file %1 with code %2", name, code))
	quit sc
}

/// Выполнить команду ОС
ClassMethod execute(cmd, debug As %Boolean = {$$$NO}) As %Status
{
	#dim sc As %Status = $$$OK
	set code = ""
	//set out = ""
	write:debug !, "cmd: ", cmd
	//set sc = ##class(%Net.Remote.Utility).RunCommandViaZF(cmd, , .out, timeout, $$$YES, .code)
	set code = $zf(-1, cmd)
	write:debug !,"code: ", code
	
	if code'=0 {
		set sc1 = $$$ERROR($$$GeneralError, $$$FormatText("Комманда ОС: `%1` завершилась с кодом: `%2`", cmd, code))
		set sc = $$$ADDSC(sc, sc1)	
	}
	return sc
}

}


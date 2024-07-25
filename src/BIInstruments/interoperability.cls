/// Class to export/import various config items.
/// Was created by https://github.com/eduard93
Class BIInstruments.interoperability
{

// Query LUT() As %SQLQuery
// {
// SELECT DISTINCT TableName FROM Ens_Util.LookupTable
// }

/// Export Lookup Tables into dir
/// 
/// do ##class(dev.interoperability).ExportLUT()
ClassMethod ExportLUT(dir)
{
	set dir = ##class(%File).NormalizeDirectory(dir)

	set sql = "SELECT DISTINCT TableName FROM Ens_Util.LookupTable"
	set rs = ##class(%SQL.Statement).%ExecDirect(, sql)
	if rs.%SQLCODE '=0 quit ""
	//set rs = ..LUTFunc()

	while rs.%Next() {
		set lut = rs.TableName
		/// LUTs are guaranteed to have distinct names
		try {
			$$$ThrowOnError($System.OBJ.Export(lut _ ".LUT", ..GenerateFileName(dir, lut), "-d"))
		} catch ex {
			write "New export failed. Trying legacy export",!
			$$$ThrowOnError(##class(Ens.Util.LookupTable).%Export(..GenerateFileName(dir, lut), lut))
		}
	}
}

/// do ##class(dev.interoperability).ImportLUT()
ClassMethod ImportLUT(dir)
{
	#include %occErrors
	write "Lookup Tables import from: " _ dir
	set rs = ##class(%File).FileSetFunc(dir, "*.xml")
	while rs.%Next() {
		set tablePath = rs.Get("Name")
		write "Importing: " _ tablePath,!
		// table is the full path, the last part (denoted by *) is the actual file name
		set tablePathNoExtension = $PIECE(tablePath, "/", *)
		// asking for $PIECE with just delimiter asks for the first part, thus ignore anything after the .
		set tablePathNoExtension = $PIECE(tablePathNoExtension, ".")
		write "Importing Lookup Table in " _ tablePathNoExtension,!
		// lookup table should be named the file name (without extension)
		do ##class(Ens.Util.LookupTable).%ClearTable(tablePathNoExtension)
		
		// Try the new import first.
		// It returns an error if no LUTs were found in the tablePath file
		//Set sc = ##class(EnsPortal.LookupSettings).Import(tablePath)
		//zw sc
		//w $System.Status.DisplayError(sc),!
		
		set sc = $system.OBJ.Load(tablePath, "-d")
		
		// If we got an error, try legacy import
		if $$$ISERR(sc) {
			write "New import failed. Trying legacy import",!
			set sc=##class(Ens.Util.LookupTable).%Import(tablePath)
			if $$$ISOK(sc) {
				write "Import successful",!
			}
		}
		
		// Error remains unfixed. Fail.
		if $$$ISERR(sc) {
			write "Lookup Table import failure: ", $System.Status.GetErrorText(sc),!
			do $system.Process.Terminate(, 1)
		}
	}
}

/// Export Custom HL7 schemas to a dir, one schema per file.
/// 
/// do ##class(dev.interoperability).ExportCustomSchemas("C:\InterSystems")
ClassMethod ExportCustomSchemas(dir)
{
	#dim sc As %sc = $$$OK
	set dir = ##class(%File).NormalizeDirectory(dir)
	
	// list all schemas	
	set rs = ##class(EnsLib.HL7.Schema).TypeCategoriesFunc()
	while rs.%Next() {
		// export only custom schemas
		if rs.IsStandard = $$$NO {
			set category = rs.Category
			$$$THROWONERROR(sc, $System.OBJ.Export(category _ ".HL7", ..GenerateFileName(dir, category), "-d"))
		}
	}
}

/// Import directory with custom HL7 schemas
/// 
/// do ##class(dev.interoperability).ImportCustomSchemas("C:\InterSystems")
ClassMethod ImportCustomSchemas(dir)
{
	write "Custom Schemas import from: " _ dir
	set sc = $System.OBJ.LoadDir(dir)
	if $$$ISERR(sc) {
		write "Schema import failure: ", $System.Status.GetErrorText(sc),!
		do $system.Process.Terminate(, 1)
	}
}

/// Export Business Partners to one directory. One Business Partner per file.
/// 
/// do ##class(dev.interoperability).ExportBusinessPartners("C:\InterSystems\BP")
ClassMethod ExportBusinessPartners(dir)
{
	set dir = ##class(%File).NormalizeDirectory(dir)
	
	// list all Business Partners	
	set rs = ##class(Ens.Config.BusinessPartner).ExtentFunc()
	while rs.%Next() {
		$$$THROWONERROR(sc, ##class(Ens.Config.BusinessPartner).%Export(rs.ID, ..GenerateFileName(dir, rs.ID)))	
	}
}

/// Import Business Partners from a dir. This would overwrite partners with the same name, if any.
/// 
/// do ##class(dev.interoperability).ImportBusinessPartners("C:\InterSystems\BP")
ClassMethod ImportBusinessPartners(dir)
{
	write "Business Partner import from: " _ dir, !
	set rs = ##class(%File).FileSetFunc(dir, "*.xml")
	
	while rs.%Next() {
		set sc = ##class(Ens.Config.BusinessPartner).%Import(rs.Name, 1, 1)
		if $$$ISERR(sc) {
			write "Business Partner " _ rs.Name _ " import failure: ", $System.Status.GetErrorText(sc),!
			do $system.Process.Terminate(, 1)
		}
	}
}

Query Tasks() As %SQLQuery(SELECTMODE = "DISPLAY")
{
SELECT ID
FROM %SYS.Task
WHERE Type = 'User'
}

/// Export User Tasks to one directory. One Task per file.
/// 
/// do ##class(dev.interoperability).ExportTasks("C:\InterSystems\HCC\Tasks")
ClassMethod ExportTasks(dir)
{
	set dir = ##class(%File).NormalizeDirectory(dir)
	
	// list all tasks	
	set rs = ..TasksFunc()
	while rs.%Next() {
		$$$THROWONERROR(sc, ##class(%SYS.TaskSuper).ExportTasks($lb(rs.ID), ..GenerateFileName(dir, rs.ID)))	
	}
}

/// Import User Tasks from a dir. Tasks with the same JobGUID would be skipped.
/// 
/// do ##class(dev.interoperability).ImportTasks("C:\InterSystems\HCC\Tasks")
ClassMethod ImportTasks(dir)
{
	write "Tasks import from: " _ dir, !
	set rs = ##class(%File).FileSetFunc(dir, "*.xml")
	
	while rs.%Next() {
		set sc = ##class(%SYS.TaskSuper).ImportTasks(rs.Name)
		if $$$ISERR(sc) {
			write "Task " _ rs.Name _ " import failure: ", $System.Status.GetErrorText(sc),!
			do $system.Process.Terminate(, 1)
		}
	}
}

/// Export credentials to one directory. One credential per file.
/// NOT TO BE STORED IN SOURCE CONTROL
/// 
/// do ##class(dev.interoperability).ExportCredentials("C:\InterSystems\HCC\Credentials")
ClassMethod ExportCredentials(dir)
{
	set dir = ##class(%File).NormalizeDirectory(dir)
	
	// list all tasks	
	set rs = ##class(Ens.Config.Credentials).ExtentFunc()
	while rs.%Next() {
		$$$THROWONERROR(sc, ..ExportCredential(rs.ID, ..GenerateFileName(dir, rs.ID)))	
	}
}

ClassMethod ExportCredential(id, file) As %Status
{
	#dim sc As %Status = $$$OK
	try {
		set credential = ##class(Ens.Config.Credentials).%OpenId(id,,.sc)
		if '$IsObject(credential) {
			set sc = $$$ERROR($$$GeneralError,"Unable to find Credential: "_id)
			quit
		}

		// make sure we can open the file
		open file:"WNU":0 else  set sc = $$$ERROR($$$GeneralError,"Unable to open file: "_file) quit
		close file

		set writer = ##class(%XML.Writer).%New()
		set writer.Indent = 1
		set sc = writer.OutputToFile(file)
		if $$$ISERR(sc) quit
		set sc = writer.StartDocument()
		if $$$ISERR(sc) quit
		set sc = writer.RootObject(credential)
		if $$$ISERR(sc) quit
		set sc = writer.EndDocument()
		if $$$ISERR(sc) quit
	} catch(ex) {
		set sc = ex.AsStatus()
	}
	if $$$ISERR(sc) {
		write !,$System.Status.DisplayError(sc)
	}

	quit sc
}

/// Import credentials from one directory.
/// NOT TO BE STORED IN SOURCE CONTROL
/// 
/// do ##class(dev.interoperability).ImportCredentials("C:\InterSystems\HCC\Credentials")
ClassMethod ImportCredentials(dir)
{
	write "Credential import from: " _ dir, !
	set rs = ##class(%File).FileSetFunc(dir, "*.xml")
	
	while rs.%Next() {
		set sc = ..ImportCredential(rs.Name)
		if $$$ISERR(sc) {
			write "Credential " _ rs.Name _ " import failure: ", $System.Status.GetErrorText(sc),!
		}
	}
}

/// Import one credential from file
ClassMethod ImportCredential(file) As %Status
{
	#dim sc As %Status = $$$OK
	try {
		// Create an instance of %XML.Reader
		set reader = ##class(%XML.Reader).%New()
	
		// Begin processing of the file
		set sc = reader.OpenFile(file)
		if $$$ISERR(sc) quit

		Do reader.Correlate("Credentials", "Ens.Config.Credentials")

		// Read objects from xml file
		while (reader.Next(.credential, .sc)) {
			set exists = ##class(Ens.Config.Credentials).%ExistsId(credential.SystemName)

			if (exists=1) {
				write "Replacing: ",credential.SystemName,!
				set sc = ##class(Ens.Config.Credentials).%DeleteId(credential.SystemName)
				if $$$ISERR(sc) quit
			} else {
				write "Importing: ", credential.SystemName,!
			}
			set sc = credential.%Save()
			if $$$ISERR(sc) quit
		}
		if $$$ISERR(sc) quit
	} catch(ex) {
		set sc = ex.AsStatus()
	}
	quit sc
}

/// Export SSL configurations to one directory.
/// One SSL config per file (with additional files for CAFile, CRLFile, CertificateFile, and PrivateKeyFile.
/// Set CAPath results in a directory copy.
/// 
/// NOT TO BE STORED IN SOURCE CONTROL IF SSL CONFIG CONTAINS A PRIVATE KEY
/// 
/// do ##class(dev.interoperability).ExportSSL("C:\InterSystems\HCC\SSL")
ClassMethod ExportSSL(dir)
{
	new $namespace
	set $namespace = "%SYS"
	set dir = ##class(%File).NormalizeDirectory(dir)
	
	// list all SSL configs
	set rs = ##class(Security.SSLConfigs).ExtentFunc()
	while rs.%Next() {
		set sslFullFileName = ..GenerateFileName(dir, rs.ID)
		set sslFileName = ##class(%File).GetFilename(sslFullFileName)
		set sslFileNameNoExt = $p(sslFileName, ".", 1, *-1)
		$$$THROWONERROR(sc, ##class(Security.SSLConfigs).Export(sslFullFileName, , rs.ID))
		$$$THROWONERROR(sc, ##class(Security.SSLConfigs).Get(rs.ID, .props))
		for file = "CAFile", "CRLFile", "CertificateFile", "PrivateKeyFile" {
			if props(file)'="" {
				set ext = $p(##class(%File).GetFilename(props(file)), ".", *, *)
				set targetFile = ..GenerateFileName(dir, sslFileNameNoExt _ file, ext)
				set rc = ##class(%File).CopyFile(props(file), targetFile, ,.return)
				if rs = 0 {
					$$$THROWONERROR(sc, $$$ERROR($$$GeneralError, $$$FormatText("Error copying file %1 into %2, which is %3 for SSL config %4. Error code %5", props(file), targetFile, file, rs.ID, return)))
				}
			}
		}
		if props("CAPath")'="" {
			set rc = ##class(%File).CopyDir(props("CAPath"), dir _ sslFileNameNoExt)
			if rs = 0 {
				$$$THROWONERROR(sc, $$$ERROR($$$GeneralError, $$$FormatText("Error copying dir %1 into %2, which is CAPath dir for SSL config %3", props("CAPath"), target, dir _ sslFileNameNoExt, rs.ID)))
			}
		}
		
	}
}

/// Import SSL configurations from one directory.
/// NOT TO BE STORED IN SOURCE CONTROL IF SSL CONFIG CONTAINS A PRIVATE KEY
/// 
/// do ##class(dev.interoperability).ImportSSL("C:\InterSystems\HCC\SSL")
ClassMethod ImportSSL(dir)
{
	new $namespace
	set $namespace = "%SYS"
	set dir = ##class(%File).NormalizeDirectory(dir)
	
	write "SSL Configuration import from: " _ dir, !
	set rs = ##class(%File).FileSetFunc(dir, "*.xml")
	
	while rs.%Next() {
		set sslFullFileName = rs.Name
		set sslFileName = ##class(%File).GetFilename(sslFullFileName)
		set sslFileNameNoExt = $p(sslFileName, ".", 1, *-1)

		// 1. Patch SSL Config XML to use correct paths	

		// Create an instance of %XML.Reader
		set reader = ##class(%XML.Reader).%New()
	
		// Begin processing of the file
		$$$THROWONERROR(sc, reader.OpenFile(sslFullFileName))
		if $$$ISERR(sc) quit

		do reader.Correlate("SSLConfigs","Security.SSLConfigs")

		// Assuming one SSL config per file
		do reader.Next(.ssl, .sc)
		$$$THROWONERROR(sc, sc)

		for prop = "CAFile", "CRLFile", "CertificateFile", "PrivateKeyFile" {
			if $property(ssl, prop)'="" {
				set file = $ZSEARCH(dir _ sslFileNameNoExt _ prop _ "*")
				if file="" {
					throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, $$$FormatText("SSL config %1 from file %2 refers to %3 which is not found at expected location %4", ssl.Name, sslFullFileName, prop, dir _ sslFileNameNoExt _ prop _ "*")))
				}
				set $property(ssl, prop) = file
			}
		}
		
		if ssl.CAPath'="" {
			if ##class(%File).DirectoryExists(dir _ sslFileNameNoExt) {
				set ssl.CAPath = dir _ sslFileNameNoExt			
			} else {
				throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, $$$FormatText("SSL config %1 from file %2 refers to CAPath which is not found at expected location %3", ssl.Name, sslFullFileName, dir _ sslFileNameNoExt)))
			}
		}
		
		kill reader
		
		// 2. Write patched SSL config to file
		
		set writer=##class(%XML.Writer).%New()
		$$$THROWONERROR(sc, writer.OutputToFile(sslFullFileName))
		set writer.Charset="UTF-8"
		set writer.Indent=1
		$$$THROWONERROR(sc, writer.RootElement("SSLConfigsExport"))
		$$$THROWONERROR(sc, writer.Object(ssl))
		$$$THROWONERROR(sc, writer.EndRootElement())
		$$$THROWONERROR(sc, writer.EndDocument())
		
		kill writer
		
		// 3. Import new SSL config
		$$$THROWONERROR(sc, ##class(Security.SSLConfigs).Import(sslFullFileName))
	}
}

/// Generate a filename in a dir with a specific extension.
/// Filename is guaranteed to not exist OR be absolutely the same.
/// This is achieved by adding underscores to the start of the name if any conflicts exist.
/// 
/// w ##class(dev.interoperability).GenerateFileName("C:\InterSystems\BP", "test")
ClassMethod GenerateFileName(dir, name, ext = "xml") As %String
{
	set dir = ##class(%File).NormalizeDirectory(dir)
	set filename = dir _name _ "." _ ext
	if '##class(%File).Exists(filename) {
		quit filename
	} elseif ##class(%File).NormalizeFilename(filename) = filename {
		quit filename
	}
	quit ..GenerateFileName(dir, "_" _ name, ext)
}

}
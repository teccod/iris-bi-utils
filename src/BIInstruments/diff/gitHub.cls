Class BIInstruments.diff.gitHub
{

ClassMethod Get(Output items, Owner As %String = "", Repository As %String = "", Username As %String = "clminstaller", Password As %String = "clminstaller2016", CommitFrom As %Integer = "", CommitTo As %Integer = "") As %Status
{
	#dim req As %Net.HttpRequest
	set req = ..CreateRequest(Username, Password)
	set req.Location = "repos/" _ Owner _ "/" _ Repository _ "/commits" 	// as described in https://developer.github.com/v3/repos/
	
 	set links = ##class(%ListOfDataTypes).%New()
 	set sc = ..GetSHAs(.req, CommitFrom, CommitTo, .items)

 	return sc
}

ClassMethod GetSHAs(Request As %Net.HttpRequest, CommitFrom As %Integer, CommitTo As %Integer, Output Items) As %Status
{
	set st = Request.Get()

	return:$$$ISERR(st) st
	return:(Request.HttpResponse.StatusCode = 404) $$$ERROR($$$GeneralError,"Repository doesn't exist OR you don't have access")
	return:((Request.HttpResponse.StatusCode = 403) && (Request.HttpResponse.GetHeader("X-RATELIMIT-REMAINING")=0)) $$$ERROR($$$GeneralError,"API rate limit exceeded. Try logging in.")
 	return:(Request.HttpResponse.StatusCode '= 200) $$$ERROR($$$GeneralError,"Received " _ Request.HttpResponse.StatusCode _ " expected 200")

	#dim objects As List of %ZEN.proxyObject
	set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(Request.HttpResponse.Data,,.objects,1)
 
	if ((CommitFrom >= 1) && (CommitTo <= objects.Size)) {
		set list = ""
		for i=CommitFrom:1:CommitTo
		{
			set sha = objects.GetAt(i).%data("sha")
			set list = list _ $lb(sha)
		}
	}else {
		w "CommitTo can't be more than 30"
        return $$$NO
	}
	
	do ..GetFileNameForReleaseBySHAs(Request,list,.Items)
	
	return $$$OK
}

ClassMethod GetFileNameForReleaseBySHAs(Request As %Net.HttpRequest, SHAsList, Output filesForRelease) As %Status
{
	#dim objects As List of %ZEN.proxyObject
	#dim files As List of %ZEN.proxyObject
	set location = Request.Location
	for i=1:1:$ll(SHAsList) 
	{
		set Request.Location = location_"/"_$lg(SHAsList, i)
		
		set st = Request.Get()
		Return:$$$ISERR(st) st
		
		set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(Request.HttpResponse.Data,,.objects,1)
		return:$$$ISERR(st) st
		
		set files = objects.%data("files")
		
		for j=1:1:files.Size
		{
			set fileStatus = files.GetAt(j).%data("status")
			continue:(fileStatus'="modified")&&(fileStatus'="added")
			set fileName = files.GetAt(j).%data("filename")
			set:$L(fileName,".xml")'=1 fileName = $extract(fileName,1,*-4)
			continue:..IsCacheFile(fileName)=0
			do ##class(BIInstruments.utils).ToCacheName(.fileName)
			set filesForRelease(fileName) = ""
		}
	}
}

ClassMethod CreateRequest(Username As %String, Password As %String) As %Net.HttpRequest
{
	set namespace = $Namespace
 	set SSLConfig = "GitHub"

 	zn "%SYS"
 	do:'##class(Security.SSLConfigs).Exists(SSLConfig) ##class(Security.SSLConfigs).Create(SSLConfig)
 	zn namespace

 	set req=##class(%Net.HttpRequest).%New()
 	set req.Https=1
	set req.SSLConfiguration=SSLConfig
	set req.Server="api.github.com"
	do req.SetHeader("Accept","application/vnd.github.v3+json") 			// we want 3rd version of api

	if ($d(Username) && $d(Password) && (Username'="") && (Password'="")) {	// supply Username and Password, if both are provided. GitHub accept Basic Auth
		set req.Username = Username											// https://developer.github.com/v3/auth/
	 	set req.Password = Password
	}

	return req
}

/// Check that incoming file is the one you need.
ClassMethod IsCacheFile(FileName As %String) As %Boolean
{
	set extensions = "xml,cls,csp,csr,mac,int,bas,inc,gbl,prj,obj,pkg,gof,dfi,pivot,dashboard," //html,css,js,ts,scss,"
	return:($L(FileName,".")=1) 0 //no extension
	set fileExtension = $P(FileName,".",*)
	return $F(extensions,","_$ZCVT(fileExtension,"l")_",")
}

}


Class BIInstruments.import
{
    /// import all from workdir
ClassMethod import(filemask = "*.xml;*.cls;*.mac;*.int;*.inc;*.dfi", qspec = "cku-d", ByRef err = "", recurse = 1, ByRef loaded = "", verbose = 1) As %Status
{
	#define push(%dir) set dirs( $i( dirs ) ) = %dir
	#define next(%i,%dir) set %i=$o( dirs( "" ), 1, %dir )  kill:%i'="" dirs(%i)
	#define isDirectory(%type) ( %type = "D" )
	#define log write !, $piece(filename,##class(BIInstruments.utils).workdir(),2), " " write:sc "Ok" do:'sc $system.OBJ.DisplayError(sc)
	
	set sc = 1, dirs = "", dir = ##class(BIInstruments.utils).workdir() $$$push(dir)
	if verbose write "#; Importing from ", dir,!
	do ##class(BIInstruments.utils).setIgnore(.fm,verbose)
	for 
	{ 
		$$$next(i,dir) quit:i=""  quit:dir=""
		set rs = ##class(%File).FileSetFunc( dir, filemask, , 1 )

		while rs.%Next() 
		{
			set filename = rs.Name

			if $$$isDirectory(rs.Type) {
				if recurse $$$push(filename)
				continue
			}
			// check file filter
			if ##class(BIInstruments.utils).inFilter(.fm,filename) continue

			set ext = $zcvt($p( filename, ".", * ),"l")

			if (ext = "dfi") {
				set sc = ##class(%DeepSee.UserLibrary.Utils).%Import( filename, 1, 0, 0, "", .dsloaded )

			} else {
				// load classes only
				set sc = $system.OBJ.Load( filename, "k-d", .err, .loaded)
			}

			if verbose $$$log
			
	    }
		// compile all the loaded classes to obey dependencies
		set sc=$system.OBJ.CompileList( .loaded, "cukbr-d/multicompile",.err )
		
	}
	
	if verbose {
	
		if $D(err) {
			set i=$Order(err("")) 
			while i'="" {
			write !,err(i)
			set i=$O(err(i))
			}
		}
		
		write !,!,"#; Imported from ", ##class(BIInstruments.utils).workdir()
		}
	return sc
}

/// import from workdir all files with ts newer than code ts in db
ClassMethod importUpdated(filemask = "*.*", qspec = "cku-d", ByRef err = "", recurse = 1, ByRef loaded = "", verbose = 1) As %Status
{
	#define push(%dir) s dirs( $i( dirs ) ) = %dir
	#define next(%i,%dir) s %i=$o( dirs( "" ), 1, %dir )  k:%i'="" dirs(%i)
	#define isDirectory(%type) ( %type = "D" )
	#define log w !, $piece(filename,##class(BIInstruments.utils).workdir(),2)," " w:sc "Ok" d:'sc $system.OBJ.DisplayError( sc )

	set sc = 1, dirs = "", dir = ##class(BIInstruments.utils).workdir() $$$push(dir)
	if verbose write "#; Importing updated from ", dir,!
	do ##class(BIInstruments.utils).setIgnore(.fm,verbose)
	for 
	{ 
		$$$next(i,dir) quit:i=""  quit:dir=""

		set rs = ##class(%File).FileSetFunc( dir, filemask, , 1 )

		while rs.%Next() 
		{
			set filename = rs.Name

			if $$$isDirectory( rs.Type ) 
			{
				if ( recurse ) $$$push(filename) ;push directory
				continue
			}

			// check file filter
			if ##class(BIInstruments.utils).inFilter(.fm,filename) continue

			set filets = rs.DateModified
			set codename = ##class(BIInstruments.utils).codename( filename, .ext )
			set codets = ##class(BIInstruments.utils).codets( codename, ext )
			
			if ( filets '] codets ) continue
				
			if (ext = "dfi"){
				set sc = ##class(%DeepSee.UserLibrary.Utils).%Import( filename, 1, 0, 0, "", .dsloaded )
			} else 
			{
				#; drop existing code before import ( purge DateModified )
				#; s:codets'="" sc = ##class(%RoutineMgr).Delete( codename )
				kill err 
				set sc = $system.OBJ.Load( filename, qspec, .err, .loaded)
			}
			if verbose $$$log
	    }
	}
	write:verbose !,"#; Imported updated from ", ##class(BIInstruments.utils).workdir()
	return sc
}
}
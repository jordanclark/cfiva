component {

	function init(
		required string appID
	,	numeric throttle= 500
	,	numeric httpTimeOut= 60
	,	boolean debug
	) {
		arguments.debug = ( arguments.debug ?: request.debug ?: false );
		this.appID = arguments.appID;
		this.httpTimeOut = arguments.httpTimeOut;
		this.throttle = arguments.throttle;
		this.lastRequest= server.iva_lastRequest ?: 0;
		return this;
	}

	function debugLog( required input ) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "IVA: " & arguments.input );
			} else {
				request.log( "IVA: (complex type)" );
				request.log( arguments.input );
			}
		} else if( this.debug ) {
			var info= ( isSimpleValue( arguments.input ) ? arguments.input : serializeJson( arguments.input ) );
			cftrace(
				var= "info"
			,	category= "IVA"
			,	type= "information"
			);
		}
		return;
	}

	struct function apiRequest( required string path ) {
		var http = {};
		var dataKeys = 0;
		var item = "";
		var out = {
			success = false
		,	error = ""
		,	status = ""
		,	statusCode = 0
		,	response = ""
		,	requestUrl = arguments.path
		,	delay= 0
		};
		arguments[ "appid" ] = this.appID;
		structDelete( arguments, "path" );
		out.requestUrl &= this.structToQueryString( arguments );
		this.debugLog( out.requestUrl );
		// this.debugLog( out );
		// throttle requests by sleeping the thread to prevent overloading api
		if ( this.lastRequest > 0 && this.throttle > 0 ) {
			out.delay= this.throttle - ( getTickCount() - this.lastRequest );
			if ( out.delay > 0 ) {
				this.debugLog( "Pausing for #out.delay#/ms" );
				sleep( out.delay );
			}
		}
		cftimer( type="debug", label="iva request" ) {
			cfhttp( result="http", method="GET", url=out.requestUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut );
			if ( this.throttle > 0 ) {
				this.lastRequest= getTickCount();
				server.iva_lastRequest= this.lastRequest;
			}
		}
		out.response = toString( http.fileContent );
		// this.debugLog( http );
		// this.debugLog( out.response );
		out.statusCode = http.responseHeader.Status_Code ?: 500;
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.error = "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error = out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success = true;
		}
		// parse response 
		if ( len( out.response ) ) {
			try {
				out.json = deserializeJSON( out.response );
				if ( isStruct( out.json ) && structKeyExists( out.json, "status" ) && out.json.status == "error" ) {
					out.success = false;
					out.error = out.json.message;
				}
				if ( structCount( out.json ) == 1 ) {
					out.json = out.json[ structKeyList( out.json ) ];
				}
			} catch (any cfcatch) {
				out.error = "JSON Error: " & (cfcatch.message?:"No catch message") & " " & (cfcatch.detail?:"No catch detail");
			}
		}
		if ( len( out.error ) ) {
			out.success = false;
		}
		this.debugLog( out.statusCode & " " & out.error );
		return out;
	}

	struct function idSearch( required string id, required string idType ) {
		var args = {
			"id" = arguments.id
		,	"idtype" = arguments.idType
		};
		var out = this.apiRequest(
			path= "https://ee.internetvideoarchive.net/api/expressstandard/#arguments.id#"
		,	argumentCollection= args
		);
		return out;
	}

	struct function search( required string q ) {
		var args = {
			"term" = arguments.q
		};
		var out = this.apiRequest(
			path= "https://ee.internetvideoarchive.net/api/expressstandard/actions/search"
		,	argumentCollection= args
		);
		return out;
	}

	string function structToQueryString( required struct stInput, boolean bEncode= true, string lExclude= "", string sDelims= "," ) {
		var sOutput = "";
		var sItem = "";
		var sValue = "";
		var amp = "?";
		for ( sItem in stInput ) {
			if ( !len( lExclude ) || !listFindNoCase( lExclude, sItem, sDelims ) ) {
				try {
					sValue = stInput[ sItem ];
					if ( len( sValue ) ) {
						if ( bEncode ) {
							sOutput &= amp & lCase( sItem ) & "=" & urlEncodedFormat( sValue );
						} else {
							sOutput &= amp & lCase( sItem ) & "=" & sValue;
						}
						amp = "&";
					}
				} catch (any cfcatch) {
				}
			}
		}
		return sOutput;
	}

}

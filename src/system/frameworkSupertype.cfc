<!-----------------------------------------------------------------------
		<cfreturn variables.controller/>
	</cffunction>
	<cffunction name="setcontroller" access="public" output="false" returntype="void" hint="Set controller">
		<cfargument name="controller" type="any" required="true"/>
		<cfset variables.controller = arguments.controller/>
	</cffunction>
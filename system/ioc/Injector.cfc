<!-----------------------------------------------------------------------
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************

Author 	    :	Luis Majano
Description :
	The WireBox injector is the pivotal class in WireBox that performs
	dependency injection.  It can be used standalone or it can be used in conjunction
	of a ColdBox application context.  It can also be configured with a mapping configuration
	file that can provide object/mappings.
	

----------------------------------------------------------------------->
<cfcomponent hint="A WireBox Injector: Builds the graphs of objects that make up your application." output="false" serializable="false">

<!----------------------------------------- CONSTRUCTOR ------------------------------------->			
		
	<!--- init --->
	<cffunction name="init" access="public" returntype="CacheFactory" hint="Constructor" output="false" >
		<cfargument name="config"  		type="coldbox.system.ioc.config.WireBoxConfig" 	required="false" hint="The WireBoxConfig object to use to configure this injector. If not passed then WireBox will instantiate the default configuration."/>
		<cfargument name="coldbox" 		type="coldbox.system.web.Controller" 			required="false" hint="A coldbox application that this instance of CacheBox can be linked to, if not using it, just ignore it."/>
		<cfscript>
			// Prepare Injector
			instance = {
				// WireBox Injector UniqueID
				injectorID = createObject('java','java.lang.System').identityHashCode(this),	
				// Version
				version = "1.0.0",	 
				// Configuration object
				config  = "",
				// ColdBox Application Link
				coldbox = "",
				// Event Manager Link
				eventManager = "",
				// Configured Event States
				eventStates = [
					"afterInjectorConfiguration", 	// once injector is created and configured
					"beforeObjectCreation", 	// Before an injector creates the object, the configuration data is passed here.
					"afterObjectCreation", 		// once an object is created but not initialized via its constructor, the obj reference is passed
					"beforeObjectInitialized",	// before the constructor is called, the arguments that will be passed to the constructer are sent
					"afterObjectInitialized",	// once the constructor is called
					"afterDIComplete",			// after object is completely initialized and DI injections have ocurred
					"beforeMetadataInspection",	// before an object is inspected for injection metadata
					"afterMetadataInspection",	// after an object has been inspected and metadata is ready to be saved
					"onObjectException"			// traps when the injector throws controlled exceptions when building, injeting objects
				],
				// LogBox Links
				logBox  = "",
				log		= "",
				// Singleton Cache
				singletons = structnew(),
				// Parent Injector
				parent = "",
				// Metadata Dictionary
				DICacheDictionary = createObject("component","coldbox.system.core.collections.BaseDictionary").init('DIMetadata')
			};
			
			// Prepare Lock Info
			instance.lockName = "WireBox.Injector.#instance.injectorID#";
			
			// Check if linking ColdBox
			if( structKeyExists(arguments, "coldbox") ){ 
				instance.coldbox = arguments.coldbox;
			}
			
			// Passed in configuration?
			if( NOT structKeyExists(arguments,"config") ){
				// Create default configuration
				arguments.config = createObject("component","coldbox.system.ioc.config.WireBoxConfig").init(CFCConfigPath="coldbox.system.ioc.config.DefaultConfiguration");
			}
			
			// Configure the injector
			configure( arguments.config );
			
			return this;
		</cfscript>
	</cffunction>
	
		
	<!--- configure --->
	<cffunction name="configure" output="false" access="public" returntype="void" hint="Configure the cache factory for operation, called by the init(). You can also re-configure CacheBox programmatically.">
		<cfargument name="config" type="coldbox.system.cache.config.CacheBoxConfig" required="true" hint="The CacheBoxConfig object to use to configure this instance of CacheBox"/>
		<cfscript>
			var defaultCacheConfig = "";
			var caches 	= "";
			var key 	= "";
			var iData	= {};
		</cfscript>
		
		<cflock name="#instance.lockName#" type="exclusive" timeout="30" throwontimeout="true">
			<cfscript>
			// Store config object
			instance.config = arguments.config;
			// Validate configuration
			instance.config.validate();
			
			if( isColdBoxLinked() ){ 
				// link LogBox
				instance.logBox  = instance.coldbox.getLogBox();
				// Link CacheBox
				instance.cacheBox = instance.coldbox.getCacheBox();
				// Link Event Manager
				instance.eventManager = instance.coldbox.getInterceptorService();
				// Link Interception States
				instance.coldbox.getInterceptorService().appendInterceptionPoints( arrayToList(instance.eventStates) ); 
			}
			else{
				// Running standalone, so create our own logging first
				configureLogBox( instance.config.getLogBoxConfig() );
				// Create local CacheBox reference
				configureCacheBox( instance.config.getCacheBoxConfig() ); 
				// Create local event manager
				configureEventManager();
			}
			// Configure Logging for this injector
			instance.log = getLogBox().getLogger( this );
			
			// Reset Registries
			instance.singletons = {};
			
			// Register Listeners if not using ColdBox
			if( NOT isColdBoxLinked() ){
				registerListeners();
			}
			
			// Parent Injector declared
			if( isObject(config.getParent()) ){
				setParent( config.getParent() );
			}
			
			// Register Scan Locations
			
			// Register Mappings
			
			// Scope registration
			if( instance.config.getScopeRegistration().enabled ){
				doScopeRegistration();
			}
			
			// Announce To Listeners
			iData.injector = this;
			getEventManager().processState("afterInjectorConfiguration",iData);	
			</cfscript>
		</cflock>
	</cffunction>
	
	<!--- removeFromScope --->
    <cffunction name="removeFromScope" output="false" access="public" returntype="void" hint="Remove the Injector from scope registration if enabled, else does nothing">
    	<cfscript>
			var scopeInfo 		= instance.config.getScopeRegistration();
			var scopeStorage	= "";
			
			if( scopeInfo.enabled ){
				scopeStorage = createObject("component","coldbox.system.core.collections.ScopeStorage").init();
				scopeStorage.delete(scopeInfo.key, scopeInfo.scope);
			}
		</cfscript>
    </cffunction>
	
	<!--- contains --->
    <cffunction name="contains" output="false" access="public" returntype="boolean" hint="Checks if this container contains a specific object mapping or not">
    	<cfargument name="name" type="string" required="true" hint="The object name or alias to search for if this container has information about it"/>
    </cffunction>
	
	<!--- locateInstance --->
    <cffunction name="locateInstance" output="false" access="public" returntype="any" hint="Tries to locate a specific instance by name or alias">
    	
    </cffunction>
	
	<!--- getInstance --->
    <cffunction name="getInstance" output="false" access="public" returntype="any" hint="Locates, Creates, Injects and Configures an object instance">
    	
    </cffunction>

	<!--- autowire --->
    <cffunction name="autowire" output="false" access="public" returntype="any" hint="The main method that does the magical autowiring">
    	
    </cffunction>
	
	<!--- setParent --->
    <cffunction name="setParent" output="false" access="public" returntype="void" hint="Link a parent Injector with this injector">
    	<cfargument name="injector" type="any" required="true" hint="A WireBox Injector to assign as a parent to this Injector"/>
    	<cfset instance.parent = arguments.injector>
    </cffunction>
	
	<!--- getParent --->
    <cffunction name="getParent" output="false" access="public" returntype="any" hint="Get a reference to the parent injector, else an empty string" colddoc:generic="coldbox.system.ioc.Injector">
    	<cfreturn instance.parent>
    </cffunction>
	
	<!--- getPopulator --->
    <cffunction name="getPopulator" output="false" access="public" returntype="coldbox.system.core.dynamic.BeanPopulator" hint="Get an object populator useful for populating objects from JSON,XML, etc.">
    	<cfreturn createObject("component","coldbox.system.core.dynamic.BeanPopulator").init()>
    </cffunction>
	
	<!--- getSingletons --->
    <cffunction name="getSingletons" output="false" access="public" returntype="any" hint="Get a collection of all the objects in the singleton cache">
    	<cfreturn instance.singletons>
    </cffunction>
	
	<!--- getColdbox --->
    <cffunction name="getColdbox" output="false" access="public" returntype="coldbox.system.web.Controller" hint="Get the instance of ColdBox linked in this Injector. Empty if using standalone version">
    	<cfreturn instance.coldbox>
    </cffunction>
	
	<!--- isColdBoxLinked --->
    <cffunction name="isColdBoxLinked" output="false" access="public" returntype="boolean" hint="Checks if Coldbox application context is linked">
    	<cfreturn isObject(instance.coldbox)>
    </cffunction>
	
	<!--- getCacheBox --->
    <cffunction name="getCacheBox" output="false" access="public" returntype="any" hint="Get the instance of CacheBox linked in this Injector. Empty if using standalone version">
    	<cfreturn instance.cacheBox>
    </cffunction>
	
	<!--- isCacheBoxLinked --->
    <cffunction name="isCacheBoxLinked" output="false" access="public" returntype="boolean" hint="Checks if CacheBox is linked">
    	<cfreturn isObject(instance.cacheBox)>
    </cffunction>

	<!--- getLogBox --->
    <cffunction name="getLogBox" output="false" access="public" returntype="coldbox.system.logging.LogBox" hint="Get the instance of LogBox configured for this Injector">
    	<cfreturn instance.logBox>
    </cffunction>

	<!--- Get Version --->
	<cffunction name="getVersion" access="public" returntype="string" output="false" hint="Get the Injector's version string.">
		<cfreturn instance.version>
	</cffunction>
	
	<!--- Get the config object --->
	<cffunction name="getConfig" access="public" returntype="coldbox.system.ioc.config.WireBoxConfig" output="false" hint="Get the Injector's configuration object">
		<cfreturn instance.config>
	</cffunction>
	
	<!--- getInjectorID --->
    <cffunction name="getInjectorID" output="false" access="public" returntype="any" hint="Get the unique ID of this injector">
    	<cfreturn instance.injectorID>
    </cffunction>
	
	<!--- getEventManager --->
    <cffunction name="getEventManager" output="false" access="public" returntype="any" hint="Get the injector's event manager">
 		<cfreturn instance.eventManager>
    </cffunction>

	<!--- getScopeRegistration --->
    <cffunction name="getScopeRegistration" output="false" access="public" returntype="struct" hint="Get the scope registration information">
    	<cfreturn instance.config.getScopeRegistration()>
    </cffunction>

<!----------------------------------------- PRIVATE ------------------------------------->	

	<!--- registerListeners --->
    <cffunction name="registerListeners" output="false" access="private" returntype="void" hint="Register all the configured listeners in the configuration file">
    	<cfscript>
    		var listeners 	= instance.config.getListeners();
			var regLen		= arrayLen(listeners);
			var x			= 1;
			var thisListener = "";
			
			// iterate and register listeners
			for(x=1; x lte regLen; x++){
				// try to create it
				try{
					// create it
					thisListener = createObject("component", listeners[x].class);
					// configure it
					thisListener.configure( this, listeners[x].properties);
				}
				catch(Any e){
					getUtil().throwit(message="Error creating listener: #listeners[x].toString()#",
									  detail="#e.message# #e.detail# #e.stackTrace#",
									  type="Injector.ListenerCreationException");
				}
				
				// Now register listener
				getEventManager().register(thisListener,listeners[x].name);
			}			
		</cfscript>
    </cffunction>
	
	<!--- doScopeRegistration --->
    <cffunction name="doScopeRegistration" output="false" access="private" returntype="void" hint="Register this injector on a user specified scope">
    	<cfscript>
    		var scopeInfo 		= instance.config.getScopeRegistration();
			var scopeStorage	= createObject("component","coldbox.system.core.collections.ScopeStorage").init();
			// register injector with scope
			scopeStorage.put(scopeInfo.key, this, scopeInfo.scope);
		</cfscript>
    </cffunction>
	
	<!--- configureCacheBox --->
    <cffunction name="configureCacheBox" output="false" access="private" returntype="void" hint="Configure a standalone version of cacheBox for persistence">
    	<cfargument name="config" type="struct" required="true" hint="The cacheBox configuration data structure"/>
    	<cfscript>
    		var args 	= structnew();
			var oConfig	= "";
			
			// is cachebox enabled?
			if( NOT arguments.config.enabled ){
				return;
			}
			
			// Do we have a configuration file?
			if( len(arguments.config.configFile) ){
				// xml?
				if( listFindNoCase("xml,cfm", listLast(arguments.configPath,".") ) ){
					args["XMLConfig"] = arguments.configPath;
				}
				else{
					// cfc
					args["CFCConfigPath"] = arguments.configPath;
				}
				// Create Standalone CacheBox
				oConfig = createObject("component","cachebox.system.cache.config.CacheBoxConfig").init(argumentCollection=args);
				instance.cacheBox = createObject("component","cachebox.system.cache.CacheFactory").init( config );
				return;
			}
			
			// Do we have a cacheBox reference?
			if( isObject(arguments.config.cacheFactory) ){
				instance.cacheBox = arguments.config.cacheFactory;
			}			
		</cfscript>
    </cffunction>
	
	<!--- configureLogBox --->
    <cffunction name="configureLogBox" output="false" access="private" returntype="void" hint="Configure a standalone version of logBox for logging">
    	<cfargument name="configPath" type="string" required="true" hint="The logBox configuration path to use"/>
    	<cfscript>
    		var config 	= ""; 
			var args 	= structnew();
			
			// xml?
			if( listFindNoCase("xml,cfm", listLast(arguments.configPath,".") ) ){
				args["XMLConfig"] = arguments.configPath;
			}
			else{
				// cfc
				args["CFCConfigPath"] = arguments.configPath;
			}
			
			config = createObject("component","coldbox.system.logging.config.LogBoxConfig").init(argumentCollection=args);
			
			// Create LogBox
			instance.logBox = createObject("component","coldbox.system.logging.LogBox").init( config );
		</cfscript>
    </cffunction>
	
	<!--- configureEventManager --->
    <cffunction name="configureEventManager" output="false" access="private" returntype="void" hint="Configure a standalone version of a WireBox Event Manager">
    	<cfscript>
    		// create event manager
			instance.eventManager = createObject("component","coldbox.system.core.events.EventPoolManager").init( instance.eventStates );
		</cfscript>
    </cffunction>
	
	<!--- Get ColdBox Util --->
	<cffunction name="getUtil" access="private" output="false" returntype="coldbox.system.core.util.Util" hint="Create and return a core util object">
		<cfreturn createObject("component","coldbox.system.core.util.Util")/>
	</cffunction>
	
</cfcomponent>
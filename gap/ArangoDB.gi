#
# ArangoDBInterface: An interface to ArangoDB
#
# Implementations
#

####################################
#
# representations:
#
####################################

DeclareRepresentation( "IsArangoDatabaseRep",
        IsArangoDatabase,
        [ ] );

DeclareRepresentation( "IsDatabaseCollectionRep",
        IsDatabaseCollection,
        [ ] );

DeclareRepresentation( "IsDatabaseStatementRep",
        IsDatabaseStatement,
        [ ] );

DeclareRepresentation( "IsDatabaseCursorRep",
        IsDatabaseCursor,
        [ ] );

DeclareRepresentation( "IsDatabaseArrayRep",
        IsDatabaseArray,
        [ ] );

DeclareRepresentation( "IsDatabaseDocumentRep",
        IsDatabaseDocument,
        [ ] );

####################################
#
# families and types:
#
####################################

# new families:
BindGlobal( "TheFamilyOfArangoDatabases",
        NewFamily( "TheFamilyOfArangoDatabases" ) );

BindGlobal( "TheFamilyOfDatabaseCollections",
        NewFamily( "TheFamilyOfDatabaseCollections" ) );

BindGlobal( "TheFamilyOfDatabaseStatements",
        NewFamily( "TheFamilyOfDatabaseStatements" ) );

BindGlobal( "TheFamilyOfDatabaseCursors",
        NewFamily( "TheFamilyOfDatabaseCursors" ) );

BindGlobal( "TheFamilyOfDatabaseArrays",
        NewFamily( "TheFamilyOfDatabaseArrays" ) );

BindGlobal( "TheFamilyOfDatabaseDocuments",
        NewFamily( "TheFamilyOfDatabaseDocuments" ) );

# new types:
BindGlobal( "TheTypeArangoDatabase",
        NewType( TheFamilyOfArangoDatabases,
                IsArangoDatabaseRep ) );

BindGlobal( "TheTypeDatabaseCollection",
        NewType( TheFamilyOfDatabaseCollections,
                IsDatabaseCollectionRep ) );

BindGlobal( "TheTypeDatabaseStatement",
        NewType( TheFamilyOfDatabaseStatements,
                IsDatabaseStatementRep ) );

BindGlobal( "TheTypeDatabaseCursor",
        NewType( TheFamilyOfDatabaseCursors,
                IsDatabaseCursorRep ) );

BindGlobal( "TheTypeDatabaseArray",
        NewType( TheFamilyOfDatabaseArrays,
                IsDatabaseArrayRep ) );

BindGlobal( "TheTypeDatabaseDocument",
        NewType( TheFamilyOfDatabaseDocuments,
                IsDatabaseDocumentRep ) );

####################################
#
# global variables:
#
####################################

InstallValue( HOMALG_IO_ArangoShell,
        rec(
            cas := "arangosh",			## normalized name on which the user should have no control
            name := "arangosh",
            executable := [ "arangosh" ],	## this list is processed from left to right
            credentials := [ "--server.username", "root@example", "--server.database", "example", "--server.password", "password" ],
            options := Concatenation( [ "--console.auto-complete", "false", "--console.colors", "false", "--console.pretty-print", "false" ], ~.credentials ),
            BUFSIZE := 1024,
            READY := "!$%&/(",
            CUT_POS_BEGIN := 1,			## these are the most
            CUT_POS_END := 2,			## delicate values!
            eoc_verbose := "",
            eoc_quiet := "",
            remove_enter := true,			## an arangosh specific
            error_stdout := "JavaScript exception",	## an arangosh specific
            define := "=",
            delete := function( var, stream ) homalgSendBlocking( [ "delete(", var, ")" ], "need_command", stream, HOMALG_IO.Pictograms.delete ); end,
            prompt := "\033[01marangosh>\033[0m ",
            output_prompt := "\033[1;30;43m<arangosh\033[0m ",
            display_color := "\033[0;30;47m",
            max_chars_per_line := 7000,
#            init_string := "",
#            InitializeCASMacros := InitializeArangoDBMacros,
#            time := function( stream, t ) return Int( homalgSendBlocking( [ "" ], "need_output", stream, HOMALG_IO.Pictograms.time ) ) - t; end,
#            memory_usage := function( stream, o ) return Int( homalgSendBlocking( [ "" ], "need_output", stream, HOMALG_IO.Pictograms.memory ) ); end,
           )
);

HOMALG_IO_ArangoShell.READY_LENGTH := Length( HOMALG_IO_ArangoShell.READY );

####################################
#
# rewrite a Json method
#
####################################

InstallMethod(_GapToJsonStreamInternal, [IsOutputStream, IsBool],
function(o, b)
  if b = true then
      PrintTo(o, "true");
  elif b = false then
      PrintTo(o, "false");
  elif b = fail then
      PrintTo(o, "null");
  else
      Error("Invalid Boolean");
  fi;
end );

##
InstallGlobalFunction( GapToJsonStringForArangoDB,
  function( r )
    local string, l, s, i, str, chunk, c, k, rev;
    
    string := GapToJsonString( r );
    
    l := HOMALG_IO_ArangoShell.max_chars_per_line;
    
    s := Length( string );
    
    if s <= l then
        return string;
    fi;
    
    i := 0;
    str := "";
    c := 0;
    
    repeat
        
        chunk := string{[ (i + 1) .. ( i + l ) ]};
        
        c := c + Length( Positions( chunk, '\"' ) );
        
        if IsEvenInt( c ) then
            # if we can't split the input line inside a string, we try to split
            # it after one of the characters ',' ':' ' '
            rev := Reversed(chunk);
            k := PositionNthOccurrence(rev, ',', 1);
            if k = fail then
                k := PositionNthOccurrence(rev, ' ', 1);
                if k = fail then
                    k := PositionNthOccurrence(rev, ':', 1);
                    if k = fail then
                        Error( "splitting the input line for arangosh in the middle of a non-string is not supported yet\n" );
                    fi;
                fi;
            fi;
            Append(str, Concatenation(chunk{[1..l-k+1]}, "\n"));
            i := i+l-k+1;
        else
            ## ASSUMPTION: only works if we are splitting a string
            Append( str, Concatenation( chunk, "\\\n" ) );
            i := i + l;
        fi;
        
    until i + l > s;

    Append( str, string{[ (i + 1) .. s ]} );
    
    return str;
    
end );

####################################
#
# methods for constructors:
#
####################################

##
InstallGlobalFunction( AttachAnArangoDatabase,
  function( arg )
    local nargs, save, options, stream, client, name, split, db;
    
    nargs := Length( arg );
    
    if nargs = 1 and IsList( arg[1] ) then
        save := HOMALG_IO_ArangoShell.options;
        HOMALG_IO_ArangoShell.options := arg[1];
    fi;
    
    options := HOMALG_IO_ArangoShell.options;
    
    stream := LaunchCAS( "HOMALG_IO_ArangoShell" );
    
    client := HOMALG_IO_ArangoShell.name;
    
    if IsBound( save ) then
        HOMALG_IO_ArangoShell.options := save;
    fi;
    
    name := homalgSendBlocking( [ "db" ], "need_display", stream );
    
    split := SplitString( name, "\"" );
    
    if Length( split ) > 2 and split[3] = " : [object ArangoConnection:,unconnected], " then
        Error( client, " is unable to connect to the database server: ", name );
    fi;
    
    name := split[2];
    
    db := rec( stream := stream,
               options := options,
               pointer := "db",
               name := name );
    
    ObjectifyWithAttributes( db, TheTypeArangoDatabase,
            Name, Concatenation( "[object ArangoDatabase \"", name, "\"]" )
            );
    
    return db;
    
end );

##
InstallMethod( _ExtractDatabase,
        "for a homalg external object",
        [ IshomalgExternalObjectRep ],

  function( ext_obj )
    local database;
    
    if not IsBound( ext_obj!.database ) then
        Error( "the external object has no component called `database'\n" );
    fi;
    
    database := ext_obj!.database;
    
    if not IsArangoDatabaseRep( database ) then
        Error( "the component ext_obj!.database is not an IsArangoDatabaseRep\n" );
    fi;
    
    return database;
    
end );

##
InstallMethod( CreateDatabaseCollection,
        "for a homalg external object",
        [ IshomalgExternalObjectRep ],

  function( ext_obj )
    local database, name, collection;
    
    if not IsBound( ext_obj!.name ) then
        Error( "the external object has no component called `name'\n" );
    fi;
    
    name := ext_obj!.name;
    
    database := _ExtractDatabase( ext_obj );
    
    collection := rec( pointer := ext_obj, name := name, database := database );
    
    ObjectifyWithAttributes( collection, TheTypeDatabaseCollection,
            Name, Concatenation( "[ArangoCollection \"", name, "\"]" )
            );
    
    return collection;
    
end );

##
InstallMethod( CreateDatabaseStatement,
        "for a homalg external object",
        [ IshomalgExternalObjectRep ],

  function( ext_obj )
    local database, statement;
    
    if not IsBound( ext_obj!.statement ) then
        Error( "the external object has no component called `statement'\n" );
    fi;
    
    database := _ExtractDatabase( ext_obj );
    
    statement := rec( pointer := ext_obj, statement := ext_obj!.statement, database := database );
    
    ObjectifyWithAttributes( statement, TheTypeDatabaseStatement,
            Name, Concatenation( "[ArangoStatement in ", Name( database ), "]" )
            );
    
    return statement;
    
end );

##
InstallMethod( CreateDatabaseCursor,
        "for a homalg external object",
        [ IshomalgExternalObjectRep ],

  function( ext_obj )
    local database, cursor;
    
    database := _ExtractDatabase( ext_obj );
    
    cursor := rec( pointer := ext_obj, database := database );
    
    ObjectifyWithAttributes( cursor, TheTypeDatabaseCursor,
            Name, Concatenation( "[ArangoQueryCursor in ", Name( database ), "]" )
            );
    
    return cursor;
    
end );

##
InstallMethod( CreateDatabaseArray,
        "for a homalg external object",
        [ IshomalgExternalObjectRep ],

  function( ext_obj )
    local database, array;
    
    database := _ExtractDatabase( ext_obj );
    
    array := rec( pointer := ext_obj, database := database );
    
    ObjectifyWithAttributes( array, TheTypeDatabaseArray,
            Name, "[ArangoArray]"
            );
    
    return array;
    
end );

##
InstallMethod( CreateDatabaseDocument,
        "for a homalg external object",
        [ IshomalgExternalObjectRep ],

  function( ext_obj )
    local database, document;
    
    database := _ExtractDatabase( ext_obj );
    
    document := rec( pointer := ext_obj, database := database );
    
    ObjectifyWithAttributes( document, TheTypeDatabaseDocument,
            Name, "[ArangoDocument]"
            );
    
    return document;
    
end );

####################################
#
# methods for operations:
#
####################################

##
InstallMethod( \.,
        "for an Arango database and a positive integer",
        [ IsArangoDatabaseRep, IsPosInt ],
        
  function( db, string_as_int )
    local name, ext_obj;
    
    name := NameRNam( string_as_int );
    
    if name in [ "_createDatabase", "_useDatabase", "_dropDatabase" ] then
        
        return
          function( database_name )
            local output;
            
            output := homalgSendBlocking( [ db!.pointer, ".", name, "(\"", database_name, "\")" ], db!.stream, "need_output" );
            
            return EvalString( output );
            
        end;
        
    elif name in [ "_isSystem" ] then
        
        return
          function( )
            local output;
            
            output := homalgSendBlocking( [ db!.pointer, ".", name, "()" ], db!.stream, "need_output" );
            
            return EvalString( output );
            
        end;
        
    elif name in [ "_name", "_id", "_path" ] then
        
        return
          function( )
            local output;
            
            return homalgSendBlocking( [ db!.pointer, ".", name, "()" ], db!.stream, "need_output" );
            
        end;
        
    elif name in [ "_databases" ] then
        
        return
          function( )
            local ext_obj;
            
            ext_obj := homalgSendBlocking( [ db!.pointer, ".", name, "()" ], db!.stream );
            
            ext_obj!.database := db;
            
            return CreateDatabaseArray( ext_obj );
            
        end;
        
    elif name in [ "_engineStats" ] then
        
        return
          function( )
            local ext_obj;
            
            ext_obj := homalgSendBlocking( [ db!.pointer, ".", name, "()" ], db!.stream );
            
            ext_obj!.database := db;
            
            return CreateDatabaseDocument( ext_obj );
            
        end;
        
    elif name in [ "_help" ] then
        
        return
          function( )
            
            Print( homalgSendBlocking( [ db!.pointer, ".", name, "()" ], db!.stream, "need_display" ) );
            
        end;
        
    elif name = "_create" then
        
        return
          function( collection_name )
            local ext_obj, collection;
            
            ext_obj := homalgSendBlocking( [ db!.pointer, ".", name, "(\"", collection_name, "\")" ], db!.stream );
            
            ext_obj!.name := collection_name;
            ext_obj!.database := db;
            
            collection := CreateDatabaseCollection( ext_obj );
            
            Assert( 0, collection.count() = 0 );
            
            return collection;
            
        end;
        
    elif name in [ "_truncate", "_drop" ] then
        
        return
          function( collection )
            local collection_name, output;
            
            if IsDatabaseCollectionRep( collection ) then
                collection_name := collection!.name;
            elif IsString( collection ) then
                collection_name := collection;
            else
                Error( "the input should either be a collection or its name as a string\n" );
            fi;
            
            output := homalgSendBlocking( [ db!.pointer, ".", name, "(\"", collection_name, "\")" ], db!.stream, "need_output" );
            
            if not output = "" then
                Error( output, "\n" );
            fi;
            
            return true;
            
        end;
        
    elif name in [ "_createStatement" ] then
        
        return
          function( keys_values_rec )
            local string, ext_obj;
            
            string := GapToJsonStringForArangoDB( keys_values_rec );
            
            ext_obj := homalgSendBlocking( [ db!.pointer, ".", name, "(", string, ")" ], db!.stream );
            
            ext_obj!.statement := keys_values_rec;
            ext_obj!.database := db;
            
            return CreateDatabaseStatement( ext_obj );
            
        end;
        
    elif name in [ "_query" ] then
        
        return
          function( query_string )
            local t, cursor, ext_obj;
            
            if not IsString( query_string ) then
                query_string := Concatenation( query_string );
            fi;
            
            t := db._createStatement( rec( query := query_string, count := true ) );
            cursor := t.execute( );
            
            ext_obj := cursor!.pointer;
            
            ext_obj!.query := query_string;
            ext_obj!.database := db;
            
            return cursor;
            
        end;
        
    elif name in [ "_exists" ] then
        
        return
          function( _id )
            
            return EvalString( homalgSendBlocking( [ db!.pointer, ".", name, "('", _id, "')" ], db!.stream, "need_output" ) );
            
        end;
        
    elif name in [ "_document" ] then
        
        return
          function( _id )
            local ext_obj;
            
            ext_obj := homalgSendBlocking( [ db!.pointer, ".", name, "('", _id, "')" ], db!.stream );
            
            ext_obj!.database := db;
            
            return CreateDatabaseDocument( ext_obj );
            
        end;
        
    elif name in [ "_executeTransaction" ] then
        
        return
          function( keys_values_rec )
            local string, output;
            
            string := GapToJsonStringForArangoDB( keys_values_rec );
            
            output := homalgSendBlocking( [ db!.pointer, ".", name, "(", string, ")" ], db!.stream, "need_output" );
            
            if not ( output = "null" or output = "" ) then
                Error( output, "\n" );
            fi;
            
            return true;
            
        end;
        
    elif name[1] = '_' then
        
        return
          function( keys_values_rec )
            local string;
            
            string := GapToJsonStringForArangoDB( keys_values_rec );
            
            return homalgSendBlocking( [ db!.pointer, ".", name, "(", string, ")" ], db!.stream );
            
        end;
        
    fi;
    
    if homalgSendBlocking( [ db!.pointer, ".", name ], "need_output", db!.stream ) = "" then
        return fail;
    fi;
    
    ext_obj := homalgSendBlocking( [ db!.pointer, ".", name ], db!.stream );
    
    ext_obj!.name := name;
    ext_obj!.database := db;
    
    return CreateDatabaseCollection( ext_obj );
    
end );

##
InstallMethod( \.,
        "for a database collections and a positive integer",
        [ IsDatabaseCollectionRep, IsPosInt ],
        
  function( collection, string_as_int )
    local name;
    
    name := NameRNam( string_as_int );
    
    if name in [ "rename" ] then
        
        return
          function( new_collection_name )
            
            homalgSendBlocking( [ collection!.pointer, ".", name, "(\"", new_collection_name, "\")" ], "need_command" );
            
            collection!.name := new_collection_name;
            collection!.pointer!.name := new_collection_name;
            collection!.Name := Concatenation( "[ArangoCollection \"", new_collection_name, "\"]" );
            
            return collection;
            
        end;
        
    elif name in [ "document" ] then
        
        return
          function( _key )
            local ext_obj, d;
            
            if IsInt( _key ) then
                _key := String( _key );
            fi;
            
            ext_obj := homalgSendBlocking( [ collection!.pointer, ".", name, "('", _key, "')" ] );
            
            ext_obj!.database := collection!.database;
            
            d := CreateDatabaseDocument( ext_obj );
            
            d!.collection := collection;
            
            return d;
            
        end;
        
    elif name in [ "all" ] then
        
        return
          function( )
            local ext_obj;
            
            ext_obj := homalgSendBlocking( [ collection!.pointer, ".", name, "()" ] );
            
            ext_obj!.query := Concatenation( "SimpleQueryAll(", collection!.name, ")" );
            ext_obj!.database := collection!.database;
            
            return CreateDatabaseCursor( ext_obj );
            
        end;
        
    elif name in [ "count" ] then
        
        return
          function( )
            
            return Int( homalgSendBlocking( [ collection!.pointer, ".", name, "()" ], "need_output" ) );
            
        end;
        
    elif name in [ "exists" ] then
        
        return
          function( _key )
            
            return JsonStringToGap( homalgSendBlocking( [ collection!.pointer, ".", name, "(\"", _key, "\")" ], "need_output" ) );
            
        end;
        
    elif name in [ "save", "ensureIndex" ] then
        
        return
          function( keys_values_rec )
            local string, ext_obj;
            
            string := GapToJsonStringForArangoDB( keys_values_rec );
            
            ext_obj := homalgSendBlocking( [ collection!.pointer, ".", name, "(", string, ")" ] );
            
            ext_obj!.database := collection!.database;
            
            return CreateDatabaseDocument( ext_obj );
            
        end;
        
    fi;
    
    Error( "collection.", name, " is not supported yet\n" );
    
end );

##
InstallMethod( \.,
        "for a database statement and a positive integer",
        [ IsDatabaseStatementRep, IsPosInt ],
        
  function( statement, string_as_int )
    local name;
    
    name := NameRNam( string_as_int );
    
    if name = "execute" then
        
        return function( )
            local pointer, ext_obj;
            
            pointer := statement!.pointer;
            
            ext_obj := homalgSendBlocking( [ pointer, ".", name, "()" ] );
            
            ext_obj!.database := statement!.database;
            
            return CreateDatabaseCursor( ext_obj );
            
        end;
        
    elif name = "getCount" then
        
        return function( )
            local pointer, output;
            
            pointer := statement!.pointer;
            
            return Int( homalgSendBlocking( [ pointer, ".", name, "()" ], "need_output" ) );
            
        end;
        
    fi;
    
    Error( name, " is an unknown or yet unsupported method for database collections\n" );
    
end );

##
InstallMethod( \.,
        "for a database cursor and a positive integer",
        [ IsDatabaseCursorRep, IsPosInt ],
        
  function( cursor, string_as_int )
    local name;
    
    name := NameRNam( string_as_int );
    
    if name = "toArray" then
        
        return function( )
            local pointer, str, ext_obj, array;
            
            pointer := cursor!.pointer;
            
            str := homalgSendBlocking( [ pointer ], "need_output" );
            
            str := SplitString( str, "," )[2];
            str := SplitString( str, ":" )[2];
            
            ext_obj := homalgSendBlocking( [ pointer, ".toArray()" ] );
            
            ext_obj!.database := pointer!.database;
            
            array := CreateDatabaseArray( ext_obj );
            
            SetLength( array, Int( str ) );
            
            array!.Name := Concatenation( "[ArangoArray of length ", str, "]" );
            
            if IsBound( cursor!.conversions ) then
                array!.conversions := cursor!.conversions;
            fi;
            
            return array;
            
        end;
        
    elif name = "count" then
        
        return function( )
            local output;
            
            output := homalgSendBlocking( [ cursor!.pointer, ".", name, "()" ], "need_output" );
            
            if output = "" then
                Error( "cursor.count() returned nothing\n" );
            elif Int( output ) = fail then
                Error( "arangosh returned ", output, " instead of an integer\n" );
            fi;
            
            return Int( output );
            
        end;
        
    elif name = "hasNext" then
        
        return function( )
            
            return EvalString( homalgSendBlocking( [ cursor!.pointer, ".hasNext()" ], "need_output" ) );
            
        end;
        
    elif name = "next" then
        
        return function( )
            local ext_obj, document;
            
            ext_obj := homalgSendBlocking( [ cursor!.pointer, ".next()" ] );
            
            ext_obj!.database := cursor!.database;
            
            document := CreateDatabaseDocument( ext_obj );
            
            if IsBound( cursor!.conversions ) then
                document!.conversions := cursor!.conversions;
            fi;
            
            return document;
            
        end;
        
    fi;
    
    Error( name, " is an unknown or yet unsupported method for database cursors\n" );
    
end );

##
InstallOtherMethod( \[\],
        "for a database array and a positive integer",
        [ IsDatabaseArrayRep, IsPosInt ],
        
  function( array, n )
    local pointer, ext_obj, document;
    
    pointer := array!.pointer;
    
    ext_obj := homalgSendBlocking( [ array!.pointer, "[", String( n - 1 ), "]" ] );
    
    ext_obj!.database := pointer!.database;
    
    document := CreateDatabaseDocument( ext_obj );
    
    if IsBound( array!.conversions ) then
        document!.conversions := array!.conversions;
    fi;
    
    return document;
    
end );

##
InstallMethod( \.,
        "for a database document and a positive integer",
        [ IsDatabaseDocumentRep, IsPosInt ],
        
  function( document, string_as_int )
    local name, v, output, undefined, o, doc, func;
    
    name := NameRNam( string_as_int );
    
    v := document!.pointer!.stream.variable_name;
    
    ## arangosh prevents you from doing both in one step
    output := homalgSendBlocking( [ v, "d = { \"", name, "\" : ", document!.pointer, ".", name, " }" ], "need_display" );
    
    if Length( output ) <= Length( name ) + 30 then ## only compare if reasonable
        undefined := Concatenation( [ "{ \"", name, "\" : undefined }" ] );
        o := ShallowCopy( output );
        NormalizeWhitespace( o );
        if o = undefined then
            Error( "Document: '<doc>.", name, "' must have an assigned value\n" );
        fi;
    fi;
    
    doc := JsonStringToGap( output );
    
    if IsString( doc.(name) ) then
        ## get the string again through a direct method as it might be truncated
        output := homalgSendBlocking( [ document!.pointer, ".", name ], "need_display" );
        ## the pseudo-tty based interface is not reliable concerning
        ## the number of trailing ENTERs which should be 3 but
        ## too often decreases
        while Length( output ) > 0 and output[Length( output )] = '\n' do
            Remove( output );
        od;
        ## the pseudo-tty based interface is not reliable concerning
        ## the number of preceding ENTERs which should be 0 but
        ## too often decreases
        while Length( output ) > 0 and output[1] = '\n' do
            Remove( output, 1 );
        od;
    else
        output := doc.(name);
    fi;
    
    if IsBound( document!.conversions ) and IsBound( document!.conversions.(name) ) then
        func := document!.conversions.(name);
    else
        func := IdFunc;
    fi;
    
    return func( output );
    
end );

##
InstallMethod( IsBound\.,
        "for a database document and a positive integer",
        [ IsDatabaseDocumentRep, IsPosInt ],
        
  function( document, string_as_int )
    local name;
    
    name := NameRNam( string_as_int );
    
    return not EvalString( homalgSendBlocking( [ document!.pointer, ".", name, " == null" ], "need_output" ) );
    
end );

##
InstallMethod( InsertIntoDatabase,
        "for a record and a database collection",
        [ IsRecord, IsDatabaseCollectionRep ],

  function( keys_values_rec, collection )
    
    return collection.save( keys_values_rec );
    
end );

##
InstallMethod( InsertIntoDatabase,
        "for a database document and a database collection",
        [ IsDatabaseDocumentRep, IsDatabaseCollectionRep ],

  function( document, collection )
    
    return InsertIntoDatabase( DatabaseDocumentToRecord( document ), collection );
    
end );

##
InstallMethod( UpdateDatabase,
        "for a record, a string, and a database collection",
        [ IsRecord, IsString and IsStringRep, IsDatabaseCollectionRep ],
        
  function( query_rec, str, collection )
    local db, update, coll, options;
    
    db := collection!.database;
    
    coll := collection!.name;
    
    update := _ArangoDB_create_filter_string( coll : FILTER := query_rec );
    
    Append( update, [ " UPDATE d WITH ", str, " IN ", collection!.name ] );
    
    options := ValueOption( "OPTIONS" );
    
    if not options = fail then
        Append( update, [ " OPTIONS ", GapToJsonString( options ) ] );
    fi;
    
    return db._query( update );
    
end );

##
InstallMethod( UpdateDatabase,
        "for two records and a database collection",
        [ IsRecord, IsRecord, IsDatabaseCollectionRep ],
        
  function( query_rec, keys_values_rec, collection )
    
    return UpdateDatabase( query_rec, GapToJsonStringForArangoDB( keys_values_rec ), collection );
    
end );

##
InstallMethod( UpdateDatabase,
        "for a string, a record, and a database collection",
        [ IsString, IsRecord, IsDatabaseCollectionRep ],

  function( id, keys_values_rec, collection )
    local db, string, options;
    
    db := collection!.database;
    
    string := GapToJsonStringForArangoDB( keys_values_rec );
    
    string := [ "UPDATE \"", id, "\" WITH ", string, " IN ", collection!.name ];
    
    options := ValueOption( "OPTIONS" );
    
    if not options = fail then
        Append( string, [ " OPTIONS ", GapToJsonString( options ) ] );
    fi;
    
    return db._query( string );
    
end );

##
InstallMethod( RemoveFromDatabase,
        "for a string and a database collection",
        [ IsString, IsDatabaseCollectionRep ],

  function( id, collection )
    local db, string, options;
    
    db := collection!.database;
    
    string := [ "REMOVE \"", id, "\" IN ", collection!.name ];
    
    options := ValueOption( "OPTIONS" );
    
    if not options = fail then
        Append( string, [ " OPTIONS ", GapToJsonString( options ) ] );
    fi;
    
    return db._query( string );
    
end );

##
InstallMethod( Unbind\.,
        "for a database document and a positive integer",
        [ IsDatabaseDocumentRep, IsPosInt ],
        
  function( document, string_as_int )
    local name;
    
    name := NameRNam( string_as_int );
    
    if not IsBound( document!.collection ) then
        Error( "document has no component called `collection'\n" );
    fi;
    
    UpdateDatabase( rec( _id := document._id, (name) := [ "!=", fail ] ), rec( (name) := fail ), document!.collection : OPTIONS := rec( keepNull := false ) );
    
end );

##
InstallMethod( \.\:\=,
        "for a database document, a positive integer, and an object",
        [ IsDatabaseDocumentRep, IsPosInt, IsObject ],
        
  function( document, string_as_int, obj )
    local name;
    
    name := NameRNam( string_as_int );
    
    if not IsBound( document!.collection ) then
        Error( "document has no component called `collection'\n" );
    fi;
    
    UpdateDatabase( rec( _id := document._id ), rec( (name) := obj ), document!.collection );
    
end );

##
InstallMethod( RemoveKeyFromCollection,
        "for a string and a database collection",
        [ IsString, IsDatabaseCollectionRep ],
        
  function( name, coll )
    local query_rec;
    
    query_rec := ValueOption( "query_rec" );
    
    if IsRecord( query_rec ) then
        query_rec := ShallowCopy( query_rec );
    else
        query_rec := rec( );
    fi;
    
    if not IsBound( query_rec.(name) ) then
        query_rec.(name) := [ "!=", fail ];
    fi;
    
    return UpdateDatabase( query_rec, rec( (name) := fail ), coll : OPTIONS := rec( keepNull := false ) );
    
end );

##
InstallMethod( RemoveKeyFromCollection,
        "for a string, a record, and a database collection",
        [ IsString, IsRecord, IsDatabaseCollectionRep ],
        
  function( name, query_rec, coll )
    
    return RemoveKeyFromCollection( name, coll : query_rec := query_rec );
    
end );

##
InstallGlobalFunction( _ArangoDB_create_filter_string,
  function( collection )
    local string, query_rec, keys, AND, i, key, value, j, val, limit, sort, desc;
    
    string := [ "FOR d IN ", collection ];
    
    query_rec := ValueOption( "FILTER" );
    
    if query_rec = fail then
        query_rec := rec( );
    fi;
    
    if IsRecord( query_rec ) then
        keys := NamesOfComponents( query_rec );
        if not keys = [ ] then
            Add( string, " FILTER " );
        fi;
        AND := "";
    else
        keys := [ ];
        if not query_rec = [ ] then
            Append( string, [ " FILTER ", query_rec ] );
        fi;
    fi;
    
    for i in [ 1 .. Length( keys ) ] do
        key := keys[i];
        value := query_rec.(key);
        if not IsString( value ) and IsList( value ) and IsEvenInt( Length( value ) ) then
            for j in [ 1 .. Length( value ) / 2 ] do
                if value[2*j] = fail then
                    val := "null";
                else
                    if IsString( value[2*j] ) then
                        val := Concatenation( [ "\"", String( value[2*j] ), "\"" ] );
                    else
                        val := GapToJsonStringForArangoDB( value[2*j] );
                    fi;
                fi;
                Append( string, [ AND, "d.", key, " ", value[2*j-1], " ", val ] );
                AND := " && ";
            od;
        elif IsString( value ) or not IsList( value ) then
            if value = fail then
                val := "null";
            else
                if IsString( value ) then
                    val := Concatenation( [ "\"", String( value ), "\"" ] );
                else
                    val := GapToJsonStringForArangoDB( value );
                fi;
            fi;
            Append( string, [ AND, "d.", key, " == ", val ] );
            AND := " && ";
        else
            Error( "wrong syntax of query value: ", value, "\n" );
        fi;
    od;
    
    sort := ValueOption( "SORT" );
    
    if not sort = fail then
        Append( string, [ " SORT d.", String( sort ) ] );
    fi;
    
    desc := ValueOption( "DESC" );
    
    if desc = true then
        Append( string, [ " DESC" ] );
    fi;
    
    limit := ValueOption( "LIMIT" );
    
    if IsInt( limit ) then
        Append( string, [ " LIMIT ", String( limit ) ] );
    fi;
    
    return string;
    
end );

##
InstallGlobalFunction( _ArangoDB_create_filter_return_string,
  function( collection )
    local string, result, result_rec, keys, SEP, func, key, value;
    
    string := _ArangoDB_create_filter_string( collection );
    
    Add( string, " RETURN " );
    
    result := ValueOption( "RETURN" );
    
    result_rec := rec( );
    
    if result = fail then
        Add( string, " d" );
        return Concatenation( string );
    elif result = [ ] then
        Error( "the option `result' is not allowed to be an empty list/string\n" );
    elif IsString( result ) then
        result_rec.(result) := result;
    elif IsList( result ) then
        Perform( result, function( key ) result_rec.(key) := key; end );
    elif IsRecord( result ) then
        if NamesOfComponents( result ) = [ ] then
            Error( "the option `result' is not allowed to be an empty record\n" );
        fi;
        result_rec := ShallowCopy( result );
    else
        Error( "expected for given option `result' a non empty string, a non empty list, or a nonempty record but got ", result, "\n" );
    fi;
    
    Add( string, "{ " );
    
    keys := NamesOfComponents( result_rec );
    
    SEP := "";
    
    func := rec( );
    
    for key in keys do
        value := result_rec.(key);
        if not IsString( value ) and IsList( value ) and Length( value ) = 2 then
            Append( string, [ SEP, key, " : d.", value[1] ] );
            func.(key) := value[2];
        elif IsString( value ) or not IsList( value ) then
            Append( string, [ SEP, key, " : d.", value ] );
            func.(key) := IdFunc;
        else
            Error( "wrong syntax of result key: ", value, "\n" );
        fi;
        SEP := ", ";
    od;
    
    Add( string, " }" );
    
    return [ Concatenation( string ), func ];
    
end );

##
InstallMethod( QueryDatabase,
        "for a database collection",
        [ IsDatabaseCollectionRep ],

  function( collection )
    local string, func, db, cursor;
    
    string := _ArangoDB_create_filter_return_string( collection!.name );
    
    if not IsString( string ) and Length( string ) = 2 and IsRecord( string[2] ) then
        func := string[2];
        string := string[1];
    fi;
    
    db := collection!.database;
    
    cursor := db._query( string );
    
    if IsBound( func ) then
        cursor!.conversions := func;
    fi;
    
    return cursor;
    
end );

##
InstallMethod( QueryDatabase,
        "for a string and a database collection",
        [ IsString and IsStringRep, IsDatabaseCollectionRep ],

  function( query_str, collection )
    
    return QueryDatabase( collection : FILTER := query_str );
    
end );

##
InstallMethod( QueryDatabase,
        "for a record and a database collection",
        [ IsRecord, IsDatabaseCollectionRep ],

  function( query_rec, collection )
    
    return QueryDatabase( collection : FILTER := query_rec );
    
end );

##
InstallMethod( QueryDatabase,
        "for a string, an object, and a database collection",
        [ IsString and IsStringRep, IsObject, IsDatabaseCollectionRep ],

  function( query_str, result, collection )
    
    return QueryDatabase( collection : FILTER := query_str, RETURN := result );
    
end );

##
InstallMethod( QueryDatabase,
        "for a record, an object, and a database collection",
        [ IsRecord, IsObject, IsDatabaseCollectionRep ],

  function( query_rec, result, collection )
    
    return QueryDatabase( collection : FILTER := query_rec, RETURN := result );
    
end );

##
InstallMethod( MarkFirstNDocuments,
        "for an integer, two records, and a database collection",
        [ IsInt, IsRecord, IsRecord, IsDatabaseCollectionRep ],

  function( n, query_rec, mark_rec, collection )
    local q, keys, key, coll, query, mark, action, r, db, trans, c;
    
    q := QueryDatabase( collection : FILTER := query_rec, LIMIT := 1 );
    
    if q.count() = 0 then
        return false;
    fi;
    
    query_rec := ShallowCopy( query_rec );
    
    keys := NamesOfComponents( mark_rec );
    
    for key in keys do
        if not IsBound( query_rec.(key) ) then
            query_rec.(key) := fail;
        fi;
    od;
    
    coll := collection!.name;
    
    query := _ArangoDB_create_filter_string( coll : FILTER := query_rec, LIMIT := n );
    
    mark := [ " UPDATE d WITH " ];
    
    Add( mark, GapToJsonString( mark_rec ) );
    
    Append( mark, [ " IN ", coll ] );
    
    query := Concatenation( query );
    
    mark := Concatenation( mark );
    
    action := [ "function () { ",
                "  var db = require(\"@arangodb\").db;",
                "  var coll = db.", coll, ";",
                "  var c = db._query('", query, mark, "');",
                "}",
                ];
    
    r := rec( collections := rec( write := [ coll ] ),
              waitForSync := true,
              action := Concatenation( action )
              );
    
    db := collection!.database;
    
    trans := db._executeTransaction( r );
    
    if not trans = true then
        Error( "the transaction returned ", String( trans ), "\n" );
    fi;
    
    q := QueryDatabase( mark_rec, collection );
    
    c := q.count();
    
    if c = 0 then
        return fail;
    elif n = 1 and not c = n then
        Error( "expected exactly document but found ", c, "\n" );
    elif not c <= n then
        Error( "expected ", n, " documents (or less) but found ", c, "\n" );
    fi;
    
    return q.toArray();
    
end );

##
InstallMethod( MarkFirstDocument,
        "for two records and a database collection",
        [ IsRecord, IsRecord, IsDatabaseCollectionRep ],

  function( query_rec, mark_rec, collection )
    local a;
    
    a := MarkFirstNDocuments( 1, query_rec, mark_rec, collection );
    
    if IsDatabaseArray( a ) then
        return a[1];
    fi;
    
    return a;
    
end );

##
InstallMethod( Iterator,
        "for a database cursor",
        [ IsDatabaseCursorRep ],
        
  function( cursor )
    local iter;
    
    iter := rec(
                NextIterator := iter -> cursor.next(),
                IsDoneIterator := iter -> not cursor.hasNext(),
                ShallowCopy := IdFunc
                );
    
    return IteratorByFunctions( iter );
    
end );

##
InstallMethod( Iterator,
        "for a database array",
        [ IsDatabaseArrayRep ],
        
  function( array )
    local iter;
    
    iter := rec(
                counter := 1,
                array := array,
                NextIterator := function( iter ) local d; d := iter!.array[iter!.counter]; iter!.counter := iter!.counter + 1; return d; end,
                IsDoneIterator := iter -> iter!.counter > Length( iter!.array ),
                ShallowCopy := function( iter )
                                 return
                                   rec(
                                       counter := iter!.counter,
                                       array := iter!.array,
                                       NextIterator := iter!.NextIterator,
                                       IsDoneIterator := iter!.IsDoneIterator,
                                       ShallowCopy := iter!.ShallowCopy
                                       );
                               end
                );
    
    return IteratorByFunctions( iter );
    
end );

##
InstallMethod( ListOp,
        "for a database array",
        [ IsDatabaseArrayRep ],

  function( array )
    
    return List( [ 1 .. Length( array ) ], i -> array[i] );
    
end );

##
InstallMethod( ListOp,
        "for a database cursor",
        [ IsDatabaseCursorRep ],

  function( cursor )
    
    return ListOp( cursor.toArray( ) );
    
end );

##
InstallMethod( ListOp,
        "for a database array and a function",
        [ IsDatabaseArrayRep, IsFunction ],

  function( array, f )
    
    return List( [ 1 .. Length( array ) ], i -> f( array[i] ) );
    
end );

##
InstallMethod( ListOp,
        "for a database cursor and a function",
        [ IsDatabaseCursorRep, IsFunction ],

  function( cursor, f )
    
    return ListOp( cursor.toArray( ), f );
    
end );

##
InstallMethod( SumOp,
        "for a database cursor and a function",
        [ IsDatabaseCursorRep, IsFunction ],

  function( cursor, f )
    
    return Sum( List( cursor, f ) );
    
end );

##
InstallMethod( SumOp,
        "for a database array and a function",
        [ IsDatabaseArrayRep, IsFunction ],

  function( array, f )
    
    return Sum( List( array, f ) );
    
end );

##
InstallMethod( DatabaseDocumentToRecord,
        "for a database document",
        [ IsDatabaseDocumentRep ],

  function( document )
    local str, doc, i;
    
    str := homalgSendBlocking( [ document!.pointer ], "need_display" );
    
    doc := JsonStringToGap( str );
    
    ## long values of keys will probably be corrupt
    ## so get everything again after knowing all keys
    for i in NamesOfComponents( doc ) do
        doc.(i) := document.(i);
    od;
    
    return doc;
    
end );

##
InstallMethod( DisplayInArangoSh,
        "for a database document",
        [ IsObject ],
        
  function( obj )
    
    if IsBound( obj!.pointer ) then
        homalgDisplay( obj!.pointer );
    fi;
    
end );

##
InstallMethod( ArangoImport,
        "for a string and a database collection",
        [ IsString, IsDatabaseCollectionRep ],
        
  function( filename, collection )
    local exec, type, pos, separator, options, show, db, credentials, i, output;
    
    exec := [ "arangoimp", "--file", filename ];
    
    Append( exec, [ "--collection", Concatenation( [ "\"", collection!.name, "\"" ] ) ] );
    
    type := ValueOption( "type" );
    
    if type = fail then
        ## try to figure out type from suffix
        
        pos := Positions( filename, '.' );
        
        if pos = [ ] then
            Error( "unable to read of the type as a suffix of the file named: ", filename, "\n" );
        fi;
        
        type := filename{[ pos[Length( pos )] + 1 .. Length( filename ) ]};
        
    fi;
    
    Append( exec, [ "--type", type ] );
    
    if type in [ "csv", "tsv" ] then
        
        separator := ValueOption( "separator" );
        
        if separator = fail then
            separator := ",";
        fi;
        
        Append( exec, [ "--separator", Concatenation( [ "\'", separator, "\'" ] ) ] );
        
    fi;
    
    options := ValueOption( "options" );
    
    if not options = fail then
        Add( exec, options );
    fi;
    
    show := [ "# " ];
    Append( show, exec );
    
    db := collection!.database;
    
    credentials := db!.options;
    
    ## get the credentials of the database
    for i in [ 1 .. Length( credentials ) ] do
        if Length( credentials[i] ) > 9 and credentials[i]{[ 1 .. 9 ]} = "--server." then
            Append( exec, credentials{[ i .. i+1 ]} );
            if not credentials[i] = "--server.password" then
                ## do not show password
                Append( show, credentials{[ i .. i+1 ]} );
            fi;
            i := i + 1;
        fi;
    od;
    
    show := JoinStringsWithSeparator( show, " " );
    
    Display( show );
    
    exec := JoinStringsWithSeparator( exec, " " );
    
    output := ExecForHomalg( exec );
    
    Display( output );
    
end );

##
InstallMethod( DocumentsWithDeadLocks,
        "for a string and a database collection",
        [ IsString, IsDatabaseCollectionRep ],
        
  function( json_key, collection )
    local json_key_lock, Hostname, zombies, process_names;
    
    json_key_lock := Concatenation( json_key, "_lock" );
    
    Hostname := IO_gethostname();
    
    zombies := QueryDatabase( rec( (json_key_lock) := [ "!=", fail ] ), collection : LIMIT := 1000 ).toArray();
    
    zombies := List( zombies );
    
    Info( InfoArangoDB, 2, Length( zombies ), "\t   documents with existing ", json_key_lock );
    
    zombies := Filtered( zombies, d -> d.(json_key_lock).Hostname = Hostname );
    
    Info( InfoArangoDB, 2, Length( zombies ), "\t   of them locked by processes started here on ", Hostname );
    
    process_names := ValueOption( "process_names" );
    
    zombies := Filtered( zombies,
                           function( d )
                             local ucomm;
                             ucomm := ExecForHomalg(
                                              Concatenation( "ps -o ucomm ", String( d.(json_key_lock).PID ),
                                                      " | tail -1 | grep -v ^UCOMM | grep -v ^COMMAND" ) );
                             NormalizeWhitespace( ucomm );
                             if process_names = fail then
                                 return ucomm = "";
                             fi;
                             return not ucomm in process_names;
                         end
                       );
    
    Info( InfoArangoDB, 2, Length( zombies ), "\t   of them have deadlocks" );
    
    Perform( zombies, function( d ) d!.collection := collection; end );
    
    return zombies;
    
end );

##
InstallMethod( RemoveDeadLocksFromDocuments,
        "for a string and a database collection",
        [ IsString, IsDatabaseCollectionRep ],
        
  function( json_key, collection )
    local zombies, json_key_lock, d;
    
    zombies := DocumentsWithDeadLocks( json_key, collection );
    
    json_key_lock := Concatenation( json_key, "_lock" );
    
    for d in zombies do
        Unbind( d.(json_key_lock) );
    od;
    
    return zombies;
    
end );

####################################
#
# View, Print, and Display methods:
#
####################################

##
InstallMethod( Display,
        "for a database collection",
        [ IsDatabaseCollectionRep ],
        
  function( collection )
    
    homalgDisplay( collection!.pointer );
    
end );

##
InstallMethod( Display,
        "for a database statement",
        [ IsDatabaseStatementRep ],
        
  function( statement )
    
    homalgDisplay( statement!.pointer );
    
end );

##
InstallMethod( Display,
        "for a database cursor",
        [ IsDatabaseCursorRep ],
        
  function( cursor )
    
    homalgDisplay( cursor!.pointer );
    
end );

##
InstallMethod( Display,
        "for a database array",
        [ IsDatabaseArrayRep ],
        
  function( array )
    
    homalgDisplay( array!.pointer );
    
end );

##
InstallMethod( Display,
        "for a database document",
        [ IsDatabaseDocumentRep ],
        
  function( document )
    
    homalgDisplay( document!.pointer );
    
end );

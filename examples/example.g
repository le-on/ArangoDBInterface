#! @System example

LoadPackage( "ArangoDBInterface" );

#! @Example
db := AttachAnArangoDatabase( );
#! [object ArangoDatabase "example"]
db._drop( "test" );
#! true
coll := db._create( "test" );
#! [ArangoCollection "test"]
db.test;
#! [ArangoCollection "test"]
coll.count();
#! 0
db.test.count();
#! 0
InsertIntoDatabase( rec( _key := "1", TP := "x-y" ), coll );;
coll.count();
#! 1
db._truncate( coll );
#! true
coll.count();
#! 0
coll.save( rec( _key := "1", TP := "x-y" ) );;
coll.count();
#! 1
db._truncate( coll );
#! true
coll.count();
#! 0
coll.save( rec( _key := "1", TP := "x-y" ) );;
coll.save( rec( _key := "2", TP := "x*y" ) );;
InsertIntoDatabase( rec( _key := "3", TP := "x+2*y" ), coll );;
coll.count();
#! 3
UpdateDatabase( "3", rec( TP := "x+y" ), coll );
#! [ArangoQueryCursor in [object ArangoDatabase "example"]]
coll.ensureIndex(rec( type := "hash", fields := [ "TP" ] ));;
t := db._createStatement( rec( query := "FOR e IN test RETURN e", count := true ) );
#! [ArangoStatement in [object ArangoDatabase "example"]]
c := t.execute();
#! [ArangoQueryCursor in [object ArangoDatabase "example"]]
c.count();
#! 3
a := c.toArray();
#! [ArangoArray of length 3]
Length( a );
#! 3
Length( List( a ) );
#! 3
a[1].TP;
#! "x-y"
a[2].TP;
#! "x*y"
a[3].TP;
#! "x+y"
c := t.execute();
#! [ArangoQueryCursor in [object ArangoDatabase "example"]]
i := AsIterator( c );
#! <iterator>
d1 := NextIterator( i );
#! [ArangoDocument]
d1.TP;
#! "x-y"
d2 := NextIterator( i );
#! [ArangoDocument]
d2.TP;
#! "x*y"
d3 := NextIterator( i );
#! [ArangoDocument]
d3.TP;
#! "x+y"
r3 := DatabaseDocumentToRecord( d3 );;
IsRecord( r3 );
#! true
NamesOfComponents( r3 );
#! [ "_key", "TP", "_id", "_rev" ]
[ r3._id, r3._key, r3.TP ];
#! [ "test/3", "3", "x+y" ]
UpdateDatabase( "1", rec( TP := "x+y" ), coll );
#! [ArangoQueryCursor in [object ArangoDatabase "example"]]
q := QueryDatabase( rec( TP := "x+y" ), [ "_key", "TP" ], coll );
#! [ArangoQueryCursor in [object ArangoDatabase "example"]]
a := q.toArray();
#! [ArangoArray of length 2]
Set( List( a ) );
#! [ rec( TP := "x+y", _key := "1" ), rec( TP := "x+y", _key := "3" ) ]
RemoveFromDatabase( "1", coll );
#! [ArangoQueryCursor in [object ArangoDatabase "example"]]
RemoveFromDatabase( "2", coll );
#! [ArangoQueryCursor in [object ArangoDatabase "example"]]
coll.count();
#! 1
db._exists( "test/1" );
#! false
db._exists( "test/3" );
#! true
db._document( "test/3" );
#! [ArangoDocument]
r := rec( collections := rec( write := [ "test" ] ),
          action := "function () { \
          var db = require(\"@arangodb\").db;\
          for (var i = 4; i < 10; ++i)\
            { db.test.save({ _key: \"\" + i }); }\
            db.test.count();\
          }" );;
db._executeTransaction( r );
#! true
coll.count();
#! 7
MarkFirstDocument( rec( TP := fail ), rec( TP_lock := "me1" ), coll );
#! [ArangoDocument]
MarkFirstDocument( rec( TP := fail ), rec( TP_lock := "me2" ), coll );
#! [ArangoDocument]
#! @EndExample

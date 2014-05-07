DCFSQLite
=========

DCFSQLite - Library for easy access, execution of commands and queries in mobile iOS applications using SQLite.

BEFORE
======
You need to import SQLite3 framework. 
Frameworks-> Add existing framework->libsql3.dylib

## HOW TO USE
	# import "DCFSQLite.h"
	
	//Init database 
	[DCFSQLite initDB:@"myapp.db"];
	
	// To create, insert, update and delete
	BOOL ok = [DCFSQLite execSQL:@"INSERT INTO Customer (name, email) VALUES ('Diego', 'diegocfreire@gmail.com')"];
	
	//OR
	BOOL ok = [DCFSQLite execSQL:@"INSERT INTO Customer (name, email) VALUES (?, ?)", @"Diego", @"diegocfreire@gmail.com"];

	//For get result queryes
	NSArray *qryResult = [DCFSQLite getRows:@"SELECT * FROM Customer"];

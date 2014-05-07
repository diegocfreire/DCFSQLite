DCFSQLite
=========

DCFSQLite - Library for easy access, execution of commands and queries in mobile iOS applications using SQLite.

## HOW TO USE
	# import "DCFSQLite.h"
	
	//Init database 
	[DCFSQLite initWithDB:@"myapp.db"];
	
	// To create, insert, update and delete
	BOOL ok = [DCFSQLite execSQL:@"INSERT INTO Customer (name, email) VALUES ('Diego', 'diegocfreire@gmail.com')"];
	
	//OR
	BOOL ok = [DCFSQLite execSQL:@"INSERT INTO Customer (name, email) VALUES (?, ?)", @"Diego", @"diegocfreire@gmail.com"];

	//For get result queryes
	NSArray *qryResult = [DCFSQLite getRows:@"SELECT * FROM Customer"];

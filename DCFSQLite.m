//
//  DCFSQLite.h
//
//  Created by Diego Freire on 2014/05/07.
//  Copyright (c) 2014 DCFSistemas. All rights reserved.

#import "DCFSQLite.h"

@interface DCFSQLite ()

- (BOOL)openDB;
- (BOOL)closeDB;

@end


@implementation DCFSQLite

@synthesize database = _database;

#pragma mark - Singleton

+ (DCFSQLite *)shared
{
    static DCFSQLite * _dcfsqlite = nil;
    
    @synchronized (self){
        
        static dispatch_once_t pred;
        dispatch_once(&pred, ^{
            _dcfsqlite = [[DCFSQLite alloc] init];
        });
    }
    
    return _dcfsqlite;
}



#pragma mark - Public Methods

+ (void)initDB:(NSString *)database
{
    [DCFSQLite shared].database = database;
}


+ (BOOL)execSQL:(NSString *)sql, ...
{
    BOOL openDB = NO;
	
    va_list arguments;
    va_start(arguments, sql);
    //   NSLogv(sql, arguments);
    sql = [[NSString alloc] initWithFormat:sql arguments:arguments];
    va_end(arguments);
    
	//Check if database is open and ready.
	if ([DCFSQLite shared]->db == nil) {
		openDB = [[DCFSQLite shared] openDB];
	}
	
	if (openDB) {
		sqlite3_stmt *statement;
		const char *query = [sql UTF8String];
        
        // prepare
        if (sqlite3_prepare_v2([DCFSQLite shared]->db, query, -1, &statement, NULL) != SQLITE_OK) {
            NSLog(@"Error: failed to prepare statement with message '%s'.", sqlite3_errmsg([DCFSQLite shared]->db));
            return NO;
        }
        
        id obj;
        int idx = 0;
        int queryCount = sqlite3_bind_parameter_count(statement);
        
        while (idx < queryCount) {
            obj = va_arg(arguments, id);
            idx++;
            [[DCFSQLite shared] bindObject:obj toColumn:idx inStatement:statement];
        }
        
        // execute
        while (1) {
            if(sqlite3_step(statement) == SQLITE_DONE){
                
                sqlite3_finalize(statement);
                [[DCFSQLite shared] closeDB];
                
                return YES;
            }else {
                NSLog(@" 2. Error %d: '%s' com sql: %@", sqlite3_errcode([DCFSQLite shared]->db), sqlite3_errmsg([DCFSQLite shared]->db), sql);
                if(sqlite3_errcode([DCFSQLite shared]->db) != SQLITE_LOCKED){
                    
                    sqlite3_finalize(statement);
                    [[DCFSQLite shared] closeDB];
                    
                    return NO;
                }
                
                [NSThread sleepForTimeInterval:.1];
            }
        }
	}
	else {
        return NO;
	}
    
	return YES;
}

+ (NSArray *)getRows:(NSString *)sql, ...
{
    
    va_list arguments;
    va_start(arguments, sql);
    //   NSLogv(sql, arguments);
    sql = [[NSString alloc] initWithFormat:sql arguments:arguments];
    va_end(arguments);
    
    NSMutableArray *resultsArray = [[NSMutableArray alloc] initWithCapacity:1];
	
	if ([DCFSQLite shared]->db == nil) {
		[[DCFSQLite shared] openDB];
	}
	
	sqlite3_stmt *statement;
	const char *query = [sql UTF8String];
	sqlite3_prepare_v2([DCFSQLite shared]->db, query, -1, &statement, NULL);
    
	while (sqlite3_step(statement) == SQLITE_ROW) {
        
		int columns = sqlite3_column_count(statement);
		NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:columns];
		
        for (int i = 0; i<columns; i++) {
			const char *name = sqlite3_column_name(statement, i);
            
			NSString *columnName = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
			
			int type = sqlite3_column_type(statement, i);
            
			switch (type) {
                    
				case SQLITE_INTEGER:{
                    int value = sqlite3_column_int(statement, i);
                    [result setObject:[NSNumber numberWithInt:value] forKey:columnName];
                    break;
				}
                    
				case SQLITE_FLOAT:{
                    float value = sqlite3_column_double(statement, i);
                    [result setObject:[NSNumber numberWithFloat:value] forKey:columnName];
                    break;
				}
                    
				case SQLITE_TEXT:{
                    const char *value = (const char*)sqlite3_column_text(statement, i);
                    [result setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:columnName];
                    break;
				}
                    
				case SQLITE_BLOB:{
                    int dataSize = sqlite3_column_bytes(statement, i);
                    NSMutableData *data = [NSMutableData dataWithLength:dataSize];
                    memcpy([data mutableBytes], sqlite3_column_blob(statement, i), dataSize);
                    [result setObject:data forKey:columnName];
					break;
                }
                    
				case SQLITE_NULL:
					[result setObject:[NSNull null] forKey:columnName];
					break;
                    
				default:{
                    const char *value = (const char *)sqlite3_column_text(statement, i);
                    [result setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:columnName];
                    break;
				}
			}
		}
		
		[resultsArray addObject:result];
        
	}
    
	sqlite3_finalize(statement);
	
	[[DCFSQLite shared] closeDB];
	
	return resultsArray;
}

+ (NSString *)getDump
{
	NSMutableString *dump = [[NSMutableString alloc] initWithCapacity:256];
	
	// info string ;) please do not remove it
	[dump appendString:@";\n; Dump generated with DCFSQLite \n;\n"];
	[dump appendString:[NSString stringWithFormat:@"; database %@;\n\n", [DCFSQLite shared].database]];
	
	// first get all table information
	
	NSArray *rows = [DCFSQLite getRows:@"SELECT * FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%%';"];
	
	//loop through all tables
	for (int i = 0; i<[rows count]; i++) {
		
		NSDictionary *obj = [rows objectAtIndex:i];
		//get sql "create table" sentence
		NSString *sql = [obj objectForKey:@"sql"];
		[dump appendString:[NSString stringWithFormat:@"%@;\n",sql]];
        
		//get table name
		NSString *tableName = [obj objectForKey:@"name"];
        
		//get all table content
		NSArray *tableContent = [DCFSQLite getRows:@"SELECT * FROM %@",tableName];
		
		for (int j = 0; j < [tableContent count]; j++) {
			NSDictionary *item = [tableContent objectAtIndex:j];
			
			//keys are column names
			NSArray *keys = [item allKeys];
			
			//values are column values
			NSArray *values = [item allValues];
			
			//start constructing insert statement for this item
			[dump appendString:[NSString stringWithFormat:@"insert into %@ (",tableName]];
			
			//loop through all keys (aka column names)
			NSEnumerator *enumerator = [keys objectEnumerator];
			id obj;
			while ((obj = [enumerator nextObject])) {
				[dump appendString:[NSString stringWithFormat:@"%@,",obj]];
			}
			
			//delete last comma
			NSRange range;
			range.length = 1;
			range.location = [dump length]-1;
			[dump deleteCharactersInRange:range];
			[dump appendString:@") values ("];
			
			// loop through all values
			// value types could be:
			// NSNumber for integer and floats, NSNull for null or NSString for text.
			
			enumerator = [values objectEnumerator];
			while ((obj = [enumerator nextObject])) {
				//if it's a number (integer or float)
				if ([obj isKindOfClass:[NSNumber class]]){
					[dump appendString:[NSString stringWithFormat:@"%@,",[obj stringValue]]];
				}
				//if it's a null
				else if ([obj isKindOfClass:[NSNull class]]){
					[dump appendString:@"null,"];
				}
				//else is a string ;)
				else{
					[dump appendString:[NSString stringWithFormat:@"'%@',",obj]];
				}
				
			}
			
			//delete last comma again
			range.length = 1;
			range.location = [dump length]-1;
			[dump deleteCharactersInRange:range];
			
			//finish our insert statement
			[dump appendString:@");\n"];
			
		}
	}
    
	return dump;
}



#pragma mark - Private Methods

- (BOOL)openDB
{
    NSString *databasePath;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    if (self.database != nil) {
        databasePath = [documentsDirectory stringByAppendingPathComponent:self.database];
    }else{
        return NO;
    }
    
    //first check if exist
	if(![[NSFileManager defaultManager] fileExistsAtPath:databasePath]) {
        // if not, move pro mainbundle root to documents
		BOOL success = [[NSFileManager defaultManager] copyItemAtPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.database] toPath:databasePath error:nil];
		if (!success) return NO;
	}
    
    BOOL success = YES;
    
    if(!sqlite3_open([databasePath UTF8String], &db) == SQLITE_OK ) success = NO;
	
	return success;
}

- (void)bindObject:(id)obj toColumn:(int)idx inStatement:(sqlite3_stmt*)pStmt
{
    if ((!obj) || ((NSNull *)obj == [NSNull null])) {
        sqlite3_bind_null(pStmt, idx);
    }
    
    // FIXME - someday check the return codes on these binds.
    else if ([obj isKindOfClass:[NSData class]]) {
        const void *bytes = [obj bytes];
        if (!bytes) {
            // it's an empty NSData object, aka [NSData data].
            // Don't pass a NULL pointer, or sqlite will bind a SQL null instead of a blob.
            bytes = "";
        }
        sqlite3_bind_blob(pStmt, idx, bytes, (int)[obj length], SQLITE_STATIC);
    }
    else if ([obj isKindOfClass:[NSDate class]]) {
        sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        
        if (strcmp([obj objCType], @encode(BOOL)) == 0) {
            sqlite3_bind_int(pStmt, idx, ([obj boolValue] ? 1 : 0));
        }
        else if (strcmp([obj objCType], @encode(int)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(long long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longLongValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned long long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedLongLongValue]);
        }
        else if (strcmp([obj objCType], @encode(float)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj floatValue]);
        }
        else if (strcmp([obj objCType], @encode(double)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj doubleValue]);
        }
        else {
            sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
        }
    }
    else {
        sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
    }
}


- (BOOL)closeDB
{
	if (db != nil) {
        if (sqlite3_close(db) != SQLITE_OK){
            return NO;
        }
        
		db = nil;
	}
    
	return YES;
}

@end

//
//  DCFSQLite.h
//
//  Created by Diego Freire on 2014/05/07.
//  Copyright (c) 2014 DCFSistemas. All rights reserved.


#import <Foundation/Foundation.h>
#import "sqlite3.h"


@interface DCFSQLite : NSObject {
    sqlite3 *db;
}

@property (copy, nonatomic) NSString *database;


+ (void)initDB:(NSString *)database;
+ (BOOL)execSQL:(NSString *)sql, ...;
+ (NSArray *)getRows:(NSString *)sql, ... NS_FORMAT_FUNCTION(1,2);
+ (NSString *)getDump;

@end

//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import "DatabaseManager.h"
#import "ErrorHandler.h"
#import "DocumentManager.h"
#import "AppGroup.h"
#import "BundleUtil.h"
#import "UserSettings.h"
#import "ValidationLogger.h"
#import "MDMSetup.h"
#import "DatabaseContext.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "Utils.h"

#define THREEMA_DB_MODEL @"ThreemaData"

#define THREEMA_DB_FILE @"ThreemaData.sqlite"
#define THREEMA_DB_IMPORT_FILE @"RepairedThreemaData.sqlite"
#define THREEMA_DB_EXTERNALS @".ThreemaData_SUPPORT"

#define THREEMA_DB_DIRTY_OBJECT_KEY @"DBDirtyObjectsKey"
#define THREEMA_DB_DID_UPDATE_EXTERNAL_DATA_PROTECTION_KEY @"DBDidUpdateExternalDataProtectionNewKey"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif


@implementation DatabaseManager

#pragma mark - Core Data

static DatabaseManager *dbManager;

+ (instancetype)dbManager {
    if (dbManager == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dbManager = [[DatabaseManager alloc] init];
        });
    }
    
    return dbManager;
}

- (DatabaseContext *)getDatabaseContext:(BOOL)forBackgroundProcess
{
    DatabaseContext *context;
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        context = [[DatabaseContext alloc] initWithPersistentCoordinator:coordinator forBackgroundProcess:forBackgroundProcess];
    }
    else {
        [NSException raise:@"Invalid persistent store coordinator" format:@"Could not create persistent store coordinator"];
    }
    
    return context;
}

- (BOOL)shouldUpdateProtection {
    BOOL didUpdateProtectionForExternalData = [[AppGroup userDefaults] boolForKey:THREEMA_DB_DID_UPDATE_EXTERNAL_DATA_PROTECTION_KEY];
        
    NSError *error;
    NSURL *storeURL = [DatabaseManager storeUrl];
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:storeURL.path error:&error];
    if (dict[@"NSFileProtectionKey"] == NSFileProtectionCompleteUntilFirstUserAuthentication && didUpdateProtectionForExternalData) {
        // Update shared directories every time to avoid crash (IOS-1406)
        [self updateDirectoryProtectionAtURL:[DocumentManager databaseDirectory]];
        return NO;
    }
    return YES;
}

- (void)updateDirectoryProtectionAtURL:(NSURL *)baseURL {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSDirectoryEnumerator *directoryEnumerator = [fileManager enumeratorAtURL:baseURL includingPropertiesForKeys:@[NSURLNameKey, NSURLFileProtectionKey] options:0 errorHandler:nil];
    for (NSURL *fileURL in [directoryEnumerator.allObjects filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"RWIsDirectory == YES"]]) {
        NSString *fileProtection = nil;
        [fileURL getResourceValue:&fileProtection forKey:NSURLFileProtectionKey error:nil];
        
        if (fileProtection != NSURLFileProtectionComplete)
            continue;
        
        [fileManager setAttributes:@{NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication} ofItemAtPath:fileURL.path error:nil];
    }
}

- (void)updateProtection {
    // In earlier versions, when we updated the database from NSFileProtectionComplete to NSFileProtectionCompleteUntilFirstUserAuthentication,
    // we did not also update the contents of the external data directory. This needs to be done now, because the Web client must be
    // able to access images etc. when the device is locked, and Core Data needs to save external data files for received media.
    // To be sure, we check our entire app and group containers and change any files or directories that are still set to
    // NSFileProtectionComplete to the more apppropriate NSFileProtectionCompleteUntilFirstUserAuthentication.
    // Note that directories may have a file protection class (which then applies to all new files created within them), but they do not have to.
    
    [self updateProtectionAtURL:[DocumentManager databaseDirectory]];
    [self updateProtectionAtURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
    
    NSUserDefaults *defaults = [AppGroup userDefaults];
    [defaults setBool:YES forKey:THREEMA_DB_DID_UPDATE_EXTERNAL_DATA_PROTECTION_KEY];
    [defaults synchronize];
}

- (void)updateProtectionAtURL:(NSURL*)baseURL {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSDirectoryEnumerator *directoryEnumerator = [fileManager enumeratorAtURL:baseURL includingPropertiesForKeys:@[NSURLNameKey, NSURLFileProtectionKey] options:0 errorHandler:nil];
    
    for (NSURL *fileURL in directoryEnumerator) {
        NSString *fileProtection = nil;
        [fileURL getResourceValue:&fileProtection forKey:NSURLFileProtectionKey error:nil];
        
        if (fileProtection != NSURLFileProtectionComplete)
            continue;
        
        [fileManager setAttributes:@{NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication} ofItemAtPath:fileURL.path error:nil];
    }
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    
    NSURL *modelURL = [BundleUtil URLForResource:THREEMA_DB_MODEL withExtension:@"momd"];

    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

+ (BOOL)storeExists {
    NSURL *storeURL = [DatabaseManager storeUrl];
    return [[NSFileManager defaultManager] fileExistsAtPath:storeURL.path];
}

- (BOOL)storeRequiresMigration {
    NSURL *storeURL = [DatabaseManager storeUrl];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:storeURL.path]) {
        return NO;  /* no store = no migration */
    }
    
    NSError *error;
    NSFileProtectionType protectionType = NSFileProtectionCompleteUntilFirstUserAuthentication;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             protectionType, NSPersistentStoreFileProtectionKey, nil];
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:storeURL options:options error:&error];
    return ![self.managedObjectModel isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata];
}

- (BOOL)storeRequiresImport {
    NSURL *repairedThreemaDataUrl = [[DocumentManager applicationDocumentsDirectory] URLByAppendingPathComponent:THREEMA_DB_IMPORT_FILE];
    return [[NSFileManager defaultManager] fileExistsAtPath:repairedThreemaDataUrl.path];
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
*/
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    // Execute possible DB migration just once
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        if (_persistentStoreCoordinator == nil) {
    
#ifdef DEBUG
            if ([AppGroup getCurrentType] == AppGroupTypeApp) {
                [FileUtility logDirectoriesAndFilesWithPath:[DocumentManager databaseDirectory] logFileName:@"db-migration-before.log"];
            }
#endif
    
            double startTime = CACurrentMediaTime();
            
            NSURL *storeURL = [DatabaseManager storeUrl];
            
            [self migrateDatabaseLocation];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSURL *documentsUrl = [DocumentManager databaseDirectory];
            NSURL *tmpUrlToExternalStorage = [documentsUrl URLByAppendingPathComponent:@"tmpPathToReplacementData"];
            NSURL *urlToExternalStorage = [documentsUrl URLByAppendingPathComponent:@".ThreemaData_SUPPORT/_EXTERNAL_DATA"];
            
            NSString *coreDataModelVersion = [BundleUtil objectForInfoDictionaryKey:@"ThreemaCoreDataVersion"];
            
            NSURL *urlToBackupStorage = [NSURL URLWithString:[NSString stringWithFormat:@"%@.bak.%@", storeURL.absoluteString, coreDataModelVersion]];
            NSURL *tmpUrlToBackupStorage = [NSURL URLWithString:[NSString stringWithFormat:@"%@.bak.%@.%.0f", storeURL.absoluteString, coreDataModelVersion, [[NSDate date] timeIntervalSince1970]]];
            
            //Check if the new model is compatible with any previously stored model
            BOOL requiresMigration = [self storeRequiresMigration];
            
            if (requiresMigration) {
                // Migration is required - check if a store backup file (.bak) exists. If so, the last migration attempt has
                // failed, and before trying again, we copy the backup back to the store URL so Core Data can make another try.
                // Also, during migration, we move away the external data storage folder to keep Core Data from copying every
                // single external data item (media etc.), which is useless, and takes a long time and a lot of disk space.
                if ([fileManager fileExistsAtPath:[urlToBackupStorage path]]) {
                    // Delete the broken, half-migrated store and copy the backup
                    NSError *copyBackupError = nil;
                    [fileManager removeItemAtURL:storeURL error:nil];
                    [fileManager copyItemAtURL:urlToBackupStorage toURL:storeURL error:&copyBackupError];
                    if (copyBackupError != nil) {
                        _storeError = copyBackupError;
                    }
                    else {
                        // Remove wal and shm temporary files to prevent problems with the SQLite store
                        NSURL *walFile = [NSURL URLWithString:[NSString stringWithFormat:@"%@-wal", storeURL.absoluteString]];
                        [fileManager removeItemAtURL:walFile error:nil];
                        NSURL *shmFile = [NSURL URLWithString:[NSString stringWithFormat:@"%@-shm", storeURL.absoluteString]];
                        [fileManager removeItemAtURL:shmFile error:nil];

                        // Remove external storage folder; the original will be at tmpUrlToExternalStorage at this point
                        [fileManager removeItemAtURL:urlToExternalStorage error:nil];
                    }
                } else {
                    // Before migration begins, copy the store to a backup file (.bak). We do this in two steps:
                    // first we copy the store to a .bak2 file, and then we rename the .bak2 to .bak. This is
                    // so that if the copy operation is interrupted (which is possible as it can take some time for
                    // large stores), we don't end up using a broken .bak when we start again.
                    NSError *copyBackupError = nil;
                    [fileManager removeItemAtURL:tmpUrlToBackupStorage error:nil];
                    [fileManager copyItemAtURL:storeURL toURL:tmpUrlToBackupStorage error:&copyBackupError];
                    if (copyBackupError != nil) {
                        _storeError = copyBackupError;
                    }
                    else {
                        // Rename .bak2 to .bak
                        [fileManager removeItemAtURL:urlToBackupStorage error:nil];
                        [fileManager moveItemAtURL:tmpUrlToBackupStorage toURL:urlToBackupStorage error:nil];
                        
                        // Move away external storage directory during migration
                        [fileManager removeItemAtURL:tmpUrlToExternalStorage error:nil];
                        if ([fileManager fileExistsAtPath:[urlToExternalStorage path]]) {
                            [fileManager moveItemAtURL:urlToExternalStorage toURL:tmpUrlToExternalStorage error:nil];
                        }
                    }
                }
            } else {
                // Migration is currently not required, but if a previous migration completed without
                // us having a chance to put the external data storage folder back in place, we will
                // end up with the media in tmpUrlToExternalStorage where it is inaccessible to Core Data.
                // Attempt to move the media back in such a case, if necessary
                if ([fileManager fileExistsAtPath:[tmpUrlToExternalStorage path]]) {
                    if ([fileManager fileExistsAtPath:[urlToExternalStorage path]]) {
                        // Ooops, the external storage directory already exists, so we should not delete it or
                        // we will risk losing some (new) media. Instead, merge the contents of the two directories
                        NSError *mergeError = nil;
                        [self mergeContentsOfPath:[tmpUrlToExternalStorage path] intoPath:[urlToExternalStorage path] error:&mergeError];
                        if (!mergeError) {
                            [fileManager removeItemAtURL:tmpUrlToExternalStorage error:nil];
                        }
                    } else {
                        [fileManager moveItemAtURL:tmpUrlToExternalStorage toURL:urlToExternalStorage error:nil];
                    }
                    [self removeMigrationLeftover];
                }
            }
            
            if (_storeError == nil) {
                NSError *error = nil;
                
                NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
                
                NSFileProtectionType protectionType = NSFileProtectionCompleteUntilFirstUserAuthentication;
                NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                         [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                                         protectionType, NSPersistentStoreFileProtectionKey, nil];

                if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
                    if ([fileManager fileExistsAtPath:[urlToBackupStorage path]]) {
                        [fileManager removeItemAtURL:storeURL error:nil];
                        [fileManager copyItemAtURL:urlToBackupStorage toURL:storeURL error:nil];
                    }
                    
                    DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
                    _storeError = error;
                }
                
                if (requiresMigration && error == nil) {
                    // Core Data migration is now complete. Replace the default external storage folder with the version pre upgrade,
                    // and delete the store backup files.
                    [fileManager removeItemAtURL:urlToExternalStorage error:nil];
                    [fileManager moveItemAtURL:tmpUrlToExternalStorage toURL:urlToExternalStorage error:nil];
                    [fileManager removeItemAtURL:urlToBackupStorage error:nil];
                    [fileManager removeItemAtURL:tmpUrlToBackupStorage error:nil];
                    
                    [self removeMigrationLeftover];
                }
                
                double endTime = CACurrentMediaTime();
                DDLogInfo(@"DB setup time %f s", (endTime - startTime));
    
#ifdef DEBUG
                [FileUtility logDirectoriesAndFilesWithPath:[DocumentManager databaseDirectory] logFileName:@"db-migration-after.log"];
#endif

                _persistentStoreCoordinator = persistentStoreCoordinator;
            }
        }
    });
    
    return _persistentStoreCoordinator;
}

- (void)removeMigrationLeftover {
    // remove any leftover from previous failed migrations
    NSURL *documentsUrl = [DocumentManager databaseDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:documentsUrl.path error:nil];
    for (NSString *fileName in files) {
        if ([fileName hasPrefix:[NSString stringWithFormat:@"%@.v2.bak", THREEMA_DB_FILE]] || [fileName hasPrefix:[NSString stringWithFormat:@"%@.bak", THREEMA_DB_FILE]]) {
            NSURL *fileUrl = [documentsUrl URLByAppendingPathComponent:fileName];
            [fileManager removeItemAtURL:fileUrl error:nil];
        }
    }
}

- (unsigned long long)storeSize {
    unsigned long long storeSize = 0;
    
    NSString *documentsPath = [DocumentManager databaseDirectory].path;
    
    storeSize += [DocumentManager sizeOfObjectAtPath:[documentsPath stringByAppendingPathComponent:THREEMA_DB_FILE]];
    
    //    NSString *pathToSupportDir = [documentsPath stringByAppendingPathComponent:THREEMA_DB_EXTERNALS];
    //    storeSize += [Utils sizeOfObjectAtPath:pathToSupportDir];
    
    return storeSize;
}

- (BOOL)canMigrateDB {
    unsigned long long storeSize = [self storeSize];
    unsigned long long freeDiskSpace = [self freeDiskSpace];
    unsigned long long minFreeRequired = MAX(storeSize*3, 512*1024*1024);
    
    /* must have at least 3 * storeSize free, and in any case at least 512 MB */
    if (freeDiskSpace < minFreeRequired) {
        DDLogError(@"Not enough space for migration (store size %llu, %llu free)", storeSize, freeDiskSpace);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"database_migration_storage_warning_message", nil), minFreeRequired/1073741824.0f, freeDiskSpace/1073741824.0f];
            [ErrorHandler abortWithTitle:NSLocalizedString(@"database_migration_storage_warning_title", nil) message:message];
        });
        
        return NO;
    }
    
    return YES;
}

- (void)doMigrateDB {
    [self persistentStoreCoordinator];
}

- (void)copyImportedDatabase {
    double startTime = CACurrentMediaTime();
    
    NSURL *storeURL = [DatabaseManager storeUrl];
    
    [self migrateDatabaseLocation];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsUrl = [DocumentManager applicationDocumentsDirectory];
    NSURL *urlToImportStorage = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", documentsUrl.absoluteString, THREEMA_DB_IMPORT_FILE]];
    
    if ([fileManager fileExistsAtPath:[urlToImportStorage path]]) {
        NSError *copyImportError = nil;
        [fileManager removeItemAtURL:storeURL error:nil];
        [fileManager copyItemAtURL:urlToImportStorage toURL:storeURL error:&copyImportError];
        
        if (copyImportError == nil) {
            // Remove wal and shm temporary files to prevent problems with the SQLite store
            NSURL *walFile = [NSURL URLWithString:[NSString stringWithFormat:@"%@-wal", storeURL.absoluteString]];
            [fileManager removeItemAtURL:walFile error:nil];
            NSURL *shmFile = [NSURL URLWithString:[NSString stringWithFormat:@"%@-shm", storeURL.absoluteString]];
            [fileManager removeItemAtURL:shmFile error:nil];
            
             [fileManager removeItemAtURL:urlToImportStorage error:nil];
        }
        
        double endTime = CACurrentMediaTime();
        DDLogInfo(@"DB setup time %f s", (endTime - startTime));
    }
}

- (void)eraseDB {
    NSArray *stores = [_persistentStoreCoordinator persistentStores];
    for (NSPersistentStore *store in stores) {
        [_persistentStoreCoordinator removePersistentStore:store error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:store.URL.path error:nil];
    }
    
    _persistentStoreCoordinator = nil;
}

- (void)migrateDatabaseLocation {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // check if data is at application location, if yes move it to group directory
    NSURL *appUrl = [DocumentManager applicationDocumentsDirectory];
    NSURL *appFile = [appUrl URLByAppendingPathComponent:THREEMA_DB_FILE];
    
    if ([fileManager fileExistsAtPath:appFile.path]) {
        NSURL *targetURL = [DocumentManager databaseDirectory];
        [self moveDBFilesFrom:appUrl to:targetURL];
    }
}

- (void)moveDBFilesFrom:(NSURL *)sourceUrl to:(NSURL *)targetUrl {
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [fileManager createDirectoryAtURL:targetUrl withIntermediateDirectories:YES attributes:nil error:&error];
    
    NSURL *sourceDBFile = [sourceUrl URLByAppendingPathComponent:THREEMA_DB_FILE];
    NSURL *targetDBFile = [targetUrl URLByAppendingPathComponent:THREEMA_DB_FILE];
    if ([fileManager fileExistsAtPath:sourceDBFile.path]) {
        [fileManager removeItemAtURL:targetDBFile error:&error];
        [fileManager moveItemAtURL:sourceDBFile toURL:targetDBFile error:&error];
    }
    
    NSString *walFile = [THREEMA_DB_FILE stringByAppendingString:@"-wal"];
    NSURL *sourceDBWalFile = [sourceUrl URLByAppendingPathComponent:walFile];
    NSURL *targetDBWalFile = [targetUrl URLByAppendingPathComponent:walFile];
    if ([fileManager fileExistsAtPath:sourceDBWalFile.path]) {
        [fileManager removeItemAtURL:targetDBWalFile error:&error];
        [fileManager moveItemAtURL:sourceDBWalFile toURL:targetDBWalFile error:&error];
    }
 
    // no need to move shm file, it is recreated by sqllite (https://www.sqlite.org/tempfiles.html)
    // to keep clean -> delete it
    NSString *shmFile = [THREEMA_DB_FILE stringByAppendingString:@"-shm"];
    NSURL *shmUrl = [sourceUrl URLByAppendingPathComponent:shmFile];
    if ([fileManager fileExistsAtPath:shmUrl.path]) {
        [fileManager removeItemAtURL:shmUrl error:nil];
    }

    NSURL *sourceExternals = [sourceUrl URLByAppendingPathComponent:THREEMA_DB_EXTERNALS];
    NSURL *targetExternals = [targetUrl URLByAppendingPathComponent:THREEMA_DB_EXTERNALS];
    if ([fileManager fileExistsAtPath:sourceExternals.path]) {
        
        if ([fileManager fileExistsAtPath:targetExternals.path]) {
            // there already are some external files at target -> keep it and move source files one by one
            
            NSURL *sourceExternalsSubDir = [sourceExternals URLByAppendingPathComponent:@"_EXTERNAL_DATA"];
            NSURL *targetExternalsSubDir = [targetExternals URLByAppendingPathComponent:@"_EXTERNAL_DATA"];
            if ([fileManager fileExistsAtPath:targetExternalsSubDir.path] == NO) {
                [fileManager createDirectoryAtURL:targetExternalsSubDir withIntermediateDirectories:YES attributes:0 error:nil];
            }
            
            NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:sourceExternalsSubDir.path];
            
            NSString *file;
            while ((file = [dirEnum nextObject])) {
                NSURL *externalDataSource = [sourceExternalsSubDir URLByAppendingPathComponent:file];
                NSURL *externalDataTarget = [targetExternalsSubDir URLByAppendingPathComponent:file];
                
                [fileManager moveItemAtPath:externalDataSource.path toPath:externalDataTarget.path error:&error];
            }
            
            
            // remove old directory
            [fileManager removeItemAtURL:sourceExternalsSubDir error:nil];
            
        } else {
            // move whole directory
            [fileManager moveItemAtURL:sourceExternals toURL:targetExternals error:&error];
        }
    }
}

+ (NSURL *)storeUrl {
    return [[DocumentManager databaseDirectory] URLByAppendingPathComponent:THREEMA_DB_FILE];
}

- (unsigned long long)freeDiskSpace {
    if (@available(iOS 11.0, *)) {
        NSURL *fileUrl = [NSURL fileURLWithPath:NSHomeDirectory()];
        NSError *error = nil;
        NSDictionary *dict = [fileUrl resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey] error:&error];
        if (dict) {
            NSNumber *availableCapacity = dict[NSURLVolumeAvailableCapacityForImportantUsageKey];
            return availableCapacity.unsignedLongLongValue;
        } else {
            DDLogError(@"Cannot retrieve free disk space: %@", error);
            return 0;
        }
    } else {
        //unsigned long long totalSpace = 0;
        unsigned long long totalFreeSpace = 0;
        
        NSError *error = nil;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
        
        if (dictionary) {
            //NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
            NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
            //totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
            totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
        }
        
        return totalFreeSpace;
    }
}

- (void)disableBackupForDatabaseDirectory:(BOOL)disable
{
    NSString *documentsPath = [DocumentManager databaseDirectory].path;
    NSString *applicationDocumentsPath = [DocumentManager applicationDocumentsDirectory].path;
    NSString *cachePath = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject].path;
    
    NSURL *urlToExternalStorage = [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:@".ThreemaData_SUPPORT"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:THREEMA_DB_FILE]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:@"ThreemaData.sqlite-shm"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:@"ThreemaData.sqlite-wal"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:@"DoneMessages"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:@"WebSessions"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:@"PreviousContext"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[applicationDocumentsPath stringByAppendingPathComponent:@"idbackup.txt"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[cachePath stringByAppendingPathComponent:@"ch.threema.work.iapp/Cache.db"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[cachePath stringByAppendingPathComponent:@"ch.threema.work.iapp/Cache.db-shm"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
    
    urlToExternalStorage = [NSURL fileURLWithPath:[cachePath stringByAppendingPathComponent:@"ch.threema.work.iapp/Cache.db-wal"]];
    [self setResourceValue:disable forUrl:urlToExternalStorage];
}

- (void)setResourceValue:(BOOL)disable forUrl:(NSURL *)url {
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
//        assert([[NSFileManager defaultManager] fileExistsAtPath:[url path]]);
        BOOL success = [url setResourceValue:[NSNumber numberWithBool:disable] forKey: NSURLIsExcludedFromBackupKey error: &error];
        if(!success){
            DDLogError(@"Error excluding %@ from backup %@", [url lastPathComponent], error);
        }
    }
}


#pragma mark - dirty object handling (e.g. when switching from share extension back to app)

- (void)refreshDirtyObjectIDs:(NSDictionary *)changes intoContext:(NSManagedObjectContext *)context {
    [NSManagedObjectContext mergeChangesFromRemoteContextSave:changes intoContexts:@[context]];
}

- (void)refreshDirtyObjects {
  
    DatabaseContext *dbContext = [self getDatabaseContext:NO];

    NSUserDefaults *defaults = [AppGroup userDefaults];
    NSArray *objects = [defaults arrayForKey:THREEMA_DB_DIRTY_OBJECT_KEY];
    if (objects == nil) {
        return;
    }
    
    [defaults removeObjectForKey:THREEMA_DB_DIRTY_OBJECT_KEY];
    [defaults synchronize];
    
    NSTimeInterval stalenessInterval = dbContext.main.stalenessInterval;
    [dbContext main].stalenessInterval = 0.0;
    
    NSMutableSet *notifyObjectIds = [NSMutableSet setWithCapacity:[objects count]];
    // first refresh objects in context
    for (NSString *urlString in objects) {
        NSURL *url = [NSURL URLWithString:urlString];
        NSManagedObjectID *objectID = [_persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
        if (objectID) {
            NSManagedObject *object = [[dbContext main] objectWithID:objectID];
            [[dbContext main] refreshObject:object mergeChanges:YES];
            
            [notifyObjectIds addObject:objectID];
        }
    }
    
    [dbContext main].stalenessInterval = stalenessInterval;

    // notfiy object changes
    for (NSManagedObjectID *objectID in notifyObjectIds) {
        DDLogInfo(@"Notify refresh of dirty object: %@", objectID);
        [self notifyObjectRefresh:objectID];
    }
}

- (void)notifyObjectRefresh:(NSManagedObjectID *)objectID {
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          objectID, kKeyObjectID,
                          nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDBRefreshedDirtyObject object:self userInfo:info];
}

- (void)addDirtyObject:(NSManagedObject *)object {
    if (object == nil || object.objectID == nil) {
        return;
    }

    NSMutableSet *newObjects;
    
    NSUserDefaults *defaults = [AppGroup userDefaults];
    NSArray *objects = [defaults arrayForKey:THREEMA_DB_DIRTY_OBJECT_KEY];
    if (objects) {
        newObjects = [NSMutableSet setWithArray:objects];
    } else {
        newObjects = [NSMutableSet set];
    }
    
    NSURL *url = object.objectID.URIRepresentation;
    [newObjects addObject:url.absoluteString];
    
    NSArray *newObjectsArray = [newObjects allObjects];
    [defaults setObject:newObjectsArray forKey:THREEMA_DB_DIRTY_OBJECT_KEY];
    [defaults synchronize];
    
    [AppGroup notifyAppGroupSyncNeeded];
}

- (void)mergeContentsOfPath:(NSString *)srcDir intoPath:(NSString *)dstDir error:(NSError**)err {    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *srcDirEnum = [fm enumeratorAtPath:srcDir];
    NSString *subPath;
    while ((subPath = [srcDirEnum nextObject])) {
        NSString *srcPath =  [srcDir stringByAppendingPathComponent:subPath];
        NSString *dstPath = [dstDir stringByAppendingPathComponent:subPath];
        
        [fm moveItemAtPath:srcPath toPath:dstPath error:err];
        if (err && *err) {
            NSLog(@"ERROR: %@", *err);
            return;
        }
    }
}

- (BOOL)copyOldVersionOfDatabase {
    NSURL *oldVersionUrl = [[DocumentManager applicationDocumentsDirectory] URLByAppendingPathComponent:@"ThreemaDataOldVersion"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:oldVersionUrl.path]) {
        
        // delete current DB
        NSURL *databaseUrl = [DatabaseManager storeUrl];
        [DocumentManager removeItemIfExists:databaseUrl];
        
        NSString *shmFile = [THREEMA_DB_FILE stringByAppendingString:@"-shm"];
        [DocumentManager removeItemIfExists:[[DocumentManager databaseDirectory] URLByAppendingPathComponent:shmFile]];
        
        NSString *walFile = [THREEMA_DB_FILE stringByAppendingString:@"-wal"];
        [DocumentManager removeItemIfExists:[[DocumentManager databaseDirectory] URLByAppendingPathComponent:walFile]];
        
        NSURL *externalsUrl = [[DocumentManager databaseDirectory] URLByAppendingPathComponent:THREEMA_DB_EXTERNALS];
        [DocumentManager removeItemIfExists:externalsUrl];
        
        // move older version of DB
        NSURL *sourceDatabaseUrl = [[[DocumentManager applicationDocumentsDirectory] URLByAppendingPathComponent:@"ThreemaDataOldVersion"] URLByAppendingPathComponent:THREEMA_DB_FILE];
        [DocumentManager moveItemIfExists:sourceDatabaseUrl destination:databaseUrl];
        
        NSURL *sourceExternalsUrl = [[[DocumentManager applicationDocumentsDirectory] URLByAppendingPathComponent:@"ThreemaDataOldVersion"] URLByAppendingPathComponent:THREEMA_DB_EXTERNALS];
        [DocumentManager moveItemIfExists:sourceExternalsUrl destination:externalsUrl];
        
        // delete older version files
        [fm removeItemAtURL:oldVersionUrl error:nil];
        
        NSURL *pendingMessages = [[DocumentManager documentsDirectory] URLByAppendingPathComponent:@"PendingMessages"];
        [DocumentManager removeItemIfExists:pendingMessages];
        
        return YES;
    }
    
    return NO;
}

@end

@implementation NSURL (RWIsDirectory)

- (BOOL)RWIsDirectory
{
    NSNumber * isDir;
    [self getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
    return [isDir boolValue];
}

@end

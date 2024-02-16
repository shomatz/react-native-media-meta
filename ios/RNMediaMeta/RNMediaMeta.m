#import "RNMediaMeta.h"

static NSArray *metadatas;
@implementation RNMediaMeta

- (NSArray *)metadatas
{
  if (!metadatas) {
    metadatas = @[
      @"albumName",
      @"artist",
      @"comment",
      @"copyrights",
      @"creationDate",
      @"date",
      @"encodedby",
      @"genre",
      @"language",
      @"location",
      @"lastModifiedDate",
      @"performer",
      @"publisher",
      @"title"
    ];
  }
  return metadatas;
}

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
  return dispatch_queue_create("com.mybigday.rn.MediaMetaQueue", DISPATCH_QUEUE_SERIAL);
}

RCT_EXPORT_METHOD(get:(NSString *)path
                  withOptions:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    BOOL isDir;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDir]){
        NSError *err = [NSError errorWithDomain:@"file not found" code:-15 userInfo:nil];
        reject([NSString stringWithFormat: @"%lu", (long)err.code], err.localizedDescription, err);
        return;
    }
    
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    
    if (error) {
        NSString *codeWithDomain = [NSString stringWithFormat:@"E%@%zd", error.domain.uppercaseString, error.code];
        reject(codeWithDomain, error.localizedDescription, error);
    }
    
    NSMutableDictionary *result = [NSMutableDictionary new];
    
    [result setObject:@([(NSDate *)[attributes objectForKey:NSFileCreationDate] timeIntervalSince1970]) forKey:@"ctime"];
    [result setObject:@([(NSDate *)[attributes objectForKey:NSFileModificationDate] timeIntervalSince1970]) forKey:@"mtime"];
    [result setObject:[attributes objectForKey:NSFileSize] forKey:@"size"];
    [result setObject:isDir ? @"directory" : @"file" forKey:@"type"];
    [result setObject:@([[NSString stringWithFormat:@"%ld", (long)[(NSNumber *)[attributes objectForKey:NSFilePosixPermissions] integerValue]] integerValue]) forKey:@"mode"];
    
    if (isDir) {
        resolve(result);
    } else {
        NSDictionary *assetOptions = @{AVURLAssetPreferPreciseDurationAndTimingKey: @YES};
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:assetOptions];
        
        NSArray *keys = [NSArray arrayWithObjects:@"commonMetadata", nil];
        [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
            // string keys
            for (NSString *key in [self metadatas]) {
                NSArray *items = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata
                                                                withKey:key
                                                               keySpace:AVMetadataKeySpaceCommon];
                for (AVMetadataItem *item in items) {
                    [result setObject:item.value forKey:key];
                }
            }
            
            if (options[@"getThumb"]) {
                UIImage *thumbnail;
                NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata
                                                                   withKey:AVMetadataCommonKeyArtwork
                                                                  keySpace:AVMetadataKeySpaceCommon];
                // artwork thumb
                for (AVMetadataItem *item in artworks) {
                    thumbnail = [UIImage imageWithData:item.value];
                }
                if (thumbnail) {
                    [result setObject:@(thumbnail.size.width) forKey:@"width"];
                    [result setObject:@(thumbnail.size.height) forKey:@"height"];
                    NSString *filePath = [NSTemporaryDirectory() stringByAppendingString:[[NSUUID UUID] UUIDString]];
                    filePath = [filePath stringByAppendingString:@".png"];
                    [UIImagePNGRepresentation(thumbnail) writeToFile:filePath atomically:true];
                    [result setObject:filePath forKey:@"thumb"];
                }
                
                // video frame thumb
                AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:asset];
                imageGenerator.appliesPreferredTrackTransform = YES;
                CMTime duration = [asset duration];
                CMTime time = CMTimeMake(duration.value / 2, duration.timescale);
                
                CGImageRef imageRef = [imageGenerator copyCGImageAtTime:time actualTime:NULL error:NULL];
                thumbnail = [UIImage imageWithCGImage:imageRef];
                if (thumbnail) {
                    [result setObject:@(thumbnail.size.width) forKey:@"width"];
                    [result setObject:@(thumbnail.size.height) forKey:@"height"];
                    [result setObject:@((CMTimeGetSeconds(asset.duration) * 1000)) forKey:@"duration"];
                    NSString *filePath = [NSTemporaryDirectory() stringByAppendingString:[[NSUUID UUID] UUIDString]];
                    filePath = [filePath stringByAppendingString:@".png"];
                    [UIImagePNGRepresentation(thumbnail) writeToFile:filePath atomically:true];
                    [result setObject:filePath forKey:@"thumb"];
                }
                CGImageRelease(imageRef);
            }
            
            resolve(result);
        }];
    }
}

@end

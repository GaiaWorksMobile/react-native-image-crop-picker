//
//  Compression.m
//  imageCropPicker
//
//  Created by Ivan Pusic on 12/24/16.
//  Copyright © 2016 Ivan Pusic. All rights reserved.
//

#import "Compression.h"

@implementation Compression

- (instancetype)init {
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                 @"640x480": AVAssetExportPreset640x480,
                                                                                 @"960x540": AVAssetExportPreset960x540,
                                                                                 @"1280x720": AVAssetExportPreset1280x720,
                                                                                 @"1920x1080": AVAssetExportPreset1920x1080,
                                                                                 @"LowQuality": AVAssetExportPresetLowQuality,
                                                                                 @"MediumQuality": AVAssetExportPresetMediumQuality,
                                                                                 @"HighestQuality": AVAssetExportPresetHighestQuality,
                                                                                 }];
    NSOperatingSystemVersion systemVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (systemVersion.majorVersion >= 9) {
        [dic addEntriesFromDictionary:@{@"3840x2160": AVAssetExportPreset3840x2160}];
    }
    self.exportPresets = dic;
    
    return self;
}

- (ImageResult*) compressImageDimensions:(UIImage*)image
                             withOptions:(NSDictionary*)options {
    
    NSNumber *maxWidth = [options valueForKey:@"compressImageMaxWidth"];
    NSNumber *maxHeight = [options valueForKey:@"compressImageMaxHeight"];
    ImageResult *result = [[ImageResult alloc] init];
    
//    if ([maxWidth integerValue] == 0 || [maxWidth integerValue] == 0) {
//        result.width = [NSNumber numberWithFloat:image.size.width];
//        result.height = [NSNumber numberWithFloat:image.size.height];
//        result.image = image;
//        return result;
//    }
    
    CGFloat oldWidth = image.size.width;
    CGFloat oldHeight = image.size.height;
    
    CGFloat scaleFactor = (oldWidth > oldHeight) ? [maxWidth floatValue] / oldWidth : [maxHeight floatValue] / oldHeight;
    
    int newWidth = oldWidth * scaleFactor;
    int newHeight = oldHeight * scaleFactor;
    
//    CGSize newSize = CGSizeMake(newWidth, newHeight);
    
//    UIGraphicsBeginImageContext(newSize);
//    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
//    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
    
    result.width = [NSNumber numberWithFloat:newWidth];
    result.height = [NSNumber numberWithFloat:newHeight];
//    result.image = resizedImage;
    
    
//    //获取压缩图片大小值， KB
//    NSUInteger attachmentCompressSize = [[options valueForKey:@"attachSize"] integerValue];
//    NSUInteger imageSize = attachmentCompressSize * 1024;
//
//    NSLog(@"attachmentCompressSize **-->%lu", (unsigned long)attachmentCompressSize);
//
//    // 压缩图片
//    result.image = [UIImage imageWithData:[self compressWithMaxLength:imageSize withImage:image]];
    
    
    return result;
}



//压缩图片
-(NSData *)compressWithMaxLength:(NSUInteger)maxLength withImage:(UIImage*)image{
    
    //压缩质量，减小大小 Compress by quality
    CGFloat compression = 1;
    NSData *data = UIImageJPEGRepresentation(image, compression);
    //NSLog(@"Before compressing quality, image size = %ld KB",data.length/1024);
    if (data.length < maxLength) return data;
    
    CGFloat max = 1;
    CGFloat min = 0;
    for (int i = 0; i < 6; ++i) {
        compression = (max + min) / 2;
        data = UIImageJPEGRepresentation(image, compression);
        NSLog(@"Compression = %.1f", compression);
        NSLog(@"In compressing quality loop, image size = %ld KB", data.length / 1024);
        if (data.length < maxLength * 0.9) {
            min = compression;
        } else if (data.length > maxLength) {
            max = compression;
        } else {
            break;
        }
    }
    //NSLog(@"After compressing quality, image size = %ld KB", data.length / 1024);
    if (data.length < maxLength) return data;
    
    UIImage *resultImage = [UIImage imageWithData:data];
    //压缩尺寸，减小大小 Compress by size
    NSUInteger lastDataLength = 0;
    while (data.length > maxLength && data.length != lastDataLength) {
        lastDataLength = data.length;
        CGFloat ratio = (CGFloat)maxLength / data.length;
        //NSLog(@"Ratio = %.1f", ratio);
        CGSize size = CGSizeMake((NSUInteger)(resultImage.size.width * sqrtf(ratio)),
                                 (NSUInteger)(resultImage.size.height * sqrtf(ratio))); // Use NSUInteger to prevent white blank
        UIGraphicsBeginImageContext(size);
        [resultImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
        resultImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        data = UIImageJPEGRepresentation(resultImage, compression);
        //NSLog(@"In compressing size loop, image size = %ld KB", data.length / 1024);
    }
    NSLog(@"After compressing size loop, image size = %ld KB", data.length / 1024);
    
    return data;
}


- (ImageResult*) compressImage:(UIImage*)image
                   withOptions:(NSDictionary*)options {
    ImageResult *result = [self compressImageDimensions:image withOptions:options];
    
//    NSNumber *compressQuality = [options valueForKey:@"compressImageQuality"];
//    if (compressQuality == nil) {
//        compressQuality = [NSNumber numberWithFloat:1];
//    }
//    result.data = UIImageJPEGRepresentation(result.image, [compressQuality floatValue]);
    
    //获取压缩图片大小值， KB
    NSUInteger attachmentCompressSize = [[options valueForKey:@"attachSize"] integerValue];
    NSUInteger imageSize = attachmentCompressSize * 1024;
    
    NSLog(@"attachmentCompressSize **-->%lu", (unsigned long)attachmentCompressSize);
    
    //压缩图片
    NSData *tempData = [self compressWithMaxLength:imageSize withImage:image];
    result.data = tempData;
    result.image = [UIImage imageWithData:tempData];
    result.mime = @"image/jpeg";
    
    NSLog(@"最后的压缩 -->%lu KB",(result.data.length)/1024);
    
    //由于base转字符串之后，会再一次改变图片大小，这边再做一下处理
    NSUInteger base64StrLength = [[tempData base64EncodedStringWithOptions:0] length];
    if(base64StrLength > imageSize){
        CGFloat compression = 1;
        NSData *data = UIImageJPEGRepresentation(result.image, compression);
      
        CGFloat max = 1;
        CGFloat min = 0;
        for (int i = 0; i < 10; ++i) {
            compression = (max + min) / 2;
            data = UIImageJPEGRepresentation(result.image, compression);
            if (data.length < imageSize * 0.9) {
                min = compression;
            } else if (data.length > imageSize) {
                max = compression;
            }
            if([[data base64EncodedStringWithOptions:0] length] <= imageSize){
                break;
            }
        }
        
        UIImage *resultImage = [UIImage imageWithData:data];
        //压缩尺寸，减小大小 Compress by size
        NSUInteger lastDataLength = 0;
        while (([[data base64EncodedStringWithOptions:0] length] > imageSize) && data.length != lastDataLength) {
            lastDataLength = data.length;
            CGFloat ratio = (CGFloat)imageSize/([[data base64EncodedStringWithOptions:0] length]);
            CGSize size = CGSizeMake((NSUInteger)(resultImage.size.width * sqrtf(ratio)),
                                     (NSUInteger)(resultImage.size.height * sqrtf(ratio))); // Use NSUInteger to prevent white blank
            UIGraphicsBeginImageContext(size);
            [resultImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
            resultImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
    
            data = UIImageJPEGRepresentation(resultImage, compression);
        }
        result.data = data;
    }
    
    
    return result;
}

- (void)compressVideo:(NSURL*)inputURL
            outputURL:(NSURL*)outputURL
          withOptions:(NSDictionary*)options
              handler:(void (^)(AVAssetExportSession*))handler {
    
    NSString *presetKey = [options valueForKey:@"compressVideoPreset"];
    if (presetKey == nil) {
        presetKey = @"MediumQuality";
    }
    
    NSString *preset = [self.exportPresets valueForKey:presetKey];
    if (preset == nil) {
        preset = AVAssetExportPresetMediumQuality;
    }
    
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:nil];
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
        handler(exportSession);
    }];
}

@end

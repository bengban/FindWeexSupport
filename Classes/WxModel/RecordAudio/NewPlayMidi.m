//
//  NewPlayMidi.m
//  WeexDemo
//
//  Created by 徐林琳 on 2018/7/24.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import "NewPlayMidi.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreAudio/CoreAudioTypes.h>
#include <CoreMIDI/CoreMIDI.h>
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h> //for AUGraph
//#include "McDownload.h"
#define COM_LOCAL(key) NSLocalizedStringFromTable(key, @"common_language", nil)
//MyMusicSequence
@interface MyMusicSequence : NSObject
{
    MusicSequence _sequence;
}
-(MusicSequence)getSequence;
-(void)setSequence:(MusicSequence)sequence;
@end
@implementation MyMusicSequence
-(MusicSequence)getSequence
{
    return _sequence;
}
-(void)setSequence:(MusicSequence)sequence
{
    _sequence=sequence;
}
@end

//MyMIDINoteMessage
@interface MyMIDINoteMessage : NSObject
{
    MIDINoteMessage note_message;
}
- (id)initWithNoteMessage:(MIDINoteMessage*)msg;
- (MIDINoteMessage*)getNoteMessage;
@end

@implementation MyMIDINoteMessage
- (id)initWithNoteMessage:(MIDINoteMessage*)msg
{
    self = [super init];
    if (self) {
        note_message=*msg;
    }
    return self;
}
- (MIDINoteMessage*)getNoteMessage
{
    return &note_message;
}
@end

@interface MyMidiEndPoint : NSObject
@property (nonatomic, assign) MIDIEndpointRef endpointRef;
@property (nonatomic, assign) MIDIPortRef inPort;
@end
@implementation MyMidiEndPoint
+ (MyMidiEndPoint*)myEndPoint:(MIDIEndpointRef)endpointRef
{
    MyMidiEndPoint *end=[[MyMidiEndPoint alloc]init];
    end.endpointRef=endpointRef;
    return end;
}
@end


//NewPlayMidi
@interface NewPlayMidi()
{
    AUGraph _processingGraph;
    
    //for midi instruments
#define MAX_Channel 32
#define Drums_Channel 9
#define Pinao_Channel 100
    int samplerForChannel[MAX_Channel];
#define MAX_SamplerUnit (8)
    int SamplerPrograms[MAX_SamplerUnit];
    int samplerUnite_count;
    AudioUnit _samplerUnit,_mixerUnit,_ioUnit;
    AudioUnit _samplerUnit_Programs[MAX_SamplerUnit];
    //AudioUnit _samplerUnit_Piano,_samplerUnit_Violin,_samplerUnit_Flute,_samplerUnit_Clarinet,_samplerUnit_Trumpet;
    UInt8 midiChannelInUse;
    
    //play midi progress
    Float64 midi_total_seconds;
    MusicTimeStamp midi_total_beats;
    id progress_target;
    SEL progress_action;
    NSTimer *timer;
    //    float curTime;
    //    int playStatus;
    
    //for midi I/O device
    MIDIClientRef    virtualMidiClient;
    MIDIPortRef      gOutPort, gInPort;
    MIDIEndpointRef  gUsbDest, gMidiSrc;
}
@property (nonatomic, assign) float soundFontDownloadProgress;
@property (nonatomic, strong) NSString* soundInDocumentDir;
//@property (nonatomic, readonly, nullable) AudioUnit instrumentUnit;
//for midi I/O device: key: port name, value:MyMidiEndPoint
@property (strong) NSMutableDictionary *midiDests, *midiSources;
@property (nonatomic, strong) NSString *MIDIPORT_Prefix;
enum{
    MS_STOP_REQ,
    MS_STOPPED,
    MS_PLAYING,
    MS_PAUSED
};

-(void)midiDeviceOpen;
-(void)midiDeviceClose;

@end

@implementation NewPlayMidi
-(AudioUnit)currentSampleUnit {
    return _samplerUnit;
}
- (id)init
{
    self = [super init];
    if (self) {
        self.playStatus=MS_STOPPED;
        midi_total_seconds=0;
        //s=NULL;
        _processingGraph=NULL;
        _samplerUnit=NULL;
        midiChannelInUse=0;//we're using midi channel 1...
        self.MIDIPORT_NewPrefix=@"FIND MIDI DAC";
        self.MIDIPORT_Prefix=@"FIND MIDI DAC"; //@"AVCON MIDI DC";
        self.MIDIPORT_Normal=@"";//[self.MIDIPORT_Prefix stringByAppendingString:@"端口 1"];
        self.MIDIPORT_Autoplay=@"";//[self.MIDIPORT_Prefix stringByAppendingString:@"端口 2"];
        self.MIDIPORT_Test=@"";//[self.MIDIPORT_Prefix stringByAppendingString:@"端口 3"];
    }
    return self;
}

#pragma mark - play midi to out device
/*
 //for midi I/O device
 static MIDIClientRef    virtualMidiClient=0;
 static MIDIPortRef      gOutPort = 0, gInPort = 0;
 static MIDIEndpointRef  gUsbDest=0, gMidiSrc=0;
 */
- (void) getMidiDeviceInfo
{
    // How many MIDI devices do we have?
    ItemCount deviceCount = MIDIGetNumberOfDevices();
    
    // Iterate through all MIDI devices
    for (ItemCount i = 0 ; i < deviceCount ; ++i) {
        
        // Grab a reference to current device
        MIDIDeviceRef device = MIDIGetDevice(i);
        NSLog(@"Device: %@", [self getName:device]);
        
        // Is this device online? (Currently connected?)
        SInt32 isOffline = 0;
        MIDIObjectGetIntegerProperty(device, kMIDIPropertyOffline, &isOffline);
        NSLog(@"Device is online: %s", (isOffline ? "No" : "Yes"));
        
        // How many entities do we have?
        ItemCount entityCount = MIDIDeviceGetNumberOfEntities(device);
        
        // Iterate through this device's entities
        for (ItemCount j = 0 ; j < entityCount ; ++j) {
            
            // Grab a reference to an entity
            MIDIEntityRef entity = MIDIDeviceGetEntity(device, j);
            NSLog(@"  Entity: %@", [self getName:(entity)]);
            
            // Iterate through this device's source endpoints (MIDI In)
            ItemCount sourceCount = MIDIEntityGetNumberOfSources(entity);
            for (ItemCount k = 0 ; k < sourceCount ; ++k) {
                
                // Grab a reference to a source endpoint
                MIDIEndpointRef source = MIDIEntityGetSource(entity, k);
                NSLog(@"    Source: %@", [self getName:(source)]);
            }
            
            // Iterate through this device's destination endpoints
            ItemCount destCount = MIDIEntityGetNumberOfDestinations(entity);
            for (ItemCount k = 0 ; k < destCount ; ++k) {
                
                // Grab a reference to a destination endpoint
                MIDIEndpointRef dest = MIDIEntityGetDestination(entity, k);
                NSLog(@"    Destination: %@", [self getName:(dest)]);
            }
        }
        NSLog(@"------");
    }
}

- (NSString*) getName:(MIDIObjectRef) object
{
    // Returns the name of a given MIDIObjectRef as an NSString
    CFStringRef name = nil;
    if (noErr != MIDIObjectGetStringProperty(object, kMIDIPropertyName, &name))
        return nil;
    NSString *ret=CFBridgingRelease(name);
    //CFRelease(name);
    return ret;
}

-(void)setCurTime:(float)curTime {
    _curTime = curTime;
    double t = curTime;
    dispatch_async(dispatch_get_main_queue(), ^{
        __weak __typeof(self)weakSelf = self;
        weakSelf.curtimeBlock(t);
    });
}

- (void)setPlayStatus:(int)playStatus
{
    _playStatus = playStatus;
    NSString *statusStr = @"readyToPlay";
    switch (_playStatus) {
        case MS_PLAYING:
            statusStr = @"playing";
            break;
        case MS_STOPPED:
            statusStr = @"finish";
            break;
        case MS_PAUSED:
            statusStr = @"pause";
            break;
        case MS_STOP_REQ:
            statusStr = @"MS_STOP_REQ";
            break;
        default:
            break;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        __weak __typeof(self)weakSelf = self;
        weakSelf.statusBlock(statusStr);
    });
    
}

- (void)setCurInputDevice:(NSString *)curInputDevice
{
    if (gMidiSrc) {
        MIDIPortDisconnectSource(gInPort, gMidiSrc);
        gMidiSrc=0;
    }
    MyMidiEndPoint *source=[self.midiSources objectForKey:curInputDevice];
    if (source) {
        gMidiSrc=source.endpointRef;
        //        MIDIPortConnectSource(gInPort, gMidiSrc, NULL);
        MIDIPortConnectSource(gInPort, gMidiSrc, (__bridge void *)(curInputDevice));
    }
    _curInputDevice=curInputDevice;
}

- (void)listenAllInputDevice {
    for (NSString *device in self.midiInputDevices) {
        MyMidiEndPoint *p=self.midiSources[device];
        if (p && p.inPort==0) {
            MIDIPortRef inPort;
            MIDIInputPortCreate(virtualMidiClient, CFSTR("Input port"), myMIDIReadProc, (__bridge void *)(self), &inPort);
            p.inPort=inPort;
            MIDIPortConnectSource(p.inPort, p.endpointRef, (__bridge void *)(device));
        }
    }
}

#define kSettingMidiOutputDevice @"kSettingMidiOutputDevice"
- (void)setCurOutputDevice:(NSString *)curOutputDevice
{
    if (self.MIDIPORT_stick) {//  && [curOutputDevice isEqualToString:self.MIDIPORT_stick]
        self.isMidiStick=YES;
    }else{
        self.isMidiStick=NO;
    }
    
    if ([_curOutputDevice isEqualToString:curOutputDevice]) {
        return;
    }
    if (_curOutputDevice) {
        unsigned char data[]={kMidiMessage_ControlChange, GM_Control_ResetAllControl, 0, kMidiMessage_ControlChange, GM_Control_AllNotesOff, 0};
        [self sendUsbPort:_curOutputDevice event:data length:sizeof(data)/sizeof(data[0])];
    }
    
    [self stopAllNotes:gUsbDest==0];
    
    MyMidiEndPoint *dest=[self.midiDests objectForKey:curOutputDevice];
    if (dest) {
        gUsbDest=dest.endpointRef;
    }else{
        gUsbDest=0;
    }
    _curOutputDevice=curOutputDevice;
    [[NSUserDefaults standardUserDefaults] setObject:curOutputDevice forKey:kSettingMidiOutputDevice];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
}
- (void) getMidiDestSrc
{
    self.MIDIPORT_stick=nil;
    NSLog(@"Iterate through destinations");
    _curOutputDevice = [[NSUserDefaults standardUserDefaults] objectForKey:kSettingMidiOutputDevice];
    
    ItemCount destCount = MIDIGetNumberOfDestinations();
    if (destCount>0) {
        self.midiDests=[[NSMutableDictionary alloc]initWithCapacity:destCount];
        for (ItemCount i = 0 ; i < destCount ; ++i) {
            // Grab a reference to a destination endpoint
            MIDIEndpointRef dest = MIDIGetDestination(i);
            //NSLog(@"  Destination: 0x%x", dest);
            NSString *destDisplayName=[self getDisplayName:(dest)];
            if (dest != 0 && destDisplayName.length>0) {
                NSLog(@"  Destination: %@", destDisplayName);
                [self.midiDests setObject:[MyMidiEndPoint myEndPoint:dest] forKey:destDisplayName];
            }
            //if ([destDisplayName hasPrefix:@"USB MIDI Interface"])
            {
                if (destDisplayName) {
                    if ([destDisplayName containsString:@"端口"]) {
                        if ([destDisplayName hasPrefix:self.MIDIPORT_NewPrefix]) {
                            self.MIDIPORT_Prefix = self.MIDIPORT_NewPrefix;
                        }
                        if ([destDisplayName hasSuffix:@"1"]) {
                            self.MIDIPORT_Normal=destDisplayName;
                        }else if ([destDisplayName hasSuffix:@"2"]) {
                            self.MIDIPORT_Autoplay=destDisplayName;
                        }else if ([destDisplayName hasSuffix:@"3"]) {
                            self.MIDIPORT_Test=destDisplayName;
                        }
                        //                    }else if ([destDisplayName hasPrefix:@"EPIANO(LE)-"] || [destDisplayName hasPrefix:@"EPIANO-BTMIDI(LE)-"]) {
                    }else{
                        //                        NSRange range = [destDisplayName rangeOfString:@"BTMIDI"];
                        if ([destDisplayName length]>0) {
                            self.MIDIPORT_stick=destDisplayName;
                            if (_curOutputDevice && [_curOutputDevice isEqualToString:self.MIDIPORT_stick]) {
                                self.curOutputDevice=destDisplayName;
                            }
                        }
                    }
                }
                //gUsbDest=dest;
                if (i==0 && destDisplayName && _curOutputDevice==nil) {
                    self.curOutputDevice=destDisplayName;
                    //                    gUsbDest=dest;
                }
            }
        }
        self.midiOutputDevices=self.midiDests.allKeys;
    }
    if ([self.midiDests.allKeys indexOfObject:_curOutputDevice]>=self.midiDests.count) {
        _curOutputDevice=nil;
    }else if(self.midiDests.count>0){
        if (_curOutputDevice) {
            MyMidiEndPoint *end=self.midiDests[_curOutputDevice];
            gUsbDest=end.endpointRef;
        }
    }
    
    NSLog(@"Iterate through sources");
    self.midiInputDevices=nil;
    // Virtual sources and destinations don't have entities
    ItemCount sourceCount = MIDIGetNumberOfSources();
    if (sourceCount>0) {
        self.midiSources=[[NSMutableDictionary alloc]initWithCapacity:sourceCount];
        for (ItemCount i = 0 ; i < sourceCount ; ++i) {
            
            MIDIEndpointRef source = MIDIGetSource(i);
            //NSLog(@"  source: 0x%x", source);
            NSString *srcDisplayName=[self getDisplayName:(source)];
            if (source != 0 && srcDisplayName.length>0) {
                NSLog(@"  Source: %@", srcDisplayName);
                [self.midiSources setObject:[MyMidiEndPoint myEndPoint:source] forKey:srcDisplayName];
                //self.curInputDevice=srcDisplayName;
                _curInputDevice=srcDisplayName;
            }
            //if ([srcDisplayName hasPrefix:@"USB MIDI Interface"])
            {
                gMidiSrc=source;
            }
        }
        self.midiInputDevices=self.midiSources.allKeys;
    }
}

- (NSString*) getDisplayName:(MIDIObjectRef) object
{
    // Returns the display name of a given MIDIObjectRef as an NSString
    CFStringRef name = nil;
    if (noErr != MIDIObjectGetStringProperty(object, kMIDIPropertyDisplayName, &name))
        return nil;
    NSString *ret=(__bridge NSString *)name;
    NSRange range=[ret rangeOfString:@"Session"];
    if (range.length>0) {
        return nil;
    }
    return ret;
}
// some MIDI constants:
/*
 General MIDI，简称GM，是MIDI的统一规格.
 允许同时24个发声数(包含16个旋律，和8个打击乐的声音)
 能对应音符力度
 能同时使用16个频道(频道10被预留为打击乐用)
 每个频道能够演奏复音
 
 General MIDI Level 2，简称GM2，是MIDI的标准规格。它的基础是General MIDI以及GS extensions。
 同时发声数：32
 MIDI频道：16
 同时演奏旋律乐器达16个(所有频道)
 同时演奏打击乐器组达2组(频道10/11)
 
 */
/*
 case 0xa0: //触摸键盘以后  音符:00~7F 力度:00~7F
 */
/*
 kMIDIMessage_NoteOff            = 0x80,//8n: 关闭n通道发音; xx: 音符00~7F; vv:力度00~7F
 kMIDIMessage_NoteOn             = 0x90,//9n: 打开n通道发音; xx: 音符00~7F; vv:力度00~7F
 
 除了Channel 10外按照音色(programer)编号来播放音符。
 
 打击乐音符(Percussion notes)
 在General MIDI中，频道10被保留作为打击乐器使用，不论音色编号为何。 不同的音符对应到不同的打击乐器。见下表：
 No.    English    中文
 35    Bass Drum 2    大鼓 2
 36    Bass Drum 1    大鼓 1
 37    Side Stick    小鼓鼓边
 38    Snare Drum 1    小鼓 1
 39    Hand Clap    拍手
 40    Snare Drum 2    小鼓 2
 41    Low Tom 2    低音筒鼓 2
 42    Closed Hi-hat    闭合开合钹
 43    Low Tom 1    低音筒鼓 1
 44    Pedal Hi-hat    脚踏开合钹
 45    Mid Tom 2    中音筒鼓 2
 46    Open Hi-hat    开放开合钹
 47    Mid Tom 1    中音筒鼓 1
 48    High Tom 2    高音筒鼓 2
 49    Crash Cymbal 1    强音钹 1
 50    High Tom 1    高音筒鼓 1
 51    Ride Cymbal 1    打点钹 1
 52    Chinese Cymbal    钹
 53    Ride Bell    响铃
 54    Tambourine    铃鼓
 55    Splash Cymbal    小钹铜钹
 56    Cowbell    牛铃
 57    Crash Cymbal 2    强音钹 2
 58    Vibra Slap    噪音器
 59    Ride Cymbal 2    打点钹 2
 60    High Bongo    高音 邦加鼓
 61    Low Bongo    低音 邦加鼓
 62    Mute High Conga    闷音高音 康加鼓
 63    Open High Conga    开放高音 康加鼓
 64    Low Conga    低音 康加鼓
 65    High Timbale    高音 天巴雷鼓
 66    Low Timbale    低音 天巴雷鼓
 67    High Agogo    高音 阿哥哥
 68    Low Agogo    低音 阿哥哥
 69    Cabasa    铁沙铃
 70    Maracas    沙槌
 71    Short Whistle    短口哨
 72    Long Whistle    长口哨
 73    Short Guiro    短刮瓜
 74    Long Guiro    长刮瓜
 75    Claves    击木
 76    High Wood Block    高音木鱼
 77    Low Wood Block    低音木鱼
 78    Mute Cuica
 79    Open Cuica
 80    Mute Triangle    闷音三角铁
 81    Open Triangle    开放三角铁
 */

/*
 ControlChange 0xb0: //控制器  控制器号码:00~7F 控制器参数:00~7F
 控制器事件(Controller events)
 GM也同时规范了数个控制器的工作 [1][2]
 No.    功能
 1    Modulation wheel(颤音)
 6    Data Entry MSB
 7    Volume(音量)
 10    Pan(相位)
 11    Expression(表情踏板)
 38    Data Entry LSB
 64    Sustain pedal(延音踏板)
 100    RPN LSB (参考后面RPN)
 101    RPN MSB (参考后面RPN)
 121    Reset all controllers(重设所有控制器)
 123    All notes off(消音)
 
 
 RPN(Registered Parameter Number)
 MSB    LSB    意义
 0    0    Pitch bend range(滑音范围)
 0    1    Channel Fine tuning(频道细调)
 0    2    Channel Coarse tuning(频道粗调)
 0    3    Tuning Program Change(转换调节音色)
 0    4    Tuning Bank Select(转换调节群组)
 0    5    Modulation Depth Range(颤音深度范围)
 */

/*
 ProgramChange 0xc0: //切换音色： 乐器号码:00~7F
 General MIDI，简称GM
 Piano(钢 琴)
 1    Acoustic Grand Piano    平台钢琴
 2    Bright Acoustic Piano    亮音钢琴
 3    Electric Grand Piano    电钢琴
 4    Honky-tonk Piano    酒吧钢琴
 5    Electric Piano 1    电钢琴 1
 6    Electric Piano 2    电钢琴 2
 7    Harpsichord    大键琴
 8    Clavinet    电翼琴
 Chromatic Percussion(半音阶打击乐器)
 9    Celesta    钢片琴
 10    Glockenspiel    钟琴 港译:铁片琴
 11    Musical box    音乐盒
 12    Vibraphone    颤音琴
 13    Marimba    马林巴琴
 14    Xylophone    木琴
 15    Tubular Bell    管钟
 16    Dulcimer    洋琴
 Organ(风 琴)
 17    Drawbar Organ    音栓风琴
 18    Percussive Organ    敲击风琴
 19    Rock Organ    摇滚风琴
 20    Church organ    教堂管风琴
 21    Reed organ    簧风琴
 22    Accordion    手风琴
 23    Harmonica    口琴
 24    Tango Accordion    探戈手风琴
 Guitar(吉 他)
 25    Acoustic Guitar(nylon)    木吉他(尼龙弦)
 26    Acoustic Guitar(steel)    木吉他(钢弦)
 27    Electric Guitar(jazz)    电吉他(爵士)
 28    Electric Guitar(clean)    电吉他(原音)
 29    Electric Guitar(muted)    电吉他(闷音)
 30    Overdriven Guitar    电吉他(破音)
 31    Distortion Guitar    电吉他(失真)
 32    Guitar harmonics    吉他泛音
 Bass(贝 斯)
 33    Acoustic Bass    民谣贝斯
 34    Electric Bass(finger)    电贝斯(指奏)
 35    Electric Bass(pick)    电贝斯(拨奏)
 36    Fretless Bass    无格贝斯
 37    Slap Bass 1    捶鈎贝斯 1
 38    Slap Bass 2    捶鈎贝斯 2
 39    Synth Bass 1    合成贝斯 1
 40    Synth Bass 2    合成贝斯 2
 Strings(弦 乐 器)
 41    Violin    小提琴
 42    Viola    中提琴
 43    Cello    大提琴
 44    Contrabass    低音大提琴
 45    Tremolo Strings    颤弓弦乐
 46    Pizzicato Strings    弹拨弦乐
 47    Orchestral Harp    竖琴
 48    Timpani    定音鼓
 Ensemble(合 奏)
 49    String Ensemble 1    弦乐合奏 1
 50    String Ensemble 2    弦乐合奏 2
 51    Synth Strings 1    合成弦乐 1
 52    Synth Strings 2    合成弦乐 2
 53    Voice Aahs    人声“啊”
 54    Voice Oohs    人声“喔”
 55    Synth Voice    合成人声
 56    Orchestra Hit    交响打击乐
 Brass(铜 管 乐 器)
 57    Trumpet    小号
 58    Trombone    长号
 59    Tuba    大号(吐巴号、低音号)
 60    Muted Trumpet    闷音小号
 61    French horn    法国号(圆号)
 62    Brass Section    铜管乐
 63    Synth Brass 1    合成铜管 1
 64    Synth Brass 2    合成铜管 2
 Reed(簧 乐 器)
 65    Soprano Sax    高音萨克斯风
 66    Alto Sax    中音萨克斯风
 67    Tenor Sax    次中音萨克斯风
 68    Baritone Sax    上低音萨克斯风
 69    Oboe    双簧管
 70    English Horn    英国管
 71    Bassoon    低音管(巴颂管)
 72    Clarinet    单簧管(黑管、竖笛)
 Pipe(吹 管 乐 器)
 73    Piccolo    短笛
 74    Flute    长笛
 75    Recorder    直笛
 76    Pan Flute    排笛
 77    Blown Bottle    瓶笛
 78    Shakuhachi    尺八
 79    Whistle    哨子
 80    Ocarina    陶笛
 Synth Lead(合成音 主旋律)
 81    Lead 1(square)    方波
 82    Lead 2(sawtooth)    锯齿波
 83    Lead 3(calliope)    汽笛风琴
 84    Lead 4(chiff)    合成吹管
 85    Lead 5(charang)    合成电吉他
 86    Lead 6(voice)    人声键盘
 87    Lead 7(fifths)    五度音
 88    Lead 8(bass + lead)    贝斯吉他合奏
 Synth Pad(合成音 和弦衬底)
 89    Pad 1(new age)    新世纪
 90    Pad 2(warm)    温暖
 91    Pad 3(polysynth)    多重合音
 92    Pad 4(choir)    人声合唱
 93    Pad 5(bowed)    玻璃
 94    Pad 6(metallic)    金属
 95    Pad 7(halo)    光华
 96    Pad 8(sweep)    扫掠
 Synth Effects(合成音 效果)
 97    FX 1(rain)    雨
 98    FX 2(soundtrack)    电影音效
 99    FX 3(crystal)    水晶
 100    FX 4(atmosphere)    气氛
 101    FX 5(brightness)    明亮
 102    FX 6(goblins)    魅影
 103    FX 7(echoes)    回音
 104    FX 8(sci-fi)    科幻
 Ethnic(民 族 乐 器)
 105    Sitar    西塔琴
 106    Banjo    五弦琴(斑鸠琴)
 107    Shamisen    三味线
 108    Koto    十三弦琴(古筝)
 109    Kalimba    卡林巴铁片琴
 110    Bagpipe    苏格兰风笛
 111    Fiddle    古提琴
 112    Shanai    (弄蛇人)兽笛 ;发声机制类似唢呐
 Percussive(打 击 乐 器)
 113    Tinkle Bell    叮当铃
 114    Agogo    阿哥哥鼓
 115    Steel Drums    钢鼓
 116    Woodblock    木鱼
 117    Taiko Drum    太鼓
 118    Melodic Tom    定音筒鼓
 119    Synth Drum    合成鼓
 120    Reverse Cymbal    逆转钹声
 Sound effects(特 殊 音 效)
 121    Guitar Fret Noise    吉他滑弦杂音
 122    Breath Noise    呼吸杂音
 123    Seashore    海岸
 124    Bird Tweet    鸟鸣
 125    Telephone Ring    电话铃声
 126    Helicopter    直升机
 127    Applause    拍手
 128    Gunshot    枪声
 
 case 0xd0: //通道演奏压力(可近似认为是音量) 值:00~7F
 case 0xe0: //滑音 音高(Pitch)低位:Pitch mod 128  音高高位:Pitch div 128
 */



+(int)patchForInstrumentName:(NSString*)name{
    static NSDictionary *instrumentPatch=nil;
    if (instrumentPatch==nil) {
        instrumentPatch=@{// Piano(钢 琴)
                          @"":@(1),
                          @"Grand Piano":@(1),
                          @"Acoustic Grand Piano":@(1), //平台钢琴
                          @"Bright Acoustic Piano":@(2), //亮音钢琴
                          @"Electric Grand Piano":@(3), //电钢琴
                          @"Honky-tonk Piano":@(4), //酒吧钢琴
                          @"Electric Piano 1":@(5), //电钢琴 1
                          @"Electric Piano 2":@(6), //电钢琴 2
                          @"Harpsichord":@(7), //大键琴
                          @"Clavinet":@(8), //电翼琴
                          //Chromatic Percussion(半音阶打击乐器)
                          @"Celesta":@(9), //钢片琴
                          @"Glockenspiel":@(10), //钟琴 港译:铁片琴
                          @"Musical box":@(11), //音乐盒
                          @"Vibraphone":@(12), //颤音琴
                          @"Marimba":@(13), //马林巴琴
                          @"Xylophone":@(14), //木琴
                          @"Tubular Bell":@(15), //管钟
                          @"Dulcimer":@(16), //洋琴
                          //Organ(风 琴)
                          @"Drawbar Organ":@(17), //音栓风琴
                          @"Percussive Organ":@(18), //敲击风琴
                          @"Rock Organ":@(19), //摇滚风琴
                          @"Church organ":@(20), //教堂管风琴
                          @"Reed organ":@(21), //簧风琴
                          @"Accordion":@(22), //手风琴
                          @"Harmonica":@(23), //口琴
                          @"Tango Accordion":@(24), //探戈手风琴
                          //Guitar(吉 他)
                          @"Guitar":@(25),
                          @"Acoustic Guitar(nylon)":@(25), //木吉他(尼龙弦)
                          @"Acoustic Guitar(steel)":@(26), //木吉他(钢弦)
                          @"Electric Guitar(jazz)":@(27), //电吉他(爵士)
                          @"Electric Guitar(clean)":@(28), //电吉他(原音)
                          @"Electric Guitar(muted)":@(29), //电吉他(闷音)
                          @"Overdriven Guitar":@(30), //电吉他(破音)
                          @"Distortion Guitar":@(31), //电吉他(失真)
                          @"Guitar harmonics":@(32), //吉他泛音
                          //Bass(贝 斯)
                          @"Bass":@(33),
                          @"Acoustic Bass":@(33), //民谣贝斯
                          @"Electric Bass(finger)":@(34), //电贝斯(指奏)
                          @"Electric Bass(pick)":@(35), //电贝斯(拨奏)
                          @"Fretless Bass":@(36), //无格贝斯
                          @"Slap Bass 1":@(37), //捶鈎贝斯 1
                          @"Slap Bass 2":@(38), //捶鈎贝斯 2
                          @"Synth Bass 1":@(39), //合成贝斯 1
                          @"Synth Bass 2":@(40), //合成贝斯 2
                          //Strings(弦 乐 器)
                          @"Violin II":@(41),
                          @"Violin":@(41), //小提琴
                          @"Viola":@(42), //中提琴
                          @"Cello":@(43), //大提琴
                          @"Contrabass":@(44), //低音大提琴
                          @"Tremolo Strings":@(45), //颤弓弦乐
                          @"Pizzicato Strings":@(46), //弹拨弦乐
                          @"Orchestral Harp":@(47), //竖琴
                          @"Timpani":@(48), //定音鼓
                          //Ensemble(合 奏)
                          @"String Ensemble 1":@(49), //弦乐合奏 1
                          @"String Ensemble 2":@(50), //弦乐合奏 2
                          @"Synth Strings 1":@(51), //合成弦乐 1
                          @"Synth Strings 2":@(52), //合成弦乐 2
                          
                          @"Voice":@(53),
                          @"Voice Aahs":@(53), //人声“啊”
                          @"Voice Oohs":@(54), //人声“喔”
                          @"Synth Voice":@(55), //合成人声
                          @"Orchestra Hit":@(56), //交响打击乐
                          //Brass(铜 管 乐 器)
                          @"Trumpets":@(57),
                          @"Trumpet":@(57), //小号
                          @"Trombone":@(58), //长号
                          @"Tuba":@(59), //大号(吐巴号、低音号)
                          @"Muted Trumpet":@(60), //闷音小号
                          @"Horn":@(61),
                          @"French horn":@(61), //法国号(圆号)
                          
                          @"Brass":@(62),
                          @"Brass Section":@(62), //铜管乐
                          @"Synth Brass 1":@(63), //合成铜管 1
                          @"Synth Brass 2":@(64), //合成铜管 2
                          
                          //Reed(簧 乐 器)
                          
                          @"Sax":@(65),
                          @"Soprano Sax":@(65), //高音萨克斯风
                          @"Alto Sax":@(66), //中音萨克斯风
                          @"Tenor Sax":@(67), //次中音萨克斯风
                          @"Baritone Sax":@(68), //上低音萨克斯风
                          @"Oboes":@(69),
                          @"Oboe":@(69), //双簧管
                          @"English Horn":@(70), //英国管
                          @"Bassoons":@(71),
                          @"Bassoon":@(71), //低音管(巴颂管)
                          @"Bass Clarinet in Bb":@(72),
                          @"Clarinets":@(72),
                          @"Clarinets in Bb":@(72),
                          @"Clarinet":@(72), //单簧管(黑管、竖笛)
                          //Pipe(吹 管 乐 器)
                          @"Piccolo":@(73), //短笛
                          @"Flutes":@(74),
                          @"Flute":@(74), //长笛
                          @"Recorder":@(75), //直笛
                          @"Pan Flute":@(76), //排笛
                          @"Blown Bottle":@(77), //瓶笛
                          @"Shakuhachi":@(78), //尺八
                          @"Whistle":@(79), //哨子
                          @"Ocarina":@(80), //陶笛
                          //Synth Lead(合成音 主旋律)
                          @"Lead 1(square)":@(81), //方波
                          @"Lead 2(sawtooth)":@(82), //锯齿波
                          @"Lead 3(calliope)":@(83), //汽笛风琴
                          @"Lead 4(chiff)":@(84), //合成吹管
                          @"Lead 5(charang)":@(85), //合成电吉他
                          @"Lead 6(voice)":@(86), //人声键盘
                          @"Lead 7(fifths)":@(87), //五度音
                          @"Lead 8(bass + lead)":@(88), //贝斯吉他合奏
                          //Synth Pad(合成音 和弦衬底)
                          @"Pad 1(new age)":@(89), //新世纪
                          @"Pad 2(warm)":@(90), //温暖
                          @"Pad 3(polysynth)":@(91), //多重合音
                          @"Choir Aahs":@(92),
                          @"Pad 4(choir)":@(92), //人声合唱
                          @"Pad 5(bowed)":@(93), //玻璃
                          @"Pad 6(metallic)":@(94), //金属
                          @"Pad 7(halo)":@(95), //光华
                          @"Pad 8(sweep)":@(96), //扫掠
                          //Synth Effects(合成音 效果)
                          @"FX 1(rain)":@(97), //雨
                          @"FX 2(soundtrack)":@(98), //电影音效
                          @"FX 3(crystal)":@(99), //水晶
                          @"FX 4(atmosphere)":@(100), //气氛
                          @"FX 5(brightness)":@(101), //明亮
                          @"FX 6(goblins)":@(102), //魅影
                          @"FX 7(echoes)":@(103), //回音
                          @"FX 8(sci-fi)":@(104), //科幻
                          //Ethnic(民 族 乐 器)
                          @"Sitar":@(105), //西塔琴
                          @"Banjo":@(106), //五弦琴(斑鸠琴)
                          @"Shamisen":@(107), //三味线
                          @"Koto":@(108), //十三弦琴(古筝)
                          @"Kalimba":@(109), //卡林巴铁片琴
                          @"Bagpipe":@(110), //苏格兰风笛
                          @"Fiddle":@(111), //古提琴
                          @"Shanai":@(112), //(弄蛇人)兽笛 ;发声机制类似唢呐
                          //Percussive(打 击 乐 器)
                          @"Tinkle Bell":@(113), //叮当铃
                          @"Agogo":@(114), //阿哥哥鼓
                          @"Steel Drums":@(115), //钢鼓
                          @"Woodblock":@(116), //木鱼
                          @"Taiko Drum":@(117), //太鼓
                          @"Melodic Tom":@(118), //定音筒鼓
                          @"Synth Drum":@(119), //合成鼓
                          @"Reverse Cymbal":@(120), //逆转钹声
                          //Sound effects(特 殊 音 效)
                          @"Guitar Fret Noise":@(121), //吉他滑弦杂音
                          @"Breath Noise":@(122), //呼吸杂音
                          @"Seashore":@(123), //海岸
                          @"Bird Tweet":@(124), //鸟鸣
                          @"Telephone Ring":@(125), //电话铃声
                          @"Helicopter":@(126), //直升机
                          @"Applause":@(127), //拍手
                          @"Gunshot":@(128), //枪声
                          };
    }
    int patch=0;
    NSNumber *num=instrumentPatch[name];
    if (num) {
        patch=[num intValue];
    }else{
        NSLog(@"unknow inst:%@", name);
    }
    return patch-1;
}
+(NSString*)nameForPatch:(int)patch
{
    static NSDictionary *patchNames=nil;
    if (patchNames==nil) {
        patchNames=@{// Piano(钢 琴)
                     @(1): @"Acoustic Grand Piano", //平台钢琴
                     @(2): @"Bright Acoustic Piano", //亮音钢琴
                     @(3): @"Electric Grand Piano", //电钢琴
                     @(4): @"Honky-tonk Piano", //酒吧钢琴
                     @(5): @"Electric Piano 1", //电钢琴 1
                     @(6): @"Electric Piano 2", //电钢琴 2
                     @(7): @"Harpsichord", //大键琴
                     @(8): @"Clavinet", //电翼琴
                     //Chromatic Percussion(半音阶打击乐器)
                     @(9): @"Celesta", //钢片琴
                     @(10): @"Glockenspiel", //钟琴 港译:铁片琴
                     @(11): @"Musical box", //音乐盒
                     @(12): @"Vibraphone", //颤音琴
                     @(13): @"Marimba", //马林巴琴
                     @(14): @"Xylophone", //木琴
                     @(15): @"Tubular Bell", //管钟
                     @(16): @"Dulcimer", //洋琴
                     //Organ(风 琴)
                     @(17): @"Drawbar Organ", //音栓风琴
                     @(18): @"Percussive Organ", //敲击风琴
                     @(19): @"Rock Organ", //摇滚风琴
                     @(20): @"Church organ", //教堂管风琴
                     @(21): @"Reed organ", //簧风琴
                     @(22): @"Accordion", //手风琴
                     @(23): @"Harmonica", //口琴
                     @(24): @"Tango Accordion", //探戈手风琴
                     //Guitar(吉 他)
                     @(25): @"Acoustic Guitar(nylon)", //木吉他(尼龙弦)
                     @(26): @"Acoustic Guitar(steel)", //木吉他(钢弦)
                     @(27): @"Electric Guitar(jazz)", //电吉他(爵士)
                     @(28): @"Electric Guitar(clean)", //电吉他(原音)
                     @(29): @"Electric Guitar(muted)", //电吉他(闷音)
                     @(30): @"Overdriven Guitar", //电吉他(破音)
                     @(31): @"Distortion Guitar", //电吉他(失真)
                     @(32): @"Guitar harmonics", //吉他泛音
                     //Bass(贝 斯)
                     @(33): @"Acoustic Bass", //民谣贝斯
                     @(34): @"Electric Bass(finger)", //电贝斯(指奏)
                     @(35): @"Electric Bass(pick)", //电贝斯(拨奏)
                     @(36): @"Fretless Bass", //无格贝斯
                     @(37): @"Slap Bass 1", //捶鈎贝斯 1
                     @(38): @"Slap Bass 2", //捶鈎贝斯 2
                     @(39): @"Synth Bass 1", //合成贝斯 1
                     @(40): @"Synth Bass 2", //合成贝斯 2
                     //Strings(弦 乐 器)
                     @(41): @"Violin", //小提琴
                     @(42): @"Viola", //中提琴
                     @(43): @"Cello", //大提琴
                     @(44): @"Contrabass", //低音大提琴
                     @(45): @"Tremolo Strings", //颤弓弦乐
                     @(46): @"Pizzicato Strings", //弹拨弦乐
                     @(47): @"Orchestral Harp", //竖琴
                     @(48): @"Timpani", //定音鼓
                     //Ensemble(合 奏)
                     @(49): @"String Ensemble 1", //弦乐合奏 1
                     @(50): @"String Ensemble 2", //弦乐合奏 2
                     @(51): @"Synth Strings 1", //合成弦乐 1
                     @(52): @"Synth Strings 2", //合成弦乐 2
                     @(53): @"Voice Aahs", //人声“啊”
                     @(54): @"Voice Oohs", //人声“喔”
                     @(55): @"Synth Voice", //合成人声
                     @(56): @"Orchestra Hit", //交响打击乐
                     //Brass(铜 管 乐 器)
                     @(57): @"Trumpet", //小号
                     @(58): @"Trombone", //长号
                     @(59): @"Tuba", //大号(吐巴号、低音号)
                     @(60): @"Muted Trumpet", //闷音小号
                     @(61): @"French horn", //法国号(圆号)
                     @(62): @"Brass Section", //铜管乐
                     @(63): @"Synth Brass 1", //合成铜管 1
                     @(64): @"Synth Brass 2", //合成铜管 2
                     //Reed(簧 乐 器)
                     @(65): @"Soprano Sax", //高音萨克斯风
                     @(66): @"Alto Sax", //中音萨克斯风
                     @(67): @"Tenor Sax", //次中音萨克斯风
                     @(68): @"Baritone Sax", //上低音萨克斯风
                     @(69): @"Oboe", //双簧管
                     @(70): @"English Horn", //英国管
                     @(71): @"Bassoon", //低音管(巴颂管)
                     @(72): @"Clarinet", //单簧管(黑管、竖笛)
                     //Pipe(吹 管 乐 器)
                     @(73): @"Piccolo", //短笛
                     @(74): @"Flute", //长笛
                     @(75): @"Recorder", //直笛
                     @(76): @"Pan Flute", //排笛
                     @(77): @"Blown Bottle", //瓶笛
                     @(78): @"Shakuhachi", //尺八
                     @(79): @"Whistle", //哨子
                     @(80): @"Ocarina", //陶笛
                     //Synth Lead(合成音 主旋律)
                     @(81): @"Lead 1(square)", //方波
                     @(82): @"Lead 2(sawtooth)", //锯齿波
                     @(83): @"Lead 3(calliope)", //汽笛风琴
                     @(84): @"Lead 4(chiff)", //合成吹管
                     @(85): @"Lead 5(charang)", //合成电吉他
                     @(86): @"Lead 6(voice)", //人声键盘
                     @(87): @"Lead 7(fifths)", //五度音
                     @(88): @"Lead 8(bass + lead)", //贝斯吉他合奏
                     //Synth Pad(合成音 和弦衬底)
                     @(89): @"Pad 1(new age)", //新世纪
                     @(90): @"Pad 2(warm)", //温暖
                     @(91): @"Pad 3(polysynth)", //多重合音
                     @(92): @"Pad 4(choir)", //人声合唱
                     @(93): @"Pad 5(bowed)", //玻璃
                     @(94): @"Pad 6(metallic)", //金属
                     @(95): @"Pad 7(halo)", //光华
                     @(96): @"Pad 8(sweep)", //扫掠
                     //Synth Effects(合成音 效果)
                     @(97): @"FX 1(rain)", //雨
                     @(98): @"FX 2(soundtrack)", //电影音效
                     @(99): @"FX 3(crystal)", //水晶
                     @(100): @"FX 4(atmosphere)", //气氛
                     @(101): @"FX 5(brightness)", //明亮
                     @(102): @"FX 6(goblins)", //魅影
                     @(103): @"FX 7(echoes)", //回音
                     @(104): @"FX 8(sci-fi)", //科幻
                     //Ethnic(民 族 乐 器)
                     @(105): @"Sitar", //西塔琴
                     @(106): @"Banjo", //五弦琴(斑鸠琴)
                     @(107): @"Shamisen", //三味线
                     @(108): @"Koto", //十三弦琴(古筝)
                     @(109): @"Kalimba", //卡林巴铁片琴
                     @(110): @"Bagpipe", //苏格兰风笛
                     @(111): @"Fiddle", //古提琴
                     @(112): @"Shanai", //(弄蛇人)兽笛 ;发声机制类似唢呐
                     //Percussive(打 击 乐 器)
                     @(113): @"Tinkle Bell", //叮当铃
                     @(114): @"Agogo", //阿哥哥鼓
                     @(115): @"Steel Drums", //钢鼓
                     @(116): @"Woodblock", //木鱼
                     @(117): @"Taiko Drum", //太鼓
                     @(118): @"Melodic Tom", //定音筒鼓
                     @(119): @"Synth Drum", //合成鼓
                     @(120): @"Reverse Cymbal", //逆转钹声
                     //Sound effects(特 殊 音 效)
                     @(121): @"Guitar Fret Noise", //吉他滑弦杂音
                     @(122): @"Breath Noise", //呼吸杂音
                     @(123): @"Seashore", //海岸
                     @(124): @"Bird Tweet", //鸟鸣
                     @(125): @"Telephone Ring", //电话铃声
                     @(126): @"Helicopter", //直升机
                     @(127): @"Applause", //拍手
                     @(128): @"Gunshot", //枪声
                     };
    }
    
    if (patch<0) {
        patch=0;
    }
    return COM_LOCAL([patchNames objectForKey:@(patch+1)]);
}
//static unsigned char last_buf[256]={0,0,0};
//static int last_buf_len=0;
//static int test_num=0, test_total=0;

static NSString *logFile=nil;

void dumpMidi(NSString *port, unsigned char *data, int length) {
    if (logFile==nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
        NSString *destPath = paths.firstObject;
        logFile = [destPath stringByAppendingPathComponent:@"log.txt"];
    }
    FILE *fp = fopen(logFile.UTF8String, "wa+");
    //    fseek(fp, 0, SEEK_END);
    NSData *d=[NSData dataWithBytes:data length:length];
    NSString *tmp=[NSString stringWithFormat:@"%@\n", d];
    NSLog(@"dumpMidi:%@", tmp);
    fwrite(tmp.UTF8String, 1, tmp.length, fp);
    fclose(fp);
}

void myMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon)
{
    NewPlayMidi *newPlayMidi=(__bridge NewPlayMidi *)(readProcRefCon);
    NSString *port=(__bridge NSString *)(srcConnRefCon);
    //    dispatch_async(dispatch_get_main_queue(), ^{
    myMIDIReadProcAsync(pktlist, newPlayMidi, port);
    //    });
}

void myMIDIReadProcAsync(const MIDIPacketList *pktlist, NewPlayMidi *newPlayMidi, NSString *port)
{
    //NSLog(@"receive midi");
    
    for (int i=0; i<pktlist->numPackets; i++) {
        MIDIPacket *packet = (MIDIPacket *)&(pktlist->packet[i]);
        //        if (packet->length==0) {
        //            continue;
        //        }
        newPlayMidi.timestampMidiPort=packet->timeStamp;
        //        NSLog(@"port:%@",port);
        //        NSLog(@"midi tick:%llu", packet->timeStamp);
#if 0
        dumpMidi(port,packet->data,packet->length);
#endif
        
        //        if (pktlist->numPackets>1) {
        //            NSLog(@"more packet received");
        //        }
        /*
         hotfix for ios/mac midi over BLE bug:
         if send 80 80 F0 xx xx xx 80 F7, ios/mac may receive F0 xx xx xx, and lost F7
         */
        //#if TARGET_OS_IPHONE
        //        if (i==0 && pktlist->numPackets==2 && packet->data[0]==0xF0) {
        //            MIDIPacket *nextpacket = (MIDIPacket *)&(pktlist->packet[1]);
        //            if (nextpacket->length==0) {
        //                packet->data[packet->length]=0xF7;
        //                packet->length++;
        //            }
        //        }
        //        if (newPlayMidi.delegate && [newPlayMidi.delegate respondsToSelector:@selector(midiEventReceived:)]) {
        //            [newPlayMidi.delegate midiEventReceived:packet];
        //        }
        //#endif
        if ([newPlayMidi.curOutputDevice isEqualToString:newPlayMidi.MIDIPORT_stick] || [port isEqualToString:newPlayMidi.MIDIPORT_Normal]) {
            if (i==0 && pktlist->numPackets==2 && packet->data[0]==0xF0) {
                MIDIPacket *nextpacket = (MIDIPacket *)&(pktlist->packet[1]);
                if (nextpacket->length==0) {
                    packet->data[packet->length]=0xF7;
                    packet->length++;
                }
            }
            if (newPlayMidi.delegate && [newPlayMidi.delegate respondsToSelector:@selector(midiEventReceived:)]) {
                [newPlayMidi.delegate midiEventReceived:packet];
            }
        }
        if (port) {
            MIDIPacket local=*packet;
            if (newPlayMidi.receiveMidiPortBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    newPlayMidi.receiveMidiPortBlock(port, local.timeStamp, &local.data[0], local.length);
                });
            }
            if (newPlayMidi.gReceivMidiPortBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    newPlayMidi.gReceivMidiPortBlock(port, local.timeStamp, &local.data[0], local.length);
                });
            }
            if (newPlayMidi.receiveTestPortBlock && [port isEqualToString:newPlayMidi.MIDIPORT_Test]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    newPlayMidi.receiveTestPortBlock(port, local.timeStamp, &local.data[0], local.length);
                });
            }
        }
        
#if !TARGET_OS_IPHONE
        
        //if ([[UIDevice currentDevice].systemVersion characterAtIndex:0]>='8')
        {
            //NSString *port=(__bridge NSString *)(srcConnRefCon);
            if (port) {
                BOOL found=NO;
                NSRange range=[port rangeOfString:@"Find"];
                if (range.length>0) {
                    found=YES;
                }else{
                    range=[port rangeOfString:@"Pad"];
                    if (range.length>0) {
                        found=YES;
                    }else{
                        range=[port rangeOfString:@"Phone"];
                        if (range.length>0) {
                            found=YES;
                        }
                    }
                }
                if (!found) {
                    found=![port hasPrefix:newPlayMidi.MIDIPORT_Prefix];
                }
                if (found) {
                    //[newPlayMidi sendUsbPort:@"UM-ONE" event:packet->data length:packet->length];
                    [newPlayMidi sendUsbPort:newPlayMidi.MIDIPORT_Autoplay event:packet->data length:packet->length];//自动演奏
                }
                //forward pedal to @"AVCON MIDI DC端口 1"
                //                if ([port isEqualToString:@"AVCON MIDI DC端口 1"]) {
                //                    int i=0;
                //                    while (i<packet->length) {
                //                        unsigned char evt=packet->data[i]&0xf0;
                //                        if (evt==kMidiMessage_ControlChange) {
                //                            unsigned char buf[3]={kMidiMessage_ControlChange, packet->data[i+1], packet->data[i+2]};
                //                            [newPlayMidi sendUsbPort:@"AVCON MIDI DC端口 1" event:buf length:3];
                //                        }
                //                        i+=3;
                //                    }
                //                }
            }
        }
#else
        
#endif
    }
}
#pragma mark - IOS5 play functions
///////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL) createAUGraph
{
    // Each core audio call returns an OSStatus. This means that we
    // Can see if there have been any errors in the setup
    OSStatus result = noErr;
    
    // Create 2 audio units one sampler and one IO
    AUNode samplerNode, ioNode;
    
    // Specify the common portion of an audio unit's identify, used for both audio units
    // in the graph.
    // Setup the manufacturer - in this case Apple
    AudioComponentDescription cd = {};
    cd.componentManufacturer     = kAudioUnitManufacturer_Apple;
    cd.componentFlags            = 0;
    cd.componentFlagsMask        = 0;
    
    // Instantiate an audio processing graph
    result = NewAUGraph (&_processingGraph);
    if (result != noErr)NSLog(@"Unable to create an AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    //Specify the Sampler unit, to be used as the first node of the graph
    cd.componentType = kAudioUnitType_MusicDevice; // type - music device
    cd.componentSubType = kAudioUnitSubType_Sampler; // sub type - sampler to convert our MIDI
    
    // Add the Sampler unit node to the graph
    result = AUGraphAddNode (_processingGraph, &cd, &samplerNode);
    if (result != noErr)NSLog(@"Unable to add the Sampler unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Specify the Output unit, to be used as the second and final node of the graph
    cd.componentType = kAudioUnitType_Output;  // Output
#if !TARGET_OS_IPHONE
    cd.componentSubType = kAudioUnitSubType_DefaultOutput;  // Output to speakers
#else
    cd.componentSubType = kAudioUnitSubType_RemoteIO;  // Output to speakers
#endif
    // Add the Output unit node to the graph
    result = AUGraphAddNode (_processingGraph, &cd, &ioNode);
    if (result != noErr)NSLog(@"Unable to add the Output unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Open the graph
    result = AUGraphOpen (_processingGraph);
    if (result != noErr)NSLog(@"Unable to open the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Connect the Sampler unit to the output unit
    result = AUGraphConnectNodeInput (_processingGraph, samplerNode, 0, ioNode, 0);
    if (result != noErr)NSLog(@"Unable to interconnect the nodes in the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Obtain a reference to the Sampler unit from its node
    result = AUGraphNodeInfo (_processingGraph, samplerNode, 0, &_samplerUnit);
    if (result != noErr)NSLog(@"Unable to obtain a reference to the Sampler unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Obtain a reference to the I/O unit from its node
    result = AUGraphNodeInfo (_processingGraph, ioNode, 0, &_ioUnit);
    if (result != noErr)NSLog(@"Unable to obtain a reference to the I/O unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    return YES;
}



// Load a sound effect from a SoundFont file
-(OSStatus) loadFromDLSOrSoundFont: (NSURL *)bankURL withPatch: (int)presetNumber {
    
    OSStatus result = noErr;
    
    // fill out a bank preset data structure
    AUSamplerInstrumentData bpdata;
    bpdata.fileURL  = (__bridge  CFURLRef) bankURL;
    bpdata.instrumentType = kInstrumentType_SF2Preset;//kInstrumentType_DLSPreset;
    bpdata.bankMSB  = kAUSampler_DefaultMelodicBankMSB;//kAUSampler_DefaultPercussionBankMSB;//kAUSampler_DefaultMelodicBankMSB;
    bpdata.bankLSB  = kAUSampler_DefaultBankLSB;
    bpdata.presetID = (UInt8) presetNumber;
    // set the kAUSamplerProperty_LoadPresetFromBank property
    result = AudioUnitSetProperty(_samplerUnit,
                                  kAUSamplerProperty_LoadInstrument,
                                  kAudioUnitScope_Global,
                                  0,
                                  &bpdata,
                                  sizeof(bpdata));
    
    // check for errors
    if (result != noErr)NSLog(@"Unable to set the preset property on the Sampler. Error code:%d '%.4s'",
                              (int) result,
                              (const char *)&result);
    //kAudioUnitProperty_ClassInfo
    CFArrayRef presets = NULL;
    UInt32 sz = sizeof (CFArrayRef);
    //analyze never read
    //    int num = 0;
    
    if (AudioUnitGetProperty (_samplerUnit,
                              kAudioUnitProperty_FactoryPresets,
                              kAudioUnitScope_Global,
                              0, &presets, &sz) == noErr)
    {
        //analyze never read
        //        num = (int) CFArrayGetCount (presets);
        CFRelease (presets);
    }
    
    
    presets = NULL;
    UInt32 propertySize = sizeof(presets);
    result = AudioUnitGetProperty(_samplerUnit,
                                  kAudioUnitProperty_ClassInfo,
                                  kAudioUnitScope_Global,
                                  0,
                                  &presets,
                                  &propertySize);
    
    
    
    
    return result;
}

// Load a sound effect from a SoundFont file
-(OSStatus) loadFromDLSOrSoundFont1: (NSURL *)bankURL withPatch: (int)presetNumber {
    
    OSStatus result = noErr;
    
    // fill out a bank preset data structure
    AUSamplerBankPresetData bpdata;
    bpdata.bankURL  = (__bridge  CFURLRef) bankURL;
    bpdata.bankMSB  = kAUSampler_DefaultMelodicBankMSB;
    bpdata.bankLSB  = kAUSampler_DefaultBankLSB;
    bpdata.presetID = (UInt8) presetNumber;
    
    // set the kAUSamplerProperty_LoadPresetFromBank property
    result = AudioUnitSetProperty(_samplerUnit,
                                  kAUSamplerProperty_LoadPresetFromBank,
                                  kAudioUnitScope_Global,
                                  0,
                                  &bpdata,
                                  sizeof(bpdata));
    
    // check for errors
    if (result != noErr)NSLog(@"Unable to set the preset property on the Sampler. Error code:%d '%.4s'",
                              (int) result,
                              (const char *)&result);
    
    return result;
}

static void MyMIDINotifyProc (const MIDINotification  *message, void *refCon) {
    //printf("MIDI Notify, messageId=%ld,", message->messageID);
    //NSLog(@"MIDI Notify, messageId=%ld", message->messageID);
}


enum {
    kMIDIControl_Pedal  = 0x40, //64 (0x40)    Damper pedal (sustain), 00-7F
};

-(void)midiDeviceOpen1
{
    OSStatus result = noErr;
    
    [self createAUGraph];
    // Initialize the audio processing graph.
    result = AUGraphInitialize (_processingGraph);
    if (result != noErr)NSLog(@"Unable to initialze AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Start the graph
    result = AUGraphStart (_processingGraph);
    if (result != noErr)NSLog(@"Unable to start audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Print out the graph to the console
    //CAShow (_processingGraph);
#if 1 //for extern MIDI device
    //get midi device info
    [self getMidiDeviceInfo];
    [self getMidiDestSrc];
    
    // Create a client for out port
    MIDIClientRef virtualMidi;
    result = MIDIClientCreate(CFSTR("Virtual Client"), MyMIDINotifyProc, NULL, &virtualMidi);
    if(result != noErr)NSLog(@"MIDIClientCreate failed. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    MIDIOutputPortCreate(virtualMidi, CFSTR("Output port"), &gOutPort);
    
    // Create a client for in port
    MIDIInputPortCreate(virtualMidi, CFSTR("Input port"), myMIDIReadProc, (__bridge void *)(self), &gInPort);
    MIDIPortConnectSource(gInPort, gMidiSrc, NULL);
#endif
    
    // Initialise the sound font
#if 0
    NSURL *presetURL = [[NSURL alloc] initFileURLWithPath:self.soundInDocumentDir];
#else
    //NSURL *presetURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:@"WaveSynth" ofType:@"dlsc"]];
    //GeneralUser GS SoftSynth v1.44.sf2
    NSURL *presetURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:@"TimGM6mb" ofType:@"sf2"]];
#endif
    [self loadFromDLSOrSoundFont: (NSURL *)presetURL withPatch: (int)0];
    
    //[self loadFromDLSOrSoundFontInstruments: (NSURL *)presetURL];
}
#if !TARGET_OS_IPHONE
// This call creates the Graph and the Synth unit...
OSStatus    CreateAUGraph (AUGraph *outGraph, AudioUnit *outSynth)
{
    OSStatus result;
    //create the nodes of the graph
    AUNode synthNode, limiterNode, outNode;
    
    NewAUGraph (outGraph);
    
    //instrument node
    AudioComponentDescription cd;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    
    cd.componentType = kAudioUnitType_MusicDevice;
#if TARGET_OS_IPHONE
    cd.componentSubType = kAudioUnitSubType_Sampler;
#else
    cd.componentSubType = kAudioUnitSubType_DLSSynth;
#endif
    AUGraphAddNode (*outGraph, &cd, &synthNode);
    
    //effect node
    cd.componentType = kAudioUnitType_Effect;
    cd.componentSubType = kAudioUnitSubType_PeakLimiter;
    
    AUGraphAddNode (*outGraph, &cd, &limiterNode);
    
    //output node
    cd.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE
    cd.componentSubType = kAudioUnitSubType_RemoteIO;
#else
    cd.componentSubType = kAudioUnitSubType_DefaultOutput;
#endif
    AUGraphAddNode (*outGraph, &cd, &outNode);
    
    //open graph
    AUGraphOpen (*outGraph);
    
    AUGraphConnectNodeInput (*outGraph, synthNode, 0, limiterNode, 0);
    AUGraphConnectNodeInput (*outGraph, limiterNode, 0, outNode, 0);
    
    // ok we're good to go - get the Synth Unit...
    result = AUGraphNodeInfo(*outGraph, synthNode, 0, outSynth);
    
    return result;
}

- (void)midiDeviceOpen
{
    _processingGraph = 0;
    //AudioUnit synthUnit;
    OSStatus result;
    //char* bankPath = 0;
    
    //UInt8 midiChannelInUse = 0; //we're using midi channel 1...
    
    // this is the only option to main that we have...
    // just the full path of the sample bank...
    
    // On OS X there are known places were sample banks can be stored
    // Library/Audio/Sounds/Banks - so you could scan this directory and give the user options
    // about which sample bank to use...
    
    CreateAUGraph (&_processingGraph, &_samplerUnit);
    
    
    // ok we're set up to go - initialize and start the graph
    AUGraphInitialize (_processingGraph);
    
    //set our bank
    MusicDeviceMIDIEvent(_samplerUnit, kMidiMessage_ControlChange | 0, 0, 0, 0/*sample offset*/);
    
    MusicDeviceMIDIEvent(_samplerUnit, kMidiMessage_ProgramChange | 0, 0/*prog change num*/, 0, 0/*sample offset*/);
    
    //CAShow (_processingGraph); // prints out the graph so we can see what it looks like...
    
    AUGraphStart (_processingGraph);
    
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *currDircetory = documentPaths.firstObject;
#if TARGET_OS_IPHONE
    self.soundInDocumentDir=[currDircetory stringByAppendingPathComponent:@"mcache"];
#else
    self.soundInDocumentDir=[currDircetory stringByAppendingPathComponent:@"Find Sound"];
#endif
    //    self.soundInDocumentDir=[self.soundInDocumentDir stringByAppendingPathComponent:@"FluidR3 GM2-2.SF2"];
    //    self.soundInDocumentDir=[self.soundInDocumentDir stringByAppendingPathComponent:@"FluidR3Mono_GM.sf3"];
    //    self.soundInDocumentDir=[self.soundInDocumentDir stringByAppendingPathComponent:@"Arachno SoundFont - Version 1.0.sf2"];
    //    self.soundInDocumentDir=[self.soundInDocumentDir stringByAppendingPathComponent:@"acoustic_grand_piano.sf2"];
    //    self.soundInDocumentDir=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TimGM6mb.sf2"];
    //    self.soundInDocumentDir=[self.soundInDocumentDir stringByAppendingPathComponent:@"Sonatina_Symphonic_Orchestra.sf2"];
    //    self.soundInDocumentDir=[self.soundInDocumentDir stringByAppendingPathComponent:@"Sounds/001 Piano.aupreset"];
    //    self.soundInDocumentDir=[self.soundInDocumentDir stringByAppendingPathComponent:@"Sounds/Trombone.aupreset"];
    //    self.soundInDocumentDir=[self.soundInDocumentDir stringByAppendingPathComponent:@"Sounds/Vibraphone.aupreset"];
    self.soundInDocumentDir=[self.soundInDocumentDir stringByAppendingPathComponent:@"Sounds/White Baby Grand.aupreset"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.soundInDocumentDir]) {
        self.soundInDocumentDir=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TimGM6mb.sf2"];
    }
    
#if TARGET_OS_IPHONE
#else
    NSURL *url=[NSURL fileURLWithPath:self.soundInDocumentDir];
    CFURLRef soundBankURL=(__bridge CFURLRef)url;
    //NSLog (@"Setting Sound Bank:%@\n", self.soundInDocumentDir);
    
    BOOL isDir=YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.soundInDocumentDir isDirectory:&isDir] && !isDir) {
        
        if ([self.soundInDocumentDir.pathExtension isEqualToString:@"aupreset"]){
            CFDataRef propertyResourceData = 0;
            Boolean status;
            SInt32 errorCode = 0;
            //            OSStatus result = noErr;
            
            // Read from the URL and convert into a CFData chunk
            status = CFURLCreateDataAndPropertiesFromResource (
                                                               kCFAllocatorDefault,
                                                               (__bridge CFURLRef) url,
                                                               &propertyResourceData,
                                                               NULL,
                                                               NULL,
                                                               &errorCode
                                                               );
            //            CFDictionaryRef dictRef = CFURLCopyResourcePropertiesForKeys(url, <#CFArrayRef keys#>, &errorCode);
            NSAssert (status == YES && propertyResourceData != 0, @"Unable to create data and properties from a preset. Error code: %d '%.4s'", (int) errorCode, (const char *)&errorCode);
            
            // Convert the data object into a property list
            CFPropertyListRef presetPropertyList = 0;
            CFPropertyListFormat dataFormat = 0;
            CFErrorRef errorRef = 0;
            presetPropertyList = CFPropertyListCreateWithData (
                                                               kCFAllocatorDefault,
                                                               propertyResourceData,
                                                               kCFPropertyListImmutable,
                                                               &dataFormat,
                                                               &errorRef
                                                               );
            
            // Set the class info property for the Sampler unit using the property list as the value.
            if (presetPropertyList != 0) {
                
                AudioUnitSetProperty(
                                     _samplerUnit,
                                     kAudioUnitProperty_ClassInfo,
                                     kAudioUnitScope_Global,
                                     0,
                                     &presetPropertyList,
                                     sizeof(CFPropertyListRef)
                                     );
                
                CFRelease(presetPropertyList);
            }
            
            if (errorRef) CFRelease(errorRef);
            CFRelease (propertyResourceData);
        }else
        {
            /*
             FSRef fsRef;
             result = FSPathMakeRef ((const UInt8*)bankPath, &fsRef, 0);
             
             printf ("Setting Sound Bank:%s\n", bankPath);
             
             result = AudioUnitSetProperty (synthUnit,
             kMusicDeviceProperty_SoundBankFSRef,
             kAudioUnitScope_Global, 0,
             &fsRef, sizeof(fsRef));
             */
            //        CFURLRef soundBankURL = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8*)self.soundInDocumentDir.UTF8String, strlen(self.soundInDocumentDir.UTF8String), false);
            
            
            result = AudioUnitSetProperty (_samplerUnit,
                                           kMusicDeviceProperty_SoundBankURL,
                                           kAudioUnitScope_Global, 0,
                                           &soundBankURL, sizeof(soundBankURL));
            if (soundBankURL) CFRelease(soundBankURL);
            if (result!=noErr) {
                NSLog(@"AudioUnitSetProperty: kMusicDeviceProperty_SoundBankURL error=0x%x", result);
            }
        }
    }
    
#endif
    
    [self reloadExternalMidiDevices];
    //[self setInstrumentUnit:_samplerUnit];
}



#else //#if !TARGET_OS_IPHONE
-(void)midiDeviceOpen
{
    memset(notes_on, 0, sizeof(notes_on));
    SamplerPrograms[0]=GM_Program_Piano;
    samplerUnite_count=1;
    
    // Set up variables for the audio graph
    OSStatus result = noErr;
    AUNode ioNode, mixerNode;
    //AUNode samplerNode_Piano, samplerNode_Violin, samplerNode_Flute, samplerNode_Clarinet,samplerNode_Trumpet;
    AUNode samplerNode_Programs[MAX_SamplerUnit];
    // Specify the common portion of an audio unit's identify, used for all audio units
    // in the graph.
    AudioComponentDescription cd = {};
    cd.componentManufacturer     = kAudioUnitManufacturer_Apple;
    
    // Instantiate an audio processing graph
    result = NewAUGraph (&_processingGraph);
    NSCAssert (result == noErr, @"Unable to create an AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
    // SAMPLER UNIT
    //Specify the Sampler unit, to be used as the first node of the graph
    cd.componentType = kAudioUnitType_MusicDevice;
    cd.componentSubType = kAudioUnitSubType_Sampler;
    
    // Create a new sampler note
    for (int i=0; i<MAX_SamplerUnit; i++) {
        result = AUGraphAddNode (_processingGraph, &cd, &samplerNode_Programs[i]);
    }
    
    // Check for any errors
    NSCAssert (result == noErr, @"Unable to add the Sampler unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // IO UNIT
    // Specify the Output unit, to be used as the second and final node of the graph
    cd.componentType = kAudioUnitType_Output;
    cd.componentSubType = kAudioUnitSubType_RemoteIO;
    
    // Add the Output unit node to the graph
    result = AUGraphAddNode (_processingGraph, &cd, &ioNode);
    NSCAssert (result == noErr, @"Unable to add the Output unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // MIXER UNIT
    // Add the mixer unit to the graph
    cd.componentType = kAudioUnitType_Mixer;
    cd.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    
    result = AUGraphAddNode (_processingGraph, &cd, &mixerNode);
    NSCAssert (result == noErr, @"Unable to add the Output unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    
    // Open the graph
    result = AUGraphOpen (_processingGraph);
    NSCAssert (result == noErr, @"Unable to open the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Now that the graph is open get references to all the nodes and store
    // them as audio units
    
    // Get a reference to the sampler node and store it in the samplerUnit variable
    for (int i=0; i<MAX_SamplerUnit; i++) {
        result = AUGraphNodeInfo (_processingGraph, samplerNode_Programs[i], 0, &_samplerUnit_Programs[i]);
    }
    _samplerUnit=_samplerUnit_Programs[0];
    
    NSCAssert (result == noErr, @"Unable to obtain a reference to the Sampler unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Load a soundfont into the mixer unit
    /*
     for (int i=0; i<MAX_SamplerUnit; i++) {
     [self loadSoundFont:presetURL withPatch:SamplerPrograms[i]-1 withSampler:_samplerUnit_Programs[i]];
     }
     */
    //Piano is default for No.0
    [self loadSoundFontWithPatch:GM_Program_Piano-1 withSampler:_samplerUnit_Programs[0] percussionBank:NO];
    
    // Create a new mixer unit. This is necessary because if we want to have more than one
    // sampler outputting throught the speakers
    result = AUGraphNodeInfo (_processingGraph, mixerNode, 0, &_mixerUnit);
    NSCAssert (result == noErr, @"Unable to obtain a reference to the Sampler unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Obtain a reference to the I/O unit from its node
    result = AUGraphNodeInfo (_processingGraph, ioNode, 0, &_ioUnit);
    NSCAssert (result == noErr, @"Unable to obtain a reference to the I/O unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Define the number of input busses on the mixer unit
    UInt32 busCount   = 1;
    
    // Set the input channels property on the mixer unit
    result = AudioUnitSetProperty (_mixerUnit,
                                   kAudioUnitProperty_ElementCount,
                                   kAudioUnitScope_Input,
                                   0,
                                   &busCount,
                                   sizeof (busCount)
                                   );
    NSCAssert (result == noErr, @"AudioUnitSetProperty Set mixer bus count. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Connect the sampler unit to the mixer unit
    for (int i=0; i<MAX_SamplerUnit; i++) {
        result = AUGraphConnectNodeInput(_processingGraph, samplerNode_Programs[i], 0, mixerNode, i);
        if (result!=noErr) {
            NSLog(@"Couldn't connect speech synth unit output (0) to mixer input (1). Error code: %d '%.4s'", (int) result, (const char *)&result);
        }
    }
    
    // Set the volume of the channel
    AudioUnitSetParameter(_mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1, 0);
    
    
    // Connect the output of the mixer node to the input of he io node
    result = AUGraphConnectNodeInput (_processingGraph, mixerNode, 0, ioNode, 0);
    NSCAssert (result == noErr, @"Unable to interconnect the nodes in the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Print a graphic version of the graph
    //    CAShow(_processingGraph);
    
    // Start the graph
    result = AUGraphInitialize (_processingGraph);
    
    //    NSAssert (result == noErr, @"Unable to initialze AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
    NSLog(@"Unable to initialze AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Start the graph
    result = AUGraphStart (_processingGraph);
    //    NSAssert (result == noErr, @"Unable to start audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    NSLog(@"Unable to start audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Play middle c on the sampler - sampler unit to send the command to, midi command i.e. note on, note number, velocity
    //MusicDeviceMIDIEvent(_samplerUnit, 0x90, 60, 127, 0);
    
#if 0 //for extern MIDI device
    // Create a client for MIDIs I/O port
    if (virtualMidiClient==0)
    {
        result = MIDIClientCreate(CFSTR("Virtual Client"), MyMIDINotifyProc, NULL, &virtualMidiClient);
        if(result != noErr)NSLog(@"MIDIClientCreate failed. Error code: %d '%.4s'", (int) result, (const char *)&result);
        //MIDI Output Port
        MIDIOutputPortCreate(virtualMidiClient, CFSTR("Output port"), &gOutPort);
        
        //MIDI Input Port
        MIDIInputPortCreate(virtualMidiClient, CFSTR("Input port"), myMIDIReadProc, (__bridge void *)(self), &gInPort);
        //MIDIPortConnectSource(gInPort, self.gMidiSrc, NULL);
    }
    
    //get midi device info
    [self getMidiDeviceInfo];
    [self getMidiDestSrc];
    
    if (gMidiSrc) {
        MIDIPortConnectSource(gInPort, gMidiSrc, NULL);
    }
#else
    [self reloadExternalMidiDevices];
#endif
}
#endif

- (void)setVolume:(float)volume {
    if (volume<0) {
        volume=0;
    }else if (volume>1){
        volume=1;
    }
    if (_volume!=volume) {
        _volume=volume;
        AudioUnitSetParameter(_mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, volume, 0);
    }
}

- (void)reloadExternalMidiDevices{
    if (virtualMidiClient==0)
    {
        OSStatus result = MIDIClientCreate(CFSTR("Virtual Client"), MyMIDINotifyProc, NULL, &virtualMidiClient);
        if(result != noErr)NSLog(@"MIDIClientCreate failed. Error code: %d '%.4s'", (int) result, (const char *)&result);
        //MIDI Output Port
        MIDIOutputPortCreate(virtualMidiClient, CFSTR("Output port"), &gOutPort);
        
        //MIDI Input Port
        MIDIInputPortCreate(virtualMidiClient, CFSTR("Input port"), myMIDIReadProc, (__bridge void *)(self), &gInPort);
        
        //MIDIPortConnectSource(gInPort, self.gMidiSrc, NULL);
    }
    
    //get midi device info
    [self getMidiDeviceInfo];
    [self getMidiDestSrc];
    
    if (gMidiSrc) {
        MIDIPortConnectSource(gInPort, gMidiSrc, NULL);
    }
}

// Load a sound effect from a SoundFont file
-(OSStatus) loadSoundFontWithPatch:(UInt8)presetID withSampler:(AudioUnit)samplerUnit percussionBank:(BOOL)percussionBank
{
    OSStatus result = noErr;
    static NSURL *bankURL = nil;
    if (bankURL==nil) {
        bankURL=[[NSURL alloc] initFileURLWithPath:self.soundInDocumentDir];
    }
    //#if 0
#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE))
    AUSamplerInstrumentData bpdata;
    bpdata.fileURL  = (__bridge  CFURLRef) bankURL;
    bpdata.instrumentType = kInstrumentType_SF2Preset;//kInstrumentType_DLSPreset;
    bpdata.bankMSB  = kAUSampler_DefaultMelodicBankMSB;//kAUSampler_DefaultPercussionBankMSB;//kAUSampler_DefaultMelodicBankMSB;
    bpdata.bankLSB  = kAUSampler_DefaultBankLSB;
    bpdata.presetID = (UInt8) presetID;
    // set the kAUSamplerProperty_LoadPresetFromBank property
    result = AudioUnitSetProperty(samplerUnit,
                                  kAUSamplerProperty_LoadInstrument,
                                  kAudioUnitScope_Global,
                                  0,
                                  &bpdata,
                                  sizeof(bpdata));
#else
    // fill out a bank preset data structure
    AUSamplerBankPresetData bpdata;
    bpdata.bankURL  = (__bridge  CFURLRef) bankURL;
    bpdata.bankMSB  = (percussionBank)?kAUSampler_DefaultPercussionBankMSB:kAUSampler_DefaultMelodicBankMSB;//kAUSampler_DefaultPercussionBankMSB;//kAUSampler_DefaultMelodicBankMSB;
    bpdata.bankLSB  = kAUSampler_DefaultBankLSB;
    bpdata.presetID = (UInt8) presetID;
    
    // set the kAUSamplerProperty_LoadPresetFromBank property
    result = AudioUnitSetProperty(samplerUnit,
                                  kAUSamplerProperty_LoadPresetFromBank,//kAUSamplerProperty_LoadInstrument,
                                  kAudioUnitScope_Global,
                                  0,
                                  &bpdata,
                                  sizeof(bpdata));
#endif
    // check for errors
    if (result != noErr)NSLog(@"Unable to set the preset property on the Sampler. Error code:%d '%.4s'",
                              (int) result,
                              (const char *)&result);
    /*
     CFArrayRef presets = NULL;
     UInt32 propertySize = sizeof(presets);
     result = AudioUnitGetProperty(samplerUnit,
     kAudioUnitProperty_ClassInfo,
     kAudioUnitScope_Global,
     0,
     &presets,
     &propertySize);
     if (presets) {
     CFRelease (presets);
     }
     */
    return result;
}

-(void) midiDeviceClose
{
    if ( _processingGraph ) {
        for (int i=0; i<MAX_SamplerUnit; i++) {
            _samplerUnit_Programs[i]=NULL;
        }
        if (gInPort) {
            MIDIPortDispose(gInPort);
            gInPort=0;
        }
        if (gOutPort) {
            MIDIPortDispose(gOutPort);
            gOutPort=0;
        }
        AUGraphStop (_processingGraph);
        DisposeAUGraph (_processingGraph);
        _processingGraph=NULL;
        _samplerUnit=NULL;
        //MIDIClientDispose(virtualMidiClient);
        //virtualMidiClient=0;
    }
}


static __strong NewPlayMidi *midi_player=nil;
+ (NewPlayMidi*)getMidiPlayer
{
    //#if TARGET_OS_MAC
    //    return nil;
    //#endif
    if (midi_player==nil) {
        midi_player=[[NewPlayMidi alloc]init];
        if ([midi_player checkSoundFont]) {
            //[midi_player performSelectorInBackground:@selector(midiDeviceOpen) withObject:nil];
            [midi_player midiDeviceOpen];
        }
    }
    return midi_player;
}
+ (void)closeMidiPlayer
{
    [midi_player midiDeviceClose];
    midi_player=nil;
}
+ (void)resetMidiPlayer
{
    [midi_player midiDeviceClose];
    [midi_player midiDeviceOpen];
}

#pragma mark - MIDI event API
//volume:14 bits
- (void) sendMidiPitchWheel:(int)velocity
{
    UInt32 data1 = velocity >> 7;//Hi 7 bits;
    UInt32 data2 = velocity & 0x7F;//low 7 bits
    UInt32 noteCommand =  kMidiMessage_PitchWheel | midiChannelInUse;
    
    OSStatus result = noErr;
    result = MusicDeviceMIDIEvent(_samplerUnit, noteCommand, data1, data2, 0);
    if (result != noErr) NSLog (@"Unable to sendMidiPitchWheel. Error code: %d '%.4s'\n", (int) result, (const char *)&result);
}

- (void) sendMidiChannelPressure:(int)pressure
{
    UInt32 noteCommand =  kMidiMessage_ChannelPressure | midiChannelInUse;
    
    OSStatus result = noErr;
    result = MusicDeviceMIDIEvent(_samplerUnit, noteCommand, pressure, 0, 0);
    if (result != noErr) NSLog (@"Unable to sendMidiChannelPressure. Error code: %d '%.4s'\n", (int) result, (const char *)&result);
}


- (void) resetPrograms
{
    samplerUnite_count=1;
    samplerForChannel[0]=0;
    for (int i=1; i<MAX_Channel; i++) {
        samplerForChannel[i]=-1;
    }
}

- (void) sendProgramEventLocal:(int)program channel:(int)channel
{
    if (program==0) {
        program=1;
    }
    if (channel==Drums_Channel) {
        if (samplerForChannel[Drums_Channel]<0) {
            if(noErr ==[self loadSoundFontWithPatch:0 withSampler:_samplerUnit_Programs[samplerUnite_count] percussionBank:YES])
            {
                samplerForChannel[channel]=samplerUnite_count;
                SamplerPrograms[samplerUnite_count]=0xff;
                samplerUnite_count++;
            }else{ //其他都作为Piano
                NSLog(@"too many programs(%d), can not load more",samplerUnite_count);
                samplerForChannel[channel]=samplerUnite_count;
                SamplerPrograms[samplerUnite_count]=GM_Program_Piano;
                samplerUnite_count++;
            }
        }
        //kAUSampler_DefaultPercussionBankMSB
    }else if (channel<MAX_Channel) {
        BOOL found=NO;
        for (int i=0; i<MAX_SamplerUnit && i<samplerUnite_count; i++) {
            if (program==SamplerPrograms[i]) { //判断这个乐器是否已经加载了
                samplerForChannel[channel]=i;
                found=YES;
                break;
            }
        }
        if (!found && samplerUnite_count<MAX_SamplerUnit) {
            if (noErr ==[self loadSoundFontWithPatch:program withSampler:_samplerUnit_Programs[samplerUnite_count] percussionBank:NO])
            {
                samplerForChannel[channel]=samplerUnite_count;
                SamplerPrograms[samplerUnite_count]=program;
                samplerUnite_count++;
            }else{ //其他都作为Piano
                NSLog(@"too many programs(%d), can not load more",samplerUnite_count);
                samplerForChannel[channel]=samplerUnite_count;
                SamplerPrograms[samplerUnite_count]=GM_Program_Piano;
                samplerUnite_count++;
            }
        }
    }
    return;
    //    UInt32 status =  kMidiMessage_ProgramChange | channel;
    //    OSStatus result = noErr;
    //    result = MusicDeviceMIDIEvent(_samplerUnit, status, program, 0, 0);
    //    if (result != noErr) NSLog (@"Unable to sendProgramEvent. Error code: %d '%.4s'\n", (int) result, (const char *)&result);
}
- (void) sendProgramEvent:(int)program channel:(int)channel
{
    if (gUsbDest)
    {
        if (channel<MAX_Channel) {
            MIDIPacketList packetList;
            packetList.numPackets = 1;
            MIDIPacket* firstPacket = &packetList.packet[0];
            firstPacket->timeStamp = 0; // send immediately
            firstPacket->length = 2;
            firstPacket->data[0] = kMidiMessage_ProgramChange|channel;
            firstPacket->data[1] = program;
            MIDISend(gOutPort, gUsbDest, &packetList);
            samplerForChannel[channel]=program;
        }
    }else{
        //        [self sendProgramEventLocal:program channel:channel];
#if TARGET_OS_IPHONE
        [self sendProgramEventLocal:program channel:channel];
#else
        //        [self sendProgramEventLocal:program channel:channel];
        OSStatus status = MusicDeviceMIDIEvent(_samplerUnit,
                                               kMidiMessage_ProgramChange | channel,
                                               program/*prog change num*/, 0,
                                               0/*sample offset*/);
        NSLog(@"sendProgramEvent=%d",status);
#endif
    }
}

- (void)sendControlEventLocal:(int)control velocity:(int)velocity channel:(int)channel
{
    UInt32 status =  kMidiMessage_ControlChange | channel;
    //NSLog(@"sendControlEvent:%d=%d",control,velocity);
    if (channel<MAX_Channel) {
        _samplerUnit=_samplerUnit_Programs[samplerForChannel[channel]];
    }else{
        _samplerUnit=_samplerUnit_Programs[0];
    }
    
    OSStatus result = noErr;
    result = MusicDeviceMIDIEvent(_samplerUnit, status, control, velocity, 0);
    if (result != noErr)
        NSLog (@"Unable to sendControlEvent(%d,%d,%d). Error code: %d '%.4s'\n", control,velocity,channel, (int) result, (const char *)&result);
}
- (void) sendUsbPortSysex:(NSString*)port event:(unsigned char*)data length:(int)length
{
    MyMidiEndPoint *p=self.midiDests[port];
    if (p) {
        MIDIEndpointRef usbDest=p.endpointRef;
        sendMessage(gOutPort, usbDest, data, length);
    }
}
void sendMessage(MIDIPortRef port, MIDIEndpointRef endpoint, unsigned char *message, int nBytes)
{
    if ( nBytes == 0 ) {
        return;
    }
    
    if ( message[0] != 0xF0 && nBytes > 3 ) {
        NSLog(@"MidiOutCore::sendMessage: message format problem ... not sysex but > 3 bytes?");
        return;
    }
    
    MIDITimeStamp timeStamp = 0;//AudioGetCurrentHostTime();
    OSStatus result;
    
    Byte buffer[nBytes+(sizeof(MIDIPacketList))];
    ByteCount listSize = sizeof(buffer);
    MIDIPacketList *packetList = (MIDIPacketList*)buffer;
    MIDIPacket *packet = MIDIPacketListInit( packetList );
    
    ByteCount remainingBytes = nBytes;
    while (remainingBytes) {
        ByteCount bytesForPacket = remainingBytes > 65535 ? 65535 : remainingBytes; // 65535 = maximum size of a MIDIPacket
        const Byte* dataStartPtr = (const Byte *) &message[nBytes - remainingBytes];   //&message->at( nBytes - remainingBytes );
        packet = MIDIPacketListAdd( packetList, listSize, packet, timeStamp, bytesForPacket, dataStartPtr);
        remainingBytes -= bytesForPacket;
    }
    
    if ( !packet ) {
        NSLog(@"MidiOutCore::sendMessage: could not allocate packet list");
        return;
    }
    
    // Send to any destinations that may have connected to us.
    //    if ( endpoint ) {
    //        result = MIDIReceived( endpoint, packetList );
    //        if ( result != noErr ) {
    //            errorString_ = "MidiOutCore::sendMessage: error sending MIDI to virtual destinations.";
    //            error( RtMidiError::WARNING, errorString_ );
    //        }
    //    }
    
    // And send to an explicit destination port if we're connected.
    if ( endpoint ) {
        result = MIDISend( port, endpoint, packetList );
        if ( result != noErr ) {
            NSLog(@"MidiOutCore::sendMessage: error sending MIDI message to port.");
        }
    }
}

- (void)sendMidiData:(unsigned char*)events length:(int)size toDest:(MIDIEndpointRef) usbDest
{
    if (size<256) {
        MIDIPacketList packetList;
        packetList.numPackets = 1;
        MIDIPacket* firstPacket = &packetList.packet[0];
        firstPacket->timeStamp = 0; // send immediately
        firstPacket->length = size;
        memcpy(firstPacket->data, events, size);
        MIDISend(gOutPort, usbDest, &packetList);
    }else{
        sendMessage(gOutPort, usbDest, events, size);
    }
}

- (BOOL)sendUsbEvent:(unsigned char*)events length:(int)size {
    if (gUsbDest)
    {
        [self sendMidiData:events length:size toDest:gUsbDest];
        return YES;
    }
    return NO;
}

- (void) sendUsbPort:(NSString*)port event:(unsigned char*)data length:(int)length
{
#ifdef DEBUG //debug auto play issue
    if ([port isEqualToString:self.MIDIPORT_Autoplay]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AutoPlayMidiControl" object:[NSData dataWithBytes:data length:length]];
        //        NSData *d=[NSData dataWithBytes:data length:length];
        //        NSLog(@"sendUsbPort %@ %@", port, d);
    }
    //    NSData *d=[NSData dataWithBytes:data length:length];
    //    NSLog(@"sendUsbPort %@ %@", port, d);
#endif
    
    MyMidiEndPoint *p=self.midiDests[port];
    if (p) {
        MIDIEndpointRef usbDest=p.endpointRef;
        [self sendMidiData:data length:length toDest:usbDest];
    }else if(data[0]!=0xf0){
        [self sendLocalEvents:data size:length];
    }
    
#ifdef DEBUG
    if(p==nil && self.gReceivMidiPortBlock){
        [self debugMidiTest:port event:data length:length];
    }
#endif
}
#ifdef DEBUG
- (void) debugResponseAck:(int)command port:(NSString*)port {
    //old ack
    //unsigned char buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,0x02,0x01,0x06,0xF7}; //ACK
    //new ack
    //unsigned char buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,0x00,0x01,0x00,0x01,0x06,0xF7}; //ACK
    
    static unsigned char ackBuffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,
        0x00,0x01, //command
        0x00,0x01, //param len
        0x06, //0x06:ACK, 0x07:NAK
        0xF7};
    ackBuffer[10]=command;
    //    if (self.receiveMidiPortBlock) {
    //        self.receiveMidiPortBlock(port, 0, ackBuffer, sizeof(ackBuffer)/sizeof(ackBuffer[0]));
    //    }else{
    self.receiveTestPortBlock(port, 0, ackBuffer, sizeof(ackBuffer)/sizeof(ackBuffer[0]));
    //    }
}
- (void) debugMidiTest:(NSString*)port event:(unsigned char*)data length:(int)length
{
#if 0
    if ([port isEqualToString:self.MIDIPORT_Autoplay]) {
        unsigned char cmd[7]={0xF0,0x7F,0x0C,0x03,0x00,0x00,0xF7};
        if (memcmp(data, cmd, 7)==0) {
            //request calibate data
            //F0 7F 0C 03 00 00 F7
            //response 88 data
            //F0 7F 0C 04 88xvv F7
            unsigned char buffer[]={0xf0, 0x7F, 0x0C,0x04,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0x01,0x02,0x01,0x02, 0x01,0x02,0x01,0x02,
                0xF7};
            UInt64 timastamp = mach_absolute_time();
            
            self.receiveMidiPortBlock(port,timastamp, buffer, 40);
            self.receiveMidiPortBlock(port,timastamp, &buffer[40], sizeof(buffer)/sizeof(buffer[0])-40);
        }else if (data[0]==kMIDIMessage_NoteOn) {
            //                usleep(0.01*1000*1000);
            //
            //                unsigned char buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,0x03,1,
            //                    0x06, //ACK
            //                    0xF7};
            //                self.receiveMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
            //
            //                unsigned char strengthBuf[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,0x03,3,
            //                    21, 0, 0,
            //                    0xF7};
            //
            //                strengthBuf[11]=data[1];
            //
            //                int k=(127-data[2])*16/127;
            //                int s=k*(512/16);
            //                strengthBuf[12]=(s>>7)&0x7f;
            //                strengthBuf[13]=s&0x7f;
            //                self.receiveMidiPortBlock(port, strengthBuf, sizeof(strengthBuf)/sizeof(strengthBuf[0]));
        }
    }
#endif
#ifdef DEBUG
    
    //loop test <f0004554 48445000 01000401 020304f7> <f0004554 48445000 00000000 04010203 04f7>
    static unsigned char looptestPrefix[]={0xf0,0x00,0x45,0x54,0x48,0x44,0x50,0x00,0x00,0x00,0x00,0x00};
    if (memcmp(data, looptestPrefix, sizeof(looptestPrefix)) == 0) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            usleep(0.001*1000*1000);
            dispatch_async(dispatch_get_main_queue(), ^{
                unsigned char ack_buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x00, 0x00,0x00, 0x00,0x04,0x01,0x02,0x03,0x04,0xF7};
                self.receiveTestPortBlock(port, 0, ack_buffer, sizeof(ack_buffer)/sizeof(ack_buffer[0]));
            });
        });
        return;
    }
    
    //发送力度曲线
    //block1: 1-4
    //F0 00 45 54 48 44 50 00 03 03 70 01 01
    //F0 00 45 54 48 44 50 00 03 03 70 01 02
    //F0 00 45 54 48 44 50 00 03 03 70 01 03
    //...
    //block2: 1-4
    //F0 00 45 54 48 44 50 00 03 03 70 02 01
    static unsigned char keyStrengthLinePrefix[]={0xF0, 0x00, 0x45, 0x54, 0x48, 0x44, 0x50, 0x00, 0x03};
    if(memcmp(data, keyStrengthLinePrefix, sizeof(keyStrengthLinePrefix)/sizeof(keyStrengthLinePrefix[0]))==0){
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            usleep(0.001*1000*1000);
            [self debugResponseAck:0x03 port:port];
        });
    }
    //need calibrate:
    //old: 0xf0,0x00,'E','T','H','D','P',0x00,0x01,0x02,0x01,0x00,0xF7
    //new: 0xF0,0x00,'E','T','H','D','P',0x00,0x02,0x00,0x01,0x00,0x01,0x00,0xF7
    static unsigned char reqBuf[]= {0xF0,0x00,'E','T','H','D','P',0x00,0x02,0x00,0x01,0x00,0x01,0x00,0xF7}; //need calibrate
    if (memcmp(reqBuf, data, length)==0) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            usleep(1*1000*1000);
            [self debugResponseAck:0x01 port:port];
        });
        return;
    }
    //
    static BOOL testingStrength=NO;
    static unsigned char beginStrength[]={0xf0,0x00,'E','T','H','D','P', 0x00,0x04,0x03,0x01,0x01,0xF7};
    if (memcmp(beginStrength, data, length)==0) {
        testingStrength=YES;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            usleep(1*1000*1000);
            [self debugResponseAck:0x03 port:port];
            //                unsigned char buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,0x03,1,
            //                    0x06, //ACK
            //                    0xF7};
            //                self.gReceivMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
            
            unsigned char strengthBuf[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,0x03,
                0, 3, //param len
                21, 0, 0, //params
                0xF7};
            for (int i=0; i<88 && testingStrength; i++) {
                strengthBuf[11]=21+i;
                for (int k=0; k<16 && testingStrength; k++) {
                    int s=k*(512/16);
                    strengthBuf[12]=(s>>7)&0x7f;
                    strengthBuf[13]=s&0x7f;
                    self.gReceivMidiPortBlock(port, 0, strengthBuf, sizeof(strengthBuf)/sizeof(strengthBuf[0]));
                    usleep(1*1000*1000);
                }
            }
        });
        return;
    }
#endif
#if 0
    //check keyboard status
    static unsigned char keyStatus[]={0xf0,0x00,'E','T','H','D','P', 0x00,0x01,0x02,0x01,0x03,0xF7};
    if (memcmp(keyStatus, data, length)==0) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            usleep(3*1000*1000);
            unsigned char buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,0x02,19,
                0x00,0x33,
                0x02,0x33,
                0x00,0x00,
                0x00,0x00,
                0x00,0x00,
                0x00,0x00,
                0x00,0x00,
                0x00,0x00,
                0x00,0x00,
                0x00,
                0xF7};
            self.receiveMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
        });
        return;
    }
    static BOOL calibrating=NO;
    static unsigned char beginCalibrate[]={0xf0,0x00,'E','T','H','D','P', 0x00,0x04,0x02,0x01,0x01,0xF7};
    if (memcmp(beginCalibrate, data, length)==0) {
        calibrating=YES;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            usleep(1*1000*1000);
            unsigned char ack_buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,0x02,0x01,0x06,0xF7}; //ACK
            self.receiveMidiPortBlock(port, ack_buffer, sizeof(ack_buffer)/sizeof(ack_buffer[0]));
            
            usleep(1*1000*1000);
            unsigned char buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x04,0x02,3,
                0x04,21,0x01,
                0xF7};
#if 0
            usleep(1*1000*1000);
            for (int i=0; i<20;i++) {
                buffer[12]=i+21;
                buffer[13]=0x01;
                self.receiveMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
            }
            usleep(1*1000*1000);
            for (int i=0; i<20;i++) {
                buffer[12]=i+21;
                buffer[13]=0x02;
                self.receiveMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
            }
#else
            for (int i=0; i<88 && calibrating; i++) {
                buffer[12]=i+21;
                buffer[13]=0x01;
                self.receiveMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
                usleep(1*1000*1000);
                
                buffer[13]=0x02;
                self.receiveMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
                usleep(1*1000*1000);
            }
#endif
        });
        return;
    }
    //F0 00 45 54 48 44 50 00 04 02 01 02 F7
    static unsigned char finishCalibrate[]={0xf0,0x00,'E','T','H','D','P', 0x00,0x04,0x02,0x01,0x02,0xF7};
    if (memcmp(finishCalibrate, data, length)==0) {
        calibrating=NO;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            usleep(1*1000*1000);
            
            unsigned char buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x04,0x02,2,
                0x05,0x01,
                0xF7};
            self.receiveMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
            usleep(2*1000*1000);
            
            buffer[12]=0x02;
            self.receiveMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
        });
        return;
    }
    
    //F0 00 45 54 48 44 50 00 04 03 01 02 F7
    static unsigned char endStrength[]={0xf0,0x00,'E','T','H','D','P', 0x00,0x04,0x03,0x01,0x02,0xF7};
    if (memcmp(endStrength, data, length)==0) {
        testingStrength=NO;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            usleep(1*1000*1000);
            
            unsigned char buffer[]={0xf0, 0x00, 'E','T','H','D','P',0x00,0x02,0x03,1,
                0x06, //ARK
                0xF7};
            self.receiveMidiPortBlock(port, buffer, sizeof(buffer)/sizeof(buffer[0]));
        });
        return;
    }
#endif
}
#endif

- (void) sendControlEvent:(int)control velocity:(int)velocity channel:(int)channel
{
    if (gUsbDest)
    {
        MIDIPacketList packetList;
        packetList.numPackets = 1;
        MIDIPacket* firstPacket = &packetList.packet[0];
        firstPacket->timeStamp = 0; // send immediately
        firstPacket->length = 3;
        firstPacket->data[0] = kMidiMessage_ControlChange|channel;
        firstPacket->data[1] = control;
        firstPacket->data[2] = velocity;
        MIDISend(gOutPort, gUsbDest, &packetList);
    }else{
#if TARGET_OS_IPHONE
        if ([NSThread isMainThread]) {
            [self sendControlEventLocal:control velocity:velocity channel:channel];
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendControlEventLocal:control velocity:velocity channel:channel];
            });
        }
#else
        MusicDeviceMIDIEvent(_samplerUnit,
                             kMidiMessage_ControlChange | channel,
                             control/*prog change num*/, velocity,
                             0/*sample offset*/);
#endif
    }
}
static int notes_on[MAX_Channel][128];//[channel][note]

- (void)stopAllNotes:(BOOL)local
{
    for (int channel=0; channel<MAX_Channel; channel++)
    {
        for (int note=0; note<128; note++) {
            if (notes_on[channel][note]>0) {
                if (local) {
                    _samplerUnit=_samplerUnit_Programs[samplerForChannel[channel]];
                    if (_samplerUnit) {
                        MusicDeviceMIDIEvent(_samplerUnit, kMIDIMessage_NoteOff | channel, note, 0, 0);
                    }
                }else if(gUsbDest){
                    MIDIPacketList packetList;
                    packetList.numPackets = 1;
                    MIDIPacket* firstPacket = &packetList.packet[0];
                    firstPacket->timeStamp = 0; // send immediately
                    firstPacket->length = 3;
                    firstPacket->data[0] = 0x90|channel;
                    firstPacket->data[2] = 0;
                    firstPacket->data[1] = note;
                    MIDISend(gOutPort, gUsbDest, &packetList);
                }
                notes_on[channel][note]=0;
            }
        }
    }
}
-(void)MidiEventInMainThreadLocal:(UInt32)note channel:(UInt32)channel on:(BOOL)on velocity:(UInt32)velocity
{
    AudioUnit unit;
    int sampler=0;
    if (channel<MAX_Channel) {
        sampler=samplerForChannel[channel];
    }
    if (sampler<0) {
        sampler=0;
    }
    unit=_samplerUnit_Programs[sampler];
    if (unit) {
        _samplerUnit=unit;
    }else{
        //        NSLog(@"can not find program for channel:%d",(int)channel);
    }
    if (note>=128 || channel>=MAX_Channel) {
        NSLog(@"too big note=%d, channel=%d", (unsigned int)note, (unsigned int)channel);
        return;
    }
    if (on) {
        //NSLog(@"b %d", (unsigned int)note);
        MusicDeviceMIDIEvent(_samplerUnit, kMIDIMessage_NoteOn | channel, note, velocity, 0);
        //NSLog(@"s %d:%d",(unsigned int)channel,(unsigned int)note);
        //notes_on[channel][note]++;
    }else{
        MusicDeviceMIDIEvent(_samplerUnit, kMIDIMessage_NoteOff | channel, note, 0, 0);
    }
}
- (void*)getAudioUnit
{
    return _samplerUnit=_samplerUnit_Programs[samplerForChannel[0]];
}
- (void)sendMidiNoteEvent:(UInt32)note velocity:(UInt32)velocity channel:(UInt32)channel on:(BOOL)on
{
    if (channel>=MAX_Channel || samplerForChannel[channel]<0) {
        NSLog(@"unknow channel=%d", (unsigned int)channel);
        //        return;
    }
    if (note>=128 || channel>=MAX_Channel) {
        NSLog(@"too big note=%d, channel=%d", (unsigned int)note, (unsigned int)channel);
        return;
    }
    
    if (gUsbDest) {
        MIDIPacketList packetList;
        packetList.numPackets = 1;
        MIDIPacket* firstPacket = &packetList.packet[0];
        firstPacket->timeStamp = 0; // send immediately
        firstPacket->length = 3;
        if (on) {
            firstPacket->data[0] = 0x90|channel;
            firstPacket->data[2] = velocity;
            notes_on[channel][note]++;
        }else{
            notes_on[channel][note]--;
            if (notes_on[channel][note]>0)
            {
                return;
            }
            firstPacket->data[0] = 0x90|channel;
            firstPacket->data[2] = 0;
        }
        firstPacket->data[1] = note;
        MIDISend(gOutPort, gUsbDest, &packetList);
    }else{
        [self MidiEventInMainThreadLocal:note channel:channel on:on velocity:velocity];
    }
}

- (void) playLocalMidiEvents:(unsigned char*)events size:(int)size{
    int index=0;
    unsigned char lastCmd = 0;
    while (index<size) {
        unsigned char evt = events[index]&0xf0;
        unsigned char channel = events[index]&0x0f;
        unsigned char nn = events[index+1];
        unsigned short vv = events[index+2];
        if (evt == kMIDIMessage_NoteOn && vv>0) {
            vv *= 1.2;
            if (vv>127) {
                vv=127;
            }
            index+=3;
        }else if (evt < 0x80) {
            evt=lastCmd;
            nn=events[index];
            vv=events[index+1];
            index+=2;
        }else if (evt==kMidiMessage_ProgramChange || evt==kMidiMessage_ChannelPressure) {
            index+=2;
        }else{
            index+=3;
        }
        lastCmd = evt;
        MusicDeviceMIDIEvent(_samplerUnit, evt+channel, nn, vv, 0);
    }
}

- (void) sendLocalEvents:(nonnull NSData*)data {
    Byte *byteArray = (Byte *)[data bytes];
    [self sendLocalEvents:byteArray size:(int)data.length];
}

- (void) setSamplerOfChannel:(int) channel {
    int sampler=0;
    if (channel<MAX_Channel) {
        sampler=samplerForChannel[channel];
    }
    if (sampler<0) {
        sampler=0;
    }
    AudioUnit unit=_samplerUnit_Programs[sampler];
    if (unit) {
        _samplerUnit=unit;
    }
}
- (void) sendLocalEvents:(unsigned char*)events size:(int)size{
    if ([NSThread isMainThread]) {
        int index=0;
        while (index<size) {
            //            int cmd = events[index]&0xf0;
            int channel = events[index]&0x0f;
            [self setSamplerOfChannel:channel];
            //            AudioUnit unit;
            //
            //            int sampler=0;
            //            if (channel<MAX_Channel) {
            //                sampler=samplerForChannel[channel];
            //            }
            //            if (sampler<0) {
            //                sampler=0;
            //            }
            //            unit=_samplerUnit_Programs[sampler];
            //            if (unit) {
            //                _samplerUnit=unit;
            //            }
            
            MusicDeviceMIDIEvent(_samplerUnit, events[index], events[index+1], events[index+2], 0);
            if ((events[index]&0xf0)==kMidiMessage_ProgramChange || (events[index]&0xf0)==kMidiMessage_ChannelPressure) {
                index+=2;
            }else{
                //                int cmd = events[index]&0xf0;
                //                int vel = events[index+2];
                //                BOOL on = NO;
                //                if (cmd == kMIDIMessage_NoteOn && vel>0) {
                //                    on = YES;
                //                }
                //                [self sendMidiNoteEvent:events[index+1] velocity:vel channel:events[index]&0x0f on:on];
                index+=3;
            }
        }
    }else{
        //        dispatch_sync(dispatch_get_main_queue(), ^{
        if (_samplerUnit==nil) {
            NSLog(@"Error: _samplerUnit=nil");
            //_samplerUnit=_samplerUnit_Programs[0];
        }
        int index=0;
        while (index<size) {
            int channel = events[index]&0x0f;
            [self setSamplerOfChannel:channel];
            OSStatus status = MusicDeviceMIDIEvent(_samplerUnit, events[index], events[index+1], events[index+2], 0);
            if (status!=noErr) {
                NSLog(@"MusicDeviceMIDIEvent status=%d",(int)status);
            }
            if ((events[index]&0xf0)==kMidiMessage_ProgramChange || (events[index]&0xf0)==kMidiMessage_ChannelPressure) {
                index+=2;
            }else{
                index+=3;
            }
        }
        //        });
    }
}

//- (void) sendLocalEvents:(unsigned char*)events size:(int)size{
//    if ([NSThread isMainThread]) {
//        int index=0;
//        while (index<size) {
//            MusicDeviceMIDIEvent(_samplerUnit, events[index], events[index+1], events[index+2], 0);
//            if ((events[index]&0xf0)==kMidiMessage_ProgramChange || (events[index]&0xf0)==kMidiMessage_ChannelPressure) {
//                index+=2;
//            }else{
//                index+=3;
//            }
//        }
//    }else{
////        dispatch_sync(dispatch_get_main_queue(), ^{
//            if (_samplerUnit==nil) {
//                NSLog(@"Error: _samplerUnit=nil");
//                //_samplerUnit=_samplerUnit_Programs[0];
//            }
//            int index=0;
//            while (index<size) {
//                OSStatus status = MusicDeviceMIDIEvent(_samplerUnit, events[index], events[index+1], events[index+2], 0);
//                if (status!=noErr) {
//                    NSLog(@"MusicDeviceMIDIEvent status=%d",(int)status);
//                }
//                if ((events[index]&0xf0)==kMidiMessage_ProgramChange || (events[index]&0xf0)==kMidiMessage_ChannelPressure) {
//                    index+=2;
//                }else{
//                    index+=3;
//                }
//            }
////        });
//    }
//}
- (void) sendMidiEvents:(unsigned char*)events size:(int)size{
    
    if (gUsbDest) {
        [self sendUsbEvent:events length:size];
    }else{
        if ([NSThread isMainThread]) {
            int index=0;
            while (index<size) {
                MusicDeviceMIDIEvent(_samplerUnit, events[index], events[index+1], events[index+2], 0);
                if ((events[index]&0xf0)==kMidiMessage_ProgramChange || (events[index]&0xf0)==kMidiMessage_ChannelPressure) {
                    index+=2;
                }else{
                    index+=3;
                }
            }
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                int index=0;
                while (index<size) {
                    MusicDeviceMIDIEvent(_samplerUnit, events[index], events[index+1], events[index+2], 0);
                    if ((events[index]&0xf0)==kMidiMessage_ProgramChange || (events[index]&0xf0)==kMidiMessage_ChannelPressure) {
                        index+=2;
                    }else{
                        index+=3;
                    }
                }
            });
        }
    }
}

// Play the mid note
//noteNum: CDEFGAB,60-67
- (void) startPlayMidNote:(UInt32)note velocity:(UInt32)velocity channel:(UInt32)channel
{
    if (notes_on[channel][note]>0) {
        NSLog(@"stop first notes_on[%d][%d]=%d", (unsigned int)channel, (unsigned int)note, notes_on[channel][note]);
        //MusicDeviceMIDIEvent(_samplerUnit, kMIDIMessage_NoteOff | channel, note, 0, 0);
        if ([NSThread isMainThread]) {
            [self sendMidiNoteEvent:note velocity:0 channel:channel on:NO];
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendMidiNoteEvent:note velocity:0 channel:channel on:NO];
            });
        }
        notes_on[channel][note]=0;
    }
    
    //NSLog(@"b %d", (unsigned int)note);
    //MusicDeviceMIDIEvent(_samplerUnit, kMIDIMessage_NoteOn | channel, note, velocity, 0);
    if ([NSThread isMainThread]) {
        [self sendMidiNoteEvent:note velocity:velocity channel:channel on:YES];
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendMidiNoteEvent:note velocity:velocity channel:channel on:YES];
        });
    }
    //NSLog(@"s %d:%d",(unsigned int)channel,(unsigned int)note);
    notes_on[channel][note]++;
}

// Stop the mid note
- (void) stopPlayMidNote:(UInt32)note channel:(UInt32)channel
{
    notes_on[channel][note]--;
    if (notes_on[channel][note]<=0)
    {
        //NSLog(@"e %d", (unsigned int)note);
        //MusicDeviceMIDIEvent(_samplerUnit, kMIDIMessage_NoteOff | channel, note, 0, 0);
        if ([NSThread isMainThread]) {
            [self sendMidiNoteEvent:note velocity:0 channel:channel on:NO];
        }else{
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self sendMidiNoteEvent:note velocity:0 channel:channel on:NO];
            });
        }
        //NSLog(@"e %d:%d", (unsigned int)channel,(unsigned int)note);
        notes_on[channel][note]=0;
    }else{
        NSLog(@"dont stop notes_on[%d][%d]=%d", (unsigned int)channel, (unsigned int)note, notes_on[channel][note]);
    }
}

#pragma mark - play midi files
- (void) onMidiPlayProgress:(NSNumber*)time_stamp
{
    if (progress_target) {
        if (self.playStatus!=MS_PAUSED) {
            self.curTime+=1;
            float now = self.curTime;
            if (self.playStatus==MS_STOPPED) {
                now=midi_total_seconds;
            }
            if (now >= midi_total_seconds)
            {
                now = midi_total_seconds;
                [timer invalidate];
                timer=nil;
            }
            
            NSRange range;
            range.length=round(midi_total_seconds);
            range.location=round(now);
            //NSLog(@"p(%f/%f)", self.curTime, midi_total_seconds);
            [progress_target performSelectorOnMainThread:progress_action withObject:[NSValue valueWithRange:range] waitUntilDone:NO];
        }
    }
}
- (void) stopNoteEvent:(MyMIDINoteMessage*)event
{
    MIDINoteMessage *note_event=[event getNoteMessage];
    OSStatus result = MusicDeviceMIDIEvent(_samplerUnit, kMIDIMessage_NoteOff|note_event->channel, note_event->note, note_event->releaseVelocity, 0);
    if (result!=noErr) {
        NSLog(@"Error MusicDeviceMIDIEvent=%d", (int)result);
    }
}
- (void) playMidiThread:(MyMusicSequence*)my_sequence
{
    OSStatus result = noErr;
    MusicSequence sequence=[my_sequence getSequence];
    
    self.playStatus=MS_PLAYING;
    
    //midi track
    UInt32 numberOfTracks;
    MusicSequenceGetTrackCount(sequence, &numberOfTracks);
    NSLog(@"numberOfTracks=%d",(int)numberOfTracks);
    
    MusicTrack track0;
    MusicSequenceGetIndTrack(sequence, 0, &track0);
    
    //merge tracks to track0
    /*
     for (int i=1; i<numberOfTracks; i++) {
     MusicTrack source_track;
     MusicSequenceGetIndTrack(sequence, i, &source_track);
     MusicTrackMerge(source_track, 0, midi_total_beats, track0, 0);
     }
     */
    {
        MusicEventIterator iterator;
        MusicTimeStamp time_stamp=0;//, pre_time_stamp=0;
        Float64 pre_seconds=0;
        Float32 last_duration=0;
        Float64 cur_seconds=0;
        
        NewMusicEventIterator(track0, &iterator);
        while (YES) {
            MusicEventType event_type;
            const void *event_data;
            UInt32 event_size;
            
            MusicEventIteratorGetEventInfo(iterator, &time_stamp, &event_type, &event_data, &event_size);
            MusicSequenceGetSecondsForBeats(sequence, time_stamp, &cur_seconds);
            
            if (cur_seconds>pre_seconds) {
                usleep((cur_seconds-pre_seconds)*1000*1000);
                pre_seconds=cur_seconds;
            }
            if (self.playStatus==MS_STOP_REQ) {
                break;
            }else if(self.playStatus==MS_PAUSED)
            {
                while (self.playStatus==MS_PAUSED) {
                    usleep(100);
                }
                self.curTime=cur_seconds;
            }
            switch (event_type) {
                case kMusicEventType_MIDINoteMessage:
                {
                    MIDINoteMessage *note_event=(MIDINoteMessage *)event_data;
                    last_duration=note_event->duration;
#if 0//def DEBUG
                    int noteNumber = ((int) note_event->note) % 12;
                    NSString *noteType;
                    switch (noteNumber) {
                        case 0:
                            noteType = @"C";
                            break;
                        case 1:
                            noteType = @"C#";
                            break;
                        case 2:
                            noteType = @"D";
                            break;
                        case 3:
                            noteType = @"D#";
                            break;
                        case 4:
                            noteType = @"E";
                            break;
                        case 5:
                            noteType = @"F";
                            break;
                        case 6:
                            noteType = @"F#";
                            break;
                        case 7:
                            noteType = @"G";
                            break;
                        case 8:
                            noteType = @"G#";
                            break;
                        case 9:
                            noteType = @"A";
                            break;
                        case 10:
                            noteType = @"Bb";
                            break;
                        case 11:
                            noteType = @"B";
                            break;
                        default:
                            noteType = [NSString stringWithFormat: @"unknow noteType(%d)",noteNumber];
                            break;
                    }
                    NSLog(@"%@: %i duration=%f", noteType, noteNumber, note_event->duration);
#endif
                    int velocity=note_event->velocity*1.2;
                    if (velocity>127) {
                        velocity=127;
                    }
                    //NSLog(@"[%f:%f] %ld, %ld, (%x,%x,%x,%x) %f", time_stamp*60.0/l_bpm,cur_seconds,event_type,event_size, note_event->channel, note_event->note,note_event->velocity,note_event->releaseVelocity,note_event->duration);
                    result = MusicDeviceMIDIEvent(_samplerUnit, kMIDIMessage_NoteOn|note_event->channel, note_event->note, velocity, 0);
                    if (result!=noErr) {
                        NSLog(@"Error MusicDeviceMIDIEvent=%d", (int)result);
                    }
                    MyMIDINoteMessage *vv=[[MyMIDINoteMessage alloc]initWithNoteMessage:note_event];
                    [self performSelector:@selector(stopNoteEvent:) withObject:vv afterDelay:note_event->duration];
                    
                    break;
                }
                case kMusicEventType_MIDIChannelMessage:
                {
                    MIDIChannelMessage *channel_message=(MIDIChannelMessage*)event_data;
                    NSLog(@"[%f] %d, %d, (%x,%x,%x,%x)", time_stamp,(unsigned int)event_type,(int)event_size, channel_message->status, channel_message->data1,channel_message->data2, channel_message->reserved);
                    result = MusicDeviceMIDIEvent(_samplerUnit, channel_message->status, channel_message->data1, channel_message->data2, 0);
                    if (result!=noErr) {
                        NSLog(@"Error MusicDeviceMIDIEvent=%d", (int)result);
                    }
                    break;
                }
                case kMusicEventType_Meta:
                {
                    MIDIMetaEvent *meta_event=(MIDIMetaEvent*)event_data;
                    switch (meta_event->metaEventType) {
                        case 0x03: { // 音序或 track 的名称。
                            //p[len]=0;
                            //NSString *name=[NSString stringWithCString:meta_event->data encoding:NSUTF8StringEncoding];
                            NSLog(@"[%f] %d, %d, type:0x%x len=%d(%s)", time_stamp, (unsigned int)event_type, (int)event_size, meta_event->metaEventType, (int)meta_event->dataLength, meta_event->data);
                            break;
                        }
                        case 0x04: { //乐器名称
                            //NSString *name=[NSString stringWithCString:meta_event->data encoding:NSUTF8StringEncoding];
                            NSLog(@"[%f] %d, %d, type:0x%x len=%d(%s)", time_stamp, (unsigned int)event_type, (unsigned int)event_size, meta_event->metaEventType, (unsigned int)meta_event->dataLength, meta_event->data);
                            break;
                        }
                        default:
                            NSLog(@"[%f] %d, %d, type:0x%x len=%d(%x,%x,%x,%x)", time_stamp, (unsigned int)event_type, (unsigned int)event_size, meta_event->metaEventType, (unsigned int)meta_event->dataLength, meta_event->data[0], meta_event->data[1], meta_event->data[2], meta_event->data[3]);
                            break;
                    }
                    break;
                }
                default:
                    NSLog(@"[%f] %d, %d", time_stamp,(unsigned int)event_type,(unsigned int)event_size);
                    break;
            }
            
            result = MusicEventIteratorNextEvent(iterator);
            if (result!=noErr) {
                usleep(last_duration*1000*1000);
                NSLog(@"Finished!");
                cur_seconds=midi_total_seconds;
                break;
            }
        }
        DisposeMusicEventIterator(iterator);
    }
    DisposeMusicSequence(sequence);
    self.playStatus=MS_STOPPED;
}
//return midi total time (seconds)
- (float) playMidi:(NSData*)midi_data target:(id)target progressAction:(SEL)action
{
    OSStatus result = noErr;
    progress_action=action;
    progress_target=target;
    
    if (_processingGraph==nil) {
        [self midiDeviceOpen];
    }
    if (self.playStatus!=MS_STOPPED) {
        [self stopMidi];
    }
    // Create a new music sequence
    // Initialise the music sequence
    MusicSequence s;
    result = NewMusicSequence(&s);
    if (result != noErr) NSLog (@"NewMusicSequence. Error code: %d '%.4s'\n", (int) result, (const char *)&result);
    
    result = MusicSequenceFileLoadData(s, (__bridge CFDataRef)midi_data, kMusicSequenceFile_MIDIType, kMusicSequenceLoadSMF_ChannelsToTracks);
    if (result != noErr) NSLog (@"MusicSequenceFileLoadData. Error code: %d '%.4s'\n", (int) result, (const char *)&result);
    
    
    //[self performSelectorInBackground:@selector(playMidiThread:) withObject:midi_data];
    
    //Tempo Track
    MusicTrack tempoTrack;
    //analyze never read
    //    float bpm=120;//beats per minute
    
    MusicSequenceGetTempoTrack(s, &tempoTrack);
    {
        MusicEventIterator iterator;
        MusicTimeStamp time_stamp;//, pre_time_stamp=0;
        Float64 cur_seconds=0;
        NewMusicEventIterator(tempoTrack, &iterator);
        while (self.playStatus != MS_STOPPED) {
            MusicEventType event_type;
            const void *event_data;
            UInt32 event_size;
            
            MusicEventIteratorGetEventInfo(iterator, &time_stamp, &event_type, &event_data, &event_size);
            MusicSequenceGetSecondsForBeats(s, time_stamp, &cur_seconds);
            
            switch (event_type) {
                case kMusicEventType_Meta:
                {
                    MIDIMetaEvent *meta_event=(MIDIMetaEvent*)event_data;
                    if (meta_event->metaEventType==0x58) {//拍子记号: 如： 6/8 用 nn=6，dd=3 (2^3)表示。
                        unsigned char numerator=meta_event->data[0];//分子
                        unsigned char denominator = (int) pow((float) 2, meta_event->data[1]); //分母表示为 2 的(dd次)冥
                        unsigned char number_ticks = meta_event->data[2]; //每个 MIDI 时钟节拍器的 tick 数目
                        unsigned char number_32nd_notes = meta_event->data[3]; //24个MIDI时钟中1/32音符的数目(8是标准的)
                        NSLog(@"[%f] %d, %d, type:0x%x len=%d(%d/%d 0x%x,0x%x)", time_stamp, (unsigned int)event_type, (unsigned int)event_size, meta_event->metaEventType, (unsigned int)meta_event->dataLength, numerator, denominator, number_ticks, number_32nd_notes);
                    }else{
                        NSLog(@"[%f] %d, %d, type:0x%x len=%d(%x,%x,%x,%x)", time_stamp, (unsigned int)event_type, (unsigned int)event_size, meta_event->metaEventType, (unsigned int)meta_event->dataLength, meta_event->data[0], meta_event->data[1], meta_event->data[2], meta_event->data[3]);
                    }
                    break;
                }
                case kMusicEventType_ExtendedTempo:
                {
                    ExtendedTempoEvent *tempo_event=(ExtendedTempoEvent*)event_data;
                    //bpm: beats per minute
                    //analyze never read
                    //                    bpm=tempo_event->bpm;
                    NSLog(@"[%f] %d, %d, bpm:%f", time_stamp, (unsigned int)event_type, (unsigned int)event_size, tempo_event->bpm);
                    break;
                }
                default:
                    NSLog(@"[%f] %d, %d", time_stamp,(unsigned int)event_type,(unsigned int)event_size);
                    break;
            }
            
            result = MusicEventIteratorNextEvent(iterator);
            if (result!=noErr) {
                NSLog(@"Finished!");
                break;
            }
        }
        DisposeMusicEventIterator(iterator);
    }
    if (progress_target) {
        MusicTrack t;
        
        UInt32 numberOfTracks;
        MusicSequenceGetTrackCount(s, &numberOfTracks);
        for (int i=0; i<numberOfTracks; i++) {
            UInt32 sz = sizeof(MusicTimeStamp);
            MusicSequenceGetIndTrack(s, i, &t);
            MusicTrackGetProperty(t, kSequenceTrackProperty_TrackLength, &midi_total_beats, &sz);
            MusicSequenceGetSecondsForBeats(s, midi_total_beats, &midi_total_seconds);
            NSLog(@"midi_total_beats[%d]=%f beats, %f seconds", i, midi_total_beats, midi_total_seconds);
        }
        
        self.curTime=0;
        if (timer==nil) {
            timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(onMidiPlayProgress:) userInfo:nil repeats:YES];
        }
        
        //send first progress
        NSRange range;
        range.length=round(midi_total_seconds);
        range.location=0;
        [progress_target performSelectorOnMainThread:progress_action withObject:[NSValue valueWithRange:range] waitUntilDone:NO];
    }
    
    MyMusicSequence *my_sequence=[[MyMusicSequence alloc]init];
    [my_sequence setSequence:s];
    [NSThread detachNewThreadSelector:@selector(playMidiThread:) toTarget:self withObject:my_sequence];
    return midi_total_seconds;
}

- (void) stopMidi
{
    [timer invalidate];
    timer=nil;
    if (self.playStatus!=MS_STOPPED) {
        self.playStatus=MS_STOP_REQ;
        while (self.playStatus!=MS_STOPPED) {
            usleep(100);
        }
    }
}
- (void) pauseMidi:(BOOL) paused
{
    if (self.playStatus!=MS_STOPPED)
    {
        if (paused) {
            self.playStatus=MS_PAUSED;
            NSLog (@"Stopping audio processing graph");
            Boolean isRunning = false;
            OSStatus result = AUGraphIsRunning (_processingGraph, &isRunning);
            if (noErr != result) {
                NSLog(@"AUGraphIsRunning failed");
                return;
            }
            
            if (isRunning) {
                AUGraphStop (_processingGraph);
            }
        }else{
            self.playStatus=MS_PLAYING;
            OSStatus result = AUGraphStart (_processingGraph);
            if (noErr != result) {
                NSLog(@"AUGraphStart failed res=%x",(int)result);
                return;
            }
        }
    }
}

- (BOOL) isPlaying
{
    return self.playStatus==MS_PLAYING;
}
- (BOOL) isStopped
{
    return self.playStatus==MS_STOPPED;
}


MusicPlayer musicPlayer;
MusicSequence musicSequence;
+(void) playMidiFile:(NSString*) name
{
#if 1
    NewMusicSequence(&musicSequence);
    NSURL * midiFileURL = [NSURL fileURLWithPath:name];
    MusicSequenceFileLoad(musicSequence, (__bridge CFURLRef)midiFileURL, 0, kMusicSequenceLoadSMF_ChannelsToTracks);
    
    NewMusicPlayer(&musicPlayer);
    MusicPlayerSetSequence(musicPlayer, musicSequence);
    
    MusicPlayerPreroll(musicPlayer);
    MusicPlayerStart(musicPlayer);
    
    UInt32 tracks;
    if (MusicSequenceGetTrackCount(musicSequence, &tracks) != noErr)
        for (UInt32 i = 0; i < tracks; i++) {
            MusicTrack track = NULL;
            MusicTimeStamp trackLen = 0;
            
            UInt32 trackLenLen = sizeof(trackLen);
            
            MusicSequenceGetIndTrack(musicSequence, i, &track);
            
            MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &trackLen, &trackLenLen);
            MusicTrackLoopInfo loopInfo = { trackLen, 0 };
            MusicTrackSetProperty(track, kSequenceTrackProperty_LoopInfo, &loopInfo, sizeof(loopInfo));
            NSLog(@"track length is %f", trackLen);
        }
#else
    NSString *presetURLPath = [[NSBundle mainBundle] pathForResource:@"GortsMiniPianoJ1" ofType:@"SF2"];
    NSURL * presetURL = [NSURL fileURLWithPath:presetURLPath];
    [self loadFromDLSOrSoundFont: (NSURL *)presetURL withPatch: (int)3];
    
    NSString *midiFilePath = [[NSBundle mainBundle] pathForResource:name ofType:@"mid"];
    NSURL * midiFileURL = [NSURL fileURLWithPath:midiFilePath];
    
    NewMusicPlayer(&musicPlayer);
    
    if (NewMusicSequence(&musicSequence) != noErr)
    {
        [NSException raise:@"play" format:@"Can't create MusicSequence"];
    }
    
    if(MusicSequenceFileLoad(musicSequence, (__bridge CFURLRef)midiFileURL, 0, 0 != noErr))
    {
        [NSException raise:@"play" format:@"Can't load MusicSequence"];
    }
    
    MusicPlayerSetSequence(musicPlayer, musicSequence);
    MusicSequenceSetAUGraph(musicSequence, _processingGraph);
    MusicPlayerPreroll(musicPlayer);
    MusicPlayerStart(musicPlayer);
#endif
}
-(void) stopMidiPlaying
{
    
    OSStatus result = noErr;
    result = MusicPlayerStop(musicPlayer);
    
    UInt32 trackCount;
    MusicSequenceGetTrackCount(musicSequence, &trackCount);
    
    MusicTrack track;
    for(int i=0;i<trackCount;i++)
    {
        MusicSequenceGetIndTrack (musicSequence,0,&track);
        result = MusicSequenceDisposeTrack(musicSequence, track);
    }
    
    result = DisposeMusicPlayer(musicPlayer);
    result = DisposeMusicSequence(musicSequence);
    result = DisposeAUGraph(_processingGraph);
    
    if (result != noErr)
        NSLog (@"stopMidiPlaying. Error code: %d '%.4s'\n", (int) result, (const char *)&result);
}

#pragma mark - download the soundfont file

-(BOOL)checkSoundFont{
    //check
#if 1
    self.soundInDocumentDir=[[NSBundle mainBundle] pathForResource:@"TimGM6mb" ofType:@"sf2"];
    return YES;
#else
    BOOL have_soundlib=NO;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dcoumentpath = paths.firstObject;
    self.soundInDocumentDir = [dcoumentpath stringByAppendingPathComponent:@"TimGM6mb.sf2"];
    NSFileManager *manager=[NSFileManager defaultManager];
    if (![manager fileExistsAtPath:self.soundInDocumentDir]) {
        NSError *error;
        NSString* soundInResource = [[NSBundle mainBundle] pathForResource:@"TimGM6mb" ofType:@"sf2"];
        if ([manager fileExistsAtPath:soundInResource]) {
            have_soundlib=[manager copyItemAtPath:soundInResource toPath:self.soundInDocumentDir error:&error];
        }
        if (have_soundlib) {
            [[NSURL fileURLWithPath:self.soundInDocumentDir] setResourceValue: [NSNumber numberWithBool: YES]
                                                                       forKey: NSURLIsExcludedFromBackupKey error: &error];
        }
    }else{
        have_soundlib=YES;
    }
    
    return have_soundlib;
#endif
}
@end

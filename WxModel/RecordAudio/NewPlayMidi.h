//
//  NewPlayMidi.h
//  WeexDemo
//
//  Created by 徐林琳 on 2018/7/24.
//  Copyright © 2018年 taobao. All rights reserved.
//

@import AudioToolbox;
#import <Foundation/Foundation.h>
#include <CoreMIDI/CoreMIDI.h>

typedef void(^StatusChangeBlock)(NSString * _Nullable status);
typedef void(^CurtimeChangeBlock)(double curTime);


//midi only for IOS5
@protocol NewPlayMidiDelegate;


@interface NewPlayMidi : NSObject
@property (nonatomic, strong, nullable)StatusChangeBlock statusBlock;
@property (nonatomic, strong, nullable)CurtimeChangeBlock curtimeBlock;


@property (nonatomic,weak,nullable) id<NewPlayMidiDelegate> delegate;
@property (strong,nullable) NSArray <NSString*> *midiInputDevices;
@property (strong,nullable) NSArray <NSString*> *midiOutputDevices;
@property (nonatomic, strong,nullable) NSString *curInputDevice, *curOutputDevice;
@property (nonatomic, assign) float volume;
@property (nonatomic, assign) int playStatus;
@property (nonatomic, assign) float curTime;
@property (nonatomic, assign) BOOL isMidiStick;
@property (nonatomic, strong, nullable) NSString *MIDIPORT_stick;

@property (nonatomic, strong, nonnull) NSString *MIDIPORT_NewPrefix, *MIDIPORT_Normal, *MIDIPORT_Autoplay, *MIDIPORT_Test;

+ (nonnull NewPlayMidi*)getMidiPlayer;
+ (void)closeMidiPlayer;
+ (void)resetMidiPlayer;
- (void)reloadExternalMidiDevices;

- (void) stopPlayMidNote:(UInt32)note channel:(UInt32)channel;
- (void) startPlayMidNote:(UInt32)note velocity:(UInt32)velocity channel:(UInt32)channel;
- (void)stopAllNotes:(BOOL)local;

enum {
    kMIDIMessage_NoteOff            = 0x80,//8n: 关闭n通道发音; xx: 音符00~7F; vv:力度00~7F
    kMIDIMessage_NoteOn             = 0x90,//9n: 打开n通道发音; xx: 音符00~7F; vv:力度00~7F
    kMIDIMessage_Note_Aftertouch    = 0xA0,//An: 触摸键盘以后;  音符:00~7F aftertouch value:00~7F. AfterTouch (ie, key pressure)
    kMidiMessage_ControlChange      = 0xB0,//Bn: 控制器;       控制器号码:00~7F 控制器参数:00~7F. Control Change
    kMidiMessage_ProgramChange      = 0xC0,//Cn: 切换音色;     乐器号码:00~7F, vv:not used. Program (patch) change
    kMidiMessage_ChannelPressure    = 0xD0,//Dn: 通道演奏压力(可近似认为是音量) 值:00~7F, vv:not used. Channel Pressure
    kMidiMessage_PitchWheel         = 0xE0,//En: 设置n通道音高, pitch value (LSB)    pitch value (MSB). Pitch Wheel
    kMidiMessage_BankMSBControl     = 0,
    kMidiMessage_BankLSBControl     = 32,
};

#define GM_Control_BankSelect       0
#define GM_Control_BankLSB  32
#define GM_Control_Modulation_Wheel 1
#define GM_Control_Volumel 7
#define GM_Control_Pan  10
#define GM_Control_Expression  11
#define GM_Control_Pedal 64
#define GM_Control_Pedal_mid 66 //soft pedal
#define GM_Control_Pedal_left 67 //Legato footswitch
#define GM_Control_ResetAllControl 121
#define GM_Control_AllNotesOff  123 //0x7B

#define GM_Control_VolumelWheelSub 0x60
#define GM_Control_VolumelWheelAdd 0x61
#define GM_Control_Pedal_1 0x74
#define GM_Control_Pedal_2 0x75
#define GM_Control_Pedal_3 0x76//0x77 //0x76
#define GM_Control_Pedal_4 0x77//0x76 //0x77

- (void) sendControlEvent:(int)control velocity:(int)velocity channel:(int)channel;

//Piano（钢 琴）
#define GM_Program_Piano    1 //1 Acoustic Grand Piano    平台钢琴
#define GM_Program_Piano_max    8
//Chromatic Percussion（半音阶打击乐器）
#define GM_Program_Marimba    13 //13    Marimba    马林巴琴
//Organ（风 琴）
#define GM_Program_ChurchOrgan  20//20    Church organ    教堂管风琴
//Guitar（吉 他）
#define GM_Program_Guitar   25 //25 木吉他（尼龙弦）
#define GM_Program_AcousticGuitar   26 //26    Acoustic Guitar（steel）    木吉他（钢弦）
#define GM_Program_ElectricGuitar   27 // 27 Electric Guitar（jazz）    电吉他（爵士）
#define GM_Guitar_harmonics 32    //Guitar harmonics    吉他泛音
//Bass（贝 斯）
#define GM_Program_Bass     33 //33 民谣贝斯
//Strings（弦 乐 器）
#define GM_Program_Violin   41 //小提琴
#define GM_Program_Viola    42 //中提琴
#define GM_Program_Cello    43 //大提琴
#define GM_Program_Contrabass    44 //    低音大提琴
#define GM_Program_Timpani 48    //Timpani    定音鼓
//Ensemble（合 奏）
#define GM_Program_StringEnsemble    49 //49    String Ensemble 1    弦乐合奏 1
#define GM_Program_SynthStrings2    52//52    Synth Strings 2    合成弦乐 2
#define GM_Program_Voice_Aahs 53    //Voice Aahs    人声“啊”
#define GM_Program_Voice_Oohs 54    //Voice Oohs    人声“喔”
#define GM_Program_Synth_Voice 55    //Synth Voice    合成人声
//Brass（铜 管 乐 器）
#define GM_Program_Trumpet 57    //Trumpet    小号
#define GM_Program_Trombone 58    //Trombone    长号
#define GM_Program_Tuba 59    //Tuba    大号（吐巴号、低音号）
#define GM_Program_FrenchHorn 61    //French horn    法国号（圆号）
//Reed（簧 乐 器）
#define GM_Program_SopranoSax 65    //Soprano Sax    高音萨克斯风
#define GM_Program_AltoSax  66    //Alto Sax    中音萨克斯风
#define GM_Program_Oboe 69    //Oboe    双簧管
#define GM_Program_Clarinet 72    //Clarinet    单簧管（黑管、竖笛）
//Pipe（吹 管 乐 器）
#define GM_Program_Piccolo 73    //Piccolo    短笛
#define GM_Program_Flute 74    //Flute    长笛
#define GM_Program_Whistle 79    //Whistle    哨子
//Synth Lead(合成音 主旋律)
#define GM_Program_Voice 86     //voice 人声键盘
//Percussive（打 击 乐 器）
#define GM_Program_TinkleBell 113    //Tinkle Bell    叮当铃
#define GM_Program_Agogo 114    //Agogo    阿哥哥鼓
#define GM_Program_SteelDrums 115    //Steel Drums    钢鼓
#define GM_Program_Woodblock 116    //Woodblock    木鱼
#define GM_Program_TaikoDrum 117    //Taiko Drum    太鼓
#define GM_Program_MelodicTom 118    //Melodic Tom    定音筒鼓
#define GM_Program_SynthDrum 119    //Synth Drum    合成鼓
#define GM_Program_ReverseCymbal 120    //Reverse Cymbal    逆转钹声
//Sound effects（特 殊 音 效）
#define GM_Program_GuitarFretNoise 121    //Guitar Fret Noise    吉他滑弦杂音
#define GM_Program_BreathNoise 122    //Breath Noise    呼吸杂音
#define GM_Program_Seashore 123    //Seashore    海岸
#define GM_Program_BirdTweet 124    //Bird Tweet    鸟鸣
#define GM_Program_Telephone Ring 125    //Telephone Ring    电话铃声
#define GM_Program_Helicopter 126    //Helicopter    直升机
#define GM_Program_Applause 127    //Applause    拍手
#define GM_Program_Gunshot 128    //Gunshot    枪声

- (void) resetPrograms;
- (void) sendProgramEvent:(int)program channel:(int)channel;
- (void) sendMidiChannelPressure:(int)pressure;
- (void) sendMidiPitchWheel:(int)velocity;
- (void) sendMidiEvents:(nonnull unsigned char*)events size:(int)size;
- (void) playLocalMidiEvents:(nonnull unsigned char*)events size:(int)size;
- (void) sendLocalEvents:(nonnull unsigned char*)events size:(int)size;
- (void) sendLocalEvents:(nonnull NSData*)events;

- (BOOL) sendUsbEvent:(nonnull unsigned char*)data length:(int)length;
- (void) sendUsbPort:(nonnull NSString*)port event:(nonnull unsigned char*)data length:(int)length;
- (void) sendUsbPortSysex:(nonnull NSString*)port event:(nonnull unsigned char*)data length:(int)length;

typedef void(^ReceivedMidiEventBlock)( NSString * _Nullable port, UInt64 timestamp, const unsigned char * _Nonnull data, int length);

@property (nonatomic, strong, nullable)ReceivedMidiEventBlock receiveMidiPortBlock, gReceivMidiPortBlock, receiveTestPortBlock;
@property (nonatomic, assign)double timestampMidiPort;
- (void)listenAllInputDevice;
//typedef void(^PianoKeyBlock)(unsigned char key, BOOL down);
//@property (nonatomic, copy) PianoKeyBlock pianoKeyBlock;
//- (void)sendMidiData:(unsigned char*)events length:(int)size toDest:(MIDIEndpointRef) usbDest;

//play midi file
- (float) playMidi:(nonnull NSData*)midi_data target:(nonnull id)target progressAction:(nonnull SEL)action;
- (void) stopMidi;
- (void) pauseMidi:(BOOL) paused;
- (BOOL) isPlaying;
- (BOOL) isStopped;
+(void) playMidiFile:(nonnull NSString*) name;
+(nullable NSString*)nameForPatch:(int)patch;
+(int)patchForInstrumentName:(nonnull NSString*)name;
- (nonnull void*)getAudioUnit;

@property (nonatomic, readonly, nullable) AudioUnit currentSampleUnit;

@end

@protocol NewPlayMidiDelegate <NSObject>
- (void)midiEventReceived:(nullable MIDIPacket*)midiPacket;
@end

/*******************************************************************************
 Copyright (c) 2013 Koninklijke Philips N.V.
 All Rights Reserved.
 ********************************************************************************/

#import "PHControlLightsViewController.h"
#import "PHAppDelegate.h"

#import <HueSDK_iOS/HueSDK.h>
#define MAX_HUE 65535

@interface PHControlLightsViewController()

@property (nonatomic,weak) IBOutlet UILabel *bridgeIdLabel;
@property (nonatomic,weak) IBOutlet UILabel *bridgeIpLabel;
@property (nonatomic,weak) IBOutlet UILabel *bridgeLastHeartbeatLabel;
@property (nonatomic,weak) IBOutlet UIButton *randomLightsButton;
@property (weak,nonatomic) IBOutlet UIButton *turnOnDesktopButton;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UIButton *playBackButton;
@property (strong, nonatomic) NSMutableArray * beatTimeArray;
@property CGFloat startTime;
@end


@implementation PHControlLightsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    PHNotificationManager *notificationManager = [PHNotificationManager defaultManager];
    // Register for the local heartbeat notifications
    [notificationManager registerObject:self withSelector:@selector(localConnection) forNotification:LOCAL_CONNECTION_NOTIFICATION];
    [notificationManager registerObject:self withSelector:@selector(noLocalConnection) forNotification:NO_LOCAL_CONNECTION_NOTIFICATION];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Find bridge" style:UIBarButtonItemStylePlain target:self action:@selector(findNewBridgeButtonAction)];
    
    self.navigationItem.title = @"QuickStart";
    
    [self noLocalConnection];
    
    self.beatTimeArray = [[NSMutableArray alloc] init];
}

- (UIRectEdge)edgesForExtendedLayout {
    return UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


- (void)localConnection{
    
    [self loadConnectedBridgeValues];
    
}

- (void)noLocalConnection{
    self.bridgeLastHeartbeatLabel.text = @"Not connected";
    [self.bridgeLastHeartbeatLabel setEnabled:NO];
    self.bridgeIpLabel.text = @"Not connected";
    [self.bridgeIpLabel setEnabled:NO];
    self.bridgeIdLabel.text = @"Not connected";
    [self.bridgeIdLabel setEnabled:NO];
    
    [self.randomLightsButton setEnabled:NO];
}

- (void)loadConnectedBridgeValues{
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    
    // Check if we have connected to a bridge before
    if (cache != nil && cache.bridgeConfiguration != nil && cache.bridgeConfiguration.ipaddress != nil){
        
        // Set the ip address of the bridge
        self.bridgeIpLabel.text = cache.bridgeConfiguration.ipaddress;
        
        // Set the identifier of the bridge
        self.bridgeIdLabel.text = cache.bridgeConfiguration.bridgeId;
        
        // Check if we are connected to the bridge right now
        if (UIAppDelegate.phHueSDK.localConnected) {
            
            // Show current time as last successful heartbeat time when we are connected to a bridge
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterNoStyle];
            [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
            
            self.bridgeLastHeartbeatLabel.text = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:[NSDate date]]];
            
            [self.randomLightsButton setEnabled:YES];
        } else {
            self.bridgeLastHeartbeatLabel.text = @"Waiting...";
            [self.randomLightsButton setEnabled:NO];
        }
    }
}

- (IBAction)selectOtherBridge:(id)sender{
    [UIAppDelegate searchForBridgeLocal];
}

- (IBAction)randomizeColoursOfConnectLights:(id)sender{
    [self.randomLightsButton setEnabled:NO];
    
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
    
    for (PHLight *light in cache.lights.allValues) {
        
        PHLightState *lightState = [[PHLightState alloc] init];
        
        [lightState setHue:[NSNumber numberWithInt:arc4random() % MAX_HUE]];
        [lightState setBrightness:[NSNumber numberWithInt:254]];
        [lightState setSaturation:[NSNumber numberWithInt:254]];
        
        // Send lightstate to light
        [bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
            if (errors != nil) {
                NSString *message = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Errors", @""), errors != nil ? errors : NSLocalizedString(@"none", @"")];
                
                NSLog(@"Response: %@",message);
            }
            
            [self.randomLightsButton setEnabled:YES];
        }];
    }
}
- (IBAction)startButtonPressed:(id)sender {
    //update the reference starting time everytime the start button was pressed.
    self.startTime = [[NSDate date] timeIntervalSince1970];
}
- (IBAction)stopButtonPressed:(id)sender {
    [[NSUserDefaults standardUserDefaults] setObject:self.beatTimeArray forKey:@"song_name"];
    [self.beatTimeArray removeAllObjects];
}

- (IBAction)turnOnDesktop:(id)sender{
    CGFloat beatTime = [[NSDate date] timeIntervalSince1970] - self.startTime;
    [self.beatTimeArray addObject:[NSNumber numberWithDouble:beatTime]];
    [self.turnOnDesktopButton setEnabled:NO];
    [self fullBrightness];
    [self performSelector:@selector(dimDown) withObject:nil afterDelay:0.25];
    [self.turnOnDesktopButton setEnabled:YES];
}



- (void) playBackTurnOnDesktop{
    [self fullBrightness];
    [self performSelector:@selector(dimDown) withObject:nil afterDelay:0.25];
}

- (void) fullBrightness{
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    
    
    PHLight *light = [cache.lights objectForKey:@"10"];
    PHLightState *lightState = [[PHLightState alloc] init];
    [lightState setTransitionTime:0];
    [lightState setBrightness:[NSNumber numberWithInt:254]];
    [lightState setHue:[NSNumber numberWithInt:arc4random() % MAX_HUE]];
    [lightState setSaturation:[NSNumber numberWithInt:254]];
    
    PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
    [bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
    }];
}

- (void) dimDown{
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    
    
    PHLight *light = [cache.lights objectForKey:@"10"];
    PHLightState *lightState = [[PHLightState alloc] init];
    [lightState setTransitionTime:0];
    [lightState setBrightness:[NSNumber numberWithInt:12]]; 
    [lightState setHue:[NSNumber numberWithInt:arc4random() % MAX_HUE]];
    [lightState setSaturation:[NSNumber numberWithInt:254]];
    
    PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
    [bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
    }];
}

- (void) turnOff{
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    
    
    PHLight *light = [cache.lights objectForKey:@"10"];
    PHLightState *lightState = [[PHLightState alloc] init];
    [lightState setOnBool:false];
    
    PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
    [bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
    }];
}

- (void) playBack: (NSMutableArray*) TBA{
    for (NSNumber *time in TBA) {
        [self performSelector:@selector(playBackTurnOnDesktop) withObject:(nil) afterDelay:(time.doubleValue)];
    }
}
- (IBAction)playBackButtonPressed:(id)sender {
    NSMutableArray* TBA = [[NSUserDefaults standardUserDefaults] objectForKey:@"song_name"];
    [self playBack:TBA];
}



//- (IBAction)colorPulse:(id)sender{
//    [self.pulseButton setEnabled:NO];
//    
//    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
//    PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
//    PHLight *light = [cache.lights objectForKey:@"11"];
//    PHLightState *lightState = [[PHLightState alloc] init];
//    [lightState setOnBool:true];
//    [lightState setHue:[NSNumber numberWithInt:12750]];
//    [lightState setBrightness:[NSNumber numberWithInt:20]];
//    [bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
//        if (errors != nil) {
//            NSString *message = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Errors", @""), errors != nil ? errors : NSLocalizedString(@"none", @"")];
//            
//            NSLog(@"Response: %@",message);
//        }}];
//
//    
//    NSArray *timeBeats = @[@1, @7, @13, @19, @25];
//    CGFloat startTime = [[NSDate date] timeIntervalSince1970];
//    for (NSNumber *i in timeBeats) {
//        [lightState setOnBool:false];
//        [bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
//            if (errors != nil) {
//                NSString *message = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Errors", @""), errors != nil ? errors : NSLocalizedString(@"none", @"")];
//                
//                NSLog(@"Response: %@",message);
//            }
//        }
//        ];
//        NSLog(@"timeBeat is: %@", i);
//        NSLog(@"startTime is: %f", startTime);
//        while ([[NSDate date] timeIntervalSince1970] != startTime+i.intValue) {
//        }
//        NSLog(@"currentTime is: %f", [[NSDate date] timeIntervalSince1970]);
//
//        [lightState setOnBool:true];
//        [lightState setBrightness:[NSNumber numberWithInt:254]];
////        [lightState setSaturation:[NSNumber numberWithInt:254]];
////        [lightState setHue:[NSNumber numberWithInt:arc4random() % MAX_HUE]];
////        
////        
//        [bridgeSendAPI updateLightStateForId:light.identifier withLightState:lightState completionHandler:^(NSArray *errors) {
//            if (errors != nil) {
//                NSString *message = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Errors", @""), errors != nil ? errors : NSLocalizedString(@"none", @"")];
//                
//                NSLog(@"Response: %@",message);
//            }
//            
//            [self.pulseButton setEnabled:YES];
//            }
//         ];
//        NSLog(@"beforelastwhile is: %f", [[NSDate date] timeIntervalSince1970]);
//        while ([[NSDate date] timeIntervalSince1970] != startTime+i.intValue+1) {
//        }
//        NSLog(@"afterlastwhile is: %f", [[NSDate date] timeIntervalSince1970]);
//
//    }
//}


@end

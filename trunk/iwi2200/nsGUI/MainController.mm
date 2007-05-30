#import "MainController.h"

using namespace std;

@implementation MainController

static int networkMenuCount = 0;
- (void)awakeFromNib
{
	[self preAction];
	tinterval=[[[NSDate date] addTimeInterval:3] timeIntervalSinceNow];
	timecheck=	[NSTimer scheduledTimerWithTimeInterval:tinterval target:self selector:@selector(preAction) userInfo:nil repeats:YES];
	originalIcon = [[NSApp applicationIconImage] copy];
    iconImageBuffer = [originalIcon copy];
	
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength] retain];
	
	NSString *imageName = [[NSBundle mainBundle] pathForResource:@"sig0s" ofType:@"tif"];
	statusImage = [[NSImage alloc] initWithContentsOfFile:imageName];
	statusAltImage = [[NSImage alloc] initWithContentsOfFile:imageName];

	[statusItem setImage: statusImage];
	[statusItem setAlternateImage: statusAltImage];
	[statusItem setMenu:DockMenu];
	[statusItem setTitle:@"NetworkSelector"];
	[statusItem setToolTip: @"NetworkSelector"];
	[statusItem setHighlightMode: YES];
}

- (id) init
{
	if ( self = [ super init ] )
	{
	[mainWindow setDelegate:self];
		
		fd = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL);
		if (fd) 
			{
			bzero(&addr, sizeof(addr)); // sets the sc_unit field to 0
			addr.sc_len = sizeof(addr);
			addr.sc_family = AF_SYSTEM;
			addr.ss_sysaddr = AF_SYS_CONTROL;
			}
		
		memset(&info, 0, sizeof(info));
		assert (strlen("insanelymac.iwidarwin.control") < MAX_KCTL_NAME);
		strcpy(info.ctl_name, "insanelymac.iwidarwin.control");
		int err;
		if (ioctl(fd, CTLIOCGINFO,&info)) {
			err = errno;
			printf("Could not get ID for kernel control. %d\n", err);
			return(NULL);
		}
		addr.sc_id = info.ctl_id;
		addr.sc_unit = 0;
		connect(fd, (struct sockaddr *)&addr, sizeof(addr));
		
	}

	return self;
	
}

- (IBAction)LEDAction:(id)sender
{
	setsockopt(fd,SYSPROTO_CONTROL,3,NULL,0);
	[self preAction];
}

- (IBAction)ModeAction:(id)sender
{
	[listWindow setHidden:true];
	[modeChangeTitle setHidden:false];
	[cancelChangeButton setHidden:false];
	[changeModeButton setHidden:false];
	[selectedMode setHidden:false];
}
- (IBAction)myAction:(id)sender
{
}
- (IBAction)openAboutWindow:(id)sender
{
	[about orderFront:self];
	[about orderFrontRegardless];
	[about makeKeyWindow];
}
- (IBAction)NetworkAction:(id)sender
{
		[ConnectButton setEnabled:true];
		[ConnectButton setHidden:false];
		[listWindow setHidden:false];
		//[changeModeButton setHidden:true];
		//[CancelButton setHidden:false];
		//[modeChangeTitle setHidden:true];
		[selectedMode setHidden:true];
		priv=priv0;
		sp=sizeof(priv);
		int result = getsockopt( fd, SYSPROTO_CONTROL, 0, &priv, &sp);
		priv.ieee = &ieee;			
		sp=sizeof(*priv.ieee);
		result = getsockopt( fd, SYSPROTO_CONTROL, 1, priv.ieee, &sp);
		priv.ieee->dev = &net_dev;
		sp=sizeof(*priv.ieee->dev);
		result = getsockopt( fd, SYSPROTO_CONTROL, 5, priv.ieee->dev, &sp);
		priv.ieee->networks = (struct ieee80211_network*)malloc(MAX_NETWORK_COUNT * sizeof(struct ieee80211_network));
		memset(priv.ieee->networks, 0, MAX_NETWORK_COUNT * sizeof(struct ieee80211_network));
		
		int c=-1;
		rep:
		c++;
		sp=sizeof(priv.ieee->networks[c]);
		result = getsockopt( fd, SYSPROTO_CONTROL, 2, &priv.ieee->networks[c], &sp);
		
		if (c>0)
		if (!memcmp(priv.ieee->networks[c].bssid, priv.ieee->networks[c-1].bssid, sizeof(priv.ieee->networks[c-1].bssid)))
		{
			priv.ieee->networks[c].ssid_len=0;
		}
		if (priv.ieee->networks[c].ssid_len>0) 
		{
			priv.ieee->networks[c+1]=priv.ieee->networks[c];
			goto rep;
		}
		if (priv.status & STATUS_ASSOCIATED)
		{
			priv.assoc_network=&nets;
			sp=sizeof(*priv.assoc_network);
			result = getsockopt( fd, SYSPROTO_CONTROL, 3, priv.assoc_network, &sp);
		}
		if ((priv.status & STATUS_ASSOCIATED) && priv.assoc_network)
		{
			char	sa_data[14];
			sp=sizeof(sa_data);
			result = getsockopt( fd, SYSPROTO_CONTROL, 4, sa_data, &sp);
			if (result==-1) [textOutlet setStringValue:@"Current Status: getting ip address...\n"];
			else
			{
				printf("[" IP_FORMAT "]\n",IP_LIST(sa_data));
				if (priv.ieee->iw_mode == IW_MODE_INFRA)
				if ((int)(IP_CH(sa_data)[2])==169 && (int)(IP_CH(sa_data)[3])==254)
				{
					[textOutlet setStringValue:@"no internet connection!\n"];
				}
			}
			
		}
		
		
		if (priv.status & (STATUS_RF_KILL_HW | STATUS_RF_KILL_SW)) 
			{
				[textOutlet setStringValue:[NSString stringWithCString:"Network Interface Disabled"]] ;
				networksData = [NSMutableArray new];
				[dataOutlet reloadData];
				return;
			}
				if (priv.ieee->networks)
				{
					int ii,cn=0;
					networksData = [NSMutableArray new];
					while ([[networksMenu itemArray] count])
						[networksMenu removeItemAtIndex:0];
						
					for (ii=0; ii<MAX_NETWORK_COUNT ;ii++)
					{
						if (priv.ieee->networks[ii].ssid_len>0)
						{
							char SSID[256];
							char MAC[17];
							char ch[3];

							cn++;
							sprintf(SSID,"%s",escape_essid((const char*)priv.ieee->networks[ii].ssid, priv.ieee->networks[ii].ssid_len));
							sprintf(MAC,"%02x:%02x:%02x:%02x:%02x:%02x",MAC_ARG(priv.ieee->networks[ii].bssid));
							sprintf(ch,"%d",priv.ieee->networks[ii].channel);
							
							NSString *sSSID = [NSString stringWithCString:SSID];
							NSString *sMAC = [NSString stringWithCString:MAC];
							NSString *sch = [NSString stringWithCString:ch];
							NSImage *sig = [NSImage new];
							
							NSString* imageName;
							
							int signal = priv.ieee->networks[ii].stats.signal;
							if (signal < 50 ) imageName = [[NSBundle mainBundle] pathForResource:@"sig1s" ofType:@"tif"];
							if (signal >=50 && signal <100) imageName = [[NSBundle mainBundle] pathForResource:@"sig2s" ofType:@"tif"];
							if (signal >=100 && signal <180) imageName = [[NSBundle mainBundle] pathForResource:@"sig3s" ofType:@"tif"];
							if (signal>=180) imageName = [[NSBundle mainBundle] pathForResource:@"sig4s" ofType:@"tif"];
							
							sig = [[NSImage alloc] initWithContentsOfFile:imageName];
							
							
							NSMutableArray *data = [NSMutableArray new];
							[data addObject:sSSID];[data addObject:sMAC];[data addObject:sch];[data addObject:sig];
							
							NSArray * keys   = [NSArray arrayWithObjects:@"SSID", @"MAC", @"Channel",@"Signal", nil];
							
							NSMutableDictionary *temp = [[NSMutableDictionary alloc] initWithObjects: data forKeys: keys];
							
							[networksData addObject:temp];
							
							NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:sSSID 
								action:@selector (ConnectFromMenu:) keyEquivalent:@""];
							
							
							
							
							[menuItem setTag:ii];
							[menuItem setTarget:self];
							[menuItem setImage:sig];
							
							[networksMenu addItem:menuItem];
							
							networkMenuCount++;
							
						}
					}
				}
	//	[networksMenu setAutoenablesItems:false];
		[dataOutlet reloadData];
		
				
}

- (IBAction)PowerAction:(id)sender
{
		[self cancelModeChange:nil];
		[self CancelConnect:nil];
		setsockopt(fd,SYSPROTO_CONTROL,1,NULL,0);
		[self preAction];

		NSString *imageName = [[NSBundle mainBundle] pathForResource:@"sig0s" ofType:@"tif"];
		statusImage = [[NSImage alloc] initWithContentsOfFile:imageName];
		[statusItem setImage:statusImage];
		[statusItem setAlternateImage:statusImage];
		[DockMenu removeItemAtIndex:4];
		
}

- (IBAction)quit:(id)sender
{
//	[mainWindow close];
	//[appcontrol terminate:nil];


	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Hide"];
	[alert addButtonWithTitle:@"Close"];
	[alert setMessageText:@"Do you wish to hide nsGUI or close it ?."];
	[alert setAlertStyle:NSWarningAlertStyle];
	
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];

}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{

    return [networksData count];
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex
{
    id theRecord, theValue;
 
    NSParameterAssert(rowIndex >= 0 && rowIndex < [networksData count]);
    theRecord = [networksData objectAtIndex:rowIndex];
    theValue = [theRecord objectForKey:[aTableColumn identifier]];
    return theValue;
}


- (IBAction)Connect:(id)sender
{
	int sel0 = [dataOutlet selectedRow];
	sel0++;
	if (sel0>0)
	{
		int ii;
		int vi=0;
		for (ii=0; ii<MAX_NETWORK_COUNT ;ii++)
		if (priv.ieee->networks[ii].ssid_len>0)
		{
			vi++;
			if (vi==sel0) break;
		}
		[textOutlet setStringValue:[NSString stringWithCString:"connecting to network..."]];
		[ProgressAnim setHidden:false];
		[ProgressAnim startAnimation:self];
		wait_conect=YES;
		int r=setsockopt(fd,SYSPROTO_CONTROL,2,&priv.ieee->networks[ii], sizeof(priv.ieee->networks[ii]));
		[ProgressAnim stopAnimation:self];
		[ProgressAnim setHidden:true];
		if (r==1)
		[textOutlet setStringValue:[NSString stringWithCString:"failed while connecting to network..."]];
		wait_conect=NO;
		

		
	}
	
	[self CancelConnect:nil];
}
- (void)ConnectFromMenu:(id)sender
{
	int sel0 = [sender tag];
	sel0++;
	if (sel0>0)
	{
		int ii;
		int vi=0;
		for (ii=0; ii<MAX_NETWORK_COUNT ;ii++)
		if (priv.ieee->networks[ii].ssid_len>0)
		{
			vi++;
			if (vi==sel0) break;
		}
		[textOutlet setStringValue:[NSString stringWithCString:"connecting to network..."]];
		[ProgressAnim setHidden:false];
		[ProgressAnim startAnimation:self];
		wait_conect=YES;
		int r=setsockopt(fd,SYSPROTO_CONTROL,2,&priv.ieee->networks[ii], sizeof(priv.ieee->networks[ii]));
		[ProgressAnim stopAnimation:self];
		[ProgressAnim setHidden:true];
		if (r==1)
		[textOutlet setStringValue:[NSString stringWithCString:"failed while connecting to network..."]];
		wait_conect=NO;
	}
	[self CancelConnect:nil];
}

- (IBAction)CancelConnect:(id)sender;
{
	[ConnectButton setHidden:true];
	[listWindow setHidden:true];
	//[CancelButton setHidden:true];
}

- (void)tableView:(NSTableView *)aTableView
    setObjectValue:anObject
    forTableColumn:(NSTableColumn *)aTableColumn
    row:(int)rowIndex
{
    id theRecord;
 
    NSParameterAssert(rowIndex >= 0 && rowIndex < [networksData count]);
    theRecord = [networksData objectAtIndex:rowIndex];
    [theRecord setObject:anObject forKey:[aTableColumn identifier]];
    return;
}

- (IBAction)ModeChange:(id)sender
{
	[self preAction];	
	/*if (!(priv.status & (STATUS_RF_KILL_HW | STATUS_RF_KILL_SW))) 
		{
			[textOutlet setStringValue:@"Network Interface Must Be Disabled"];
			return;
		}
	else [textOutlet setStringValue:@""];*/
	int sel0 = [selectedMode selectedRow];
	sel0++;
	if (sel0>0 && sel0<4)
	{
		int *i = (int*) malloc(sizeof (int));
		*i=(int)sel0;
		b=sizeof(int);
		setsockopt(fd,SYSPROTO_CONTROL,4,i,b);
		[self preAction];
	}
	//char mode[30];
	//sprintf (mode,"selected Mode: %d",priv.ieee->iw_mode);
	//[textOutlet setStringValue:[NSString stringWithCString:mode]];
	[self cancelModeChange:nil];
}
- (IBAction)cancelModeChange:(id)sender
{
	[changeModeButton setHidden:true];
	[cancelChangeButton setHidden:true];
	[modeChangeTitle setHidden:true];
	[selectedMode setHidden:true];
	[cancelChangeButton setHidden:true];
	[modeChangeTitle setHidden:true];
		
}

- (void)preAction
{
		if (wait_conect) return;
		priv=priv0;
		sp=sizeof(priv);
		int result = getsockopt( fd, SYSPROTO_CONTROL, 0, &priv, &sp);
		priv.ieee = &ieee;			
		sp=sizeof(*priv.ieee);
		result = getsockopt( fd, SYSPROTO_CONTROL, 1, priv.ieee, &sp);
		priv.ieee->dev = &net_dev;
		sp=sizeof(*priv.ieee->dev);
		result = getsockopt( fd, SYSPROTO_CONTROL, 5, priv.ieee->dev, &sp);
		priv.ieee->networks = (struct ieee80211_network*)malloc(MAX_NETWORK_COUNT * sizeof(struct ieee80211_network));
		memset(priv.ieee->networks, 0, MAX_NETWORK_COUNT * sizeof(struct ieee80211_network));
		
		[NSApp setApplicationIconImage:originalIcon];

		if (priv.status & (STATUS_RF_KILL_HW | STATUS_RF_KILL_SW))
		{
			[PowerButton setTitle:@"Set Power ON"];
			[[DockMenu itemWithTitle:@"Set Power OFF"] setTitle:@"Set Power ON" ];
			
			//[NetButton setEnabled:YES];
			[LedButton setEnabled:YES];
			[ModeButton setEnabled:YES];
		}
			else
		{
			[PowerButton setTitle:@"Set Power OFF"];
			[[DockMenu itemWithTitle:@"Set Power ON"] setTitle:@"Set Power OFF"];			

			
			//[NetButton setEnabled:NO];
			
			[LedButton setEnabled:NO];
			[ModeButton setEnabled:NO];
		}
		NSString *sta,*sta0;
		sta=@"";
		sta0=[NSString stringWithFormat:@"%s (%02x:%02x:%02x:%02x:%02x:%02x) [mode: %d]\n\n", priv.ieee->dev->name,
		MAC_ARG(priv.mac_addr), priv.ieee->iw_mode];
		sta=[sta stringByAppendingString:sta0];
		//sprintf(sta,"Adapter %s (%02x:%02x:%02x:%02x:%02x:%02x) [mode: %d]\n", priv.ieee->dev->name,
		//MAC_ARG(priv.mac_addr), priv.ieee->iw_mode);
		//[textOutlet setStringValue:[NSString stringWithCString:sta]];
		if (!(priv.status & (STATUS_RF_KILL_HW | STATUS_RF_KILL_SW)))
		if (!(priv.status & (STATUS_ASSOCIATED | STATUS_ASSOCIATING)))
		{
			//sprintf (sta,"Current status: scanning...\n",priv.status);
			sta0=[NSString stringWithFormat:@"Current status: scanning...\n",priv.status];
			sta=[sta stringByAppendingString:sta0];
			//[textOutlet setStringValue:[NSString stringWithCString:sta]];
		}
		if (priv.config & CFG_NO_LED)
			[LedButton setTitle:@"LED is disabled"];
		else
			[LedButton setTitle:@"LED is enabled"];
					
		int c=-1;
		rep:
		c++;
		sp=sizeof(priv.ieee->networks[c]);
		if (!(priv.status & (STATUS_RF_KILL_HW | STATUS_RF_KILL_SW)))
		result = getsockopt( fd, SYSPROTO_CONTROL, 2, &priv.ieee->networks[c], &sp);
		
		if (c>0)
		if (!memcmp(priv.ieee->networks[c].bssid, priv.ieee->networks[c-1].bssid, sizeof(priv.ieee->networks[c-1].bssid)))
		{
			priv.ieee->networks[c].ssid_len=0;
		}
		if (priv.ieee->networks[c].ssid_len>0) 
		{
			priv.ieee->networks[c+1]=priv.ieee->networks[c];
			goto rep;
		}
		if (c>0)
			//[NetButton setEnabled:YES];
			if (!(priv.status & STATUS_ASSOCIATED)) [self NetworkAction:nil];
		//else
		//	[NetButton setEnabled:NO];
		
		if (priv.status & STATUS_ASSOCIATED)
		{
			[self CancelConnect:nil];
			priv.assoc_network=&nets;
			sp=sizeof(*priv.assoc_network);
			result = getsockopt( fd, SYSPROTO_CONTROL, 3, priv.assoc_network, &sp);
		}
		if ((priv.status & STATUS_ASSOCIATED) && priv.assoc_network)
		{
			//[NetButton setEnabled:NO];
			char	sa_data[14];
			sp=sizeof(sa_data);
			result = getsockopt( fd, SYSPROTO_CONTROL, 4, sa_data, &sp);
			
			sta0=[NSString stringWithFormat:@"'%s (%02x:%02x:%02x:%02x:%02x:%02x) ch: %d'\n",
						escape_essid((const char*)priv.assoc_network->ssid, priv.assoc_network->ssid_len),
						MAC_ARG(priv.assoc_network->bssid), priv.assoc_network->channel];
			sta=[sta stringByAppendingString:sta0];
			
			int signal = priv.assoc_network->stats.signal;
			
			NSString *imageName;
			
			if (signal < 50 ) imageName = [[NSBundle mainBundle] pathForResource:@"sig1s" ofType:@"tif"];
			if (signal >=50 && signal <100) imageName = [[NSBundle mainBundle] pathForResource:@"sig2s" ofType:@"tif"];
			if (signal >=100 && signal <180) imageName = [[NSBundle mainBundle] pathForResource:@"sig3s" ofType:@"tif"];
			if (signal>=180) imageName = [[NSBundle mainBundle] pathForResource:@"sig4s" ofType:@"tif"];
			
			statusImage = [[NSImage alloc] initWithContentsOfFile:imageName];
			[statusItem setImage:statusImage];
			[statusItem setAlternateImage:statusImage];

			
			if (![DockMenu itemWithTag:360])
			{
				NSMenuItem *temp = [[NSMenuItem alloc] initWithTitle:[NSString stringWithCString:
				escape_essid((const char*)priv.assoc_network->ssid, priv.assoc_network->ssid_len)]
				action:nil keyEquivalent:@""];
				imageName = [[NSBundle mainBundle] pathForResource:@"Connected" ofType:@"png"];
				NSImage *tempImage = [[NSImage alloc] initWithContentsOfFile:imageName];
				[temp setImage:tempImage];
				[temp setTag:360];
				[DockMenu insertItem:temp atIndex:4];
			}
			while ([[networksMenu itemArray] count])
				[networksMenu removeItemAtIndex:0];
			[networksMenu addItemWithTitle:@"NetworkList Not Available"
				action:nil keyEquivalent:@""];
			
			
			if (result==-1)
			{
				//sprintf (sta,"Current Status: getting ip address...\n");
				sta0=[NSString stringWithCString:"Current Status: getting ip address...\n"];
				sta=[sta stringByAppendingString:sta0];
				//[textOutlet setStringValue:[NSString stringWithCString:sta]];
			}
			else
			{
				//printf("IP Address [" IP_FORMAT "]\n",IP_LIST(sa_data));
				//sprintf (sta,"IP Address [" IP_FORMAT "]\n",IP_LIST(sa_data));
				sta0=[NSString stringWithFormat:@"IP Address [" IP_FORMAT "]\n",IP_LIST(sa_data)];
				sta=[sta stringByAppendingString:sta0];
				//[textOutlet setStringValue:[NSString stringWithCString:sta]];
				if (priv.ieee->iw_mode == IW_MODE_INFRA)
				if ((int)(IP_CH(sa_data)[2])==169 && (int)(IP_CH(sa_data)[3])==254)
				{
					//sprintf (sta,"no internet connection!\n");
					sta0=[NSString stringWithCString:"no internet connection!\n"];
					sta=[sta stringByAppendingString:sta0];
					//[textOutlet setStringValue:[NSString stringWithCString:sta]];
				}
			}
		}
		[textOutlet setStringValue:sta];
		
		
		
}
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
	NSArray *newDescriptors = [tableView sortDescriptors];
	[networksData sortUsingDescriptors:newDescriptors];
	[dataOutlet reloadData];
}
- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
    return networksMenu;
}
- (IBAction)openMainWindow:(id)sender
{
	[mainWindow orderFront:self];
	[mainWindow orderFrontRegardless];
	[mainWindow makeKeyWindow];
}
- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn)
		[mainWindow close];
	else
		{
			[mainWindow close];
			[appcontrol terminate:nil];
		}
}
@end
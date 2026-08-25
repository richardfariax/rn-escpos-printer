#import "RNEscPosBluetoothTransport.h"

#import <CoreBluetooth/CoreBluetooth.h>

#import "RNEscPosErrors.h"

@interface RNEscPosBluetoothTransport () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property(nonatomic, strong) CBCentralManager *centralManager;
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, strong) NSMutableDictionary<NSUUID *, CBPeripheral *> *discovered;
@property(nonatomic, strong, nullable) CBPeripheral *connectedPeripheral;
@property(nonatomic, strong, nullable) CBCharacteristic *writeCharacteristic;
@property(nonatomic, assign) CBCharacteristicWriteType writeType;
@property(nonatomic, copy, nullable) RNEscPosErrorCompletion powerCompletion;
@property(nonatomic, copy, nullable) RNEscPosPrintersCompletion scanCompletion;
@property(nonatomic, copy, nullable) RNEscPosErrorCompletion connectCompletion;
@property(nonatomic, copy, nullable) RNEscPosErrorCompletion writeCompletion;
@property(nonatomic, strong) NSMutableArray<CBCharacteristic *> *writeCandidates;
@property(nonatomic, assign) NSInteger servicesPendingDiscovery;
@property(nonatomic, strong, nullable) NSData *pendingWriteData;
@property(nonatomic, assign) NSUInteger pendingWriteOffset;
@property(nonatomic, assign) NSUInteger powerGeneration;
@property(nonatomic, assign) NSUInteger connectGeneration;
@property(nonatomic, assign) NSUInteger writeGeneration;

@end

@implementation RNEscPosBluetoothTransport

- (instancetype)init
{
  self = [super init];
  if (self != nil) {
    _queue = dispatch_queue_create("com.highsoft.rnescposprinter.ble", DISPATCH_QUEUE_SERIAL);
    _discovered = [NSMutableDictionary dictionary];
    _writeCandidates = [NSMutableArray array];
    _centralManager = [[CBCentralManager alloc]
        initWithDelegate:self
                   queue:_queue
                 options:@{CBCentralManagerOptionShowPowerAlertKey : @NO}];
  }
  return self;
}

- (void)initializeWithTimeout:(NSTimeInterval)timeout
                    completion:(RNEscPosErrorCompletion)completion
{
  dispatch_async(self.queue, ^{
    NSError *stateError = [self bluetoothStateErrorAllowPending:YES];
    if (self.centralManager.state == CBManagerStatePoweredOn || stateError != nil) {
      completion(stateError);
      return;
    }

    self.powerCompletion = completion;
    NSUInteger generation = ++self.powerGeneration;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)),
        self.queue,
        ^{
          if (self.powerCompletion != nil && generation == self.powerGeneration) {
            [self completePowerWithError:RNEscPosMakeError(
                                             @"ERR_BLUETOOTH_DISABLED",
                                             @"Bluetooth did not become ready before the timeout",
                                             nil)];
          }
        });
  });
}

- (void)scanWithDuration:(NSTimeInterval)duration
               completion:(RNEscPosPrintersCompletion)completion
{
  dispatch_async(self.queue, ^{
    NSError *stateError = [self bluetoothStateErrorAllowPending:NO];
    if (stateError != nil) {
      completion(nil, stateError);
      return;
    }
    if (self.scanCompletion != nil) {
      completion(
          nil,
          RNEscPosMakeError(
              @"ERR_SCAN_FAILED", @"A Bluetooth scan is already in progress", nil));
      return;
    }

    [self.discovered removeAllObjects];
    self.scanCompletion = completion;
    [self.centralManager scanForPeripheralsWithServices:nil
                                                 options:@{
                                                   CBCentralManagerScanOptionAllowDuplicatesKey : @NO
                                                 }];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)),
        self.queue,
        ^{
          if (self.scanCompletion != nil) {
            [self.centralManager stopScan];
            [self completeScan];
          }
        });
  });
}

- (void)connectToIdentifier:(NSString *)identifier
                    timeout:(NSTimeInterval)timeout
                 completion:(RNEscPosErrorCompletion)completion
{
  dispatch_async(self.queue, ^{
    NSError *stateError = [self bluetoothStateErrorAllowPending:NO];
    if (stateError != nil) {
      completion(stateError);
      return;
    }

    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier];
    if (uuid == nil) {
      completion(RNEscPosMakeError(
          @"ERR_PRINTER_NOT_FOUND", @"The iOS printer identifier is not a valid UUID", nil));
      return;
    }

    CBPeripheral *peripheral = self.discovered[uuid];
    if (peripheral == nil) {
      peripheral = [self.centralManager retrievePeripheralsWithIdentifiers:@[ uuid ]].firstObject;
    }
    if (peripheral == nil) {
      completion(RNEscPosMakeError(
          @"ERR_PRINTER_NOT_FOUND",
          @"The BLE printer was not found. Scan while the printer is advertising and try again.",
          nil));
      return;
    }

    if ([self.connectedPeripheral.identifier isEqual:peripheral.identifier] &&
        peripheral.state == CBPeripheralStateConnected && self.writeCharacteristic != nil) {
      completion(nil);
      return;
    }

    if (self.connectedPeripheral != nil) {
      [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    [self resetConnectedPeripheral];
    self.connectCompletion = completion;
    self.connectedPeripheral = peripheral;
    self.connectedPeripheral.delegate = self;
    NSUInteger generation = ++self.connectGeneration;
    [self.centralManager connectPeripheral:peripheral options:nil];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)),
        self.queue,
        ^{
          if (self.connectCompletion != nil && generation == self.connectGeneration) {
            [self failConnectionWithError:RNEscPosMakeError(
                                              @"ERR_CONNECTION_TIMEOUT",
                                              @"BLE connection timed out",
                                              nil)];
          }
        });
  });
}

- (void)disconnectWithCompletion:(dispatch_block_t)completion
{
  dispatch_async(self.queue, ^{
    [self failWriteIfNeeded:RNEscPosMakeError(
                                @"ERR_CONNECTION_LOST", @"The printer was disconnected", nil)];
    if (self.connectedPeripheral != nil) {
      [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    [self resetConnectedPeripheral];
    completion();
  });
}

- (void)isConnectedWithCompletion:(RNEscPosBooleanCompletion)completion
{
  dispatch_async(self.queue, ^{
    completion(
        self.connectedPeripheral.state == CBPeripheralStateConnected &&
        self.writeCharacteristic != nil);
  });
}

- (void)writeData:(NSData *)data
          timeout:(NSTimeInterval)timeout
       completion:(RNEscPosErrorCompletion)completion
{
  dispatch_async(self.queue, ^{
    if (self.connectedPeripheral.state != CBPeripheralStateConnected ||
        self.writeCharacteristic == nil) {
      completion(RNEscPosMakeError(
          @"ERR_NOT_CONNECTED", @"No BLE printer is connected", nil));
      return;
    }
    if (self.writeCompletion != nil) {
      completion(RNEscPosMakeError(
          @"ERR_WRITE_FAILED", @"Another print operation is still in progress", nil));
      return;
    }

    self.pendingWriteData = data;
    self.pendingWriteOffset = 0;
    self.writeCompletion = completion;
    NSUInteger generation = ++self.writeGeneration;
    [self pumpWrite];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)),
        self.queue,
        ^{
          if (self.writeCompletion != nil && generation == self.writeGeneration) {
            [self finishWriteWithError:RNEscPosMakeError(
                                           @"ERR_WRITE_FAILED",
                                           @"The BLE print operation timed out",
                                           nil)];
          }
        });
  });
}

- (void)invalidate
{
  dispatch_async(self.queue, ^{
    [self.centralManager stopScan];
    if (self.connectedPeripheral != nil) {
      [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    [self resetConnectedPeripheral];
  });
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
  if (central.state == CBManagerStatePoweredOn) {
    [self completePowerWithError:nil];
    return;
  }

  NSError *error = [self bluetoothStateErrorAllowPending:YES];
  if (error != nil) {
    [self completePowerWithError:error];
    if (self.scanCompletion != nil) {
      RNEscPosPrintersCompletion completion = self.scanCompletion;
      self.scanCompletion = nil;
      completion(nil, error);
    }
    [self completeConnectWithError:error];
    [self failWriteIfNeeded:error];
  }
}

- (void)centralManager:(CBCentralManager *)central
    didDiscoverPeripheral:(CBPeripheral *)peripheral
        advertisementData:(NSDictionary<NSString *, id> *)advertisementData
                     RSSI:(NSNumber *)RSSI
{
  NSString *advertisedName = advertisementData[CBAdvertisementDataLocalNameKey];
  if (peripheral.name.length > 0 || advertisedName.length > 0) {
    self.discovered[peripheral.identifier] = peripheral;
  }
}

- (void)centralManager:(CBCentralManager *)central
    didConnectPeripheral:(CBPeripheral *)peripheral
{
  if (![self isCurrentPeripheral:peripheral]) {
    [central cancelPeripheralConnection:peripheral];
    return;
  }
  peripheral.delegate = self;
  [self.writeCandidates removeAllObjects];
  self.servicesPendingDiscovery = 0;
  [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central
    didFailToConnectPeripheral:(CBPeripheral *)peripheral
                         error:(NSError *)error
{
  if (![self isCurrentPeripheral:peripheral]) {
    return;
  }
  [self failConnectionWithError:RNEscPosMakeError(
                                    @"ERR_CONNECTION_FAILED",
                                    @"The BLE printer rejected the connection",
                                    error)];
}

- (void)centralManager:(CBCentralManager *)central
    didDisconnectPeripheral:(CBPeripheral *)peripheral
                       error:(NSError *)error
{
  if (![self isCurrentPeripheral:peripheral]) {
    return;
  }
  if (self.connectCompletion != nil) {
    [self completeConnectWithError:RNEscPosMakeError(
                                       @"ERR_CONNECTION_FAILED",
                                       @"The BLE printer disconnected during setup",
                                       error)];
  }
  [self failWriteIfNeeded:RNEscPosMakeError(
                              @"ERR_CONNECTION_LOST",
                              @"The BLE printer disconnected while printing",
                              error)];
  if ([self.connectedPeripheral.identifier isEqual:peripheral.identifier]) {
    [self resetConnectedPeripheral];
  }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral
    didDiscoverServices:(NSError *)error
{
  if (![self isCurrentPeripheral:peripheral]) {
    return;
  }
  if (error != nil || peripheral.services.count == 0) {
    [self failConnectionWithError:RNEscPosMakeError(
                                      @"ERR_CONNECTION_FAILED",
                                      @"The BLE printer exposes no usable services",
                                      error)];
    return;
  }

  self.servicesPendingDiscovery = peripheral.services.count;
  for (CBService *service in peripheral.services) {
    [peripheral discoverCharacteristics:nil forService:service];
  }
}

- (void)peripheral:(CBPeripheral *)peripheral
    didDiscoverCharacteristicsForService:(CBService *)service
                                   error:(NSError *)error
{
  if (![self isCurrentPeripheral:peripheral]) {
    return;
  }
  if (error == nil) {
    for (CBCharacteristic *characteristic in service.characteristics) {
      CBCharacteristicProperties properties = characteristic.properties;
      if ((properties & CBCharacteristicPropertyWrite) != 0 ||
          (properties & CBCharacteristicPropertyWriteWithoutResponse) != 0) {
        [self.writeCandidates addObject:characteristic];
      }
    }
  }

  self.servicesPendingDiscovery -= 1;
  if (self.servicesPendingDiscovery == 0) {
    CBCharacteristic *selected = [self bestWriteCharacteristic];
    if (selected == nil) {
      [self failConnectionWithError:RNEscPosMakeError(
                                        @"ERR_CONNECTION_FAILED",
                                        @"No writable BLE characteristic was found",
                                        error)];
      return;
    }
    self.writeCharacteristic = selected;
    self.writeType = (selected.properties & CBCharacteristicPropertyWrite) != 0
        ? CBCharacteristicWriteWithResponse
        : CBCharacteristicWriteWithoutResponse;
    [self completeConnectWithError:nil];
  }
}

- (void)peripheral:(CBPeripheral *)peripheral
    didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
                             error:(NSError *)error
{
  if (self.writeCompletion == nil || characteristic != self.writeCharacteristic) {
    return;
  }
  if (error != nil) {
    [self finishWriteWithError:RNEscPosMakeError(
                                   @"ERR_WRITE_FAILED",
                                   @"The BLE printer rejected a data chunk",
                                   error)];
    return;
  }
  [self pumpWrite];
}

- (void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral
{
  [self pumpWrite];
}

#pragma mark - Internal state

- (NSError *)bluetoothStateErrorAllowPending:(BOOL)allowPending
{
  switch (self.centralManager.state) {
    case CBManagerStatePoweredOn:
      return nil;
    case CBManagerStateUnauthorized:
      return RNEscPosMakeError(
          @"ERR_BLUETOOTH_PERMISSION", @"Bluetooth permission has not been granted", nil);
    case CBManagerStateUnsupported:
      return RNEscPosMakeError(
          @"ERR_BLUETOOTH_DISABLED", @"Bluetooth Low Energy is not supported", nil);
    case CBManagerStatePoweredOff:
      return RNEscPosMakeError(
          @"ERR_BLUETOOTH_DISABLED", @"Bluetooth is disabled", nil);
    case CBManagerStateResetting:
    case CBManagerStateUnknown:
      return allowPending
          ? nil
          : RNEscPosMakeError(
                @"ERR_BLUETOOTH_DISABLED", @"Bluetooth is not ready yet", nil);
  }
}

- (void)completePowerWithError:(NSError *)error
{
  if (self.powerCompletion == nil) {
    return;
  }
  RNEscPosErrorCompletion completion = self.powerCompletion;
  self.powerCompletion = nil;
  self.powerGeneration += 1;
  completion(error);
}

- (void)completeScan
{
  NSMutableArray<NSDictionary<NSString *, id> *> *printers = [NSMutableArray array];
  for (CBPeripheral *peripheral in self.discovered.allValues) {
    [printers addObject:[self dictionaryForPeripheral:peripheral]];
  }
  if (self.connectedPeripheral != nil &&
      self.discovered[self.connectedPeripheral.identifier] == nil) {
    [printers addObject:[self dictionaryForPeripheral:self.connectedPeripheral]];
  }
  [printers sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
    return [left[@"name"] localizedCaseInsensitiveCompare:right[@"name"]];
  }];

  RNEscPosPrintersCompletion completion = self.scanCompletion;
  self.scanCompletion = nil;
  completion(printers, nil);
}

- (NSDictionary<NSString *, id> *)dictionaryForPeripheral:(CBPeripheral *)peripheral
{
  NSString *identifier = peripheral.identifier.UUIDString;
  return @{
    @"id" : identifier,
    @"name" : peripheral.name.length > 0 ? peripheral.name : @"BLE printer",
    @"address" : identifier,
    @"transport" : @"ble",
    @"connected" : @([self.connectedPeripheral.identifier isEqual:peripheral.identifier] &&
                      peripheral.state == CBPeripheralStateConnected &&
                      self.writeCharacteristic != nil),
  };
}

- (void)completeConnectWithError:(NSError *)error
{
  if (self.connectCompletion == nil) {
    return;
  }
  RNEscPosErrorCompletion completion = self.connectCompletion;
  self.connectCompletion = nil;
  self.connectGeneration += 1;
  completion(error);
}

- (void)failConnectionWithError:(NSError *)error
{
  CBPeripheral *peripheral = self.connectedPeripheral;
  [self resetConnectedPeripheral];
  if (peripheral != nil && peripheral.state != CBPeripheralStateDisconnected) {
    [self.centralManager cancelPeripheralConnection:peripheral];
  }
  [self completeConnectWithError:error];
}

- (BOOL)isCurrentPeripheral:(CBPeripheral *)peripheral
{
  return self.connectedPeripheral != nil &&
      [self.connectedPeripheral.identifier isEqual:peripheral.identifier];
}

- (void)resetConnectedPeripheral
{
  self.connectedPeripheral.delegate = nil;
  self.connectedPeripheral = nil;
  self.writeCharacteristic = nil;
  [self.writeCandidates removeAllObjects];
  self.servicesPendingDiscovery = 0;
}

- (CBCharacteristic *)bestWriteCharacteristic
{
  NSSet<NSString *> *preferredUUIDs = [NSSet setWithArray:@[
    @"49535343-8841-43F4-A8D4-ECBE34729BB3",
    @"FFE1",
    @"FFF1",
    @"FFF2",
    @"FF01",
    @"FF02",
    @"AE01",
    @"AE02",
    @"2AF1",
  ]];
  NSSet<NSString *> *preferredServiceUUIDs = [NSSet setWithArray:@[
    @"49535343-FE7D-4AE5-8FA9-9FAFD205E455",
    @"FFE0",
    @"FFF0",
    @"FF00",
    @"AE30",
    @"18F0",
  ]];
  CBCharacteristic *best = nil;
  NSInteger bestScore = NSIntegerMin;
  for (CBCharacteristic *candidate in self.writeCandidates) {
    NSInteger score = 0;
    if ([preferredUUIDs containsObject:candidate.UUID.UUIDString.uppercaseString]) {
      score += 1000;
    }
    if ([preferredServiceUUIDs
            containsObject:candidate.service.UUID.UUIDString.uppercaseString]) {
      score += 500;
    }
    if ((candidate.properties & CBCharacteristicPropertyWrite) != 0) {
      score += 300;
    }
    if ((candidate.properties & CBCharacteristicPropertyWriteWithoutResponse) != 0) {
      score += 200;
    }
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}

- (void)pumpWrite
{
  if (self.writeCompletion == nil || self.pendingWriteData == nil ||
      self.writeCharacteristic == nil || self.connectedPeripheral == nil) {
    return;
  }
  if (self.pendingWriteOffset >= self.pendingWriteData.length) {
    if (self.writeType == CBCharacteristicWriteWithoutResponse) {
      NSUInteger generation = self.writeGeneration;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), self.queue, ^{
        if (self.writeCompletion != nil && generation == self.writeGeneration) {
          [self finishWriteWithError:nil];
        }
      });
    } else {
      [self finishWriteWithError:nil];
    }
    return;
  }

  NSUInteger systemMaximum = [self.connectedPeripheral
      maximumWriteValueLengthForType:self.writeType];
  NSUInteger chunkSize = MAX(20, MIN((NSUInteger)180, systemMaximum));
  NSUInteger batchSize = self.writeType == CBCharacteristicWriteWithoutResponse ? 8 : 1;
  NSUInteger chunksSent = 0;
  while (self.pendingWriteOffset < self.pendingWriteData.length && chunksSent < batchSize) {
    if (self.writeType == CBCharacteristicWriteWithoutResponse &&
        !self.connectedPeripheral.canSendWriteWithoutResponse) {
      return;
    }
    NSUInteger length = MIN(chunkSize, self.pendingWriteData.length - self.pendingWriteOffset);
    NSData *chunk = [self.pendingWriteData subdataWithRange:
                                               NSMakeRange(self.pendingWriteOffset, length)];
    self.pendingWriteOffset += length;
    chunksSent += 1;
    [self.connectedPeripheral writeValue:chunk
                       forCharacteristic:self.writeCharacteristic
                                    type:self.writeType];
    if (self.writeType == CBCharacteristicWriteWithResponse) {
      return;
    }
  }

  if (self.pendingWriteOffset >= self.pendingWriteData.length) {
    [self pumpWrite];
  } else if (self.writeType == CBCharacteristicWriteWithoutResponse &&
             self.connectedPeripheral.canSendWriteWithoutResponse) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_MSEC), self.queue, ^{
      [self pumpWrite];
    });
  }
}

- (void)finishWriteWithError:(NSError *)error
{
  if (self.writeCompletion == nil) {
    return;
  }
  RNEscPosErrorCompletion completion = self.writeCompletion;
  self.writeCompletion = nil;
  self.pendingWriteData = nil;
  self.pendingWriteOffset = 0;
  self.writeGeneration += 1;
  completion(error);
}

- (void)failWriteIfNeeded:(NSError *)error
{
  if (self.writeCompletion != nil) {
    [self finishWriteWithError:error];
  }
}

@end

jest.mock('../NativeRnEscposPrinter', () => ({
  __esModule: true,
  default: {
    initialize: jest.fn(() => Promise.resolve()),
    getPrinters: jest.fn(() => Promise.resolve([])),
    connect: jest.fn(() => Promise.resolve()),
    disconnect: jest.fn(() => Promise.resolve()),
    isConnected: jest.fn(() => Promise.resolve(true)),
    printText: jest.fn(() => Promise.resolve()),
    printImageBase64: jest.fn(() => Promise.resolve()),
  },
}));

import NativeRnEscposPrinter from '../NativeRnEscposPrinter';
import { EscPosPrinter } from '../index';

const mockNativeModule = jest.mocked(NativeRnEscposPrinter);

describe('EscPosPrinter', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('uses production-safe defaults for text', async () => {
    await EscPosPrinter.printText('Olá');

    expect(mockNativeModule.printText).toHaveBeenCalledWith(
      'Olá',
      'cp850',
      5,
      true
    );
  });

  it('passes the Portuguese CP860 code page to the native encoder', async () => {
    await EscPosPrinter.printText('Não', {
      codePage: 'cp860',
      feedLines: 0,
      cut: false,
    });

    expect(mockNativeModule.printText).toHaveBeenCalledWith(
      'Não',
      'cp860',
      0,
      false
    );
  });

  it('uses 80 mm and proportional native image processing by default', async () => {
    await EscPosPrinter.printImageBase64('aGVsbG8=');

    expect(mockNativeModule.printImageBase64).toHaveBeenCalledWith(
      'aGVsbG8=',
      80,
      160,
      5,
      true
    );
  });

  it('accepts a discovered printer object when connecting', async () => {
    await EscPosPrinter.connect(
      {
        id: 'printer-id',
        address: 'printer-id',
        name: 'Printer',
        transport: 'ble',
        connected: false,
      },
      { timeoutMs: 5_000 }
    );

    expect(mockNativeModule.connect).toHaveBeenCalledWith('printer-id', 5_000);
  });

  it('rejects invalid thresholds before calling native code', () => {
    expect(() =>
      EscPosPrinter.printImageBase64('aGVsbG8=', { threshold: 300 })
    ).toThrow('threshold must be an integer between 0 and 255');
    expect(mockNativeModule.printImageBase64).not.toHaveBeenCalled();
  });

  it('rejects invalid timeouts before scanning', async () => {
    await expect(
      EscPosPrinter.getPrinters({ scanDurationMs: 100 })
    ).rejects.toThrow(
      'scanDurationMs must be between 1000 and 60000 milliseconds'
    );
    expect(mockNativeModule.getPrinters).not.toHaveBeenCalled();
  });
});

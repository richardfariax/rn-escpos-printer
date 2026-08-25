module.exports = {
  preset: 'react-native',
  testPathIgnorePatterns: ['/node_modules/', '/example/', '/lib/'],
  collectCoverageFrom: ['src/**/*.{ts,tsx}', '!src/NativeRnEscposPrinter.ts'],
};
